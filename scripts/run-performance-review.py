#!/usr/bin/env python3
"""Bounded live OpenPlane pilot. Never a claim of all-runbook certification."""
import argparse
import datetime as dt
import hashlib
import fcntl
import json
import os
from pathlib import Path
import plistlib
import runpy
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
COUNTERS = runpy.run_path(str(ROOT / 'scripts/measure-navigation.py'))
CASES = [
 ('P01','Arrow navigation'), ('P02','Zoom'), ('P03','Activate and return'),
 ('P04','Launch closed apps'), ('P05','OpenPlane startup'), ('P06','Desktop switching'),
 ('P07','Pan, minimap and saved view'), ('P08','Move and group cards'),
 ('P09','Search'), ('P10','Window discovery and previews'), ('P11','Quit selected app'),
 ('P12','Edit and persist desktops'), ('P13','Settings and shortcuts'), ('P14','Idle and sustained use')]
SCOPED = {'P01','P02','P03','P05','P06','P09','P14'}
BLOCKERS = {
 'P04':'A disposable multi-app fixture and per-app ready criteria are not available. No personal apps were quit.',
 'P07':'Repeatable pointer/trackpad routes and camera end-state observer are missing.',
 'P08':'A disposable layout plus group/drag end-state observer is missing. Personal arrangements were preserved.',
 'P10':'A controlled changing-window source and preview-freshness observer are missing.',
 'P11':'Safe disposable app/document fixture is missing. Personal apps were not quit.',
 'P12':'A disposable profile and persistence assertions are missing. Personal desktops were not edited.',
 'P13':'The settings variant manifest and visual expectations are not yet implemented.'}

class Stopped(Exception): pass

def stamp(): return dt.datetime.now(dt.timezone.utc).isoformat()
def save(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n'); tmp.replace(path)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--cancel-file',type=Path)
    args=parser.parse_args()
    if (args.output/'run.json').exists():
        existing=json.loads((args.output/'run.json').read_text())
        if existing.get('events') or existing.get('finished_at'):
            parser.error('Use a unique output directory; existing evidence must not be overwritten.')
    args.output.mkdir(parents=True,exist_ok=True)
    runfile=args.output/'run.json'; rows=[]
    run={'id':args.output.name,'title':'OpenPlane performance review','category':'Performance',
         'brief':'Measure the current live app, expose coverage gaps and propose the next decisions. Preserve full product behavior.',
         'created_at':stamp(),'status':'running','scope':'Single-build live pilot; no A/B claim and no full 14-case certification.',
         'cases':[{'id':i,'title':title,'status':'not_run' if i in SCOPED else 'blocked',
                   'reason':'Waiting for this pilot phase.' if i in SCOPED else BLOCKERS[i],
                   'samples':[]} for i,title in CASES], 'proposals':[], 'events':[], 'artifacts':[]}
    lease_dir=ROOT/'review-desk/.state';lease_dir.mkdir(exist_ok=True)
    lease=(lease_dir/'live-test.lock').open('a')
    try: fcntl.flock(lease,fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        run.update(status='blocked',error='Another live test owns this desktop.')
        save(runfile,run);return 1
    cancelled=False
    def stop(signum, frame):
        nonlocal cancelled
        cancelled=True
    signal.signal(signal.SIGTERM,stop); signal.signal(signal.SIGINT,stop)
    def check():
        if cancelled or (args.cancel_file and args.cancel_file.exists()): raise Stopped('Cancelled by the operator.')
    def publish(message=None):
        if message: run['events'].append({'at':stamp(),'message':message}); print(message,flush=True)
        save(runfile,run)
    def command(argv, timeout=25, cleanup=False):
        if not cleanup: check()
        proc=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
        until=time.monotonic()+timeout
        try:
            while True:
                try:
                    out,err=proc.communicate(timeout=.15); break
                except subprocess.TimeoutExpired:
                    if not cleanup: check()
                    if time.monotonic()>until: raise TimeoutError('Operation timed out: '+argv[0])
            if proc.returncode: raise RuntimeError(err.strip() or 'Operation failed: '+argv[0])
            return out.strip()
        except BaseException:
            try: os.killpg(proc.pid,signal.SIGTERM)
            except ProcessLookupError: pass
            try: proc.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid,signal.SIGKILL);proc.communicate()
            raise
    def apple(s,**kw): return command(['osascript','-e',s],**kw)
    def pause(seconds):
        until=time.monotonic()+seconds
        while time.monotonic()<until: check();time.sleep(min(.1,max(0,until-time.monotonic())))
    def unlocked(): COUNTERS['require_unlocked_session']()
    def front(): return apple('tell application "System Events" to get name of first application process whose frontmost is true')
    def ensure_plane():
        unlocked()
        if front()!='OpenPlane': raise Stopped('OpenPlane lost focus; input stopped to protect the active app.')
    def keys(sequence, repeats=1, spacing=.08, modifier=''):
        ensure_plane()
        script='tell application "System Events"\nrepeat '+str(repeats)+' times\n'
        for k in sequence:
            script+='if not frontmost of process "OpenPlane" then error "OpenPlane lost focus"\n'
            script+=f'key code {k}'+(f' using {modifier} down' if modifier else '')+f'\ndelay {spacing}\n'
        script+='end repeat\nend tell'
        apple(script,timeout=max(25,len(sequence)*repeats*(spacing+.08)+5))
    def pid(): return int(command(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
    def desktop(): return apple('tell application "System Events" to tell process "OpenPlane" to get value of text field 1 of scroll area 1 of window "OpenPlane"')
    def camera_state():
        p=plistlib.loads(command(['defaults','export','com.yalpani.openplane.poc','-']).encode())
        d=json.loads(p['desktopPages']);return next(v['camera'] for v in d['pages'] if v['id']==d['selectedID'])
    def measure(action):
        process=pid(); a=COUNTERS['cpu_time'](process); start=time.monotonic(); action()
        elapsed=time.monotonic()-start
        cpu=COUNTERS['cpu_time'](process)-a
        return {'seconds':elapsed,'cpu_seconds':cpu,'cpu_percent':100*cpu/elapsed,'pid':process}
    def phase(case,trial,action,label,extra=None):
        ensure_plane()
        row={'trial':trial,'variant':label,'desktop':desktop(),'at':stamp()}
        row['idle_before']=measure(lambda:pause(5))
        row['action']=measure(action)
        row['settling']=measure(lambda:pause(1))
        row['idle_after']=measure(lambda:pause(5))
        row['additional_cpu_pp']=row['action']['cpu_percent']-row['idle_before']['cpu_percent']
        if extra: row.update(extra())
        unlocked();case['samples'].append(row);publish(f"{case['id']} · {label} · trial {trial} recorded")
    def close_search():
        ensure_plane()
        visible=apple('tell application "System Events" to tell process "OpenPlane"\nif not (exists text field 1 of window "OpenPlane") then return "false"\nreturn (description of text field 1 of window "OpenPlane" is "Search apps") as text\nend tell')
        if visible=='true': keys([53],spacing=.05)
    def search(text):
        close_search()
        apple('tell application "System Events" to keystroke '+json.dumps(text));pause(.2)
    def wait_front(name,timeout=8):
        until=time.monotonic()+timeout
        while time.monotonic()<until:
            if front()==name: return
            pause(.1)
        raise TimeoutError('Expected foreground app: '+name)
    def back():
        apple('tell application "System Events" to key code 49 using {control down, option down}')
        wait_front('OpenPlane');pause(.4)
    publish('Preparing live pilot; seven case families have executable subsets.')
    backup=None; original_front=None
    try:
        unlocked();original_front=front()
        installed=Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane')
        run['environment']={'binary_sha256':hashlib.sha256(installed.read_bytes()).hexdigest(),
          'commit':command(['git','-C',str(ROOT),'rev-parse','HEAD']),
          'source_diff_sha256':hashlib.sha256(command(['git','-C',str(ROOT),'diff','--','OpenPlane']).encode()).hexdigest(),
          'runner_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'os':command(['sw_vers','-productVersion']),'machine':command(['sysctl','-n','hw.model']),
          'cpu_units':'100% = one CPU core; OpenPlane process only',
          'observer':'Mach CPU counters at phase boundaries; AX polling for coarse foreground/start availability.',
          'limitations':['No candidate build or A/B pairs.','Live personal scene, not a frozen S/R/L fixture.',
             'No presented-frame or first-pixel latency observer.','Background user apps remain running; no claim of isolated system load.',
             'Trials are current-process samples; explicit cold/warm control is not complete.']}
        backup=Path(tempfile.mkdtemp(prefix='openplane-review-'))/'preferences.plist'
        command(['defaults','export','com.yalpani.openplane.poc',str(backup)])
        run['environment']['fixture_sha256']=hashlib.sha256(backup.read_bytes()).hexdigest()
        pages=json.loads(plistlib.loads(backup.read_bytes())['desktopPages'])['pages']
        if len(pages)!=2: raise RuntimeError('This pilot requires exactly two OpenPlane desktops; prepare the fixture first.')
        run['environment']['desktop_names']=[page['title'] for page in pages]
        apple('tell application "OpenPlane" to activate');pause(1)
        # Input-state reset is real UI; no direct calls into application handlers.
        close_search()
        for case in run['cases']:
            if case['id'] not in SCOPED: continue
            check();unlocked();case['status']='running';publish(case['id']+' · '+case['title'])
            ident=case['id']
            if ident=='P01':
                for deskindex in range(2):
                    # Separate first use and warm-up metadata; do not mix warm-ups into results.
                    keys([124,125,123,126],repeats=25);pause(1)
                    keys([124,125,123,126],repeats=25);pause(1)
                    for t in range(1,6): phase(case,t,lambda:keys([124,125,123,126],25),'100 arrows · 80 ms requested')
                    if deskindex==0: keys([48]);pause(.5)
                case['reason']='CPU measured on two desktops, five trials each, two warm-up bursts per desktop. No per-trial camera/selection reset, fixed target oracle, cold/A-B comparison or frame/latency observer.'
            elif ident=='P02':
                for t in range(1,6):
                    phase(case,t,lambda:(keys([125],45,.05,'shift'),pause(.5),keys([126],45,.05,'shift')),
                          '45 zoom-in taps + 45 zoom-out taps',lambda:{'final_camera':camera_state()})
                case['reason']='Keyboard-tap zoom CPU sampled. Final persisted zoom recorded. Full bounds, held-key/pinch behavior, ten-cycle runbook and image quality are not certified.'
            elif ident=='P03':
                # Finder is already running; no closed user application is launched or quit.
                for t in range(1,6):
                    search('Finder')
                    ensure_plane();start=time.monotonic();keys([36],spacing=.01);wait_front('Finder')
                    activation=time.monotonic()-start;start=time.monotonic();back();returntime=time.monotonic()-start
                    close_search()
                    case['samples'].append({'trial':t,'target':'Finder','foreground_observed_seconds':activation,
                      'return_observed_seconds_including_400ms_settle':returntime,'at':stamp()});publish('P03 · foreground round trip recorded')
                case['reason']='Five real Finder activations and returns verified by foreground app. Coarse script/AX timings include observer overhead; they are not first-frame or usability latency. Other apps and input paths remain untested.'
            elif ident=='P05':
                for t in range(1,6):
                    ensure_plane();apple('tell application "OpenPlane" to quit');pause(.4)
                    start=time.monotonic();command(['open','/Applications/OpenPlane.app']);wait_front('OpenPlane')
                    until=time.monotonic()+15
                    while True:
                        try: title=desktop();break
                        except RuntimeError:
                            if time.monotonic()>until:raise TimeoutError('Canvas AX title unavailable')
                            pause(.1)
                    case['samples'].append({'trial':t,'launch_to_ax_canvas_seconds':time.monotonic()-start,
                      'desktop':title,'cache_state':'fresh process; OS caches uncontrolled','at':stamp()});publish('P05 · startup observed')
                    pause(1)
                case['reason']='Five process starts to accessible canvas title. Not a presented-first-frame, full-preview or interaction-ready measurement; OS caches uncontrolled.'
            elif ident=='P06':
                for t in range(1,6):
                    startdesk=desktop()
                    phase(case,t,lambda:keys([48],30,.35),'30 desktop Tab inputs · 350 ms',lambda:{'start_desktop':startdesk,'end_desktop':desktop()})
                case['reason']='CPU for 30 real Tab inputs per trial. Final desktop recorded; accepted-event count and transition latency not observed. Rapid and mouse variants remain untested.'
            elif ident=='P09':
                for t in range(1,6):
                    def queries():
                        for q in ['Finder','OpenPlane','zzzznonmatching']:
                            search(q);keys([125,126,53],spacing=.08)
                    phase(case,t,queries,'three search queries + result arrows + Escape')
                case['reason']='Search interaction CPU measured; query/selection visual oracle and per-keystroke latency missing. No pass claim for search correctness.'
            elif ident=='P14':
                ensure_plane()
                for t in range(1,6):
                    case['samples'].append({'trial':t,'idle':measure(lambda:pause(12)),'at':stamp()});publish('P14 · 12-second idle interval recorded')
                case['reason']='60 seconds of visible idle in five windows. No long mixed-use, background, leak/footprint or wakeup coverage.'
            case['status']='partial';publish(ident+' · measured subset complete; remaining coverage is explicit')
        run['status']='review'
    except (Stopped,RuntimeError,TimeoutError,OSError,ValueError,KeyError) as exc:
        run['status']='cancelled' if isinstance(exc,Stopped) else 'blocked'
        run['error']=str(exc)
        for c in run['cases']:
            if c['status']=='running': c['status']='blocked';c['reason']=str(exc)
        publish('Pilot stopped: '+str(exc))
    finally:
        # Restore only OpenPlane's saved preferences, not other apps or system caches.
        if backup and backup.exists():
            try:
                apple('tell application "OpenPlane" to quit',cleanup=True)
                command(['defaults','import','com.yalpani.openplane.poc',str(backup)],cleanup=True)
                command(['open','-g','/Applications/OpenPlane.app'],cleanup=True)
                backup.unlink();backup.parent.rmdir()
                run['restored']=True
            except Exception as exc:
                run['restored']=False;run['restore_error']=str(exc);run['recovery_backup']=str(backup)
        run['finished_at']=stamp()
        # Suggestions are evidence-linked drafts, never implementation authorization.
        run['proposals']=[
          {'id':'navigator-reuse','title':'Reuse the navigator’s rendered app content','kind':'Optimization','priority':'High',
           'summary':'The earlier controlled diagnostic isolated roughly three CPU percentage points in navigator updates.',
           'evidence':'Historical two-trial ablation: 8.16 → 5.19% and 7.78 → 4.93%. Not a result of this pilot and not an achievable-gain guarantee.',
           'evidence_path':'docs/navigator-diagnostic-cpu.json','source':'Historical experiment','confidence':'Strong candidate; gain unproven with full behavior',
           'benefit':'Potentially reduce CPU on every app switch.','cost':'Some cache memory and invalidation logic.',
           'contract':'Keep current title/icon, fade, clicks, history, hover preview and accessibility correct.',
           'next':'Implement a bounded prototype, then run P01/P03/P07/P13 A/B comparisons with unchanged functionality.',
           'depends_on':['measurement-foundation']},
          {'id':'measurement-foundation','title':'Make latency and correctness measurable','kind':'Test infrastructure','priority':'High',
           'summary':'CPU samples alone cannot certify responsiveness or correct pixels.',
           'evidence':'All executed subsets still lack at least one required latency, presented-frame or correctness observer.',
           'source':'This run · coverage audit','confidence':'Confirmed gap','benefit':'Reliable go/no-go decisions instead of CPU-only guesses.',
           'cost':'Instrumentation and calibration work; observer overhead must be measured.',
           'contract':'Exercise the live input path; distinguish first reaction, completed animation and app readiness.',
           'next':'Pilot a calibrated event-to-visible-result observer for P01/P03/P05; preserve raw events and add functional assertions.',
           'depends_on':[]},
          {'id':'safe-fixtures','title':'Create disposable app and desktop test scenes','kind':'Test infrastructure','priority':'High',
           'summary':'Opening, quitting and rearranging all apps needs a repeatable scene without personal documents.',
           'evidence':'P04/P07/P08/P10/P11/P12/P13 are not executed in this pilot; reasons are recorded per case.',
           'source':'This run · blocked coverage','confidence':'Confirmed gap','benefit':'Unlock multi-app starts, grouping, window updates and repeatable A/B pairs.',
           'cost':'Maintain manifests, dummy documents, state reset and per-app readiness rules.',
           'contract':'Restore user state, never clear personal caches or discard unsaved documents.',
           'next':'Build S/R fixtures, verify reset twice, then implement the repeated/same/different/all-app P04 route.',
           'depends_on':[]}
        ]
        if not any(c['samples'] for c in run['cases']): run['proposals']=[]
        from review_findings import enrich
        enrich(run)
        publish('Report ready for human review. No proposals have been accepted automatically.')
        lines=['# '+run['title'],'','Run: `'+run['id']+'`','',run['scope'],'','Status: '+run['status'],'',
               '| Case | Status | Evidence / limitation |','| --- | --- | --- |']
        for c in run['cases']:lines.append('| '+c['id']+' '+c['title']+' | '+c['status']+' | '+c['reason'].replace('|','/')+' |')
        lines+=['','Raw evidence: [run.json](run.json)','','No feature changes were made by this pilot. Decisions are recorded separately by Review Desk.']
        (args.output/'report.md').write_text('\n'.join(lines)+'\n')
        return 0 if run['status']=='review' else 1

if __name__=='__main__': raise SystemExit(main())
