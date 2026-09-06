"""Separate visual check; never run alongside timed measurement."""
import pathlib,json,plistlib,subprocess,time,tempfile,hashlib,ctypes
cg=ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics");cf=ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
class Point(ctypes.Structure):_fields_=[("x",ctypes.c_double),("y",ctypes.c_double)]
cg.CGEventCreateScrollWheelEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_int32,ctypes.c_int32];cg.CGEventCreateScrollWheelEvent.restype=ctypes.c_void_p
cg.CGEventSetLocation.argtypes=[ctypes.c_void_p,Point];cg.CGEventPost.argtypes=[ctypes.c_uint32,ctypes.c_void_p];cf.CFRelease.argtypes=[ctypes.c_void_p]
OUT=pathlib.Path(__file__).resolve().parent
private=pathlib.Path(tempfile.mkdtemp(prefix='openplane-grid-visual-'))
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
backup=private/'original.plist';cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)])
original=plistlib.loads(backup.read_bytes());result={'images':[]}
try:
 for side,app in [(256,'/tmp/openplane-grid/grid256.app'),(128,'/tmp/openplane-grid/build/Build/Products/Release/OpenPlane.app')]:
  for zoom in [.15,.31,.73,1.25]:
   apple('tell application "OpenPlane" to quit');time.sleep(1)
   p=dict(original);d=json.loads(p['desktopPages'])
   for page in d['pages']:
    page['camera']={'center':[100000.25,100000.75],'zoom':zoom}
    if 'lockedCamera' in page:page['lockedCamera']=dict(page['camera'])
   p['desktopPages']=json.dumps(d).encode();p['showGrid']=True;p['showDebugInformation']=True
   f=private/'fixture.plist';f.write_bytes(plistlib.dumps(p))
   cmd(['ditto',app,'/Applications/OpenPlane.app']);cmd(['defaults','import','com.yalpani.openplane.poc',str(f)]);time.sleep(.5)
   cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(1)
   assert apple('tell application "System Events" to get bundle identifier of first application process whose frontmost is true')=='com.yalpani.openplane.poc'
   event=cg.CGEventCreateScrollWheelEvent(None,0,2,0,20000)
   assert event
   cg.CGEventSetLocation(event,Point(200,300));cg.CGEventPost(0,event);cf.CFRelease(event);time.sleep(1)
   path=pathlib.Path('/tmp/openplane-grid')/f'grid-clear-{side}-{zoom}.png';cmd(['screencapture','-x',str(path)])
   result['images'].append({'tile_side':side,'zoom':zoom,'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
finally:
 apple('tell application "OpenPlane" to quit');time.sleep(1)
 if 'showGrid' not in original:cmd(['defaults','delete','com.yalpani.openplane.poc','showGrid'])
 cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)])
 assert plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))==original
 cmd(['open','-g','/Applications/OpenPlane.app']);result['restored']=True
 (OUT/'visual-clear.json').write_text(json.dumps(result,indent=2)+'\n')
 backup.unlink();(private/'fixture.plist').unlink(missing_ok=True);private.rmdir()
