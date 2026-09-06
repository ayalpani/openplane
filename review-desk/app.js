'use strict';
const $ = (s, root=document) => root.querySelector(s);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const labels={undecided:'Offen',accepted:'Ausgewählt',rejected:'Abgelehnt',deferred:'Später',investigate:'Weiter untersuchen',partial:'Measured subset',blocked:'Blocked',not_run:'Not run',running:'Running',review:'Ready for review',cancelled:'Stopped'};
let workspace,selectedRun,currentProposal=null,loading=false,lastFocus=null;
const number=(n,d=2)=>Number.isFinite(n)?n.toFixed(d):'—';
const median=values=>{const a=values.filter(Number.isFinite).sort((a,b)=>a-b);return a.length?a.length%2?a[(a.length-1)/2]:(a[a.length/2-1]+a[a.length/2])/2:null;};
const evidenceHref=path=>'/evidence/'+String(path).split('/').map(encodeURIComponent).join('/');
const run=()=>workspace?.runs.find(r=>r.id===selectedRun);
const decision=(r,p)=>workspace.decisions[r.id+':'+p.id]||{status:'undecided',note:''};
const pill=(value,text)=>`<span class="pill ${esc(value)}">${esc(text||labels[value]||value)}</span>`;
const timeLabel=value=>value?new Date(value).toLocaleString(undefined,{month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}):'Pending';
function toast(message){$('#toast').textContent=message;$('#toast').hidden=false;setTimeout(()=>$('#toast').hidden=true,4000);}
async function api(path,data){
 const options=data===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json','X-Review-Token':workspace.token},body:JSON.stringify(data)};
 const response=await fetch(path,options);const result=await response.json();
 if(!response.ok)throw new Error(result.error||'Request failed.');return result;
}
async function refresh(){
 if(loading)return;loading=true;
 try{workspace=await api('/api/workspace');if(!selectedRun||!workspace.runs.some(r=>r.id===selectedRun))selectedRun=workspace.runs[0]?.id;
 $('#connection').hidden=true;render();}
 catch(error){$('#connection').textContent='Workspace unavailable. '+error.message+' Start the local server to reconnect.';$('#connection').hidden=false;}
 finally{loading=false;}
}

const titles={
 'inspect-current-p02':'CPU-Arbeit beim Zoomen untersuchen',
 'navigator-reuse':'Titel und Icons beim App-Wechsel wiederverwenden',
 'measurement-foundation':'Reaktionszeit und korrekte Darstellung messbar machen',
 'safe-fixtures':'Sichere Testszenen für Apps und Desktops anlegen'
};
const threadURL='codex://threads/01a071b4-0e56-70e3-94e2-4d171d2a4b15';
function title(p){return titles[p.id]||p.title;}
function sorted(r){const priority={High:0,Medium:1,Low:2};return [...(r.proposals||[])].sort((a,b)=>(priority[a.priority]??3)-(priority[b.priority]??3));}
function render(){
 const r=run();
 $('#run-picker').innerHTML=workspace.runs.map(x=>`<option value="${esc(x.id)}">${esc(timeLabel(x.created_at))} · ${esc(x.title)}</option>`).join('');
 $('#run-picker').value=selectedRun;
 if(!r){$('#content').innerHTML='<p>Noch keine Analyse vorhanden.</p>';return;}
 const proposals=sorted(r);
 $('#content').innerHTML=`<details class="analysis"><summary>Die Analyse: ${esc(r.title)}</summary><h3>Auftrag</h3><p>${esc(r.brief)}</p><h3>Resultate</h3><p>${esc(r.scope)}</p><p>${(r.cases||[]).filter(c=>c.samples?.length).length} von 14 Testfamilien teilweise gemessen. Kein vollständiges Runbook bestätigt.</p>${r.error?`<p>${esc(r.error)}</p>`:''}<p>${r.report_path?`<a href="${evidenceHref(r.report_path)}" target="_blank" rel="noopener">Bericht lesen</a> · `:''}<a href="${evidenceHref(r.raw_path)}" target="_blank" rel="noopener">Messdaten</a></p><details><summary>Einzelne Tests</summary><div class="cases">${(r.cases||[]).map(c=>`<button class="text-button" data-case="${esc(c.id)}">${esc(c.id)} · ${esc(c.title)} — ${c.samples?.length||0} Messungen</button>`).join('')}</div></details></details>
 ${r.status==='running'?`<p role="status">Live-Test läuft: ${esc(r.events?.at(-1)?.message||'Vorbereitung')} <button data-action="cancel">Stoppen</button></p>`:''}
 <ol class="proposals">${proposals.map(p=>{const d=decision(r,p);return `<li><details class="proposal" data-id="${esc(p.id)}"><summary><span>${esc(title(p))}</span><span class="decision-label">${esc(labels[d.status])}</span></summary><div class="proposal-body"><h3>Analyse</h3><p>${esc(p.summary)}</p><h3>Auftrag</h3><p>${esc(p.next)}</p><h3>Resultate</h3><p>${esc(p.evidence)}</p><p class="muted">${esc(p.confidence)}${p.evidence_path?` · <a href="${evidenceHref(p.evidence_path)}" target="_blank" rel="noopener">Quelle</a>`:''}</p><h3>Vorgeschlagene Schritte</h3><p>${esc(p.benefit)}</p><p>Aufwand: ${esc(p.cost)}</p><p>Erhalten bleiben muss: ${esc(p.contract)}</p>${p.depends_on?.length?`<p>Zuerst: ${p.depends_on.map(id=>esc(title(r.proposals.find(x=>x.id===id)||{id,title:id}))).join(', ')}.</p>`:''}<form class="decision-form" data-id="${esc(p.id)}"><label>Deine Entscheidung<select name="status">${['undecided','accepted','investigate','deferred','rejected'].map(s=>`<option value="${s}" ${s===d.status?'selected':''}>${esc(labels[s])}</option>`).join('')}</select></label><label>Kommentar oder Frage<textarea name="note" rows="2" maxlength="4000" placeholder="Optional">${esc(d.note)}</textarea></label><div class="actions"><button type="submit" class="primary">Speichern</button><button type="button" data-discuss="${esc(p.id)}">In Codex besprechen ↗</button></div><p class="form-error" role="status"></p></form></div></details></li>`;}).join('')||'<li>Für diesen Lauf gibt es noch keine Vorschläge.</li>'}</ol>`;
 $('#saved-requests').innerHTML=workspace.requests.map(x=>`<p><strong>${esc(x.title)}</strong><br>${esc(x.brief)}<br><span class="muted">Wartet auf Bearbeitung</span></p>`).join('')||'<p>Noch keine weiteren Aufträge.</p>';
 $('#history').innerHTML=[...workspace.audit].reverse().map(x=>`<p>${esc(timeLabel(x.at))} · ${esc(title(workspace.runs.find(r=>r.id===x.run_id)?.proposals.find(p=>p.id===x.proposal_id)||{id:x.proposal_id,title:x.proposal_id}))}: ${esc(labels[x.status])}${x.note?`<br>${esc(x.note)}`:''}</p>`).join('')||'<p>Noch keine Entscheidungen.</p>';
}
function showDialog(dialog){lastFocus=document.activeElement;dialog.showModal();}
function closeDialog(dialog){dialog.close();lastFocus?.focus();}
function discussionContext(r,p,values){
 return ['Bitte besprich mit mir diesen Vorschlag aus dem OpenPlane Decision Board. Noch keine Umsetzung starten.',
 'Projekt: /Users/ayalpani/dev/_products/openplane',`Lauf: ${r.id}`,`Vorschlag: ${p.id} — ${title(p)}`,
 `Analyse: ${p.summary}`,`Auftrag: ${p.next}`,`Resultate: ${p.evidence}`,`Aussagekraft: ${p.confidence}`,
 `Nutzen: ${p.benefit}`,`Aufwand: ${p.cost}`,`Erhalten bleiben muss: ${p.contract}`,
 `Abhängigkeiten: ${(p.depends_on||[]).join(', ')||'Keine'}`,`Entscheidung im Formular: ${labels[values.status]} (bitte gespeicherten Stand prüfen)`,
 `Meine Frage / Notiz: ${values.note||'Bitte erläutere Nutzen, Preis und die nächste sinnvolle Entscheidung.'}`,
 `Umfang des Laufs: ${r.scope}`,`Bericht: ${r.report_path}`,`Rohdaten: ${r.raw_path}`,`Quelle des Vorschlags: ${p.evidence_path}`].join('\n\n');
}
async function discuss(form,id){
 const r=run(),p=r.proposals.find(p=>p.id===id),context=discussionContext(r,p,Object.fromEntries(new FormData(form)));
 const status=$('.form-error',form);
 try{await navigator.clipboard.writeText(context);status.textContent='Kontext kopiert. In Codex mit ⌘V einfügen und senden.';window.location.href=threadURL;}
 catch(error){$('#handoff-text').value=context;$('#codex-link').href=threadURL;showDialog($('#handoff-dialog'));}
}
function openCase(id){
 const c=run().cases.find(c=>c.id===id);if(!c)return;currentProposal=null;
 let observations='';
 if(c.id==='P05'&&c.samples?.length){
  const values=c.samples.map(s=>s.launch_to_ax_canvas_seconds).filter(Number.isFinite);
  const mean=values.reduce((a,b)=>a+b,0)/values.length;
  observations=`<div class="detail-evidence"><span class="eyebrow">START TO ACCESSIBLE CANVAS TITLE</span><p>Mean <strong>${number(mean,3)} s</strong> · Median ${number(median(values),3)} s · ${values.length} process starts</p><p>Includes launch command and AX polling. This is not time to first visible frame or full app readiness.</p></div>`;
 }else if(c.id==='P03'&&c.samples?.length){
  observations=`<div class="detail-evidence"><span class="eyebrow">OBSERVED FOREGROUND TRANSITIONS</span><p>Finder: median ${number(median(c.samples.map(s=>s.foreground_observed_seconds)),3)} s.</p><p>Return: median ${number(median(c.samples.map(s=>s.return_observed_seconds_including_400ms_settle)),3)} s, including a fixed 400 ms settling wait.</p><p>Coarse observer timings, not interaction-ready latency.</p></div>`;
 }
 const cpuRows=(c.samples||[]).filter(s=>s.action||s.idle);
 if(cpuRows.length)observations+=`<div class="sample-scroll"><table class="sample-table"><thead><tr><th>Trial</th><th>Scene</th><th>Idle before</th><th>Action CPU</th><th>Idle after</th><th>Extra CPU</th></tr></thead><tbody>${cpuRows.map(s=>`<tr><td>${esc(s.trial)}</td><td>${esc(s.desktop||'—')}</td><td>${number(s.idle_before?.cpu_percent??s.idle?.cpu_percent)}%</td><td>${s.action?number(s.action.cpu_percent)+'%':'—'}</td><td>${s.idle_after?number(s.idle_after.cpu_percent)+'%':'—'}</td><td>${Number.isFinite(s.additional_cpu_pp)?number(s.additional_cpu_pp)+' pp':'—'}</td></tr>`).join('')}</tbody></table></div>`;
 $('#detail-content').innerHTML=`<div class="dialog-top"><span class="eyebrow">LIVE CASE ${esc(c.id)}</span><button class="icon-button close-dialog" aria-label="Close">×</button></div><h2 id="detail-title">${esc(c.title)}</h2>${pill(c.status)}<p class="detail-summary">${esc(c.reason)}</p><div class="info-box">A measured subset is not a full runbook pass. Missing latency, frame or correctness coverage remains open. CPU percentages refer to one CPU core used by OpenPlane.</div>${observations}<details><summary>Inspect all raw observations (${c.samples?.length||0})</summary><pre>${esc(JSON.stringify(c.samples||[],null,2))}</pre></details><a class="evidence-link" href="${evidenceHref('docs/performance/runbooks.md')}" target="_blank" rel="noopener">Read the test contract ↗</a>`;
 showDialog($('#detail-dialog'));
}

document.addEventListener('click',async event=>{
 const b=event.target.closest('button');if(!b)return;
 if(b.classList.contains('close-dialog'))return closeDialog(b.closest('dialog'));
 if(b.dataset.case)return openCase(b.dataset.case);
 if(b.dataset.discuss)return discuss(b.closest('form'),b.dataset.discuss);
 if(b.id==='new-request')return showDialog($('#request-dialog'));
 if(b.dataset.action==='run')return showDialog($('#run-dialog'));
 if(b.dataset.action==='cancel'){try{await api('/api/cancel',{});toast('Test wird beendet.');}catch(e){toast(e.message);}return;}
 if(b.id==='start-run'){
  b.disabled=true;try{const result=await api('/api/runs',{});selectedRun=result.id;closeDialog($('#run-dialog'));await refresh();}catch(e){$('.form-error',$('#run-dialog')).textContent=e.message;}finally{b.disabled=false;}
 }
});
document.addEventListener('change',event=>{if(event.target.id==='run-picker'){selectedRun=event.target.value;render();}});
document.addEventListener('submit',async event=>{
 const form=event.target;if(!form.matches('.decision-form,#request-form'))return;event.preventDefault();
 const button=$('button[type="submit"]',form),error=$('.form-error',form);button.disabled=true;error.textContent='';
 try{const values=Object.fromEntries(new FormData(form));
  if(form.id==='request-form'){await api('/api/request',values);form.reset();closeDialog($('#request-dialog'));await refresh();toast('Auftrag gespeichert. Wartet auf Bearbeitung.');}
  else{await api('/api/decision',{...values,run_id:selectedRun,proposal_id:form.dataset.id,revision:workspace.revision});workspace=await api('/api/workspace');const id=form.dataset.id;render();const detail=[...document.querySelectorAll('.proposal')].find(d=>d.dataset.id===id);detail.open=true;$('.form-error',detail).textContent='Gespeichert. Eine Umsetzung wurde nicht gestartet.';$('button[type=submit]',detail).focus({preventScroll:true});}
 }catch(e){error.textContent=e.message;}finally{button.disabled=false;}
});
setInterval(()=>{if(workspace?.runs.some(r=>r.status==='running')&&!document.querySelector('dialog[open],.proposal[open]'))refresh();},4000);
refresh();
