import pathlib,subprocess,json,time,runpy,fcntl,hashlib
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def windows():return int(apple('tell application "System Events" to tell process "Google Chrome" to count windows'))
def front():return apple('tell application "System Events" to get bundle identifier of first application process whose frontmost is true')
lock=(ROOT/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(ROOT/'scripts/measure-navigation.py'))['require_unlocked_session']()
result={'variants':[]};originalfront=front();assert windows()==0,'Chrome already has a window; do not close user windows'
try:
 for label,app in [('before','/tmp/openplane-reopen/baseline.app'),('after','/tmp/openplane-reopen/build/Build/Products/Release/OpenPlane.app')]:
  assert windows()==0
  apple('tell application "OpenPlane" to quit');time.sleep(.7);cmd(['ditto',app,'/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
  cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(.5)
  assert front()=='com.yalpani.openplane.poc'
  apple('tell application "System Events" to keystroke "Google Chrome"');time.sleep(.5)
  cmd(['screencapture','-x',f'/tmp/openplane-reopen/{label}-selected.png'])
  assert front()=='com.yalpani.openplane.poc'
  t=time.monotonic();apple('tell application "System Events" to key code 36');time.sleep(2)
  v={'variant':label,'binary_sha256':hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest(),'requested_return':1,'chrome_windows_after':windows(),'front_bundle_after':front(),'observation_delay_seconds':time.monotonic()-t}
  cmd(['screencapture','-x',f'/tmp/openplane-reopen/{label}-result.png']);result['variants'].append(v)
  if label=='before':assert v['chrome_windows_after']==0,'Baseline unexpectedly opened Chrome'
  else:assert v['chrome_windows_after']>0 and v['front_bundle_after']=='com.google.Chrome','Candidate failed to show Chrome'
except Exception as e:result['error']=str(e)
finally:
 apple('tell application id '+json.dumps(originalfront)+' to activate')
 (OUT/'live.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
