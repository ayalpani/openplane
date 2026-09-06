#!/usr/bin/env python3
"""Local review workspace. Decisions persist; approval never executes a fix."""
import argparse
import copy
import datetime as dt
import json
import os
from pathlib import Path
import re
import secrets
import socketserver
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, unquote

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
STATUSES={'undecided','accepted','rejected','deferred','investigate'}

def now():return dt.datetime.now(dt.timezone.utc).isoformat()
def atomic(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n');os.replace(tmp,path)

class Workspace:
    def __init__(self,state_dir=None,results=None):
        self.directory=Path(state_dir or HERE/'.state');self.file=self.directory/'decisions.json'
        self.results=Path(results or ROOT/'docs/performance/results')
        self.lock=threading.RLock();self.token=secrets.token_urlsafe(24);self.active=None
        self.directory.mkdir(parents=True,exist_ok=True)
        self.state=json.loads(self.file.read_text()) if self.file.exists() else {'revision':0,'decisions':{},'audit':[],'requests':[]}
    def runs(self):
        runs=[]
        for path in sorted(self.results.glob('*/run.json'),reverse=True):
            try:r=json.loads(path.read_text())
            except (OSError,json.JSONDecodeError):continue
            r['report_path']=str(path.parent.relative_to(ROOT)/'report.md') if path.is_relative_to(ROOT) and (path.parent/'report.md').exists() else ''
            r['raw_path']=str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else ''
            runs.append(r)
        return runs
    def snapshot(self):
        with self.lock:
            self.reap()
            return {'runs':self.runs(),**copy.deepcopy(self.state),'token':self.token,
                    'active_run':self.active['id'] if self.active else None}
    def commit(self,newstate):
        newstate['revision']+=1;atomic(self.file,newstate);self.state=newstate
    def decision(self,data):
        with self.lock:
            if data.get('revision')!=self.state['revision']:raise Conflict('Another change was saved. Refresh and try again.')
            run=next((r for r in self.runs() if r['id']==data.get('run_id')),None)
            proposal=next((p for p in (run or {}).get('proposals',[]) if p['id']==data.get('proposal_id')),None)
            if proposal is None:raise ValueError('Unknown proposal.')
            status=data.get('status');note=data.get('note','')
            if status not in STATUSES or not isinstance(note,str) or len(note)>4000:raise ValueError('Invalid decision or note.')
            key=run['id']+':'+proposal['id'];state=copy.deepcopy(self.state)
            previous=state['decisions'].get(key,{'status':'undecided','note':''})
            entry={'run_id':run['id'],'proposal_id':proposal['id'],'status':status,'note':note,'at':now()}
            state['decisions'][key]=entry;state['audit'].append({**entry,'previous':previous})
            self.commit(state);return entry
    def request(self,data):
        with self.lock:
            title=data.get('title','');brief=data.get('brief','');category=data.get('category')
            if not isinstance(title,str) or not 3<=len(title.strip())<=160:raise ValueError('Use a title of 3–160 characters.')
            if not isinstance(brief,str) or not 10<=len(brief.strip())<=4000:raise ValueError('Describe the review in 10–4000 characters.')
            if category not in {'Performance','Reliability','Usability','Product discovery'}:raise ValueError('Unknown review area.')
            row={'id':'request-'+secrets.token_hex(5),'title':title.strip(),'brief':brief.strip(),'category':category,'status':'awaiting_agent','at':now()}
            state=copy.deepcopy(self.state);state['requests'].append(row);self.commit(state);return row
    def launch(self):
        with self.lock:
            self.reap()
            if self.active:raise Conflict('A live pilot is already running. Only one may control the desktop.')
            # One supported bounded adapter; user text is never executed as a command.
            ident=dt.datetime.now().strftime('%Y-%m-%d-%H%M%S')+'-'+secrets.token_hex(2)
            output=self.results/ident;output.mkdir(parents=True)
            cancel=output/'cancel.request'
            atomic(output/'run.json',{'id':ident,'title':'OpenPlane performance review','category':'Performance',
                 'status':'running','created_at':now(),'brief':'Bounded live performance pilot','scope':'Seven partial case families; other cases remain explicit gaps.','cases':[],'proposals':[],'events':[]})
            with (output/'runner.log').open('w') as log:
                proc=subprocess.Popen([sys.executable,str(ROOT/'scripts/run-performance-review.py'),'--output',str(output),'--cancel-file',str(cancel)],
                  cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            self.active={'id':ident,'process':proc,'output':output,'cancel':cancel}
            return {'id':ident}
    def cancel(self):
        with self.lock:
            self.reap()
            if not self.active:raise ValueError('No active pilot.')
            self.active['cancel'].touch();return {'status':'stopping'}
    def reap(self):
        if self.active and self.active['process'].poll() is not None:
            path=self.active['output']/'run.json';r=json.loads(path.read_text())
            if r['status']=='running':
                r.update(status='blocked',error='Runner exited before completing. Inspect runner.log.',finished_at=now());atomic(path,r)
            self.active=None

class Conflict(Exception):pass

class LocalServer(ThreadingHTTPServer):
    def server_bind(self):
        # This service is loopback-only; avoid a needless reverse-DNS lookup.
        socketserver.TCPServer.server_bind(self)
        self.server_name='localhost'
        self.server_port=self.server_address[1]


def handler(workspace):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def send(self,data,status=200,mime='application/json; charset=utf-8',headers=None):
            raw=json.dumps(data,ensure_ascii=False).encode() if mime.startswith('application/json') else data
            self.send_response(status);self.send_header('Content-Type',mime);self.send_header('Content-Length',str(len(raw)))
            self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff')
            self.send_header('Referrer-Policy','no-referrer')
            self.send_header('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'")
            for k,v in (headers or {}).items():self.send_header(k,v)
            self.end_headers();self.wfile.write(raw)
        def host_ok(self):return self.headers.get('Host') in {f'127.0.0.1:{self.server.server_port}',f'localhost:{self.server.server_port}'}
        def do_GET(self):
            if not self.host_ok():return self.send({'error':'Local host only.'},403)
            path=urlparse(self.path).path
            if path=='/api/workspace':return self.send(workspace.snapshot())
            if path=='/api/export':
                data=workspace.snapshot();data.pop('token',None)
                return self.send(data,headers={'Content-Disposition':'attachment; filename="review-desk-export.json"'})
            if path.startswith('/evidence/'):
                target=(ROOT/unquote(path.removeprefix('/evidence/'))).resolve()
                if not target.is_relative_to(ROOT/'docs') or target.suffix not in {'.json','.md'} or not target.is_file():
                    return self.send({'error':'Evidence not found.'},404)
                return self.send(target.read_bytes(),mime='text/plain; charset=utf-8')
            assets={'/':'index.html','/app.js':'app.js','/styles.css':'styles.css'}
            if path not in assets:return self.send({'error':'Not found.'},404)
            file=HERE/assets[path]
            mime={'html':'text/html','js':'text/javascript','css':'text/css'}[file.suffix[1:]]+'; charset=utf-8'
            self.send(file.read_bytes(),mime=mime)
        def do_POST(self):
            if not self.host_ok():return self.send({'error':'Local host only.'},403)
            origin=self.headers.get('Origin')
            if origin and origin not in {f'http://127.0.0.1:{self.server.server_port}',f'http://localhost:{self.server.server_port}'}:
                return self.send({'error':'Origin rejected.'},403)
            if not secrets.compare_digest(self.headers.get('X-Review-Token',''),workspace.token):return self.send({'error':'Session token required.'},403)
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<=length<=16000:raise ValueError('Request too large.')
                data=json.loads(self.rfile.read(length))
                if not isinstance(data,dict):raise ValueError('Expected an object.')
                path=urlparse(self.path).path
                if path=='/api/decision':result=workspace.decision(data)
                elif path=='/api/request':result=workspace.request(data)
                elif path=='/api/runs':result=workspace.launch()
                elif path=='/api/cancel':result=workspace.cancel()
                else:return self.send({'error':'Not found.'},404)
                self.send(result)
            except Conflict as exc:self.send({'error':str(exc)},409)
            except (ValueError,TypeError,json.JSONDecodeError) as exc:self.send({'error':str(exc)},400)
            except OSError:self.send({'error':'Could not save. Your decision has not been recorded.'},500)
    return Handler

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8766)
    parser.add_argument('--state-dir',type=Path);args=parser.parse_args()
    workspace=Workspace(args.state_dir)
    server=LocalServer(('127.0.0.1',args.port),handler(workspace))
    print(f'Review Desk: http://127.0.0.1:{server.server_port}',flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:
        if workspace.active:
            workspace.active['cancel'].touch()
            try:workspace.active['process'].wait(timeout=35)
            except subprocess.TimeoutExpired:workspace.active['process'].terminate()
        server.server_close()
