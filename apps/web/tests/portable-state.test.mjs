import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {emptyState,decodeState,validateState,snapshot,inspectSnapshot} from '../src/state.mjs';
import {validatePortable,readPortable,portableSnapshot,importedCoverage,importedConfirmationRequired,confirmedImportedCopy} from '../src/portable-state.mjs';
import schema from '../src/portable-schema.mjs';
import {encryptBackup,decryptBackup} from '../src/backup.mjs';
import {assess} from '../src/assessment.mjs';
import {calculate} from '../src/payroll.mjs';
import {currentCalculation} from '../src/calculation-context.mjs';
const read=path=>JSON.parse(readFileSync(new URL(path,import.meta.url)));
const source=()=>decodeState(read('./fixtures/web-state-v1.json'));
const exported=state=>JSON.parse(new TextDecoder().decode(portableSnapshot(state)));
const bytes=value=>new TextEncoder().encode(JSON.stringify(value));
const captureReview=(name,document)=>{if(process.env.PORTABLE_REVIEW_ARTIFACT_DIR)writeFileSync(process.env.PORTABLE_REVIEW_ARTIFACT_DIR+'/'+name+'.json',JSON.stringify(document));};
const financial=value=>{const {source,exportedAtEpochSeconds,...facts}=value;return facts;};
const sameFinancial=(actual,expected)=>{assert.deepEqual(financial(actual),financial(expected));assert.equal(actual.source.client,'web');assert.equal(actual.source.localStateSchema,9);};
const contractRoot=process.env.PORTABLE_CONTRACT_ROOT??new URL('../../../shared/contracts/portable-state/',import.meta.url).pathname;

test('offline schema is byte-equivalent JSON to the shared frozen contract',()=>{
  assert.deepEqual(schema,JSON.parse(readFileSync(contractRoot+'/schema-v1.json')));
});
test('real legacy browser source maps every fact, exact work instant, snapshot and frozen receipt',()=>{
  const state=source(),document=exported(state),period=state.periods[0],receipt=document.paycheckReceipts[0];
  validatePortable(document);
  assert.equal(receipt.assessment.verdict,period.audits[0].assessment.verdict);
  assert.deepEqual(receipt.assessment.reviewReasons,period.audits[0].assessment.reasons);
  assert.equal(receipt.calculation.wages.amount,period.audits[0].calculation.wages);
  assert.equal(receipt.calculation.components[0].workedSeconds,period.audits[0].calculation.components[0].workedSeconds);
  assert.equal(document.workSnapshots[0].work[0].startEpochSeconds,Date.parse(period.work[0].startUTC)/1000);
  assert.equal(document.profiles[0].timeZone,null);
  assert.ok(document.profiles[0].fieldsNotRecorded.includes('timeZone'));
  assert.equal(document.periods[0].calendarWindow.boundaryModel,'localDatesOnly');
  assert.equal(document.ruleSnapshots[0].sources,null);
  const restored=validateState(readPortable(bytes(document),emptyState));
  assert.equal(restored.profiles[0].hourlyRate,period.rule.hourlyRate);
  assert.equal(restored.periods[0].work.length,0);
  assert.equal(restored.portableArchive.document.workSnapshots[0].work[0].startEpochSeconds,Date.parse(period.work[0].startUTC)/1000);
  sameFinancial(exported(restored),document);
  assert.deepEqual(inspectSnapshot(snapshot(restored)),restored);
});
test('existing line facts, missing versus zero and reported source confirmation remain explicit',()=>{
  const state=source(),period=state.periods[0],audit=period.audits[0];
  // This genuine old receipt had no source period or line confirmation; no new confirmation is invented.
  const doc=exported(state),r=doc.paycheckReceipts[0];
  assert.equal(r.sourcePeriod,null);
  assert.equal(r.assessment.reportedPeriod,null);
  assert.equal(r.paystubFacts.regularPay,null);
  assert.equal(r.paystubFacts.grossPay,audit.facts.paidGross);
  assert.equal(r.calculation.components[0].appliedAgreement.hourlyRate,null);
});
test('new native work exports with original frozen receipts and previous work snapshots intact',()=>{
  const original=source();original.periods[0].closed=false;original.periods[0].closedCalculation=null;
  const document=exported(original),state=readPortable(bytes(document),emptyState),period=state.periods[0],work={...structuredClone(period.work[0]),id:'new-native-work',startUTC:period.work[0].endUTC,endUTC:new Date(Date.parse(period.work[0].endUTC)+3600000).toISOString().replace('.000Z','Z')};
  period.work.push(work);state.revision++;
  const transferred=exported(state),updated=transferred.periods.find(item=>item.id===document.periods[0].id);
  assert.equal(transferred.workSnapshots.find(snapshot=>snapshot.id===updated.currentWorkSnapshotRef).work.length,2);
  assert.deepEqual(transferred.paycheckReceipts,document.paycheckReceipts);
  assert.ok(updated.workSnapshotRefs.includes(document.periods[0].currentWorkSnapshotRef));
  assert.deepEqual(inspectSnapshot(snapshot(state)),state);
});
test('unsupported advanced records block the entire portable export, complete recovery copy remains available',()=>{
  const state=decodeState(read('./fixtures/web-state-v7.json'));
  assert.ok(state.weeklyReviews.length>0);
  assert.throws(()=>portableSnapshot(state),/weekly review receipts/);
  assert.deepEqual(inspectSnapshot(snapshot(state)),state);
});
test('source inventory, unknown fields, dangling refs, foreign-original capability and pending verdict tampering fail closed',()=>{
  const sourceDoc=exported(source());
  for(const mutate of [doc=>doc.sourceInventory.omittedFinancialRecordCount=1,doc=>doc.sourceInventory.workEntryCount++,doc=>doc.periods[0].currentWorkSnapshotRef='missing',doc=>doc.unknownFinancialRecords=[],doc=>doc.sourceInventory.unsupportedDraftKinds.push('agreementDraft')]){
    const bad=structuredClone(sourceDoc);mutate(bad);assert.throws(()=>readPortable(bytes(bad),emptyState));
  }
  const state=source();state.periods[0].audits[0].facts.weeklyReviewPending=true;
  state.periods[0].audits[0].assessment=assess(state.periods[0].audits[0].calculation,state.periods[0].audits[0].facts,state.periods[0].rule.rounding);
  const pending=exported(state);assert.equal(pending.paycheckReceipts[0].assessment.verdict,'needsReview');
  pending.paycheckReceipts[0].assessment.verdict='matches';assert.throws(()=>validatePortable(pending),/pending weekly review/);
});
test('unknown imported rule coverage persists on current and new periods and cannot be unchecked on equal gross',()=>{
  const state=readPortable(bytes(exported(source())),emptyState),period=state.periods[0];
  assert.equal(importedCoverage(state,period.id).unknownRules,true);
  const calculation=calculate(period.work,period.rule),facts={completeWork:true,grossBasis:'wagesOnly',unreviewedFields:false,unsupportedRules:false,weeklyReviewPending:false,paidGross:calculation.wages,paidPerDiem:null};
  period.audits.push({id:'synthetic-invalid-clean',createdAt:'2026-10-20T00:00:00Z',work:structuredClone(period.work),facts,calculation,assessment:assess(calculation,facts,period.rule.rounding)});
  assert.equal(period.audits[0].assessment.verdict,'matches');
  assert.throws(()=>validateState(state),/unknown rule coverage/);
  facts.unsupportedRules=true;period.audits[0].assessment=assess(calculation,facts,period.rule.rounding);validateState(state);
  assert.equal(period.audits[0].assessment.verdict,'needsReview');
  const newPeriod={...structuredClone(period),id:'new-period',audits:[],rule:structuredClone(state.profiles[0])};
  state.periods.push(newPeriod);assert.equal(importedCoverage(state,newPeriod.id).unknownRules,true);
});
test('encrypted common Android pending receipt restores usable native work and preserves original frozen verdict on re-export',async()=>{
  const doc=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json'));
  const encrypted=await encryptBackup(bytes(doc),'Synthetic portable password 2026'),plain=await decryptBackup(encrypted,'Synthetic portable password 2026');
  const state=validateState(readPortable(plain,emptyState));
  assert.ok(state.profiles.length>0);
  assert.ok(state.periods.some(period=>period.work.length>0));
  assert.equal(doc.paycheckReceipts[0].reviewFacts.weeklyReviewPending,true);
  assert.equal(doc.paycheckReceipts[0].assessment.verdict,'needsReview');
  sameFinancial(exported(state),doc);
  const originalHash=createHash('sha256').update(JSON.stringify(doc.paycheckReceipts)).digest('hex');
  assert.equal(createHash('sha256').update(JSON.stringify(state.portableArchive.document.paycheckReceipts)).digest('hex'),originalHash);
});

test('effective rule timelines, closed period calculation, and source component rates are retained',()=>{
  const state=source(),period=state.periods[0],profile={...structuredClone(state.profiles[0]),id:'new-source-profile',hourlyRate:'60',version:'1'};
  state.profiles.push(profile);period.closed=false;period.closedCalculation=null;
  state.ruleTimelines.push({id:'effective-plan',periodID:period.id,createdAt:'2026-10-17T00:00:00Z',confirmed:true,changes:[{effectiveDate:period.start,sourceProfileID:profile.id,agreement:{...structuredClone(profile),id:period.rule.id,version:'new-rule-version'}}]});
  validateState(state);
  const document=exported(state);
  assert.equal(document.ruleTimelines.length,1);
  assert.equal(document.ruleChanges[0].effectiveDate,period.start);
  assert.equal(document.ruleSnapshots.find(rule=>rule.version==='new-rule-version').hourlyRate,'60');
  const restored=validateState(readPortable(bytes(document),emptyState));
  assert.equal(restored.ruleTimelines.length,1);
  assert.equal(restored.ruleTimelines[0].changes[0].agreement.hourlyRate,'60');
  sameFinancial(exported(restored),document);
});

test('one stable work identity retains distinct edited facts in current and frozen receipt revisions',()=>{
  const state=source(),period=state.periods[0],original=structuredClone(period.audits[0].work[0]);
  period.closed=false;period.closedCalculation=null;
  period.work[0].startUTC=new Date(Date.parse(original.startUTC)+3600000).toISOString().replace('.000Z','Z');
  validateState(state);
  const document=exported(state),current=document.workSnapshots.find(snapshot=>snapshot.id===document.periods[0].currentWorkSnapshotRef),historical=document.workSnapshots.find(snapshot=>snapshot.id===document.paycheckReceipts[0].workSnapshotRef);
  assert.equal(current.work[0].id,historical.work[0].id);
  assert.notEqual(current.work[0].startEpochSeconds,historical.work[0].startEpochSeconds);
  assert.equal(document.identityCrosswalk.filter(identity=>identity.entityType==='workEntry' && identity.portableID===current.work[0].id).length,1);
  const restored=validateState(readPortable(bytes(document),emptyState));
  assert.equal(restored.periods[0].work[0].startUTC,period.work[0].startUTC);
  assert.equal(restored.portableArchive.document.workSnapshots.find(snapshot=>snapshot.id===historical.id).work[0].startEpochSeconds,Date.parse(original.startUTC)/1000);
  const bad=structuredClone(document),extra=structuredClone(current.work[0]);extra.id='source-work-not-in-receipt';
  bad.workSnapshots.find(snapshot=>snapshot.id===current.id).work.push(extra);
  bad.identityCrosswalk.push({entityType:'workEntry',portableID:extra.id,originClient:'web',originKind:'native',originLocalID:'new-local-work'});
  bad.sourceInventory.workEntryCount++;
  bad.paycheckReceipts[0].calculation.components[0].workRef=extra.id;
  assert.throws(()=>validatePortable(bad),/another snapshot/);
  const duplicate=structuredClone(document);duplicate.workSnapshots[0].work.push(structuredClone(duplicate.workSnapshots[0].work[0]));duplicate.sourceInventory.workEntryCount++;
  assert.throws(()=>validatePortable(duplicate),/Duplicate work identity within/);
});


test('material unknowns block activation; independent confirmation creates new lineage and combined re-export',()=>{
  const document=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json')),state=readPortable(bytes(document),emptyState),originalPeriod=state.periods[0],originalRule=structuredClone(originalPeriod.rule),frozen=structuredClone(document.paycheckReceipts);
  assert.equal(importedConfirmationRequired(state,originalPeriod.id),true);
  let counter=0;confirmedImportedCopy(state,originalPeriod.id,{scale:2,mode:'halfUp',scope:'payCategory'},'2026-10-22T00:00:00Z',()=>`synthetic-adopted-${++counter}`,true);
  const confirmation=state.portableArchive.activationConfirmations[0],adopted=state.periods.find(period=>period.id===confirmation.adoptedPeriodID);
  assert.notEqual(adopted.rule.id,originalRule.id);assert.notEqual(adopted.rule.version,originalRule.version);
  assert.equal(importedConfirmationRequired(state,adopted.id),false);
  assert.equal(importedCoverage(state,adopted.id).unknownRules,true);
  assert.equal(importedCoverage(state,adopted.id).weeklyPending,true);
  const calculation=calculate(adopted.work,adopted.rule),facts={completeWork:true,grossBasis:'wagesOnly',unreviewedFields:false,unsupportedRules:true,weeklyReviewPending:true,paidGross:calculation.wages,paidPerDiem:null};
  adopted.audits.push({id:'new-adopted-check',createdAt:'2026-10-22T00:00:00Z',work:structuredClone(adopted.work),facts,calculation,assessment:assess(calculation,facts,adopted.rule.rounding)});state.revision++;
  validateState(state);
  const combined=exported(state);
  assert.deepEqual(combined.paycheckReceipts.slice(0,frozen.length),frozen);
  assert.equal(combined.adoptions.length,1);assert.equal(combined.adoptions[0].sourceProfileRef,document.profiles[0].id);
  assert.equal(combined.activeProfileRef,combined.adoptions[0].adoptedProfileRef);
  assert.equal(combined.paycheckReceipts.at(-1).assessment.verdict,'needsReview');
  const restored=validateState(readPortable(bytes(combined),emptyState));
  sameFinancial(exported(restored),combined);
});

test('later native receipts resolve imported local rule aliases to the original portable rule identity',()=>{
  const initial=source();initial.periods[0].closed=false;initial.periods[0].closedCalculation=null;
  const document=exported(initial),state=readPortable(bytes(document),emptyState),period=state.periods[0],calculation=calculate(period.work,period.rule),facts={completeWork:true,grossBasis:'wagesOnly',unreviewedFields:false,unsupportedRules:true,weeklyReviewPending:false,paidGross:calculation.wages,paidPerDiem:null};
  period.audits.push({id:'later-native-check',createdAt:'2026-10-22T00:00:00Z',work:structuredClone(period.work),facts,calculation,assessment:assess(calculation,facts,period.rule.rounding)});state.revision++;
  validateState(state);
  const transferred=exported(state),receipt=transferred.paycheckReceipts.at(-1);
  assert.equal(transferred.ruleSnapshots.length,document.ruleSnapshots.length);
  assert.equal(receipt.calculation.agreementID,initial.periods[0].rule.id);
  assert.equal(receipt.calculation.components[0].appliedAgreement.ruleID,initial.periods[0].rule.id);
  assert.equal(receipt.ruleRefs[0],document.ruleSnapshots[0].id);
});
test('pending source review follows persisted adoption lineage before any new paycheck exists',()=>{
  const document=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json')),state=readPortable(bytes(document),emptyState);let i=0;
  confirmedImportedCopy(state,state.periods[0].id,{scale:2,mode:'halfUp',scope:'payCategory'},'2026-10-22T00:00:00Z',()=>`pending-lineage-${++i}`);
  const combined=exported(state),restored=validateState(readPortable(bytes(combined),emptyState)),active=restored.periods.find(period=>!period.closed);
  assert.equal(combined.paycheckReceipts.length,document.paycheckReceipts.length);
  assert.equal(importedCoverage(restored,active.id).weeklyPending,true);
  assert.equal(importedCoverage(restored,active.id).unknownRules,true);
});
test('duplicate JSON keys including escaped aliases and valid originals refuse whole-file admission',()=>{
  const document=exported(source()),text=JSON.stringify(document);
  assert.throws(()=>readPortable(new TextEncoder().encode(text.replace('"version":1','"version":1,"version":1')),emptyState),/Duplicate portable JSON/);
  assert.throws(()=>readPortable(new TextEncoder().encode(text.replace('"version":1','"version":1,"ver\\u0073ion":1')),emptyState),/Duplicate portable JSON/);
  const withOriginals=new Uint8Array(readFileSync(contractRoot+'/fixtures/attachment-valid.json'));
  assert.throws(()=>readPortable(withOriginals,emptyState),/cannot preserve original attachments/);
});

test('source export refuses every unknown native financial category or nested fact instead of dropping it',()=>{
  for(const mutate of [state=>state.unrepresentedFinancialRecords=[{amount:'3.00'}],state=>state.profiles[0].unrepresentedRule='night differential',state=>state.periods[0].work[0].sourceDocument='unretained-original',state=>state.periods[0].audits[0].calculation.components[0].unrepresentedEvidence='private source note']){
    const state=source();mutate(state);assert.throws(()=>portableSnapshot(state),/unrepresentable native financial fields/);
  }
});


test('new effective plans on an imported current period export without dropping future default or old receipt inputs',()=>{
  const initial=source();initial.periods[0].closed=false;initial.periods[0].closedCalculation=null;
  const original=exported(initial),state=readPortable(bytes(original),emptyState),period=state.periods[0],future={...structuredClone(state.profiles[0]),id:'future-default-profile',hourlyRate:'60'};
  state.profiles.push(future);
  state.ruleTimelines.push({id:'new-imported-effective-plan',periodID:period.id,createdAt:'2026-10-22T00:00:00Z',confirmed:true,changes:[{effectiveDate:period.start,sourceProfileID:future.id,agreement:{...structuredClone(future),id:period.rule.id,version:'effective-next-version'}}]});state.revision++;
  validateState(state);assert.equal(currentCalculation(state,period).wages,'480.00');
  const combined=exported(state);
  assert.equal(combined.ruleTimelines.length,1);assert.equal(combined.ruleChanges.length,1);
  assert.equal(combined.activeProfileRef,'web:profile:future-default-profile');
  assert.deepEqual(combined.paycheckReceipts,original.paycheckReceipts);
  const current=combined.periods.find(item=>item.id===original.periods[0].id);
  assert.equal(current.isCurrent,true);assert.equal(current.profileRef,original.periods[0].profileRef);
  const restored=validateState(readPortable(bytes(combined),emptyState)),working=restored.periods.find(item=>!item.closed);
  assert.equal(working.work.length,period.work.length);
  assert.equal(working.rule.hourlyRate,'50.00');
  assert.equal(restored.profiles.at(-1).hourlyRate,'60');
  assert.equal(currentCalculation(restored,working).wages,'480.00');
  sameFinancial(exported(restored),combined);
});

function patched(document,operations){const result=structuredClone(document);for(const operation of operations){const path=operation.path.slice(1).split('/').map(key=>key.replaceAll('~1','/').replaceAll('~0','~'));let target=result;for(const key of path.slice(0,-1))target=target[key];const key=path.at(-1);if(operation.op==='remove'){if(Array.isArray(target))target.splice(Number(key),1);else delete target[key];}else if(Array.isArray(target) && key==='-')target.push(structuredClone(operation.value));else target[key]=structuredClone(operation.value);}return result;}
test('every applicable shared refusal vector reaches the real reader; activation review retains source',()=>{
 const cases=JSON.parse(readFileSync(contractRoot+'/fixtures/refusal-cases-v1.json')).cases;
 for(const item of cases.filter(item=>!item.target || item.target==='web')){const base=JSON.parse(readFileSync(contractRoot+'/fixtures/'+(item.baseFixture??'common-weekly-pending.json'))),doc=patched(base,item.operations);
 if(item.activationReview){const state=validateState(readPortable(bytes(doc),emptyState));assert.deepEqual(state.portableArchive.document,doc);assert.ok(state.periods.every(period=>period.closed || importedConfirmationRequired(state,period.id)));sameFinancial(exported(state),doc);}
 else assert.throws(()=>readPortable(bytes(doc),emptyState),item.id);}
});
test('current-only adoption preserves the separately selected next-period profile',()=>{
 const doc=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json'));
 const future=structuredClone(doc.profiles[0]);future.id='future-default';doc.profiles.push(future);doc.activeProfileRef=future.id;doc.identityCrosswalk.push({...doc.identityCrosswalk.find(row=>row.entityType==='profile'),portableID:future.id,originLocalID:'future-native'});doc.sourceInventory.profileCount++;
 doc.periods[0].isCurrent=true;doc.periods[0].fieldsNotRecorded=doc.periods[0].fieldsNotRecorded.filter(field=>field!=='isCurrent');
 const state=readPortable(bytes(doc),emptyState);let n=0;confirmedImportedCopy(state,state.periods[0].id,{scale:2,mode:'halfUp',scope:'payCategory'},'2026-10-22T00:00:00Z',()=>`current-copy-${++n}`);
 const result=exported(state);assert.equal(result.activeProfileRef,future.id);assert.deepEqual(result.profiles.find(profile=>profile.id===doc.profiles[0].id),doc.profiles[0]);assert.deepEqual(result.paycheckReceipts,doc.paycheckReceipts);
});

test('frozen embedded weekly results and repeating Decimal traces roundtrip without editor coercion',()=>{
 const doc=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json')),calculation=doc.paycheckReceipts[0].calculation;
 const money=amount=>({amount,currency:'USD'}),repeating='0.'+'3'.repeat(128);
 calculation.components[0].workedSeconds=repeating;
 calculation.weeklyRegularRate={workweekID:'frozen-week',weekStart:'2026-10-19',workweekStart:'monday',qualifyingHours:'40',includableRemuneration:money('800'),regularRate:money('20'),overtimeHours:'0',statutoryAdditionalPremium:money('0'),eligibleExtraPremiumCredit:money('0'),remainingAdditionalPremium:money('0'),cashRemuneration:money('800'),expectedCash:money('800'),allocations:[{id:'frozen-allocation',periodRef:doc.periods[0].id,amount:money('0'),basis:money('800')}],engineVersion:'frozen-source/1',startEpochSeconds:null,endEpochSeconds:null,timeZone:null,fieldsNotRecorded:['startEpochSeconds','endEpochSeconds','timeZone']};
 calculation.fieldsNotRecorded=calculation.fieldsNotRecorded.filter(field=>field!=='weeklyRegularRate');
 doc.sourceInventory.workweekCount=1;doc.sourceInventory.weeklyAllocationCount=1;
 for(const [entityType,portableID] of [['workweek','frozen-week'],['weeklyAllocation','frozen-allocation']])doc.identityCrosswalk.push({entityType,portableID,originClient:'ios',originKind:'native',originLocalID:portableID});
 const state=validateState(readPortable(bytes(doc),emptyState)),result=exported(state);assert.equal(result.paycheckReceipts[0].calculation.components[0].workedSeconds,repeating);sameFinancial(result,doc);
});

test('date-only Android windows preserve source-unknown exclusive dates without inventing them',()=>{
 const doc=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json'));for(const window of [doc.periods[0].calendarWindow,doc.paycheckReceipts[0].targetWindow]){window.endExclusiveDate=null;window.fieldsNotRecorded.push('endExclusiveDate');}
 const state=validateState(readPortable(bytes(doc),emptyState));assert.ok(state.periods[0].work.length);sameFinancial(exported(state),doc);
});

test('selected high-precision source rule stays exact and read-only; missing profile context remains unknown',()=>{
  const native=source();native.periods[0].closed=false;native.periods[0].closedCalculation=null;
  const doc=exported(native),rate='0.'+'1234567890'.repeat(5);doc.ruleSnapshots[0].hourlyRate=rate;
  // The stored native profile never owned these calendar selections; do not infer them from its period.
  captureReview('selected-high-precision',doc);const state=validateState(readPortable(bytes(doc),emptyState));assert.equal(state.profiles.length,0);assert.equal(state.periods.length,0);
  sameFinancial(exported(state),doc);assert.equal(exported(state).ruleSnapshots[0].hourlyRate,rate);
  for(const field of ['timeZone','cadence','cycleStartDate']){assert.equal(state.portableArchive.document.profiles[0][field],null);assert.ok(state.portableArchive.document.profiles[0].fieldsNotRecorded.includes(field));}
});
test('missing profile calendar metadata does not prevent usable known period work or invent calendar defaults',()=>{
  const native=source();native.periods[0].closed=false;native.periods[0].closedCalculation=null;const doc=exported(native),state=validateState(readPortable(bytes(doc),emptyState));
  assert.ok(state.periods[0].work.length);assert.equal(currentCalculation(state,state.periods[0]).wages,native.periods[0].audits[0].calculation.wages);
  const result=exported(state);captureReview('missing-profile-calendar',doc);for(const field of ['timeZone','cadence','cycleStartDate'])assert.equal(result.profiles[0][field],null);sameFinancial(result,doc);
});
test('period-owned future changes at exclusive end and later stay stored without changing current work window or future default',()=>{
  const native=source();native.periods[0].closed=false;native.periods[0].closedCalculation=null;
  const doc=exported(native),period=doc.periods[0],profile=doc.profiles[0],baseline=doc.ruleSnapshots[0],timelineID='retained-future-timeline',futureRules=[],changes=[];
  const nextDate=day=>new Date(Date.parse(day+'T00:00:00Z')+86400000).toISOString().slice(0,10);
  for(const [index,date] of [period.calendarWindow.endExclusiveDate,nextDate(period.calendarWindow.endExclusiveDate)].entries()){
    const rule={...structuredClone(baseline),id:'future-rule-'+index,ruleID:'future-rule-id-'+index,version:'future-version-'+index,hourlyRate:String(30+index)},nextProfile={...structuredClone(profile),id:'future-profile-'+index,ruleRef:rule.id,baselineRuleRef:null,ruleChangeRefs:[],currentPeriodRef:null,currentWorkSnapshotRef:null},change={id:'future-change-'+index,profileRef:profile.id,periodRef:period.id,effectiveDate:date,sourceProfileRef:nextProfile.id,ruleRef:rule.id,confirmed:true,createdAtEpochSeconds:1792627200,fieldsNotRecorded:[]};
    nextProfile.fieldsNotRecorded=[...new Set([...nextProfile.fieldsNotRecorded,'baselineRuleRef','currentPeriodRef','currentWorkSnapshotRef'])];doc.profiles.push(nextProfile);doc.ruleSnapshots.push(rule);doc.ruleChanges.push(change);futureRules.push(rule);changes.push(change.id);
    for(const [entityType,portableID] of [['profile',nextProfile.id],['ruleSnapshot',rule.id],['ruleChange',change.id]])doc.identityCrosswalk.push({entityType,portableID,originClient:'web',originKind:'native',originLocalID:portableID});
  }
  doc.activeProfileRef=doc.profiles.at(-1).id;doc.ruleTimelines.push({id:timelineID,periodRef:period.id,baselineRuleRef:baseline.id,ruleChangeRefs:changes,createdAtEpochSeconds:1792627200,confirmed:true,fieldsNotRecorded:[]});period.ruleTimelineRefs=[timelineID];period.ruleChangeRefs=changes;doc.identityCrosswalk.push({entityType:'ruleTimeline',portableID:timelineID,originClient:'web',originKind:'native',originLocalID:timelineID});
  Object.assign(doc.sourceInventory,{profileCount:doc.profiles.length,ruleSnapshotCount:doc.ruleSnapshots.length,ruleChangeCount:changes.length,ruleTimelineCount:1});
  captureReview('future-period-rules',doc);const state=validateState(readPortable(bytes(doc),emptyState)),current=state.periods[0],before=currentCalculation(state,current).wages;assert.equal(current.end,period.calendarWindow.endDateInclusive);assert.equal(current.start,period.calendarWindow.startDate);assert.equal(state.ruleTimelines[0].changes.length,2);sameFinancial(exported(state),doc);
  current.work.push({...structuredClone(current.work[0]),id:'new-current-work'});current.work.at(-1).startUTC=current.work[0].endUTC;current.work.at(-1).endUTC=new Date(Date.parse(current.work[0].endUTC)+3600000).toISOString().replace('.000Z','Z');state.revision++;
  const calculation=currentCalculation(state,current),facts={completeWork:true,grossBasis:'wagesOnly',unreviewedFields:false,unsupportedRules:true,weeklyReviewPending:false,paidGross:calculation.wages,paidPerDiem:null};current.audits.push({id:'future-plan-current-check',createdAt:'2026-10-22T00:00:00Z',work:structuredClone(current.work),facts,calculation,assessment:assess(calculation,facts,current.rule.rounding)});
  validateState(state);const result=exported(state);assert.deepEqual(new Set(result.paycheckReceipts.at(-1).ruleRefs),new Set([baseline.id,...futureRules.map(rule=>rule.id)]));captureReview('future-period-rules-with-new-work',result);assert.equal(result.activeProfileRef,doc.activeProfileRef);assert.deepEqual(result.ruleChanges,doc.ruleChanges);assert.deepEqual(result.ruleTimelines,doc.ruleTimelines);assert.deepEqual(result.paycheckReceipts.slice(0,doc.paycheckReceipts.length),doc.paycheckReceipts);assert.deepEqual(result.periods[0].calendarWindow,period.calendarWindow);assert.notEqual(currentCalculation(state,current).wages,before);
});
test('only exact recognized frozen source reasons satisfy a pending-weekly verdict',()=>{
 const doc=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json'));doc.paycheckReceipts[0].assessment.reviewReasons=['A separate complete-workweek review is pending.'];validateState(readPortable(bytes(doc),emptyState));
 doc.paycheckReceipts[0].assessment.reviewReasons=['A separate weekly schedule review is pending.'];assert.throws(()=>readPortable(bytes(doc),emptyState),/pending weekly review/);
});

test('nested assessment array markers reject known-empty contradictions before constructing replacement state',()=>{
  const sourceDoc=JSON.parse(readFileSync(contractRoot+'/fixtures/common-weekly-pending.json'));
  for(const unknown of [false,true]){
    const doc=structuredClone(sourceDoc),assessment=doc.paycheckReceipts[0].assessment;
    assessment.weeklyReviewRefs=unknown?null:[];
    assessment.fieldsNotRecorded=assessment.fieldsNotRecorded.filter(field=>field!=='weeklyReviewRefs');
    if(unknown)assessment.fieldsNotRecorded.push('weeklyReviewRefs');
    const restored=validateState(readPortable(bytes(doc),emptyState)),result=exported(restored);
    assert.deepEqual(result.paycheckReceipts[0].assessment.weeklyReviewRefs,unknown?null:[]);
    assert.equal(result.paycheckReceipts[0].assessment.fieldsNotRecorded.includes('weeklyReviewRefs'),unknown);
    sameFinancial(result,doc);
  }
  const invalid=structuredClone(sourceDoc),assessment=invalid.paycheckReceipts[0].assessment;
  assessment.weeklyReviewRefs=[];assessment.fieldsNotRecorded=[...new Set([...assessment.fieldsNotRecorded,'weeklyReviewRefs'])];
  const destination=source(),before=structuredClone(destination);let replacementConstructed=false;
  assert.throws(()=>readPortable(bytes(invalid),()=>{replacementConstructed=true;return destination;}),/Source unknown marker weeklyReviewRefs.*explicit null/);
  assert.equal(replacementConstructed,false);assert.deepEqual(destination,before);
});
