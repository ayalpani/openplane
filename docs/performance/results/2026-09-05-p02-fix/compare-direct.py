"""Bounded P02 diagnostic, not a certification runner. Uses existing CPU counters."""
import fcntl, hashlib, json, pathlib, plistlib, runpy, subprocess, tempfile, time, sys, signal
ROOT=pathlib.Path(__file__).resolve().parents[4]
OUT=pathlib.Path(__file__).resolve().parent
C=runpy.run_path(str(ROOT/'scripts/measure-navigation.py'))
def cmd(args): return subprocess.check_output(args,text=True,timeout=30).strip()
def apple(s): return cmd(['osascript','-e',s])
def front(): return apple('tell application "System Events" to get bundle identifier of first application process whose frontmost is true')
def check():
 C['require_unlocked_session']()
 if front()!='com.yalpani.openplane.poc': raise RuntimeError('Focus lost; stopping inputs')
def camera():
 p=plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
 d=json.loads(p['desktopPages'])
 return next(x['camera'] for x in d['pages'] if x['id']==d['selectedID'])
N=runpy.run_path(str(OUT/'direct-input.py'))
posted_events=[]
def keys(code,n=45):
 check()
 pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
 for i in range(n):
  posted_events.append(N['tap'](pid,code));time.sleep(.05)
def route():
 keys(125); time.sleep(.5); keys(126)
def stop(*args): raise RuntimeError('Interrupted; restore user state')
signal.signal(signal.SIGTERM,stop); signal.signal(signal.SIGINT,stop)
# Same UI route and counters as diagnosis; alternating installed builds.
lease=(ROOT/'review-desk/.state/live-test.lock').open('a')
fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB)
C['require_unlocked_session']()
backup=pathlib.Path(tempfile.mkdtemp(prefix='openplane-p02-compare-'))/'preferences.plist'
original_front=front()
cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)])
result={'samples':[],'fixture_sha256':hashlib.sha256(backup.read_bytes()).hexdigest(),'started_at':time.time(),'limitations':['Personal scene; live window/preview changes uncontrolled','Accepted/completed individual inputs and presented-frame latency unavailable'],'original_camera':camera()}
def save(): (OUT/'comparison-direct.json').write_text(json.dumps(result,indent=2)+'\n')
def quit_plane():
 apple('tell application "OpenPlane" to quit')
 deadline=time.monotonic()+10
 while subprocess.run(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$'],stdout=subprocess.DEVNULL).returncode==0:
  if time.monotonic()>deadline: raise RuntimeError('App did not quit')
  time.sleep(.1)
def install(source):
 quit_plane()
 cmd(['ditto',str(source),'/Applications/OpenPlane.app'])
 cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
 cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
 time.sleep(1)
 try: cmd(['open','/Applications/OpenPlane.app'])
 except subprocess.CalledProcessError:
  result.setdefault('launch_retries',[]).append(time.time());time.sleep(1);cmd(['open','/Applications/OpenPlane.app'])
 time.sleep(2)
 apple('tell application "OpenPlane" to activate');time.sleep(.5);check()
assert not (OUT/'comparison-direct.json').exists()
builds={'A':pathlib.Path('/tmp/openplane-p02-ab/A/OpenPlane.app'),'B':pathlib.Path('/tmp/openplane-p02-ab/build/Build/Products/Release/OpenPlane.app')}
result['builds']={k:hashlib.sha256((v/'Contents/MacOS/OpenPlane').read_bytes()).hexdigest() for k,v in builds.items()}
try:
 for pair in range(1,6):
  for variant in ('AB' if pair%2 else 'BA'):
   install(builds[variant])
   pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
   if apple('tell application "System Events" to tell process "OpenPlane" to return exists text field 1 of window "OpenPlane"')=='true': raise RuntimeError('Unexpected search/edit field')
   keys(126);time.sleep(2)
   start=camera()
   if start['zoom']!=.06: raise RuntimeError('Minimum not reached')
   for stage in ['first','warmup1','warmup2','measured']:
    check()
    if camera()!=start: raise RuntimeError('Start camera differs')
    row={'pair':pair,'variant':variant,'stage':stage,'pid':pid,'build_hash':result['builds'][variant],'start_camera':start,'requested_taps':90,'accepted_taps':None,'completed_actions':None}
    if stage=='measured': row['idle_before']=C['measure'](pid,lambda:time.sleep(5))
    posted_events.clear()
    row['action']=C['measure'](pid,route)
    row['posted_events']=list(posted_events)
    row['settling']=C['measure'](pid,lambda:time.sleep(1))
    if stage=='measured':
     row['idle_after']=C['measure'](pid,lambda:time.sleep(5))
     row['additional_cpu_pp']=row['action']['cpu_percent']-row['idle_before']['cpu_percent']
    row['end_camera']=camera()
    row['end_state_correct']=row['end_camera']==start
    result['samples'].append(row);save()
    if not row['end_state_correct']: raise RuntimeError('End camera mismatch')
    print(pair,variant,stage,round(row['action']['cpu_percent'],2),flush=True)
except Exception as e:
 result['error']=str(e);print(str(e),flush=True)
finally:
 try:
  quit_plane()
  # Restore the original app pending assessment of the comparison.
  cmd(['ditto',str(builds['A']),'/Applications/OpenPlane.app'])
  cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
  assert plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))==plistlib.loads(backup.read_bytes())
  cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1)
  apple('tell application id '+json.dumps(original_front)+' to activate')
  result['restored']=True;backup.unlink();backup.parent.rmdir()
 except Exception as e: result['restore_error']=str(e);result['backup']=str(backup)
 result['finished_at']=time.time();save()
