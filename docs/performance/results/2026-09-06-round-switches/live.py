import subprocess,json,time,pathlib,plistlib,fcntl,runpy
root=pathlib.Path.cwd();out=root/'docs/performance/results/2026-09-06-round-switches'
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def prefs():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
lock=(root/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(root/'scripts/measure-navigation.py'))['require_unlocked_session']()
original=prefs();result={};gridchanged=False
try:
 apple('tell application "OpenPlane" to activate');time.sleep(.2)
 # Dismiss any existing panel using the visible close control, without sending navigation.
 apple('tell application "System Events" to tell process "OpenPlane"\nif exists (first button of window 1 whose description is "Close settings") then click (first button of window 1 whose description is "Close settings")\nend tell')
 before=apple('tell application "System Events" to tell process "OpenPlane" to get position of (first button of window 1 whose description is "Settings")')
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Settings")');time.sleep(.2)
 after=apple('tell application "System Events" to tell process "OpenPlane" to get position of (first button of window 1 whose description is "Settings")');assert before!=after
 apple('tell application "System Events" to tell process "OpenPlane" to click (first checkbox of scroll area 2 of window 1 whose description is "Grid dots")');gridchanged=True;time.sleep(.2)
 assert prefs()['showGrid']!=original.get('showGrid',True)
 cmd(['screencapture','-x','/tmp/openplane-round-switches/off.png'])
 apple('tell application "System Events" to tell process "OpenPlane" to click (first checkbox of scroll area 2 of window 1 whose description is "Grid dots")');gridchanged=False;time.sleep(.2)
 assert prefs()['showGrid']==original.get('showGrid',True)
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Close settings")')
 restored=apple('tell application "System Events" to tell process "OpenPlane" to get position of (first button of window 1 whose description is "Settings")');assert restored==before
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Settings")')
 apple('tell application "System Events" to key code 53')
 assert apple('tell application "System Events" to tell process "OpenPlane" to exists (first button of window 1 whose description is "Close settings")')=='false'
 result={'status':'PASS','open_close_and_escape':True,'grid_toggled_and_restored':True,'settings_button_position_before':before,'settings_button_position_panel_open':after,'settings_button_position_after':restored}
except Exception as e:result={'error':str(e)}
finally:
 if gridchanged:
  apple('tell application "System Events" to tell process "OpenPlane" to click (first checkbox of scroll area 2 of window 1 whose description is "Grid dots")')
 apple('tell application id "com.openai.codex" to activate')
 (out/'live.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
