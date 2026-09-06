import subprocess,time,pathlib,fcntl,json,runpy
root=pathlib.Path.cwd();out=root/'docs/performance/results/2026-09-06-window-filter'
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
lock=(root/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(root/'scripts/measure-navigation.py'))['require_unlocked_session']()
try:
 cmd(['open','/tmp/openplane-window-filter/Fixture.app']);time.sleep(1)
 before=cmd(['/tmp/openplane-window-filter/inspect-before']);after=cmd(['/tmp/openplane-window-filter/inspect']);(out/'inventory.txt').write_text('BEFORE\n'+before+'\nAFTER\n'+after+'\n')
 apple('tell application "OpenPlane" to quit');time.sleep(.7)
 cmd(['ditto','/tmp/openplane-window-filter/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app'])
 cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(.5)
 apple('tell application "System Events" to keystroke "Window Filter Fixture"');time.sleep(1)
 cmd(['screencapture','-x','/tmp/openplane-window-filter/after-fixture.png'])
 print(before+'\nAFTER\n'+after)
finally:
 subprocess.run(['pkill','-f','^/tmp/openplane-window-filter/Fixture.app/Contents/MacOS/Fixture$'])
 apple('tell application id "com.openai.codex" to activate')
