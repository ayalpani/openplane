import pathlib,subprocess,json,plistlib,runpy,time,tempfile,hashlib,fcntl
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3]
N=runpy.run_path(str(ROOT/'docs/performance/results/2026-09-05-p02-fix/direct-input.py'))
C=runpy.run_path(str(ROOT/'scripts/measure-navigation.py'))
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def prefs():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
def state():
 d=json.loads(prefs()['desktopPages']);return {'selectedID':d['selectedID'],'cameras':{x['id']:x['camera'] for x in d['pages']}}
lease=(ROOT/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB);C['require_unlocked_session']()
private=pathlib.Path(tempfile.mkdtemp(prefix='openplane-crossfade-'));backup=private/'original.plist';cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)]);original=plistlib.loads(backup.read_bytes());front=apple('tell application "System Events" to get bundle identifier of first application process whose frontmost is true')
result={'variants':[],'fixture_sha256':hashlib.sha256(backup.read_bytes()).hexdigest()};capture=None
try:
 for label,app in [('before','/tmp/openplane-crossfade/baseline.app'),('after','/tmp/openplane-crossfade/build/Build/Products/Release/OpenPlane.app')]:
  apple('tell application "OpenPlane" to quit');time.sleep(1);cmd(['ditto',app,'/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app']);cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
  cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(.5)
  pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']));start=state();events=[]
  path=f'/tmp/openplane-crossfade/{label}.mov';capture=subprocess.Popen(['screencapture','-x','-v','-V','4',path],stdout=subprocess.PIPE,stderr=subprocess.PIPE);time.sleep(1)
  for flags in [0,1<<17]:
   prior=state();event=N['tap'](pid,48,flags);time.sleep(.5);after=state();assert after['selectedID']!=prior['selectedID'];assert after['cameras']==prior['cameras'];events.append({'input':event,'completed_state_change':True});time.sleep(.4)
  capture.communicate(timeout=15);assert capture.returncode==0;capture=None
  assert state()==start
  result['variants'].append({'variant':label,'build_sha256':hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest(),'events':events,'camera_and_desktop_restored':True,'video':path})
except Exception as e:result['error']=str(e)
finally:
 if capture is not None:capture.terminate();capture.communicate(timeout=10)
 apple('tell application "OpenPlane" to quit');time.sleep(1)
 cmd(['ditto','/tmp/openplane-crossfade/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)]);assert prefs()==original
 cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1);apple('tell application id '+json.dumps(front)+' to activate');result['restored_preferences']=True
 (OUT/'live.json').write_text(json.dumps(result,indent=2)+'\n');backup.unlink();private.rmdir();print(json.dumps(result,indent=2))
