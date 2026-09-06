import pathlib,subprocess,json,plistlib,runpy,time,tempfile,hashlib,fcntl,uuid,copy
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3]
N=runpy.run_path(str(ROOT/'docs/performance/results/2026-09-05-p02-fix/direct-input.py'));C=runpy.run_path(str(ROOT/'scripts/measure-navigation.py'))
def cmd(a):return subprocess.check_output(a,text=True,timeout=30).strip()
def apple(s):return cmd(['osascript','-e',s])
def prefs():return plistlib.loads(subprocess.check_output(['defaults','export','com.yalpani.openplane.poc','-']))
def state():
 d=json.loads(prefs()['desktopPages']);return {'selectedID':d['selectedID'],'cameras':{x['id']:x['camera'] for x in d['pages']}}
lease=(ROOT/'review-desk/.state/live-test.lock').open('a');fcntl.flock(lease,fcntl.LOCK_EX|fcntl.LOCK_NB);C['require_unlocked_session']()
private=pathlib.Path(tempfile.mkdtemp(prefix='openplane-tab-queue-'));backup=private/'original.plist';cmd(['defaults','export','com.yalpani.openplane.poc',str(backup)]);original=plistlib.loads(backup.read_bytes());front=apple('tell application "System Events" to get bundle identifier of first application process whose frontmost is true')
p=dict(original);d=json.loads(p['desktopPages']);template=d['pages'][0];d['pages']=[copy.deepcopy(template) for _ in range(4)]
for i,page in enumerate(d['pages']):
 page['id']=str(uuid.uuid4()).upper();page['title']=f'Queue test {i+1}';page['camera']['zoom']=.2+i*.1
 if 'lockedCamera' in page:page['lockedCamera']=dict(page['camera'])
ids=[page['id'] for page in d['pages']];d['selectedID']=ids[0];p['desktopPages']=json.dumps(d).encode();fixture=private/'fixture.plist';fixture.write_bytes(plistlib.dumps(p))
result={'fixture_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest(),'variants':[]}
try:
 for label,app in [('before','/tmp/openplane-tab-queue/baseline.app'),('after','/tmp/openplane-tab-queue/build/Build/Products/Release/OpenPlane.app')]:
  apple('tell application "OpenPlane" to quit');time.sleep(1);cmd(['ditto',app,'/Applications/OpenPlane.app']);cmd(['codesign','--verify','--deep','--strict','/Applications/OpenPlane.app']);cmd(['defaults','import','com.yalpani.openplane.poc',str(fixture)])
  cmd(['open','/Applications/OpenPlane.app']);time.sleep(2);apple('tell application "OpenPlane" to activate');time.sleep(.5)
  pid=int(cmd(['pgrep','-f','^/Applications/OpenPlane.app/Contents/MacOS/OpenPlane$']));initial=state();assert initial['selectedID']==ids[0]
  row={'variant':label,'build_sha256':hashlib.sha256(pathlib.Path('/Applications/OpenPlane.app/Contents/MacOS/OpenPlane').read_bytes()).hexdigest(),'bursts':[]}
  cases=[('forward',[0,0,0],3 if label=='after' else 1)]
  if label=='after':cases += [('backward',[1<<17]*3,0),('mixed',[0,1<<17,0],1)]
  for name,flags_list,expected in cases:
   before=state();events=[];started=time.monotonic()
   for flags in flags_list:events.append(N['tap'](pid,48,flags));time.sleep(.015)
   observed=[];last=before['selectedID'];deadline=time.monotonic()+1.2
   while time.monotonic()<deadline:
    if N['front_pid']()!=pid:raise RuntimeError('Focus lost while observing queue')
    now=state()
    if now['selectedID']!=last:observed.append({'index':ids.index(now['selectedID']),'observed_seconds':time.monotonic()-started});last=now['selectedID']
    time.sleep(.025)
   end=state();assert end['selectedID']==ids[expected],f'{name} wrong end desktop';assert end['cameras']==initial['cameras'],'Saved cameras changed'
   row['bursts'].append({'name':name,'posted_count':3,'events':events,'observed_states':observed,'end_index':expected,'cameras_unchanged':True})
  result['variants'].append(row)
except Exception as e:result['error']=str(e)
finally:
 apple('tell application "OpenPlane" to quit');time.sleep(1);cmd(['ditto','/tmp/openplane-tab-queue/build/Build/Products/Release/OpenPlane.app','/Applications/OpenPlane.app']);cmd(['defaults','import','com.yalpani.openplane.poc',str(backup)]);assert prefs()==original
 cmd(['open','-g','/Applications/OpenPlane.app']);time.sleep(1);apple('tell application id '+json.dumps(front)+' to activate');result['restored_preferences']=True
 (OUT/'live.json').write_text(json.dumps(result,indent=2)+'\n');backup.unlink();fixture.unlink();private.rmdir();print(json.dumps(result,indent=2))
