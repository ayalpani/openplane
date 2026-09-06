"""Bounded grid on/off CPU diagnosis, not complete performance certification."""
import fcntl,hashlib,json,pathlib,plistlib,runpy,subprocess,tempfile,time,signal
ROOT=pathlib.Path(__file__).resolve().parents[4];OUT=pathlib.Path(__file__).resolve().parent
C=runpy.run_path(str(ROOT/'scripts/measure-navigation.py'))
N=runpy.run_path(str(ROOT/'docs/performance/results/2026-09-05-p02-fix/direct-input.py'))
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def front():return apple('tell application "System Events" to get bundle identifier of first application process whose frontmost is true')
def prefs():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
def state():
 d=json.loads(prefs()['desktopPages']);return {'selectedID':d['selectedID'],'cameras':{p['id']:p['camera'] for p in d['pages']}}
def camera():
 d=state();return d['cameras'][d['selectedID']]
def quit():
 apple('tell application "OpenPlane" to quit')
 deadline=time.monotonic()+10
 while subprocess.run(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$'],stdout=subprocess.DEVNULL).returncode==0:
  if time.monotonic()>deadline:raise RuntimeError('Quit timeout')
  time.sleep(.1)
def stop(*a):raise RuntimeError('Interrupted')
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
lease=(ROOT/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB)
C['require_unlocked_session']();original_front=front()
private=pathlib.Path(tempfile.mkdtemp(prefix='openplane-grid-'));backup=private/'original.plist';cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)])
original=plistlib.loads(backup.read_bytes());fixture=dict(original);pages=json.loads(fixture['desktopPages'])
assert len(pages['pages'])==2,'This bounded switch route requires exactly two existing desktops'
for page,zoom in zip(pages['pages'],[.31,.73]):
 page['camera']['zoom']=zoom
 if 'lockedCamera' in page:page['lockedCamera']=dict(page['camera'])
fixture['desktopPages']=json.dumps(pages).encode();fixture['showDebugInformation']=True
fixture_path=private/'fixture.plist';fixture_path.write_bytes(plistlib.dumps(fixture))
result={'started_at':time.time(),'fixture_sha256':hashlib.sha256(fixture_path.read_bytes()).hexdigest(),'samples':[],'limitations':['Personal live window content uncontrolled','No calibrated frame/latency observer','Posted taps are not individually accepted actions','Only configured desktop transition duration changes from 280 to 180 ms']}
output=OUT/'comparison.json';assert not output.exists()
def save():output.write_text(json.dumps(result,indent=2)+'\n')
posted=[];pid=None
def tap(code,flags=0,pause=.12):
 posted.append(N['tap'](pid,code,flags));time.sleep(pause)
def zoom_route():
 for _ in range(45):tap(125,1<<17,.05)
 time.sleep(.5);high=camera();assert high['zoom']==1.25,'Upper zoom not reached'
 for _ in range(45):tap(126,1<<17,.05)
 time.sleep(.5);low=camera();assert low['zoom']==.06,'Lower zoom not reached'
 return {'upper':high,'lower':low,'completed_boundary_legs':2}
def navigation():
 for _ in range(5):
  for code in [124,125,123,126]:tap(code)
 return {'requested_navigation_steps':20,'completed_navigation_steps':None}
def switching():
 before=state();last=before['selectedID'];events=[]
 for _ in range(6):
  start=time.monotonic();tap(48,pause=.45);now=state()
  assert now['selectedID']!=last,'Desktop did not switch'
  events.append({'posted_to_observed_state_seconds':time.monotonic()-start,'selectedID':now['selectedID']});last=now['selectedID']
 assert state()==before,'Desktop cameras or end desktop changed'
 return {'completed_desktop_switches':6,'observations':events}
def install(on):
 quit();cmd(['ditto','/tmp/openplane-desktop-speed/baseline.app' if on else '/tmp/openplane-desktop-speed/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app']);cmd(['defaults','import','com.yalpani.openplane.poc',str(fixture_path)]);cmd(['defaults','write','com.yalpani.openplane.poc','showGrid','-bool','true']);time.sleep(1)
 cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(.5)
 C['require_unlocked_session']()
 assert front()=='com.yalpani.openplane.poc'
 return int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
try:
 quit();cmd(['ditto','/tmp/openplane-desktop-speed/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
 result['build_sha256']=hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest()
 for pair in range(1,6):
  for on in ([True,False] if pair%2 else [False,True]):
   for case,route in [('P06',switching)]:
    pid=install(on)
    if case=='P02':
     for _ in range(45):tap(126,1<<17,.05)
     time.sleep(2);assert camera()['zoom']==.06
    for stage in ['first','warmup1','warmup2','measured']:
     row={'pair':pair,'baseline_280':on, 'duration_ms':280 if on else 180,'case':case,'stage':stage,'pid':pid,'start_state':state()}
     if stage=='measured':row['idle_before']=C['measure'](pid,lambda:time.sleep(5))
     posted.clear();observed={}
     def action():observed.update(route())
     row['action']=C['measure'](pid,action);row['observed']=observed;row['posted_events']=list(posted)
     row['settling']=C['measure'](pid,lambda:time.sleep(1))
     if stage=='measured':
      row['idle_after']=C['measure'](pid,lambda:time.sleep(5));row['additional_cpu_pp']=row['action']['cpu_percent']-row['idle_before']['cpu_percent']
     row['end_state']=state();result['samples'].append(row);save()
     if stage=='measured':print(pair,'280ms' if on else '180ms',case,round(row['action']['cpu_percent'],2),flush=True)
except Exception as e:result['error']=str(e);print('ERROR',e,flush=True)
finally:
 try:
  quit()
  if 'showGrid' not in original:subprocess.run(['defaults','delete','com.yalpani.openplane.poc','showGrid'],check=True)
  cmd(['ditto','/tmp/openplane-desktop-speed/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app'])
  cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)]);assert prefs()==original
  cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1);apple('tell application id '+json.dumps(original_front)+' to activate');result['restored']=True
  backup.unlink();fixture_path.unlink();private.rmdir()
 except Exception as e:result['restore_error']=str(e);result['private_backup']=str(backup)
 result['finished_at']=time.time();save()
