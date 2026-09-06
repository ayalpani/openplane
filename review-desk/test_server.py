import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from http.server import ThreadingHTTPServer

spec=importlib.util.spec_from_file_location('review_server',Path(__file__).with_name('server.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.results=self.root/'results';(self.results/'run-a').mkdir(parents=True)
        m.atomic(self.results/'run-a/run.json',{'id':'run-a','status':'review','proposals':[{'id':'p1','title':'A proposal'}]})
        self.workspace=m.Workspace(self.root/'state',self.results)
    def tearDown(self):self.tmp.cleanup()
    def choose(self,status,revision=0,note=''):
        return self.workspace.decision({'run_id':'run-a','proposal_id':'p1','status':status,'note':note,'revision':revision})
    def test_decisions_survive_restart_and_keep_audit(self):
        self.choose('accepted',note='Keep accessibility.')
        reloaded=m.Workspace(self.root/'state',self.results)
        self.assertEqual(reloaded.state['decisions']['run-a:p1']['status'],'accepted')
        self.assertEqual(reloaded.state['audit'][0]['previous']['status'],'undecided')
        self.assertIsNone(reloaded.active) # Approval does not launch a process.
        self.choose('rejected',revision=1,note='Change of plan.')
        self.assertEqual(len(self.workspace.state['audit']),2)
    def test_stale_or_invalid_decisions_do_not_overwrite(self):
        self.choose('deferred')
        with self.assertRaises(m.Conflict):self.choose('accepted')
        with self.assertRaises(ValueError):self.choose('running',revision=1)
        self.assertEqual(self.workspace.state['revision'],1)
        self.assertEqual(self.workspace.state['decisions']['run-a:p1']['status'],'deferred')
    def test_request_is_saved_but_never_executed(self):
        text='Investigate <script>alert(1)</script> as literal text.'
        result=self.workspace.request({'title':'Check reliability','category':'Reliability','brief':text})
        self.assertEqual(result['status'],'awaiting_agent')
        self.assertEqual(self.workspace.state['requests'][0]['brief'],text)
        self.assertIsNone(self.workspace.active)
    def test_failed_save_does_not_claim_a_decision(self):
        old=m.atomic
        try:
            def failure(*args):raise OSError('disk full')
            m.atomic=failure
            with self.assertRaises(OSError):self.choose('accepted')
            self.assertEqual(self.workspace.state['decisions'],{})
            self.assertEqual(self.workspace.state['revision'],0)
        finally:m.atomic=old
    def test_pilot_has_one_owner_cancellation_and_exit_recovery(self):
        process=Mock();process.poll.return_value=None
        with patch.object(m.subprocess,'Popen',return_value=process) as start:
            result=self.workspace.launch()
            argv=start.call_args.args[0]
            self.assertIn('run-performance-review.py',argv[1])
            self.assertEqual(self.workspace.active['id'],result['id'])
            with self.assertRaises(m.Conflict):self.workspace.launch()
            self.workspace.cancel()
            self.assertTrue(self.workspace.active['cancel'].exists())
            output=self.workspace.active['output']
            process.poll.return_value=1
            self.workspace.reap()
            self.assertIsNone(self.workspace.active)
            self.assertEqual(json.loads((output/'run.json').read_text())['status'],'blocked')
    def test_http_requires_token_and_rejects_foreign_origin(self):
        server=m.LocalServer(('127.0.0.1',0),m.handler(self.workspace))
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        base=f'http://127.0.0.1:{server.server_port}'
        body=json.dumps({'run_id':'run-a','proposal_id':'p1','status':'accepted','note':'','revision':0}).encode()
        try:
            for headers in [{'Content-Type':'application/json'}, {'Content-Type':'application/json','X-Review-Token':self.workspace.token,'Origin':'https://example.com'}]:
                with self.assertRaises(HTTPError) as error:urlopen(Request(base+'/api/decision',body,headers),timeout=2)
                self.assertEqual(error.exception.code,403)
            with urlopen(Request(base+'/api/decision',body,{'Content-Type':'application/json','X-Review-Token':self.workspace.token}),timeout=2) as response:
                self.assertEqual(json.load(response)['status'],'accepted')
            with self.assertRaises(HTTPError):urlopen(base+'/evidence/../AGENTS.md',timeout=2)
        finally:server.shutdown();server.server_close();thread.join()

if __name__=='__main__':unittest.main()
