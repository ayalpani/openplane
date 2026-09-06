import pathlib,subprocess,time,json,plistlib,fcntl,runpy
root=pathlib.Path.cwd();out=root/'docs/performance/results/2026-09-06-desktop-add'
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def prefs():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
def pages():return json.loads(prefs()['desktopPages'])
lock=(root/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(root/'scripts/measure-navigation.py'))['require_unlocked_session']()
apple('tell application "OpenPlane" to quit');time.sleep(.7)
backup=pathlib.Path('/tmp/openplane-desktop-add/preferences.plist');cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)]);original=prefs();start=pages();result={}
try:
 cmd(['ditto','/tmp/openplane-desktop-add/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
 cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(.3)
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of scroll area 1 of window 1 whose description is "New desktop")');time.sleep(.6)
 assert len(pages()['pages'])==len(start['pages'])+1
 apple('tell application "System Events" to keystroke "+"');time.sleep(.6)
 assert len(pages()['pages'])==len(start['pages'])+2
 apple('tell application "System Events" to key code 48');time.sleep(.6)
 assert len(pages()['pages'])==len(start['pages'])+2
 assert pages()['selectedID']==start['pages'][0]['id']
 cmd(['screencapture','-x','/tmp/openplane-desktop-add/tabs.png'])
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Settings")');time.sleep(.2)
 assert apple('tell application "System Events" to tell process "OpenPlane" to exists (first button of window 1 whose description is "Close settings")')=='true'
 cmd(['screencapture','-x','/tmp/openplane-desktop-add/settings.png'])
 result={'status':'PASS','click_created':1,'plus_key_created':1,'tab_wrapped_without_creating':True,'header_settings_opened':True}
except Exception as e:result={'error':str(e)}
finally:
 apple('tell application "OpenPlane" to quit');time.sleep(.7);cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)]);assert prefs()==original;result['preferences_restored']=True
 cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1);apple('tell application id "com.openai.codex" to activate');backup.unlink();(out/'live.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
