import json,pathlib,statistics
p=pathlib.Path(__file__).resolve().parent
d=json.loads((p/'comparison.json').read_text());result={}
for case in ['P01','P02','P06']:
 r={}
 for on in [True,False]:
  samples=[s for s in d['samples'] if s['case']==case and s['grid_on']==on and s['stage']=='measured']
  if not samples:continue
  r['on' if on else 'off']={'n':len(samples)}
  for phase in ['idle_before','action','idle_after']:
   values=[s[phase]['cpu_percent'] for s in samples];r['on' if on else 'off'][phase]={'values':values,'median':statistics.median(values),'range':[min(values),max(values)]}
  values=[s['additional_cpu_pp'] for s in samples];r['on' if on else 'off']['additional_cpu_pp']={'values':values,'median':statistics.median(values)}
 pairs=[]
 for pair in range(1,6):
  samples={s['grid_on']:s for s in d['samples'] if s['case']==case and s['pair']==pair and s['stage']=='measured'}
  if len(samples)!=2:continue
  a,b=samples[True],samples[False]
  pairs.append({'pair':pair,'action_cpu_pp_saved_when_off':a['action']['cpu_percent']-b['action']['cpu_percent'],'cpu_time_percent_saved_when_off':100*(1-b['action']['cpu_seconds']/a['action']['cpu_seconds']),'action_seconds_on':a['action']['seconds'],'action_seconds_off':b['action']['seconds']})
 r['pairs']=pairs;result[case]=r
(p/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
