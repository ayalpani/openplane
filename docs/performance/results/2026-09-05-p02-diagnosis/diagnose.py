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
def keys(code,n=45):
 check()
 return apple('tell application "System Events"\nrepeat '+str(n)+' times\nif not frontmost of process "OpenPlane" then error "Focus lost"\nkey code '+str(code)+' using shift down\ndelay 0.05\nend repeat\nend tell')
def route():
 keys(125); time.sleep(.5); keys(126)
def stop(*args): raise RuntimeError('Interrupted; restore user state')
signal.signal(signal.SIGTERM,stop); signal.signal(signal.SIGINT,stop)
mode=sys.argv[1]
assert mode in ('cpu','profile','frames','sample')
assert not (OUT/(mode+'.json')).exists(), 'Use a fresh output directory; preserve evidence'
lease=(ROOT/'review-desk/.state/live-test.lock').open('a')
fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB)
C['require_unlocked_session']()
backup=pathlib.Path(tempfile.mkdtemp(prefix='openplane-p02-'))/'preferences.plist'
original_front=front()
cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)])
result={'mode':mode,'samples':[],'binary_sha256':hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest(),'fixture_sha256':hashlib.sha256(backup.read_bytes()).hexdigest(),'original_camera':camera(),'started_at':time.time(),'accepted_actions':None,'succeeded_actions':None,'limitations':['Personal live scene; not frozen fixture','Input calls counted, accepted and completed action counts unavailable','No presented pixel observer','No A/B candidate']}
profile=None
try:
 apple('tell application "OpenPlane" to activate');time.sleep(1);check()
 pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']))
 result['pid']=pid
 result['desktop']=apple('tell application "System Events" to tell process "OpenPlane" to get value of text field 1 of scroll area 1 of window "OpenPlane"')
 result['search_open']=apple('tell application "System Events" to tell process "OpenPlane" to return exists text field 1 of window "OpenPlane"')
 if result['search_open']=='true': raise RuntimeError('Search/edit UI open; fixture unsuitable')
 keys(126);time.sleep(2)
 result['reset_camera']=camera()
 if result['reset_camera']['zoom']!=.06: raise RuntimeError('Minimum zoom not persisted after reset')
 if mode=='cpu':
  for i in range(8):
   check(); start_camera=camera()
   if start_camera!=result['reset_camera']: raise RuntimeError('Camera differs before trial')
   row={'trial':i,'cache_state':'first route in current warm process' if i==0 else 'warmup' if i<3 else 'measured warm','start_camera':start_camera,'requested_taps':90,'accepted_taps':None,'completed_actions':None}
   row['idle_before']=C['measure'](pid,lambda:time.sleep(5))
   row['action']=C['measure'](pid,route)
   row['settling']=C['measure'](pid,lambda:time.sleep(1))
   row['idle_after']=C['measure'](pid,lambda:time.sleep(5))
   row['end_camera']=camera();row['additional_cpu_pp']=row['action']['cpu_percent']-row['idle_before']['cpu_percent']
   result['samples'].append(row)
   (OUT/(mode+'.json')).write_text(json.dumps(result,indent=2)+'\n')
   print(mode,i,row['action']['cpu_percent'],flush=True)
 elif mode=='sample':
  log=(OUT/'sample.log').open('w')
  profile=subprocess.Popen(['sample',str(pid),'23','1','-file',str(OUT/'sample.txt')],stdout=log,stderr=subprocess.STDOUT)
  time.sleep(.5)
  result['route_start_monotonic']=time.monotonic()
  for i in range(3):
   route();time.sleep(.5)
  result['route_end_monotonic']=time.monotonic();result['requested_taps']=270
  result['end_camera']=camera()
  profile.wait(timeout=30);result['trace_exit_code']=profile.returncode
 else:
  template='Time Profiler' if mode=='profile' else 'Animation Hitches'
  log=(OUT/(mode+'.log')).open('w')
  profile=subprocess.Popen(['xcrun','xctrace','record','--template',template,'--attach',str(pid),'--time-limit','25s','--output',str(OUT/(mode+'.trace')),'--no-prompt'],stdout=log,stderr=subprocess.STDOUT)
  deadline=time.monotonic()+25
  while 'Ctrl-C to stop the recording' not in (OUT/(mode+'.log')).read_text():
   if profile.poll() is not None or time.monotonic()>deadline: raise RuntimeError('Trace did not start; see '+mode+'.log')
   time.sleep(.25)
  result['route_start_monotonic']=time.monotonic()
  for i in range(3):
   route();time.sleep(.5)
  result['route_end_monotonic']=time.monotonic();result['requested_taps']=270
  result['end_camera']=camera()
  profile.wait(timeout=40)
  result['trace_exit_code']=profile.returncode
except Exception as e:
 result['error']=str(e);print(str(e),flush=True)
finally:
 if profile and profile.poll() is None:
  profile.terminate()
  try: profile.wait(timeout=10)
  except subprocess.TimeoutExpired: profile.kill();profile.wait()
 try:
  apple('tell application "OpenPlane" to quit')
  deadline=time.monotonic()+10
  while subprocess.run(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$'],stdout=subprocess.DEVNULL).returncode==0:
   if time.monotonic()>deadline: raise RuntimeError('App did not quit; preferences backup retained')
   time.sleep(.1)
  cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
  restored=plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
  assert restored==plistlib.loads(backup.read_bytes())
  cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1)
  apple('tell application id '+json.dumps(original_front)+' to activate')
  result['restored']=True;backup.unlink();backup.parent.rmdir()
 except Exception as e: result['restore_error']=str(e);result['backup']=str(backup)
 result['finished_at']=time.time()
 (OUT/(mode+'.json')).write_text(json.dumps(result,indent=2)+'\n')
