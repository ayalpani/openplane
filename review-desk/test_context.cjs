const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const sandbox={document:{addEventListener(){}},setInterval(){},fetch:()=>new Promise(()=>{})};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(__dirname+'/app.js','utf8'),sandbox);
const r=JSON.parse(fs.readFileSync(__dirname+'/../docs/performance/results/2026-09-05-review-004/run.json'));
r.report_path='docs/performance/results/'+r.id+'/report.md';r.raw_path='docs/performance/results/'+r.id+'/run.json';
test('discussion carries exact evidence, limitations, decision and question without executing work',()=>{
 for(const p of r.proposals){const text=sandbox.discussionContext(r,p,{status:'rejected',note:'Warum? <script> & "'});
 for(const expected of [r.id,p.id,p.evidence,p.contract,p.cost,p.next,r.scope,r.raw_path,r.report_path,'Abgelehnt','Warum? <script> & "','Noch keine Umsetzung starten'])assert.ok(text.includes(expected),expected);
 }
});
test('priority sorting is stable and does not mutate source evidence',()=>{
 const original={proposals:[{id:'a',priority:'Low'},{id:'b',priority:'High'},{id:'c',priority:'High'}]};
 assert.equal(sandbox.sorted(original).map(p=>p.id).join(','),'b,c,a');assert.equal(original.proposals[0].id,'a');
});
test('proposal content is escaped for HTML',()=>assert.equal(vm.runInContext('esc',sandbox)('<img src=x onerror="alert(1)">'), '&lt;img src=x onerror=&quot;alert(1)&quot;&gt;'));
