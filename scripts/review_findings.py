"""Deterministic pilot interpretation. Observations are not regression claims."""
from statistics import median


def enrich(run):
    metrics=[]
    for case in run.get('cases',[]):
        rows=[s for s in case.get('samples',[]) if 'action' in s and 'idle_before' in s]
        if not rows:continue
        cpu=median(s['action']['cpu_percent'] for s in rows)
        idle=median(s['idle_before']['cpu_percent'] for s in rows)
        metrics.append({'case_id':case['id'],'title':case['title'],'samples':len(rows),
                        'action_cpu_median':cpu,'idle_cpu_median':idle,
                        'additional_cpu_median_pp':median(s['action']['cpu_percent']-s['idle_before']['cpu_percent'] for s in rows)})
    run['analysis']={'method':'Median of phase CPU observations. Not an A/B test; different actions have different input cadences.',
                    'case_metrics':metrics,'fully_verified_cases':0,
                    'measured_case_families':sum(bool(c.get('samples')) for c in run.get('cases',[]))}
    run['proposals']=[p for p in run.get('proposals',[]) if not p['id'].startswith('inspect-current-')]
    eligible=[m for m in metrics if m['samples']>=3 and m['additional_cpu_median_pp']>=5]
    if not eligible:return run
    top=max(eligible,key=lambda m:m['additional_cpu_median_pp'])
    case_id=top['case_id'];title=top['title']
    run['proposals'].insert(0,{
        'id':'inspect-current-'+case_id.lower(),'title':f'Investigate CPU work during {title.lower()}',
        'kind':'Investigation','priority':'High','source':f'This run · {case_id}',
        'summary':f'{title} has the highest observed additional CPU among the measured action subsets in this pilot.',
        'evidence':f"{top['samples']} samples: median action CPU {top['action_cpu_median']:.2f}%, idle before {top['idle_cpu_median']:.2f}%; median per-trial additional CPU {top['additional_cpu_median_pp']:.2f} percentage points. Different action cadences prevent a like-for-like ranking of implementation efficiency.",
        'evidence_path':f"docs/performance/results/{run['id']}/run.json",
        'confidence':'Measured observation; cause and improvement are unproven',
        'benefit':'Identify whether frequently used interaction work can be removed without losing responsiveness.',
        'cost':'A focused profile and controlled reproduction first; no product change is proposed yet.',
        'contract':'Keep the full visible behavior and count completed actions. Do not improve averages by dropping input or extending animation duration.',
        'next':f'Profile {case_id} separately from timed runs; connect expensive work to code, capture response/frame timing, then propose a bounded fix with an A/B acceptance test.',
        'depends_on':[]})
    return run
