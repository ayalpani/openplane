import pathlib,subprocess,time,json,plistlib,fcntl,runpy
root=pathlib.Path.cwd();out=root/'docs/performance/results/2026-09-06-settings-motion'
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def grid():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-'])).get('showGrid',True)
lock=(root/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(root/'scripts/measure-navigation.py'))['require_unlocked_session']()
apple('tell application "OpenPlane" to quit');time.sleep(.7);cmd(['ditto','/tmp/openplane-settings-motion/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app']);cmd(['open','/Applications/OpenPlane.app']);time.sleep(3);apple('tell application "OpenPlane" to activate');time.sleep(.5)
original=grid();result={};capture=None
try:
 capture=subprocess.Popen(['screencapture','-x','-v','-V','4','/tmp/openplane-settings-motion/motion.mov'],stdout=subprocess.PIPE,stderr=subprocess.PIPE);time.sleep(1)
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Settings")');time.sleep(.5)
 pos=apple('tell application "System Events" to tell process "OpenPlane" to get position of static text "Grid dots" of scroll area 2 of window 1');x,y=[int(v) for v in pos.split(', ')]
 apple(f'tell application "System Events" to click at {{{x+30}, {y+8}}}');time.sleep(.2);assert grid()!=original
 apple(f'tell application "System Events" to click at {{{x-28}, {y+8}}}');time.sleep(.2);assert grid()==original
 cmd(['screencapture','-x','/tmp/openplane-settings-motion/panel.png'])
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Close settings")');time.sleep(.4)
 capture.communicate(timeout=10);assert capture.returncode==0;capture=None
 result={'status':'PASS','text_click_toggled':True,'icon_click_toggled_back':True,'grid_restored':True,'opening_and_closing_recorded':True}
finally:
 if capture is not None:capture.terminate();capture.communicate(timeout=5)
 if grid()!=original:
  apple('tell application "System Events" to tell process "OpenPlane" to click (first checkbox of scroll area 2 of window 1 whose description is "Grid dots")')
 apple('tell application id "com.openai.codex" to activate');(out/'live.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
