"""Native CGEvent input; timestamps represent posting, not app acceptance."""
import ctypes, time
cg=ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
cf=ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
carbon=ctypes.CDLL('/System/Library/Frameworks/Carbon.framework/Carbon')
class PSN(ctypes.Structure):
 _fields_=[('high',ctypes.c_uint32),('low',ctypes.c_uint32)]
cg.CGEventCreateKeyboardEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint16,ctypes.c_bool];cg.CGEventCreateKeyboardEvent.restype=ctypes.c_void_p
cg.CGEventSetFlags.argtypes=[ctypes.c_void_p,ctypes.c_uint64]
cg.CGEventPost.argtypes=[ctypes.c_uint32,ctypes.c_void_p]
cf.CFRelease.argtypes=[ctypes.c_void_p]
def front_pid():
 psn=PSN();pid=ctypes.c_int()
 if carbon.GetFrontProcess(ctypes.byref(psn)) or carbon.GetProcessPID(ctypes.byref(psn),ctypes.byref(pid)):raise RuntimeError('Cannot observe foreground PID')
 return pid.value
def tap(pid,code,flags=1<<17):
 if front_pid()!=pid:raise RuntimeError('Focus lost before key event')
 event=cg.CGEventCreateKeyboardEvent(None,code,True)
 if not event:raise RuntimeError('Keyboard event allocation failed')
 try:
  cg.CGEventSetFlags(event,flags);start=time.monotonic();cg.CGEventPost(0,event)
 finally:cf.CFRelease(event)
 try:time.sleep(.01)
 finally:
  event=cg.CGEventCreateKeyboardEvent(None,code,False)
  if event:
   cg.CGEventSetFlags(event,flags);cg.CGEventPost(0,event);cf.CFRelease(event)
 if front_pid()!=pid:raise RuntimeError('Focus lost during tap')
 return {'code':code,'posted_down':start,'posted_up_before':time.monotonic()}
