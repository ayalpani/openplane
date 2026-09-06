import subprocess,time,pathlib,json,fcntl,runpy
root=pathlib.Path.cwd();out=root/'docs/performance/results/2026-09-06-minimap-controls'
def cmd(a):return subprocess.check_output(a,text=True,timeout=20).strip()
def apple(s):return cmd(['osascript','-e',s])
lock=(root/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
runpy.run_path(str(root/'scripts/measure-navigation.py'))['require_unlocked_session']()
apple('tell application "OpenPlane" to quit');time.sleep(.7)
cmd(['ditto','/tmp/openplane-minimap-controls/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app']);cmd(['open','/Applications/OpenPlane.app']);time.sleep(2)
result={}
try:
 apple('tell application "OpenPlane" to activate')
 for _ in range(20):
  try:
   if apple('tell application "System Events" to tell process "OpenPlane" to exists (first button of window 1 whose description is "Settings")')=='true':break
  except subprocess.CalledProcessError:pass
  time.sleep(.3)
 positions={}
 for label in ['Settings','Search apps','Fit all windows','Lock current desktop view']:
  positions[label]=[int(n) for n in apple('tell application "System Events" to tell process "OpenPlane" to get position of (first button of window 1 whose description is '+json.dumps(label)+')').split(', ')]
 assert positions['Search apps'][0]<positions['Fit all windows'][0]<positions['Lock current desktop view'][0]
 assert positions['Settings'][0]==positions['Lock current desktop view'][0]
 x,y=positions['Settings'];cmd(['screencapture','-x','-R',f'{x-235},{y-6},280,270','/tmp/openplane-minimap-controls/minimap.png'])
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Settings")');time.sleep(.2)
 assert apple('tell application "System Events" to tell process "OpenPlane" to exists (first button of window 1 whose description is "Close settings")')=='true'
 apple('tell application "System Events" to tell process "OpenPlane" to click (first button of window 1 whose description is "Close settings")')
 result={'status':'PASS','positions':positions,'settings_open_close':True}
except Exception as e:result={'error':str(e)}
finally:
 apple('tell application id "com.openai.codex" to activate');(out/'live.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
