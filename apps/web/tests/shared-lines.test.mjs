import test from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {calculate} from "../src/payroll.mjs";
import {calculateTimeline} from "../src/payroll-v2.mjs";
import {assessWithLines} from "../src/assessment-period.mjs";
import {dec} from "../src/decimal.mjs";
const corpus=JSON.parse(readFileSync(new URL('../../../shared/contracts/reconciliation/configured-lines-v1.json',import.meta.url)));
assert.equal(corpus.format,'com.streamentry.linepay.configured-line-fixtures');assert.equal(corpus.version,1);
assert.equal(corpus.cases.length,29);assert.equal(new Set(corpus.cases.map(c=>c.id)).size,29);
for(const c of corpus.cases) test('shared earnings/hour contract: '+c.id,()=>{
 const timeline=c.changes.length?{id:'synthetic-line-plan',changes:c.changes}:null;
 const calculation=timeline?calculateTimeline(c.work,c.agreement,timeline):calculate(c.work,c.agreement);
 const period={id:'synthetic-line-period',start:'2026-09-07',end:'2026-09-08',zone:'UTC',rule:c.agreement};
 const scope={auditID:'synthetic-line-audit',periodID:period.id,startDate:period.start,endDate:period.end,timeZone:period.zone,confirmed:true};
 const lines={...c.lines,auditID:scope.auditID,periodID:period.id};
 const actual=assessWithLines(calculation,c.facts,period,scope,[],lines,c.work,timeline);
 assert.equal(actual.verdict,c.expected.verdict,c.arithmetic);
 assert.equal(dec(actual.gross).compare(dec(c.expected.gross)),0);
 assert.equal(dec(actual.difference).compare(dec(c.expected.difference)),0);
 assert.equal(actual.comparisons.length,c.expected.comparisons.length,c.id);
 for(const [i,e] of c.expected.comparisons.entries()){
  const a=actual.comparisons[i];assert.equal(a.field,e.field);
  assert.equal(a.unit??'money',e.unit);
  for(const key of ['expected','paid','difference'])assert.equal(dec(a[key]).compare(dec(e[key])),0,c.id+' '+e.field+' '+key);
  const wages=calculation.components.filter(p=>p.category!=='perDiem'),
   included=wages.filter(p=>p.category==='workedHours'||lines.guaranteeLayout==='includedInHourlyLines'),
   hourParts=lines.hoursBasis==='actualWork'?wages.filter(p=>p.category==='workedHours'):included,
   hourly=e.unit==='hours'?hourParts:included;
  const selected= e.source==='allCash'?calculation.components:e.source==='allWages'?wages:
   e.source==='allowance'?calculation.components.filter(p=>p.category==='perDiem'):
   e.source==='guarantees'?wages.filter(p=>p.category==='calloutGuarantee'):
   e.source==='allHourly'?included:e.source==='allWorked'?hourParts:
   hourly.filter(p=>p.multiplier===({regular:'1',overtime:'1.5',doubleTime:'2'})[e.source]);
  assert.deepEqual(a.componentIDs,selected.map(p=>p.id),c.id+' '+e.field+' source trace');
 }
 if(['needsReview','notComparable'].includes(actual.verdict))assert(actual.reasons.length);
});
