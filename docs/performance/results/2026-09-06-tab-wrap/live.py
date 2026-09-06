import pathlib,subprocess,time,json,plistlib,fcntl,runpy,hashlib
root=pathlib.Path.cwd();out=root/'docs/performance/results/2026-09-06-tab-wrap';tmp=pathlib.Path('/tmp/openplane-tab-wrap')
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def prefs():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
def pages():return json.loads(prefs()['desktopPages'])
lock=(root/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(root/'scripts/measure-navigation.py'))['require_unlocked_session']()
result={'baseline_binary_sha256':hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest()}
apple('tell application "OpenPlane" to quit');time.sleep(.7)
backup=tmp/'preferences.plist';cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)]);original=prefs()
video=None
try:
 cmd(['ditto',str(tmp/'build/Build/Products/Release/OpenPlane.app'),'/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
 cmd(['open','/Applications/OpenPlane.app']);time.sleep(3);apple('tell application "OpenPlane" to activate');time.sleep(.5)
 if len(pages()['pages'])<2:
  apple('tell application "System Events" to keystroke "+"');time.sleep(.5)
 before=pages();ids=[p['id'] for p in before['pages']];index=ids.index(before['selectedID'])
 for _ in range(len(ids)-1-index):
  apple('tell application "System Events" to key code 48');time.sleep(.3)
 assert pages()['selectedID']==ids[-1]
 video=subprocess.Popen(['screencapture','-x','-v','-V','3',str(tmp/'wrap.mov')]);time.sleep(.8)
 apple('tell application "System Events" to key code 48');time.sleep(.4)
 assert pages()['selectedID']==ids[0]
 apple('tell application "System Events" to key code 48');time.sleep(.4)
 assert pages()['selectedID']==ids[1]
 video.wait(timeout=10);cmd(['screencapture','-x',str(tmp/'after.png')])
 result.update(status='PASS',completed_recorded_tabs=2,wrap_target_correct=True,next_target_correct=True)
except Exception as e: result.update(status='FAIL',error=str(e))
finally:
 if video and video.poll() is None:video.terminate();video.wait()
 apple('tell application "OpenPlane" to quit');time.sleep(.7);cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)]);assert prefs()==original;result['preferences_restored']=True
 cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1);apple('tell application id "com.openai.codex" to activate');backup.unlink();(out/'live.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
