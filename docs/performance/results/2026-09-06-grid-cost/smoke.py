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
N=runpy.run_path(str(ROOT/'docs/performance/results/2026-09-05-p02-fix/direct-input.py'))
def keys(code,n=45):
 check()
 pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
 for i in range(n): N['tap'](pid,code);time.sleep(.05)
def route():
 keys(125); time.sleep(.5); keys(126)
def stop(*args): raise RuntimeError('Interrupted; restore user state')
signal.signal(signal.SIGTERM,stop); signal.signal(signal.SIGINT,stop)

lease=(ROOT/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB)
C['require_unlocked_session']()
variant=sys.argv[1]
assert variant in ('A','B')
output_name='smoke-'+variant+'.json'
assert not (OUT/output_name).exists()
backup=pathlib.Path(tempfile.mkdtemp(prefix='openplane-p02-smoke-'))/'preferences.plist'
original_front=front();cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)])
result={'cases':{},'screenshots':[],'started_at':time.time(),'limitations':['Coarse script/AX timings are not first-frame latency','No pinch or pointer-route automation; held-key bounds checked separately','P04 disposable app fixture unavailable'],'fixture_sha256':hashlib.sha256(backup.read_bytes()).hexdigest()}
def save(): (OUT/output_name).write_text(json.dumps(result,indent=2)+'\n')
def key(code,mods=''):
 check();apple('tell application "System Events" to key code '+str(code)+(' using '+mods+' down' if mods else ''))
def hold(code,seconds=4):
 check()
 pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
 cg=N['cg'];cf=N['cf']
 event=cg.CGEventCreateKeyboardEvent(None,code,True)
 if not event: raise RuntimeError('Event allocation failed')
 cg.CGEventSetFlags(event,1<<17);cg.CGEventPost(0,event);cf.CFRelease(event)
 try:
  end=time.monotonic()+seconds
  while time.monotonic()<end:
   if N['front_pid']()!=pid: raise RuntimeError('Focus lost during held key')
   time.sleep(.02)
 finally:
  event=cg.CGEventCreateKeyboardEvent(None,code,False)
  if event:
   cg.CGEventSetFlags(event,1<<17);cg.CGEventPost(0,event);cf.CFRelease(event)
 time.sleep(1)
 return camera()
def desk(): return apple('tell application "System Events" to tell process "OpenPlane" to get value of text field 1 of scroll area 1 of window "OpenPlane"')
def wait_front(bundle):
 deadline=time.monotonic()+8
 while front()!=bundle:
  if time.monotonic()>deadline: raise RuntimeError('Unexpected focus')
  time.sleep(.1)
def shot(name):
 path=pathlib.Path('/tmp/openplane-grid')/(variant+'-'+name+'.png')
 try:
  cmd(['screencapture','-x',str(path)]);result['screenshots'].append(str(path))
 except Exception as e: result.setdefault('screenshot_errors',[]).append(str(e))
try:
 apple('tell application "OpenPlane" to quit');time.sleep(1)
 source='/tmp/openplane-grid/baseline.app' if variant=='A' else '/tmp/openplane-grid/grid256.app'
 cmd(['ditto',source,'/Applications/OpenPlane.app'])
 cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
 cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
 cmd(['defaults','write','com.yalpani.openplane.poc','showDebugInformation','-bool','true'])
 time.sleep(1)
 start=time.monotonic();cmd(['open','/Applications/OpenPlane.app']);time.sleep(.5);apple('tell application "OpenPlane" to activate');wait_front('com.yalpani.openplane.poc')
 title=desk();result['cases']['P05']={'status':'partial','launch_to_ax_seconds':time.monotonic()-start,'desktop':title};time.sleep(2)
 pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
 result['binary_sha256']=hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest()
 def arrows():
  check();apple('tell application "System Events"\nrepeat 25 times\n'+''.join('if not frontmost of process "OpenPlane" then error "Focus lost"\nkey code '+str(k)+'\ndelay 0.08\n' for k in [124,125,123,126])+'end repeat\nend tell')
 result['cases']['P01']={'status':'partial','requested':100,'phase':C['measure'](pid,arrows),'accepted':None};time.sleep(1)
 keys(126);time.sleep(2);low=camera();shot('candidate-minimum')
 keys(125);time.sleep(2);high=camera();shot('candidate-maximum')
 keys(126);time.sleep(2);end=camera()
 held_high=hold(125);held_low=hold(126)
 result['held_zoom']={'high':held_high,'low':held_low,'bounds_correct':held_high['zoom']==1.25 and held_low['zoom']==.06}
 for i in range(5): key(125,'shift');key(126,'shift')
 key(124);time.sleep(1)
 result['cases']['P02']={'status':'partial','low':low,'high':high,'end':end,'bounds_correct':low['zoom']==.06 and high['zoom']==1.25 and end['zoom']==.06,'reversals_requested':5,'arrow_interruption_requested':True};save();print('P01/P02/P05 complete',flush=True)
 trips=[]
 for i in range(3):
  check();apple('tell application "System Events" to keystroke "Finder"');time.sleep(.4)
  key(36);wait_front('com.apple.finder')
  apple('tell application "System Events" to key code 49 using {control down, option down}')
  wait_front('com.yalpani.openplane.poc');time.sleep(.4);key(53)
  trips.append({'finder_and_return_observed':True})
 result['cases']['P03']={'status':'partial','trips':trips}
 initial=desk()
 for i in range(10): key(48);time.sleep(.35)
 time.sleep(1)
 result['cases']['P06']={'status':'partial','requested':10,'start':initial,'end':desk(),'accepted':None}
 check();result['cases']['P14']={'status':'partial','idle':C['measure'](pid,lambda:time.sleep(30))}
 result['cases']['P04']={'status':'BLOCKED','reason':'No dedicated disposable app/start-readiness fixture; PERF-001/005'}
except Exception as e: result['error']=str(e);print(str(e),flush=True)
finally:
 try:
  apple('tell application "OpenPlane" to quit');time.sleep(1)
  if 'showGrid' not in plistlib.loads(backup.read_bytes()): subprocess.run(['defaults','delete','com.yalpani.openplane.poc','showGrid'],check=True)
  cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
  assert plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))==plistlib.loads(backup.read_bytes())
  cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1)
  apple('tell application id '+json.dumps(original_front)+' to activate')
  result['restored_preferences']=True;backup.unlink();backup.parent.rmdir()
 except Exception as e: result['restore_error']=str(e);result['backup']=str(backup)
 result['finished_at']=time.time();save()
