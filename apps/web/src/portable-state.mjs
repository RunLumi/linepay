import schema from './portable-schema.mjs';
import { calculateTimeline } from './payroll-v2.mjs';
import { calculate, localDate } from './payroll.mjs';
const encoder = new TextEncoder();
export const PORTABLE_FORMAT = 'com.streamentry.linepay.portable-state';
const need = (ok, message) => { if (!ok) throw Error(message); };
const clone = value => structuredClone(value);
const same = (a,b) => JSON.stringify(a) === JSON.stringify(b);
function shape(value, spec, path = 'transfer') {
  if (Array.isArray(spec.type)) { need(spec.type.some(type => type === 'integer' ? Number.isSafeInteger(value) : typeof value === type), `Invalid ${path} type.`); if (typeof value === 'string' && spec.maxLength) need([...value].length <= spec.maxLength, `Invalid ${path} length.`); }
  if (spec.$ref) return shape(value, schema.$defs[spec.$ref.split('/').at(-1)], path);
  if (spec.anyOf) {
    need(spec.anyOf.some(candidate => { try { shape(value, candidate, path); return true; } catch { return false; } }), `Unsupported ${path}.`);
    return;
  }
  if ('const' in spec) need(value === spec.const, `Unsupported ${path}.`);
  if (spec.enum) need(spec.enum.includes(value), `Unsupported ${path}.`);
  if (spec.type === 'null') need(value === null, `Invalid ${path}.`);
  if (spec.type === 'object') {
    need(value && typeof value === 'object' && !Array.isArray(value), `Invalid ${path}.`);
    need(spec.required.every(key => Object.hasOwn(value,key)), `Missing ${path} fields.`);
    need(Object.keys(value).every(key => Object.hasOwn(spec.properties,key)), `Unknown ${path} fields; no records were replaced.`);
    for (const [key,item] of Object.entries(value)) shape(item,spec.properties[key],`${path}.${key}`);
  }
  if (spec.type === 'array') {
    need(Array.isArray(value) && value.length >= (spec.minItems ?? 0) && value.length <= (spec.maxItems ?? 100000), `Invalid ${path} list.`);
    if (spec.uniqueItems) need(new Set(value.map(JSON.stringify)).size === value.length, `Duplicate ${path}.`);
    value.forEach((item,i) => shape(item,spec.items,`${path}[${i}]`));
  }
  if (spec.type === 'string') {
    need(typeof value === 'string' && [...value].length >= (spec.minLength ?? 0) && [...value].length <= (spec.maxLength ?? 100000), `Invalid ${path} text.`);
    if (spec.pattern) need(new RegExp(spec.pattern).test(value), `Invalid ${path} representation.`);
  }
  if (spec.type === 'integer') need(Number.isSafeInteger(value) && value >= (spec.minimum ?? -Infinity) && value <= (spec.maximum ?? Infinity), `Invalid ${path} integer.`);
  if (spec.type === 'boolean') need(typeof value === 'boolean', `Invalid ${path} confirmation.`);
}
const iso = epoch => new Date(epoch * 1000).toISOString().replace('.000Z','Z');
function validDate(value) { need(new Date(value+'T00:00:00Z').toISOString().slice(0,10) === value, 'Invalid transfer calendar date.'); }
function validZone(zone) { new Intl.DateTimeFormat('en',{timeZone:zone}); }
function compatibleNativeRule(rule,id) {
  if(!rule || rule.weeklyOvertime!==null)return null;
  try {const projected=nativeRule(rule,id);calculate([],projected);return projected;} catch {return null;}
}
function sourceCurrentPeriod(document,period) {
  if(!period || period.closed===true || period.isCurrent===false)return false;
  if(period.isCurrent===true || period.closed===false)return true;
  return period.profileRef===document.activeProfileRef && !document.periods.some(other=>other.id!==period.id && other.isCurrent===true && other.closed!==true);
}
function sourceWorkForPeriod(document,period) {
  if(period.currentWorkSnapshotRef!==null)return document.workSnapshots.find(snapshot=>snapshot.id===period.currentWorkSnapshotRef);
  if(!sourceCurrentPeriod(document,period))return null;
  const profile=document.profiles.find(profile=>profile.id===period.profileRef),ledger=document.workSnapshots.find(snapshot=>snapshot.id===profile?.currentWorkSnapshotRef);
  if(ledger?.role!=='currentLedger')return null;
  const fits=candidate=>candidate.profileRef===profile.id && ledger.work.every(work=>work.timeZone===candidate.calendarWindow.timeZone && localDate(work.startEpochSeconds,work.timeZone)>=candidate.calendarWindow.startDate && localDate(work.endEpochSeconds-1,work.timeZone)<=candidate.calendarWindow.endDateInclusive);
  const candidates=document.periods.filter(fits);
  if(candidates.length!==1 || candidates[0].id!==period.id)return null;
  return ledger;
}
export function validatePortable(document) {
  need(encoder.encode(JSON.stringify(document)).length <= 8388608, 'Portable financial state exceeds 8 MiB.');
  shape(document,schema);
  need(document.attachments.length===0,'This browser cannot preserve original attachments. The entire transfer was refused.');
  const inventory=document.sourceInventory;
  need(inventory.unsupportedFinancialRecordKinds.length===0 && inventory.unsupportedDraftKinds.length===0 && inventory.omittedFinancialRecordCount===0,'The source contains unsupported or omitted financial records/drafts. The entire transfer was refused.');
  for(const [name,count] of [['profiles','profileCount'],['ruleSnapshots','ruleSnapshotCount'],['ruleChanges','ruleChangeCount'],['ruleTimelines','ruleTimelineCount'],['periods','periodCount'],['workSnapshots','workSnapshotCount'],['paycheckReceipts','paycheckReceiptCount'],['attachments','attachmentCount'],['adoptions','adoptionCount']])need(document[name].length===inventory[count],'Source inventory does not match retained records.');
  need(document.workSnapshots.reduce((n,snapshot)=>n+snapshot.work.length,0)===inventory.workEntryCount,'Source work inventory does not match retained facts.');
  const allCalculations=[...document.periods.map(period=>period.calculation),...document.paycheckReceipts.map(receipt=>receipt.calculation)].filter(Boolean);
  need(inventory.workBreakCount===document.workSnapshots.reduce((n,snapshot)=>n+snapshot.work.reduce((n,work)=>n+work.unpaidBreaks.length,0),0),'Source break inventory differs from retained facts.');
  need(inventory.calculationComponentCount===allCalculations.reduce((n,calculation)=>n+calculation.components.length,0),'Source calculation inventory differs from retained components.');
  need(inventory.workCorrectionCount===document.periods.reduce((n,period)=>n+period.workCorrections.length,0),'Source work correction inventory differs.');
  need(inventory.auditRevisionCount===document.paycheckReceipts.filter(receipt=>receipt.auditRevisionRef!==null).length,'Source audit revision inventory differs.');
  need(inventory.periodWindowCount===new Set([...document.periods.map(period=>period.windowRef),...document.paycheckReceipts.map(receipt=>receipt.targetWindowRef)]).size,'Source period window inventory differs.');
  const embeddedWeeks=allCalculations.map(calculation=>calculation.weeklyRegularRate).filter(Boolean);
  need(inventory.workweekCount===embeddedWeeks.length && inventory.weeklyAllocationCount===embeddedWeeks.reduce((n,week)=>n+week.allocations.length,0),'Frozen weekly result inventory differs from retained facts.');

  const all=new Map(), add=(kind,id,value)=>{
    const key=kind+'|'+id;
    if(['workEntry','workBreak','calculationComponent','workweek','weeklyAllocation'].includes(kind)){if(!all.has(key))all.set(key,{id});return;}
    need(!all.has(key)||same(all.get(key),value),'Conflicting or duplicate portable identity.');all.set(key,value);
  }, ref=(kind,id)=>{const value=all.get(kind+'|'+id);need(value,`Missing ${kind} reference.`);return value;};
  for(const [field,kind] of [['profiles','profile'],['ruleSnapshots','ruleSnapshot'],['ruleChanges','ruleChange'],['ruleTimelines','ruleTimeline'],['periods','period'],['workSnapshots','workSnapshot'],['paycheckReceipts','paycheckReceipt'],['adoptions','profileAdoption']]) {
    need(new Set(document[field].map(item=>item.id)).size===document[field].length,'Duplicate retained record identity.');document[field].forEach(value=>add(kind,value.id,value));
  }
  for(const snapshot of document.workSnapshots){
    need(new Set(snapshot.work.map(work=>work.id)).size===snapshot.work.length,'Duplicate work identity within one frozen snapshot.');
    const breaks=snapshot.work.flatMap(work=>work.unpaidBreaks);
    need(new Set(breaks.map(pause=>pause.id)).size===breaks.length,'Duplicate break identity within one frozen snapshot.');
    for(const work of snapshot.work){add('workEntry',work.id,work);work.unpaidBreaks.forEach(pause=>add('workBreak',pause.id,pause));if(work.calloutEventRef!==null)add('calloutEvent',work.calloutEventRef,{id:work.calloutEventRef});}
  }
  for(const period of document.periods){add('periodWindow',period.windowRef,period.calendarWindow);for(const component of period.calculation?.components??[])add('calculationComponent',component.id,component);}
  for(const calculation of allCalculations)need(new Set(calculation.components.map(component=>component.id)).size===calculation.components.length,'Duplicate component identity within one frozen calculation.');
  for(const receipt of document.paycheckReceipts){add('periodWindow',receipt.targetWindowRef,receipt.targetWindow);add('paystub',receipt.paystubFacts.id,receipt.paystubFacts);if(receipt.auditRevisionRef!==null)add('auditRevision',receipt.auditRevisionRef,receipt);for(const component of receipt.calculation?.components??[])add('calculationComponent',component.id,component);}
  for(const week of embeddedWeeks){add('workweek',week.workweekID,week);need(new Set(week.allocations.map(allocation=>allocation.id)).size===week.allocations.length,'Duplicate allocation within one frozen workweek result.');week.allocations.forEach(allocation=>add('weeklyAllocation',allocation.id,allocation));}
  const origins=new Set();
  for(const identity of document.identityCrosswalk){const key=identity.entityType+'|'+identity.portableID;need(!origins.has(key),'Duplicate origin crosswalk.');origins.add(key);ref(identity.entityType,identity.portableID);}
  need([...all.keys()].every(key=>origins.has(key)),'Missing origin identity crosswalk.');
  const recorded=value=>{
    if(!value||typeof value!=='object')return;
    if(Array.isArray(value)){value.forEach(recorded);return;}
    for(const field of value.fieldsNotRecorded??[])need(field.split('.').reduce((item,key)=>item?.[key],value)===null,`Source unknown marker ${field} on ${value.id??'record'} must name an explicit null field.`);
    Object.values(value).forEach(recorded);
  };recorded(document);
  need(document.profiles.length<=100 && document.periods.length<=100,'Too many profiles or periods for this browser.');
  need(document.periods.filter(period=>period.isCurrent===true).length<=1 && document.periods.filter(period=>sourceCurrentPeriod(document,period)).length<=1,'This browser supports only one open period.');
  for(const rule of document.ruleSnapshots){
    need((rule.sources??[]).every(source=>source.documentRef===null),'Original source documents are required; this browser cannot retain them.');
  }
  const window=value=>{
    if(value.timeZone!==null)validZone(value.timeZone);
    for(const field of ['startDate','endDateInclusive','endExclusiveDate'])if(value[field]!==null)validDate(value[field]);
    if(value.startDate!==null && value.endDateInclusive!==null)need(value.endDateInclusive>=value.startDate,'Invalid period order.');
    if(value.endDateInclusive!==null && value.endExclusiveDate!==null)need(new Date(Date.parse(value.endDateInclusive+'T00:00:00Z')+86400000).toISOString().slice(0,10)===value.endExclusiveDate,'Invalid exclusive final date.');
    if(value.boundaryModel==='exactInstants')need(value.startEpochSeconds!==null && value.endExclusiveEpochSeconds!==null && value.timeZone!==null && localDate(value.startEpochSeconds,value.timeZone)===value.startDate && localDate(value.endExclusiveEpochSeconds-1,value.timeZone)===value.endDateInclusive && localDate(value.endExclusiveEpochSeconds,value.timeZone)===value.endExclusiveDate,'Invalid exact period instants.');
    else need(value.startEpochSeconds===null && value.endExclusiveEpochSeconds===null,'Date-only periods must not invent exact instants.');
  };
  if(document.activeProfileRef!==null)ref('profile',document.activeProfileRef);
  for(const adoption of document.adoptions){ref('profile',adoption.sourceProfileRef);ref('profile',adoption.adoptedProfileRef);if(adoption.sourcePeriodRef!==null)ref('period',adoption.sourcePeriodRef);if(adoption.adoptedPeriodRef!==null)ref('period',adoption.adoptedPeriodRef);if(adoption.sourceWorkSnapshotRef!==null)ref('workSnapshot',adoption.sourceWorkSnapshotRef);if(adoption.adoptedWorkSnapshotRef!==null)ref('workSnapshot',adoption.adoptedWorkSnapshotRef);adoption.sourceRuleRefs.forEach(id=>ref('ruleSnapshot',id));adoption.adoptedRuleRefs.forEach(id=>ref('ruleSnapshot',id));}
  for(const profile of document.profiles){ref('ruleSnapshot',profile.ruleRef);if(profile.baselineRuleRef!==null)ref('ruleSnapshot',profile.baselineRuleRef);if(profile.timeZone!==null)validZone(profile.timeZone);if(profile.currentPeriodRef!==null)ref('period',profile.currentPeriodRef);if(profile.currentWorkSnapshotRef!==null)ref('workSnapshot',profile.currentWorkSnapshotRef);profile.ruleChangeRefs.forEach(id=>ref('ruleChange',id));}
  for(const period of document.periods){
    if(period.profileRef!==null)ref('profile',period.profileRef);if(period.ruleRef!==null)ref('ruleSnapshot',period.ruleRef);window(period.calendarWindow);
    if(period.currentWorkSnapshotRef!==null)need(period.workSnapshotRefs.includes(period.currentWorkSnapshotRef),'Period is missing its current work snapshot.');
    if(sourceCurrentPeriod(document,period) && period.profileRef!==null && period.ruleRef!==null && period.calendarWindow.startDate!==null && period.calendarWindow.endDateInclusive!==null && period.calendarWindow.timeZone!==null)sourceWorkForPeriod(document,period);
    period.workSnapshotRefs.forEach(id=>need(ref('workSnapshot',id).periodRef===period.id,'Work snapshot belongs to another period.'));
    period.ruleChangeRefs.forEach(id=>ref('ruleChange',id));
    need(period.workCorrections.length===0,'Work correction records require a future browser adapter; the whole transfer was refused.');
  }
  // Current ledgers without period ownership cannot be inferred into an arbitrary period.
  for(const snapshot of document.workSnapshots){
    ref('profile',snapshot.profileRef);
    const period=snapshot.periodRef===null?null:ref('period',snapshot.periodRef);
    // Unowned ledgers remain typed source evidence until a worker confirms a destination context.
    for(const work of snapshot.work){
      validZone(work.timeZone);need(work.endEpochSeconds>work.startEpochSeconds && work.endEpochSeconds-work.startEpochSeconds<=259200,'Unsupported work interval.');
      if(period){const scope=period.calendarWindow;if(scope.timeZone!==null)need(work.timeZone===scope.timeZone,'Work timezone differs from its retained period.');if(scope.startDate!==null)need(localDate(work.startEpochSeconds,work.timeZone)>=scope.startDate,'Work precedes its retained period.');if(scope.endDateInclusive!==null)need(localDate(work.endEpochSeconds-1,work.timeZone)<=scope.endDateInclusive,'Work follows its retained period.');}
      let end=work.startEpochSeconds;
      for(const pause of work.unpaidBreaks.toSorted((a,b)=>a.startEpochSeconds-b.startEpochSeconds)){need(pause.startEpochSeconds>=end && pause.endEpochSeconds>pause.startEpochSeconds && pause.endEpochSeconds<=work.endEpochSeconds,'Invalid unpaid break.');end=pause.endEpochSeconds;}
    }
  }
  for(const change of document.ruleChanges){if(change.profileRef!==null)ref('profile',change.profileRef);ref('ruleSnapshot',change.ruleRef);if(change.periodRef!==null)ref('period',change.periodRef);if(change.sourceProfileRef!==null)ref('profile',change.sourceProfileRef);validDate(change.effectiveDate);}
  for(const timeline of document.ruleTimelines){const period=ref('period',timeline.periodRef);if(timeline.baselineRuleRef!==null)ref('ruleSnapshot',timeline.baselineRuleRef);timeline.ruleChangeRefs.forEach(id=>need(ref('ruleChange',id).periodRef===period.id,'Timeline change belongs to another period.'));}
  for(const calculation of allCalculations){
    const week=calculation.weeklyRegularRate;if(week===null)continue;
    validDate(week.weekStart);if(week.timeZone!==null)validZone(week.timeZone);
    const amounts=[week.includableRemuneration,week.regularRate,week.statutoryAdditionalPremium,week.eligibleExtraPremiumCredit,week.remainingAdditionalPremium,week.cashRemuneration,week.expectedCash,...week.allocations.flatMap(allocation=>[allocation.amount,allocation.basis])].filter(Boolean);
    need(amounts.every(amount=>amount.currency===calculation.currency),'Frozen weekly result mixes currencies.');
    if(week.startEpochSeconds!==null || week.endEpochSeconds!==null)need(week.startEpochSeconds!==null && week.endEpochSeconds!==null && week.endEpochSeconds-week.startEpochSeconds===604800,'Frozen workweek must retain its exact168-hour boundaries.');
    for(const allocation of week.allocations)if(allocation.periodRef!==null)ref('period',allocation.periodRef);
  }
  for(const receipt of document.paycheckReceipts){
    const snapshot=ref('workSnapshot',receipt.workSnapshotRef);if(receipt.periodRef!==null)need(snapshot.periodRef===receipt.periodRef,'Receipt references another period’s work.');
    receipt.ruleRefs.forEach(id=>ref('ruleSnapshot',id));if(receipt.sourcePeriod!==null){const source=receipt.sourcePeriod;if(source.startDate!==null)validDate(source.startDate);if(source.endDateInclusive!==null)validDate(source.endDateInclusive);if(source.timeZone!==null)validZone(source.timeZone);}
    need(receipt.attachmentRefs.length===0 && receipt.paystubFacts.evidenceRef===null,'Original evidence cannot be preserved by this browser.');
    need(!receipt.assessment.weeklyContextCount && (receipt.assessment.weeklyReviewRefs??[]).length===0,'Separate weekly results cannot be imported in this transfer version.');
    const reported=receipt.assessment.reportedPeriod,target=receipt.targetWindow;
    if(receipt.assessment.periodMatch==='confirmedSamePeriod')need(reported?.confirmed===true && reported.startDate===target.startDate && reported.endDateInclusive===target.endDateInclusive && reported.timeZone===target.timeZone,'Saved period-match assessment disagrees with the reported source period.');
    const currency=receipt.paystubFacts.currency;
    need(receipt.assessment.paidGross.currency===currency && receipt.assessment.paidGross.amount===receipt.paystubFacts.grossPay,'Saved paid gross differs from its facts.');
    const monies=[receipt.calculation?.total,receipt.assessment.expectedGross,receipt.assessment.difference,...(receipt.calculation?.components.map(c=>c.amount)??[])].filter(Boolean);need(monies.every(m=>m.currency===currency),'Mixed currency in source receipt.');
    if(receipt.reviewFacts.weeklyReviewPending)need(receipt.assessment.verdict==='notComparable' || (receipt.assessment.verdict==='needsReview' && receipt.assessment.reviewReasons.some(reason=>/weekly.*pending|WEEKLY_REVIEW_PENDING|complete-workweek review is pending/i.test(reason))),'A pending weekly review must retain its Needs review or Unable-to-verify verdict.');
    if(receipt.reviewFacts.weeklyReviewPending===false)need(!receipt.assessment.reviewReasons.some(reason=>/weekly.*pending|WEEKLY_REVIEW_PENDING/i.test(reason)),'A retained pending reason conflicts with a false weekly-review flag.');
    for(const component of receipt.calculation?.components??[]){if(component.workRef!==null)need(snapshot.work.some(work=>work.id===component.workRef),'Component references another snapshot’s work.');if(component.appliedAgreement!==null)need(receipt.ruleRefs.includes(component.appliedAgreement.ruleRef),'Component is missing its exact rule snapshot.');}
    for(const comparison of receipt.assessment.comparisons){need(comparison.currency===currency,'Mixed comparison currency.');comparison.componentRefs.forEach(id=>need((receipt.calculation?.components??[]).some(c=>c.id===id),'Comparison has no retained component.'));}
  }
  return document;
}
function nativeRule(rule,id) {
  need(rule.hourlyRate!==null && rule.currency!==null, 'This browser needs a recorded base rate and currency.');
  return {id,version:rule.version,currency:rule.currency,hourlyRate:rule.hourlyRate,outsideScheduleMultiplier:rule.outsideScheduleMultiplier??"1",regularSchedule:clone(rule.regularSchedule??[]),dailyOvertimeTiers:clone(rule.dailyOvertimeTiers??[]),weekdayPremiums:clone(rule.weekdayPremiums??[]),datePremiums:clone(rule.datePremiums??[]),calloutMinimumHours:rule.calloutMinimumHours,perDiemPerWorkDate:rule.perDiemPerWorkDate?.amount??null,rounding:rule.rounding===null?{scale:2,mode:'halfUp',scope:'payCategory'}:{...rule.rounding,mode:rule.rounding.mode==='halfEven'?'bankers':rule.rounding.mode}};
}
export function validatePortableArchive(archive) {
  if(archive===null)return;
  need(archive && same(Object.keys(archive).sort(),['document','mappings','nativeBaseline','activationConfirmations'].sort()),'Unsupported retained portable metadata.');
  validatePortable(archive.document);
  need(Array.isArray(archive.activationConfirmations) && archive.activationConfirmations.length<=1000,'Invalid imported rule confirmations.');
  for(const confirmation of archive.activationConfirmations){
    need(same(Object.keys(confirmation).sort(),['periodID','adoptedPeriodID','newRuleID','newRuleVersion','sourceRuleRef','sourceProfileRef','sourceWorkSnapshotRef','confirmedAt','rounding','adoptionID'].sort()),'Unknown imported rule confirmation fields.');
    need(typeof confirmation.periodID==='string' && typeof confirmation.newRuleID==='string' && typeof confirmation.newRuleVersion==='string' && Number.isSafeInteger(Date.parse(confirmation.confirmedAt)/1000),'Invalid imported rule confirmation.');
    need(archive.document.ruleSnapshots.some(rule=>rule.id===confirmation.sourceRuleRef),'Rule confirmation has no retained source.');
    need(Number.isSafeInteger(confirmation.rounding?.scale) && confirmation.rounding.scale>=0 && confirmation.rounding.scale<=4 && ['halfUp','bankers','down','up'].includes(confirmation.rounding.mode) && confirmation.rounding.scope==='payCategory','Invalid independently confirmed rounding policy.');
  }
  need(Array.isArray(archive.mappings),'Missing portable identity mappings.');
  const ids=new Set();
  for(const mapping of archive.mappings) {
    need(same(Object.keys(mapping).sort(),['entityType','portableID','localID'].sort()) && typeof mapping.localID==='string' && /^[A-Za-z0-9-]{1,128}$/.test(mapping.localID),'Invalid local identity crosswalk.');
    const key=mapping.entityType+'|'+mapping.portableID;need(!ids.has(key),'Duplicate local portable mapping.');ids.add(key);
    need(archive.document.identityCrosswalk.some(item=>item.entityType===mapping.entityType && item.portableID===mapping.portableID),'Local mapping has no retained origin.');
  }
  need(archive.nativeBaseline && Array.isArray(archive.nativeBaseline.profiles) && Array.isArray(archive.nativeBaseline.periods),'Missing imported financial baseline.');
  need(same(Object.keys(archive.nativeBaseline).sort(),['profiles','periods','ruleTimelines'].sort()),'Unknown imported financial baseline fields.');
  const projected=projectPortable(archive.document,()=>({profiles:[],periods:[],ruleTimelines:[]}),archive.mappings);
  need(same(projected.portableArchive.nativeBaseline,archive.nativeBaseline),'Imported financial baseline differs from retained source facts.');

}
export function importPortable(document,emptyState) {
  validatePortable(document);
  return projectPortable(document,emptyState);
}
function projectPortable(document,emptyState,existingMappings=null) {
  const state=emptyState(),mappings=[],local=new Map();
  const id=(kind,portableID)=>{
    const key=kind+'|'+portableID;
    if(!local.has(key)){const retained=existingMappings?.find(item=>item.entityType===kind && item.portableID===portableID);need(existingMappings===null || retained,'An imported record is missing its persisted local identity.');const localID=retained?.localID??crypto.randomUUID();local.set(key,localID);mappings.push({entityType:kind,portableID,localID});}return local.get(key);
  };
  for(const profile of document.profiles){const localID=id('profile',profile.id),projected=compatibleNativeRule(document.ruleSnapshots.find(rule=>rule.id===profile.ruleRef),localID);if(projected)state.profiles.push(projected);}
  if(document.activeProfileRef!==null){const activeID=id('profile',document.activeProfileRef),at=state.profiles.findIndex(profile=>profile.id===activeID);if(at>=0)state.profiles.push(...state.profiles.splice(at,1));}
  for(const period of document.periods) {
    const localPeriodID=id('period',period.id),rule=document.ruleSnapshots.find(rule=>rule.id===period.ruleRef),nativeRuleID=rule?id('ruleSnapshot',rule.id):null,projected=compatibleNativeRule(rule,nativeRuleID);
    if(!projected || period.calendarWindow.startDate===null || period.calendarWindow.endDateInclusive===null || period.calendarWindow.timeZone===null)continue;
    const snapshot=sourceWorkForPeriod(document,period);
    if(sourceCurrentPeriod(document,period) && !snapshot)continue;
    const active=sourceCurrentPeriod(document,period);
    const work=(active?(snapshot?.work??[]):[]).map(entry=>({id:id('workEntry',entry.id),startUTC:iso(entry.startEpochSeconds),endUTC:iso(entry.endEpochSeconds),timeZone:entry.timeZone,kind:entry.kind,calloutEventID:entry.calloutEventRef===null?null:id('calloutEvent',entry.calloutEventRef),unpaidBreaks:entry.unpaidBreaks.map(pause=>({id:id('workBreak',pause.id),startUTC:iso(pause.startEpochSeconds),endUTC:iso(pause.endEpochSeconds)}))}));
    const native={id:id('period',period.id),start:period.calendarWindow.startDate,end:period.calendarWindow.endDateInclusive,zone:period.calendarWindow.timeZone,rule:projected,work,audits:[],closed:period.closed===true || !active,closedCalculation:null};
    if(native.closed)native.closedCalculation=calculate(work,native.rule);
    state.periods.push(native);
  }
  for(const timeline of document.ruleTimelines) {
    const period=state.periods.find(period=>period.id===id('period',timeline.periodRef));
    if(!period)continue;
    if(timeline.confirmed!==true || timeline.createdAtEpochSeconds===null || timeline.ruleChangeRefs.some(ref=>!compatibleNativeRule(document.ruleSnapshots.find(rule=>rule.id===document.ruleChanges.find(change=>change.id===ref)?.ruleRef),period.rule.id))){state.periods=state.periods.filter(item=>item.id!==period.id);continue;}
    state.ruleTimelines.push({id:id('ruleTimeline',timeline.id),periodID:period.id,createdAt:iso(timeline.createdAtEpochSeconds),confirmed:true,changes:timeline.ruleChangeRefs.map(ref=>{
      const change=document.ruleChanges.find(change=>change.id===ref),rule=document.ruleSnapshots.find(rule=>rule.id===change.ruleRef);
      const sourceID=change.sourceProfileRef!==null?id('profile',change.sourceProfileRef):id('ruleSnapshot',rule.id);
      if(!state.profiles.some(profile=>profile.id===sourceID))state.profiles.unshift(nativeRule(rule,sourceID));
      return {effectiveDate:change.effectiveDate,sourceProfileID:sourceID,agreement:nativeRule(rule,period.rule.id)};
    })});
  }
  for(const period of state.periods) {
    const timeline=state.ruleTimelines.filter(timeline=>timeline.periodID===period.id).at(-1);
    if(period.closed && timeline)period.closedCalculation=calculateTimeline(period.work,period.rule,timeline);
  }
  // All source facts, unknowns, notes, rule/source versions and frozen receipts remain typed provenance.
  state.portableArchive={document:clone(document),mappings,activationConfirmations:[],nativeBaseline:{profiles:clone(state.profiles),periods:clone(state.periods),ruleTimelines:clone(state.ruleTimelines)}};
  return state;
}
export function parsePortableJSON(bytes) {
  need(bytes instanceof Uint8Array && bytes.byteLength<=8388608,'Portable transfer exceeds 8 MiB.');
  const text=new TextDecoder('utf-8',{fatal:true}).decode(bytes);
  // JSON.parse accepts duplicate keys. Financial state refuses them instead of choosing the last value.
  JSON.parse(text);
  let at=0;
  const whitespace=()=>{while(/\s/.test(text[at]??'') && at<text.length)at++;};
  const string=()=>{const start=at++;while(at<text.length){if(text[at]==='\\'){at+=2;continue;}if(text[at++]==='"')return JSON.parse(text.slice(start,at));}throw Error('Invalid transfer JSON.');};
  const value=(depth=0)=>{need(depth<128,'Portable JSON nesting exceeds the limit.');whitespace();
    if(text[at]==='{'){at++;whitespace();const keys=new Set();if(text[at]==='}'){at++;return;}
      while(at<text.length){whitespace();const key=string();need(!keys.has(key),'Duplicate portable JSON field; no records were replaced.');keys.add(key);whitespace();at++;value(depth+1);whitespace();if(text[at++]==='}')return;}
    }else if(text[at]==='['){at++;whitespace();if(text[at]===']'){at++;return;}while(at<text.length){value(depth+1);whitespace();if(text[at++]===']')return;}}
    else if(text[at]==='"')string();else while(at<text.length && !/[\s,}\]]/.test(text[at]))at++;
  };value();return JSON.parse(text);
}
export function readPortable(bytes,emptyState) {
  need(bytes instanceof Uint8Array && bytes.byteLength<=8388608,'Portable transfer exceeds 8 MiB.');
  return importPortable(parsePortableJSON(bytes),emptyState);
}
export function importedCoverage(state,periodID) {
  const archive=state.portableArchive;
  if(!archive)return {unknownRules:false,weeklyPending:false};
  const mapping=archive.mappings.find(item=>item.entityType==='period' && item.localID===periodID),
    period=mapping?archive.document.periods.find(item=>item.id===mapping.portableID):null;
  const nativePeriod=state.periods.find(item=>item.id===periodID),
    profileMapping=archive.mappings.find(item=>item.entityType==='profile' && item.localID===nativePeriod?.rule.id),
    profile=profileMapping?archive.document.profiles.find(item=>item.id===profileMapping.portableID):null,
    ruleRef=period?.ruleRef??profile?.ruleRef??archive.activationConfirmations.find(item=>item.newRuleID===nativePeriod?.rule.id)?.sourceRuleRef,
    rule=archive.document.ruleSnapshots.find(item=>item.id===ruleRef);
  const material=['regularSchedule','dailyOvertimeTiers','outsideScheduleMultiplier','weekdayPremiums','datePremiums','calloutMinimumHours','perDiemPerWorkDate','weeklyOvertime','rounding'];
  return {unknownRules:(rule?.fieldsNotRecorded??[]).some(field=>material.includes(field)),weeklyPending:(()=>{const adoption=archive.activationConfirmations.find(item=>item.newRuleID===nativePeriod?.rule.id),originID=adoption?archive.mappings.find(item=>item.entityType==='period' && item.localID===adoption.periodID)?.portableID:null,sourceContext=period??archive.document.periods.find(item=>item.id===originID),prior=archive.document.adoptions.find(item=>item.adoptedPeriodRef===sourceContext?.id),pendingContext=prior?.sourcePeriodRef?archive.document.periods.find(item=>item.id===prior.sourcePeriodRef):sourceContext;return !!pendingContext && pendingContext.calendarWindow.startDate===nativePeriod?.start && pendingContext.calendarWindow.endDateInclusive===nativePeriod?.end && archive.document.paycheckReceipts.some(receipt=>receipt.periodRef===pendingContext.id && receipt.reviewFacts.weeklyReviewPending);})()};
}
export function pendingImportedDefault(state) {
  const archive=state.portableArchive;if(!archive || archive.document.activeProfileRef===null)return null;
  const latest=state.profiles.at(-1);if(latest && !archive.nativeBaseline.profiles.some(profile=>profile.id===latest.id))return null;
  const source=archive.document.profiles.find(profile=>profile.id===archive.document.activeProfileRef),mapping=archive.mappings.find(mapping=>mapping.entityType==='profile' && mapping.portableID===source.id);
  return state.profiles.some(profile=>profile.id===mapping?.localID)?null:source;
}
export function pendingImportedCurrent(state) {
  const archive=state.portableArchive;if(!archive)return null;
  return archive.document.periods.find(source=>sourceCurrentPeriod(archive.document,source) && !state.periods.some(period=>period.id===archive.mappings.find(mapping=>mapping.entityType==='period' && mapping.portableID===source.id)?.localID))??null;
}
export function importedConfirmationRequired(state,periodID) {
  const archive=state.portableArchive,period=state.periods.find(period=>period.id===periodID);
  if(!archive || !period)return false;
  const mapping=archive.mappings.find(item=>item.entityType==='period' && item.localID===periodID),sourcePeriod=mapping?archive.document.periods.find(item=>item.id===mapping.portableID):null;
  const profileMapping=archive.mappings.find(item=>item.entityType==='profile' && item.localID===period.rule.id),sourceProfile=profileMapping?archive.document.profiles.find(item=>item.id===profileMapping.portableID):null;
  const rule=archive.document.ruleSnapshots.find(rule=>rule.id===(sourcePeriod?.ruleRef??sourceProfile?.ruleRef));
  const missing=rule?.rounding===null || sourcePeriod?.closed===null || sourcePeriod?.isCurrent===null || sourcePeriod?.currentWorkSnapshotRef===null;
  return missing && !archive.activationConfirmations.some(item=>item.periodID===periodID && item.newRuleID===period.rule.id && item.newRuleVersion===period.rule.version && same(item.rounding,period.rule.rounding));
}
export function confirmedImportedCopy(state,periodID,rounding,confirmedAt,uid,useForFuture=false) {
  need(importedConfirmationRequired(state,periodID),'There is no unresolved imported activation to confirm.');
  const period=state.periods.find(period=>period.id===periodID),archive=state.portableArchive,mapping=archive.mappings.find(item=>item.entityType==='period' && item.localID===periodID),sourcePeriod=archive.document.periods.find(item=>item.id===mapping?.portableID),profileMapping=archive.mappings.find(item=>item.entityType==='profile' && item.localID===period.rule.id),sourceProfile=archive.document.profiles.find(item=>item.id===(sourcePeriod?.profileRef??profileMapping?.portableID));
  need(!period.closed,'A closed source period cannot be activated with replacement rules. Confirm a new profile instead.');
  need(!state.ruleTimelines.some(timeline=>timeline.periodID===periodID),'Review this source effective-rule plan in a separate new configuration before adopting it.');
  const profile={...clone(period.rule),id:uid(),version:'confirmed-'+uid(),rounding:clone(rounding)},adoptedPeriod={...clone(period),id:uid(),rule:clone(profile),closed:false,closedCalculation:null,audits:[]};
  calculate([],profile);
  if(useForFuture || !state.profiles.length)state.profiles.push(profile);else state.profiles.splice(state.profiles.length-1,0,profile);state.periods.push(adoptedPeriod);
  period.closed=true;period.work=[];period.closedCalculation=calculate([],period.rule);
  const sourceSnapshot=sourcePeriod?sourceWorkForPeriod(archive.document,sourcePeriod):archive.document.workSnapshots.find(snapshot=>snapshot.id===sourceProfile.currentWorkSnapshotRef);
  archive.activationConfirmations.push({periodID,adoptedPeriodID:adoptedPeriod.id,newRuleID:profile.id,newRuleVersion:profile.version,sourceRuleRef:sourcePeriod?.ruleRef??sourceProfile.ruleRef,sourceProfileRef:sourceProfile.id,sourceWorkSnapshotRef:sourceSnapshot.id,confirmedAt,rounding:clone(rounding),adoptionID:uid()});
  return state;
}
function inventoryFor(document) {
  const calculations=[...document.periods.map(period=>period.calculation),...document.paycheckReceipts.map(receipt=>receipt.calculation)].filter(Boolean);
  return {profileCount:document.profiles.length,ruleSnapshotCount:document.ruleSnapshots.length,ruleChangeCount:document.ruleChanges.length,ruleTimelineCount:document.ruleTimelines.length,periodCount:document.periods.length,workSnapshotCount:document.workSnapshots.length,workEntryCount:document.workSnapshots.reduce((n,snapshot)=>n+snapshot.work.length,0),workBreakCount:document.workSnapshots.reduce((n,snapshot)=>n+snapshot.work.reduce((n,work)=>n+work.unpaidBreaks.length,0),0),workCorrectionCount:document.periods.reduce((n,period)=>n+period.workCorrections.length,0),calculationComponentCount:calculations.reduce((n,calculation)=>n+calculation.components.length,0),auditRevisionCount:document.paycheckReceipts.filter(receipt=>receipt.auditRevisionRef!==null).length,periodWindowCount:new Set([...document.periods.map(period=>period.windowRef),...document.paycheckReceipts.map(receipt=>receipt.targetWindowRef)]).size,workweekCount:calculations.filter(calculation=>calculation.weeklyRegularRate!==null).length,weeklyAllocationCount:calculations.reduce((n,calculation)=>n+(calculation.weeklyRegularRate?.allocations.length??0),0),paycheckReceiptCount:document.paycheckReceipts.length,attachmentCount:document.attachments.length,adoptionCount:document.adoptions.length,unsupportedFinancialRecordKinds:[],unsupportedDraftKinds:[],omittedFinancialRecordCount:0};
}
function nativeInventory(state) {
  const fields=(value,allowed)=>need(value && typeof value==='object' && Object.keys(value).every(field=>allowed.includes(field)),'Portable export refused: unrepresentable native financial fields exist.');
  fields(state,['format','version','revision','profiles','periods','benefitChecks','templateOrigins','resolutionEvents','ruleTimelines','paycycleSchedules','paycheckScopes','weeklyReviews','paycheckLineScopes','portableArchive']);
  need(state.format==='com.streamentry.linepay.web.state' && state.version===9,'Portable export refused: unsupported native state version.');
  const rule=value=>{fields(value,['id','version','currency','hourlyRate','outsideScheduleMultiplier','regularSchedule','dailyOvertimeTiers','weekdayPremiums','datePremiums','calloutMinimumHours','perDiemPerWorkDate','rounding']);fields(value.rounding,['scope','scale','mode']);value.dailyOvertimeTiers.forEach(tier=>fields(tier,['afterHours','multiplier']));value.weekdayPremiums.forEach(premium=>fields(premium,['weekday','multiplier']));value.datePremiums.forEach(premium=>fields(premium,['date','multiplier']));};
  const work=entries=>entries.forEach(entry=>{fields(entry,['id','startUTC','endUTC','timeZone','kind','calloutEventID','unpaidBreaks']);entry.unpaidBreaks.forEach(pause=>fields(pause,['id','startUTC','endUTC']));});
  const calculation=value=>{if(value===null)return;fields(value,['engine','coverage','currency','components','wages','allowances','total','ruleTimelineID','ruleSnapshots']);value.ruleSnapshots?.forEach(rule);value.components.forEach(component=>{fields(component,['id','category','workID','date','workedSeconds','baseRate','multiplier','amount','currency','reference','explanation']);fields(component.reference,['id','version']);});};
  state.profiles.forEach(rule);
  for(const period of state.periods){fields(period,['id','start','end','zone','rule','work','audits','closed','closedCalculation']);rule(period.rule);work(period.work);calculation(period.closedCalculation);
    for(const audit of period.audits){fields(audit,['id','createdAt','work','facts','calculation','assessment']);work(audit.work);calculation(audit.calculation);fields(audit.facts,['completeWork','grossBasis','unreviewedFields','unsupportedRules','weeklyReviewPending','paidGross','paidPerDiem']);const result=audit.assessment;fields(result,['engine','verdict','gross','difference','paidGross','comparisons','reasons','periodMatch','reportedPeriod','weeklyContextCount','weeklyReviewReferences','lineMapping']);result.comparisons.forEach(comparison=>fields(comparison,['field','expected','paid','difference','componentIDs','unit']));if(result.reportedPeriod)fields(result.reportedPeriod,['startDate','endDate','timeZone','confirmed']);if(result.lineMapping)fields(result.lineMapping,['layout','hoursBasis','guaranteeLayout','completeEarnings']);}
  }
  state.ruleTimelines.forEach(timeline=>{fields(timeline,['id','periodID','createdAt','confirmed','changes']);timeline.changes.forEach(change=>{fields(change,['effectiveDate','sourceProfileID','agreement']);rule(change.agreement);});});
  state.paycycleSchedules.forEach(schedule=>{fields(schedule,['periodID','window']);fields(schedule.window,['cadence','startDate','endDate','endExclusiveDate','timeZone','startUTC','endExclusiveUTC','elapsedSeconds']);});
  state.paycheckScopes.forEach(scope=>fields(scope,['auditID','periodID','startDate','endDate','timeZone','confirmed']));
  state.paycheckLineScopes.forEach(scope=>{fields(scope,['auditID','periodID','layout','hoursBasis','guaranteeLayout','completeEarnings','amounts','hours']);fields(scope.amounts,['regularPay','overtimePay','doubleTimePay','calloutPay']);fields(scope.hours,['regularHours','overtimeHours','doubleTimeHours']);});
}
export function portableSnapshot(state) {
  nativeInventory(state);
  const unsupported=[['benefitChecks','employer-contribution receipts'],['templateOrigins','crew rule origins'],['resolutionEvents','follow-up events'],['weeklyReviews','weekly review receipts']].filter(([field])=>state[field]?.length);
  need(!unsupported.length,`Portable export refused: this financial state contains ${unsupported.map(([,label])=>label).join(', ')}. Download a complete web recovery copy instead.`);
  if(!state.portableArchive)return encoder.encode(JSON.stringify(exportNative(state)));
  const archive=state.portableArchive;validatePortableArchive(archive);
  const originalProfileIDs=new Set(archive.nativeBaseline.profiles.map(profile=>profile.id)),originalPeriods=new Map(archive.nativeBaseline.periods.map(period=>[period.id,period]));
  for(const baseline of archive.nativeBaseline.profiles)need(same(state.profiles.find(profile=>profile.id===baseline.id),baseline),'An original imported profile was changed or removed. Retain it and create an independent new profile.');
  const retainedPeriodIDs=new Set(),mutablePeriods=[];
  for(const [id,baseline] of originalPeriods){
    const current=state.periods.find(period=>period.id===id);need(current,'An imported source period was removed.');
    const canonicalID=archive.mappings.find(mapping=>mapping.entityType==='period' && mapping.localID===id)?.portableID,source=archive.document.periods.find(period=>period.id===canonicalID),adoptedAway=archive.activationConfirmations.some(confirmation=>confirmation.periodID===id),inactive=!sourceCurrentPeriod(archive.document,source);
    if(adoptedAway || inactive){if(adoptedAway)need(current.work.length===0,'The retired source projection must not receive new work.');const comparable={...clone(current),work:adoptedAway?clone(baseline.work):clone(current.work),closed:baseline.closed,closedCalculation:clone(baseline.closedCalculation)};need(same(comparable,baseline),'A retained source context changed outside its separately adopted copy.');retainedPeriodIDs.add(id);}
    else if(same(current,baseline) && same(state.ruleTimelines.filter(timeline=>timeline.periodID===id),archive.nativeBaseline.ruleTimelines.filter(timeline=>timeline.periodID===id)) && !state.paycycleSchedules.some(schedule=>schedule.periodID===id))retainedPeriodIDs.add(id);
    else {need(!baseline.closed || current.closed,'A closed source context cannot be reopened.');need(same(current.rule,baseline.rule) && current.start===baseline.start && current.end===baseline.end && current.zone===baseline.zone,'Create a separate confirmed context before changing imported period rules or boundaries.');need(!importedConfirmationRequired(state,id),'Independently confirm missing source settings before exporting a changed context.');mutablePeriods.push(current);}
  }
  const newPeriods=state.periods.filter(period=>!retainedPeriodIDs.has(period.id)),selectedIDs=new Set(newPeriods.map(period=>period.id));
  const temporary={...state,portableArchive:null,profiles:state.profiles.filter(profile=>!originalProfileIDs.has(profile.id)),periods:newPeriods,ruleTimelines:state.ruleTimelines.filter(timeline=>selectedIDs.has(timeline.periodID)),paycycleSchedules:state.paycycleSchedules.filter(schedule=>selectedIDs.has(schedule.periodID)),paycheckScopes:state.paycheckScopes.filter(scope=>selectedIDs.has(scope.periodID)),paycheckLineScopes:state.paycheckLineScopes.filter(scope=>selectedIDs.has(scope.periodID))};
  if(!temporary.profiles.length && !temporary.periods.length && !archive.activationConfirmations.length){const unchanged=clone(archive.document);unchanged.source={client:'web',localStateSchema:9,exporterVersion:'web.portable/1'};unchanged.exportedAtEpochSeconds=Math.floor(Date.now()/1000);return encoder.encode(JSON.stringify(unchanged));}
  const appended=exportNative(temporary,archive,false),document=clone(archive.document);
  document.source=appended.source;document.exportedAtEpochSeconds=appended.exportedAtEpochSeconds;
  const merge=(field,key=item=>item.id)=>{
    const map=new Map(document[field].map(item=>[key(item),item]));
    for(const item of appended[field]){
      if(field==='periods' && map.has(item.id)){
        const original=map.get(item.id);map.set(item.id,{...original,closed:item.closed,currentWorkSnapshotRef:item.currentWorkSnapshotRef,workSnapshotRefs:[...new Set([...original.workSnapshotRefs,...item.workSnapshotRefs])],ruleTimelineRefs:[...new Set([...original.ruleTimelineRefs,...item.ruleTimelineRefs])],ruleChangeRefs:[...new Set([...original.ruleChangeRefs,...item.ruleChangeRefs])],calculation:item.calculation});
      }else {need(!map.has(key(item))||same(map.get(key(item)),item),`Conflicting retained ${field} identity.`);map.set(key(item),item);}
    }document[field]=[...map.values()];
  };
  for(const field of ['profiles','ruleSnapshots','ruleChanges','ruleTimelines','periods','workSnapshots','paycheckReceipts','attachments'])merge(field);
  merge('identityCrosswalk',item=>item.entityType+'|'+item.portableID);
  for(const confirmation of archive.activationConfirmations){
    const id='web:profileAdoption:'+confirmation.adoptionID;
    if(document.adoptions.some(adoption=>adoption.id===id))continue;
    const adoptedPeriod=appended.periods.find(period=>period.id==='web:period:'+confirmation.adoptedPeriodID),sourcePeriod=archive.mappings.find(mapping=>mapping.entityType==='period' && mapping.localID===confirmation.periodID)?.portableID;
    need(adoptedPeriod,'The adopted editable context must be retained for export.');
    if(sourcePeriod){const original=document.periods.find(period=>period.id===sourcePeriod);original.isCurrent=false;original.fieldsNotRecorded=original.fieldsNotRecorded.filter(field=>field!=='isCurrent');}
    document.adoptions.push({id,sourceProfileRef:confirmation.sourceProfileRef,adoptedProfileRef:adoptedPeriod.profileRef,sourcePeriodRef:sourcePeriod??null,adoptedPeriodRef:adoptedPeriod.id,sourceWorkSnapshotRef:confirmation.sourceWorkSnapshotRef,adoptedWorkSnapshotRef:adoptedPeriod.currentWorkSnapshotRef,sourceRuleRefs:[confirmation.sourceRuleRef],adoptedRuleRefs:[adoptedPeriod.ruleRef],confirmedAtEpochSeconds:Date.parse(confirmation.confirmedAt)/1000,confirmedFields:['rounding','periodWindow'],fieldsNotRecorded:[]});
    document.identityCrosswalk.push({entityType:'profileAdoption',portableID:id,originClient:'web',originKind:'native',originLocalID:confirmation.adoptionID});
  }
  const latestProfile=state.profiles.at(-1),mapped=archive.mappings.find(mapping=>mapping.entityType==='profile' && mapping.localID===latestProfile?.id);
  document.activeProfileRef=pendingImportedDefault(state)?archive.document.activeProfileRef:latestProfile?(mapped?.portableID??'web:profile:'+latestProfile.id):archive.document.activeProfileRef;
  document.sourceInventory=inventoryFor(document);validatePortable(document);
  return encoder.encode(JSON.stringify(document));
}
function exportNative(state,archive=null,validateResult=true) {
  const document={format:PORTABLE_FORMAT,version:1,exportedAtEpochSeconds:Math.floor(Date.now()/1000),source:{client:'web',localStateSchema:9,exporterVersion:'web.portable/1'},sourceInventory:{},identityCrosswalk:[],activeProfileRef:null,adoptions:[],profiles:[],ruleSnapshots:[],ruleChanges:[],ruleTimelines:[],periods:[],workSnapshots:[],paycheckReceipts:[],attachments:[]};
  const seen=new Set(), origin=(kind,localID,context='',derived=false)=>{
    const candidate=archive?.mappings.find(mapping=>mapping.entityType===kind && mapping.localID===localID),mapping=kind==='ruleSnapshot' && context && archive?.document.ruleSnapshots.find(rule=>rule.id===candidate?.portableID)?.version!==context?null:candidate;
    const portableID=mapping?.portableID??('web:'+kind+':'+(context?context+':':'')+localID);
    need(/^[A-Za-z0-9._:-]{1,192}$/.test(portableID),'A source identity exceeds portable limits; no partial file was created.');
    const key=kind+'|'+portableID;
    if(!seen.has(key)){seen.add(key);document.identityCrosswalk.push(mapping?clone(archive.document.identityCrosswalk.find(identity=>identity.entityType===kind && identity.portableID===portableID)):{entityType:kind,portableID,originClient:'web',originKind:derived?'derived':'native',originLocalID:derived?null:localID});}
    return portableID;
  }, money=(amount,currency)=>amount===null?null:{amount,currency}, nextDate=date=>new Date(Date.parse(date+'T00:00:00Z')+86400000).toISOString().slice(0,10);
  const window=(start,end,zone)=>({startDate:start,endDateInclusive:end,endExclusiveDate:end===null?null:nextDate(end),timeZone:zone,boundaryModel:start===null?'sourcePeriodUnknown':'localDatesOnly',startEpochSeconds:null,endExclusiveEpochSeconds:null,fieldsNotRecorded:['startEpochSeconds','endExclusiveEpochSeconds']});
  const ruleRef=rule=>{
    const mappedRule=archive?.mappings.find(mapping=>mapping.entityType==='ruleSnapshot' && mapping.localID===rule.id),mappedProfile=archive?.mappings.find(mapping=>mapping.entityType==='profile' && mapping.localID===rule.id),sourceProfile=archive?.document.profiles.find(profile=>profile.id===mappedProfile?.portableID),identityRule=archive?.document.ruleSnapshots.find(source=>source.id===(mappedRule?.portableID??sourceProfile?.ruleRef)),sourceRule=archive?.document.ruleSnapshots.find(source=>source.ruleID===identityRule?.ruleID && source.version===rule.version && same(nativeRule(source,rule.id),rule));
    if(sourceRule && same(nativeRule(sourceRule,rule.id),rule))return sourceRule.id;
    const id=origin('ruleSnapshot',rule.id,rule.version);
    if(!document.ruleSnapshots.some(rule=>rule.id===id))document.ruleSnapshots.push({id,ruleID:identityRule?.ruleID??rule.id,version:rule.version,displayName:null,effectiveStartDate:null,effectiveEndDateInclusive:null,currency:rule.currency,hourlyRate:rule.hourlyRate,regularSchedule:clone(rule.regularSchedule),dailyOvertimeTiers:clone(rule.dailyOvertimeTiers),outsideScheduleMultiplier:rule.outsideScheduleMultiplier,weekdayPremiums:clone(rule.weekdayPremiums),datePremiums:clone(rule.datePremiums),calloutMinimumHours:rule.calloutMinimumHours,perDiemPerWorkDate:money(rule.perDiemPerWorkDate,rule.currency),weeklyOvertime:null,rounding:{...rule.rounding,mode:rule.rounding.mode==='bankers'?'halfEven':rule.rounding.mode},sources:null,unsupportedRuleNotes:null,confirmedAtEpochSeconds:null,confirmedByWorker:null,fieldsNotRecorded:['confirmedByWorker','displayName','effectiveStartDate','effectiveEndDateInclusive','weeklyOvertime','sources','unsupportedRuleNotes','confirmedAtEpochSeconds']});
    const confirmation=archive?.activationConfirmations.find(confirmation=>confirmation.newRuleID===rule.id);
    if(confirmation){const source=archive.document.ruleSnapshots.find(source=>source.id===confirmation.sourceRuleRef),at=document.ruleSnapshots.findIndex(snapshot=>snapshot.id===id);document.ruleSnapshots[at]={...clone(source),id,ruleID:rule.id,version:rule.version,rounding:{...clone(confirmation.rounding),mode:confirmation.rounding.mode==='bankers'?'halfEven':confirmation.rounding.mode},fieldsNotRecorded:source.fieldsNotRecorded.filter(field=>field!=='rounding')};}
    return id;
  };
  for(const profile of state.profiles)document.profiles.push({id:origin('profile',profile.id),name:null,timeZone:null,cadence:null,cycleStartDate:null,customEndDate:null,ruleRef:ruleRef(profile),baselineRuleRef:null,ruleChangeRefs:[],currentPeriodRef:null,currentWorkSnapshotRef:null,adoptedFromProfileRef:null,fieldsNotRecorded:['adoptedFromProfileRef','name','timeZone','cadence','cycleStartDate','customEndDate','baselineRuleRef','currentPeriodRef','currentWorkSnapshotRef']});
  for(const profile of document.profiles){const adoption=archive?.activationConfirmations.find(confirmation=>'web:profile:'+confirmation.newRuleID===profile.id);if(adoption){profile.adoptedFromProfileRef=adoption.sourceProfileRef;profile.fieldsNotRecorded=profile.fieldsNotRecorded.filter(field=>field!=='adoptedFromProfileRef');}}
  const workSnapshot=(work,period,profileRef,context,role)=>{
    const id=origin('workSnapshot',context,'',true), workMap=new Map();
    const sourcePeriod=archive?.document.periods.find(source=>source.id===period),adoption=archive?.activationConfirmations.find(confirmation=>'web:period:'+confirmation.adoptedPeriodID===period),sourceSnapshot=sourcePeriod?sourceWorkForPeriod(archive.document,sourcePeriod):archive?.document.workSnapshots.find(snapshot=>snapshot.id===adoption?.sourceWorkSnapshotRef);
    const entries=work.map(entry=>{
      const workID=origin('workEntry',entry.id);workMap.set(entry.id,workID);const sourceWork=sourceSnapshot?.work.find(work=>work.id===workID);
      return {id:workID,startEpochSeconds:Date.parse(entry.startUTC)/1000,endEpochSeconds:Date.parse(entry.endUTC)/1000,timeZone:entry.timeZone,kind:entry.kind,calloutEventRef:entry.calloutEventID===null?null:origin('calloutEvent',entry.calloutEventID),unpaidBreaks:entry.unpaidBreaks.map(pause=>({id:origin('workBreak',pause.id),startEpochSeconds:Date.parse(pause.startUTC)/1000,endEpochSeconds:Date.parse(pause.endUTC)/1000})),note:sourceWork?.note??null,fieldsNotRecorded:sourceWork?.note!==undefined && sourceWork.note!==null?[]:['note']};
    });
    document.workSnapshots.push({id,profileRef,periodRef:period,role,revision:null,sourceRef:sourceSnapshot?.id??null,work:entries,fieldsNotRecorded:['revision',...(!sourceSnapshot?['sourceRef']:[])]});return {id,workMap};
  };
  const calculationSnapshot=(calculation,period,workMap,context)=>{
    const currency=period.rule.currency,componentMap=new Map(),retainedRules=calculation.ruleSnapshots??[period.rule],ruleRefs=retainedRules.map(ruleRef),primaryRuleRef=ruleRef(period.rule);
    const components=calculation.components.map(component=>{
      const componentID=origin('calculationComponent',component.id);componentMap.set(component.id,componentID);
      const applied=retainedRules.find(rule=>rule.id===component.reference.id && rule.version===component.reference.version);
      need(applied,'Calculation component is missing its exact rule snapshot.');
      return {id:componentID,category:component.category,workRef:component.workID===null?null:workMap.get(component.workID),localDate:component.date,hours:null,workedSeconds:component.workedSeconds,multiplier:component.multiplier,amount:money(component.amount,component.currency),explanation:component.explanation,ruleKeys:null,baseRate:component.baseRate?money(component.baseRate,currency):null,appliedAgreement:{ruleRef:ruleRef(applied),ruleID:(document.ruleSnapshots.find(rule=>rule.id===ruleRef(applied))??archive?.document.ruleSnapshots.find(rule=>rule.id===ruleRef(applied))).ruleID,version:component.reference.version,hourlyRate:null},unroundedAmount:null,baseTimeNumerator:null,fieldsNotRecorded:['appliedAgreement.hourlyRate','hours','ruleKeys',...(!component.baseRate?['baseRate']:[]),'unroundedAmount','baseTimeNumerator']};
    });
    const timeline=calculation.ruleTimelineID?document.ruleTimelines.find(timeline=>timeline.id===origin('ruleTimeline',calculation.ruleTimelineID)):null;
    const primaryRule=document.ruleSnapshots.find(rule=>rule.id===primaryRuleRef)??archive?.document.ruleSnapshots.find(rule=>rule.id===primaryRuleRef);
    const result={agreementID:primaryRule.ruleID,agreementVersion:period.rule.version,primaryRuleRef,agreementSnapshotRefs:ruleRefs,currency,total:money(calculation.total,currency),engine:calculation.engine,coverage:calculation.coverage,wages:money(calculation.wages,currency),allowances:money(calculation.allowances,currency),ruleTimelineRef:timeline?.id??null,ruleChangeRefs:timeline?.ruleChangeRefs??[],provenance:null,weeklyRegularRate:null,components,fieldsNotRecorded:[...(!timeline?['ruleTimelineRef']:[]),'provenance','weeklyRegularRate']};
    return {result,componentMap,ruleRefs};
  };
  for(const period of state.periods){
    // Period snapshots may outlive the source profile. Preserve them as a separate explicitly unnamed profile.
    const periodID=origin('period',period.id),retainedPeriod=archive?.document.periods.find(source=>source.id===periodID);
    let sourceProfile=[...state.profiles,...(archive?.nativeBaseline.profiles??[])].find(profile=>profile.id===period.rule.id && profile.version===period.rule.version);
    const profileID=retainedPeriod?.profileRef??(sourceProfile?origin('profile',sourceProfile.id):origin('profile',period.id,'period-source',true));
    if(!document.profiles.some(profile=>profile.id===profileID) && !archive?.document.profiles.some(profile=>profile.id===profileID))document.profiles.push({id:profileID,name:null,timeZone:null,cadence:null,cycleStartDate:null,customEndDate:null,ruleRef:ruleRef(period.rule),baselineRuleRef:null,ruleChangeRefs:[],currentPeriodRef:null,currentWorkSnapshotRef:null,adoptedFromProfileRef:null,fieldsNotRecorded:['adoptedFromProfileRef','name','timeZone','cadence','cycleStartDate','customEndDate','baselineRuleRef','currentPeriodRef','currentWorkSnapshotRef']});
    const ruleID=ruleRef(period.rule),live=workSnapshot(period.work,periodID,profileID,period.id+'-r'+state.revision,'periodRevision'),schedule=state.paycycleSchedules.find(item=>item.periodID===period.id);
    const savedPeriod={id:periodID,profileRef:profileID,calendarWindow:window(period.start,period.end,period.zone),cadence:schedule?.window.cadence??null,isCurrent:!period.closed,closed:period.closed,archivedAtEpochSeconds:null,calculationIssue:null,ruleRef:ruleID,ruleChangeRefs:[],currentWorkSnapshotRef:live.id,workSnapshotRefs:[live.id],workCorrections:[],windowRef:archive?.document.periods.find(source=>source.id===periodID)?.windowRef??origin('periodWindow',period.id,'',true),ruleTimelineRefs:[],calculation:null,auditCompletedAtEpochSeconds:null,workRevision:null,fieldsNotRecorded:['calculation','auditCompletedAtEpochSeconds','workRevision','archivedAtEpochSeconds','calculationIssue',...(!schedule?['cadence']:[])]};
    if(schedule){savedPeriod.calendarWindow={...savedPeriod.calendarWindow,boundaryModel:'exactInstants',startEpochSeconds:Date.parse(schedule.window.startUTC)/1000,endExclusiveEpochSeconds:Date.parse(schedule.window.endExclusiveUTC)/1000,fieldsNotRecorded:[]};}
    const adoption=archive?.activationConfirmations.find(confirmation=>confirmation.adoptedPeriodID===period.id),sourcePeriodID=adoption?archive.mappings.find(mapping=>mapping.entityType==='period' && mapping.localID===adoption.periodID)?.portableID:periodID,sourcePeriod=archive?.document.periods.find(source=>source.id===sourcePeriodID);
    if(sourcePeriod){savedPeriod.calendarWindow=clone(sourcePeriod.calendarWindow);savedPeriod.cadence=sourcePeriod.cadence;if(sourcePeriod.cadence!==null)savedPeriod.fieldsNotRecorded=savedPeriod.fieldsNotRecorded.filter(field=>field!=='cadence');}
    document.periods.push(savedPeriod);
    for(const timeline of state.ruleTimelines.filter(item=>item.periodID===period.id)) {
      const timelineID=origin('ruleTimeline',timeline.id),changes=timeline.changes.map((change,index)=>{
        const id=origin('ruleChange',String(index),timeline.id,true);
        document.ruleChanges.push({id,profileRef:profileID,periodRef:periodID,effectiveDate:change.effectiveDate,sourceProfileRef:origin('profile',change.sourceProfileID),ruleRef:ruleRef(change.agreement),confirmed:timeline.confirmed,createdAtEpochSeconds:Date.parse(timeline.createdAt)/1000,fieldsNotRecorded:[]});return id;
      });
      document.ruleTimelines.push({id:timelineID,periodRef:periodID,baselineRuleRef:ruleID,ruleChangeRefs:changes,createdAtEpochSeconds:Date.parse(timeline.createdAt)/1000,confirmed:timeline.confirmed,fieldsNotRecorded:[]});
      savedPeriod.ruleTimelineRefs.push(timelineID);savedPeriod.ruleChangeRefs.push(...changes);
    }
    if(period.closedCalculation!==null){savedPeriod.calculation=calculationSnapshot(period.closedCalculation,period,live.workMap,period.id+'-closed').result;savedPeriod.fieldsNotRecorded=savedPeriod.fieldsNotRecorded.filter(field=>field!=='calculation');}

    for(const audit of period.audits){
      const id=origin('paycheckReceipt',audit.id),snapshot=workSnapshot(audit.work,periodID,profileID,audit.id,'auditRevision');savedPeriod.workSnapshotRefs.push(snapshot.id);
      const scope=state.paycheckScopes.find(item=>item.auditID===audit.id),lines=state.paycheckLineScopes.find(item=>item.auditID===audit.id),currency=period.rule.currency,created=Date.parse(audit.createdAt)/1000,componentMap=new Map();
      const mappedCalculation=calculationSnapshot(audit.calculation,period,snapshot.workMap,audit.id);
      mappedCalculation.componentMap.forEach((value,key)=>componentMap.set(key,value));
      const lineAmounts=Object.entries(lines?.amounts??{}).map(([field,amount])=>({field,amount:money(amount,currency)})),lineHours=Object.entries(lines?.hours??{}).map(([field,hours])=>({field,hours}));
      const missingPaystub=['confirmed','regularHours','regularPay','overtimeHours','overtimePay','doubleTimeHours','doubleTimePay','calloutPay','notes','confirmedAtEpochSeconds','evidenceRef'];
      const receipt={receiptKind:'paycheck-v1',id,targetWindowRef:savedPeriod.windowRef,targetWindow:clone(savedPeriod.calendarWindow),targetCadence:savedPeriod.cadence,targetRuleChangeRefs:clone(mappedCalculation.result.ruleChangeRefs),periodRef:periodID,workSnapshotRef:snapshot.id,createdAtEpochSeconds:created,supersedesReceiptRef:null,producer:{client:'web',localStateSchema:null,calculationEngineID:audit.calculation.engine,calculationEngineVersion:null,assessmentEngineID:audit.assessment.engine,assessmentEngineVersion:null,fieldsNotRecorded:['localStateSchema','calculationEngineVersion','assessmentEngineVersion']},ruleRefs:mappedCalculation.ruleRefs,sourcePeriod:scope?{startDate:scope.startDate,endDateInclusive:scope.endDate,timeZone:scope.timeZone,confirmed:scope.confirmed,fieldsNotRecorded:[]}:null,paystubFacts:{id:origin('paystub',audit.id,'',true),confirmed:null,periodStartDate:scope?.startDate??null,periodEndDateInclusive:scope?.endDate??null,currency,grossPay:audit.facts.paidGross,regularHours:null,regularPay:null,overtimeHours:null,overtimePay:null,doubleTimeHours:null,doubleTimePay:null,calloutPay:null,perDiemPay:audit.facts.paidPerDiem,notes:null,confirmedAtEpochSeconds:null,evidenceRef:null,fieldsNotRecorded:[...missingPaystub,...(!scope?['periodStartDate','periodEndDateInclusive']:[])]},lineFacts:{grossBasis:audit.facts.grossBasis,lineLayout:lines?.layout??null,hoursBasis:lines?.hoursBasis??null,guaranteeLayout:lines?.guaranteeLayout??null,amounts:lines?lineAmounts:null,hours:lines?lineHours:null,reviewedFields:null,suggestions:null,hasAdditionalUnmappedPay:null,workComplete:audit.facts.completeWork,earningsLinesComplete:lines?.completeEarnings??null,fieldsNotRecorded:['reviewedFields','suggestions',...(!lines?['amounts','hours']:[]),'hasAdditionalUnmappedPay',...(!lines?['lineLayout','hoursBasis','guaranteeLayout','earningsLinesComplete']:[])]},reviewFacts:{completeWorkConfirmed:audit.facts.completeWork,ruleCoverageConfirmed:!audit.facts.unsupportedRules,unreviewedFields:audit.facts.unreviewedFields,weeklyReviewPending:audit.facts.weeklyReviewPending,fieldsNotRecorded:[]},calculation:mappedCalculation.result,assessment:{engineID:audit.assessment.engine,engineVersion:null,verdict:audit.assessment.verdict,scope:audit.assessment.comparisons.some(comparison=>comparison.field!=='grossPay')?'confirmedLines':'grossOnly',expectedGross:money(audit.assessment.gross,currency),paidGross:money(audit.assessment.paidGross,currency),difference:money(audit.assessment.difference,currency),comparisons:audit.assessment.comparisons.map(comparison=>({id:comparison.field,field:comparison.field,expected:comparison.expected,paid:comparison.paid,difference:comparison.difference,unit:comparison.unit??'money',currency,componentRefs:comparison.componentIDs.map(id=>componentMap.get(id))})),reviewReasons:clone(audit.assessment.reasons),scopeNotes:null,reportedPeriod:audit.assessment.reportedPeriod?{startDate:audit.assessment.reportedPeriod.startDate,endDateInclusive:audit.assessment.reportedPeriod.endDate,timeZone:audit.assessment.reportedPeriod.timeZone,confirmed:audit.assessment.reportedPeriod.confirmed,fieldsNotRecorded:[]}:null,periodMatch:audit.assessment.periodMatch??null,weeklyContextCount:audit.assessment.weeklyContextCount??null,weeklyReviewRefs:clone(audit.assessment.weeklyReviewReferences??null),fieldsNotRecorded:['scopeNotes',...(!Object.hasOwn(audit.assessment,'weeklyReviewReferences')?['weeklyReviewRefs']:[]),'engineVersion',...(!Object.hasOwn(audit.assessment,'reportedPeriod')?['reportedPeriod']:[]),...(!Object.hasOwn(audit.assessment,'periodMatch')?['periodMatch']:[]),...(!Object.hasOwn(audit.assessment,'weeklyContextCount')?['weeklyContextCount']:[])]},auditRevisionRef:origin('auditRevision',audit.id,'',true),reconciliation:null,attachmentRefs:[],fieldsNotRecorded:[...(savedPeriod.cadence===null?['targetCadence']:[]),'supersedesReceiptRef','reconciliation',...(!scope?['sourcePeriod']:[])]};
      document.paycheckReceipts.push(receipt);
    }
  }
  document.activeProfileRef=state.profiles.at(-1)?origin('profile',state.profiles.at(-1).id):null;
  document.sourceInventory=inventoryFor(document);
  return validateResult?validatePortable(document):document;
}
