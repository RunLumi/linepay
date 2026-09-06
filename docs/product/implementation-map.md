# Product-to-code traceability map

[Product home](README.md) · [Business rules](business-rules.md) · [Payroll coverage](payroll/coverage-and-gaps.md) · [Remediation tracker #49](https://github.com/streamentry/linepay/issues/49)

**Reviewed September 6, 2026. This is a pinned source/test audit, not a release certificate.**

## Baselines and evidence

| Source | Revision |
|---|---|
| Product handbook | `990154cb517773036c29d8051a30e7e0edf9feaa`, PR #12, unmerged at review |
| Application and tests | `4fe319dc13836eb4e061442f2f9aae53c4d3b00a` on main |
| Related native remediation | PR #34, head `15cec8849864ba9dee0a4a5bba69e114b088370a`, draft/unmerged at review |

The reviewed local application archive was verified against live Git tree hashes: App `e57e993d805267404e1aa29acb1b5878437f788b`, AppTests `49bf43c5c3f0cb64bb889e21eccdde35b021c380`, AppUITests `397354932576ef581cfd39b31da4f9d5b94e86cf`, domain Sources `0098636fa4702e54782c93eaa5152ab6c6bee467`, domain Tests `ceae6beb49f750aa90a1edcb541213c9688e472d`. Product file blobs were checked against the handbook branch. EX-13 was read from the final pinned document rather than copied from an older archive variant.

**Executed:** 82 existing domain tests passed on Swift 6.2.1/Linux. The isolated copied package manifest changed tools-version 6.3 to 6.2; production domain Swift files were byte-identical. Four extra observation probes reproduced current rounding, source-consistency, callout and weekly-scope behavior. Their passing assertions describe existing problematic behavior, not fixed regressions. A separate extracted Foundation probe reproduced repeat-template DST behavior.

**Not executed here:** Xcode 26.6, native AppModel/StoreKit/Vision/UI tests, physical-device interaction, or live App Store checks. Existing native test files and previous CI reports do not establish those outcomes for this review.

### Status legend

- **P:** related existing domain regression executed portably; not proof of every requirement variant.
- **S:** implementation and related tests inspected in source; not natively executed in this audit.
- **Partial:** a concrete gap or explicitly limited subset.
- **Unsupported/reference:** deliberately outside current represented capability; not automatically a new 1.0 feature.
- **External/unverified:** device, source/applicability or storefront evidence remains necessary.

Do not combine these into a misleading completeness percentage. A file existing, a passing test and legally reviewed coverage are different facts.

## Issues and observed counterexamples

| Issue | Type | Finding |
|---|---|---|
| [#38](https://github.com/streamentry/linepay/issues/38) | P1 behavior | Contradictory confirmed paycheck totals can produce a directional verdict |
| [#39](https://github.com/streamentry/linepay/issues/39) | P1 calculation policy | Internal segmentation changes rounded wages without changing rate or work |
| [#40](https://github.com/streamentry/linepay/issues/40) | P1 time entry | Repeat moves breaks across DST and silently normalizes nonexistent times |
| [#41](https://github.com/streamentry/linepay/issues/41) | P1 event model | A physical callout has no identity separate from each work-entry row |
| [#42](https://github.com/streamentry/linepay/issues/42) | P1 scoped capability | Workweek/regular-rate reference layer is not implemented |
| [#44](https://github.com/streamentry/linepay/issues/44) | P1 lifecycle | Unpriceable saved period A blocks closing A and logging period B |
| [#45](https://github.com/streamentry/linepay/issues/45) | P2 provenance | Calculation-engine identity is missing from saved calculation results |
| [#46](https://github.com/streamentry/linepay/issues/46) | P2 specification | Same-day EX-09 does not fit the midnight-only rule timeline |
| [#47](https://github.com/streamentry/linepay/issues/47) | P2 scope | Optional reminder acceptance needs explicit implementation or deferral |

#42 and #44 were created concurrently and reused. #43 was closed as a duplicate of #42. The correct unequal-hours EX-13 value was added to #42 by comment. Keep one implementation ticket per finding.

| Probe | Synthetic input | Observed result | Meaning |
|---|---|---|---|
| R1 | $50/hour, 08:00–08:02, 1x everywhere | $1.67 as one segment; $1.66 as two one-minute entries, or with an irrelevant 08:01 schedule boundary | #39: define the approved rounding scope; no universal legal rounding rule inferred |
| R2 | Expected $550; paid gross $500 but confirmed regular $400 plus OT $150 | `possibleShortfall`, $50 difference, no review reason | #38: the paid-source facts contradict each other |
| R3 | One two-hour Tuesday callout, $50, 2x, four-hour minimum | One record $400; two adjacent records $800 | #41: distinguish event identity from rows; do not automatically merge genuinely separate calls |
| R4 | Six eight-hour days, $50, only daily 1.5x after eight | Configured $2,400; handbook restricted weekly reference $2,600 | #42: omitted reference layer, not incorrect configured daily arithmetic |
| R5 | New York March 7, 2026 00:00–08:00 with 04:00 break, repeated March 8 | Shift stays 00:00–08:00, break becomes 05:00; repeated 02:30 normalizes to 03:00 | #40: extracted Foundation path, not a native UI execution |

#44 is source-traced: the domain rejects an ambiguous spanning-callout guarantee; AppModel retains the work with no calculation; archive requires a calculation; starting B requires no active period. Its extended native close/relaunch/start-B test still needs to run.

## Business-rule mapping: all 45 IDs

Code links are pinned to the reviewed application commit. Test links identify related coverage and named methods, not complete execution evidence for every clause.

| ID | Implementation | Related tests | Status and remaining boundary |
|---|---|---|---|
| BR-001 | [STATE], [STORE], project.yml | Brand/launch configuration tests | S: public and technical identities remain distinct; no new gap |
| BR-002 | [AM], [LOCAL], [OCR], [STORE] | [StorageContractTests], [SubscriptionBehaviorTests] | S: core local; commerce and deliberate export have separate external requirements |
| BR-003 | [STATE] PayProfile; [AM] candidateForProfile | [RuleScopeRegressionTests] | S: one-profile scope; no multi-employer statutory aggregation implied |
| BR-004 | [LEDGER], [ASSESS], [REPORT] | [AuditScopeRegressionTests] | Partial: known legal coverage disclosure #14 and calculation-version gap #45 |
| BR-005 | [PROFILE], [ASSESS] | [ScreenContractTests] | Partial: confirmation is not reviewed legal coverage; #14/#26 |
| BR-006 | [PROFILE] unsupported notes; [ASSESS] reviewReasons | [PaycheckAssessmentTests] uncertainComponentsAndUnsupportedRulesCannotPassCleanly | Partial: explicit omissions handled, inherently missing layers need #14/PR #34 |
| BR-010 | [PROFILE], [ROOT] | [ScreenContractTests]; onboarding Maestro | S plus scope gap: progressive confirmation exists; #14 disclosure |
| BR-011 | [TL], [DM] snapshots/results | [AgreementTimelineTests], [TimelinePersistenceTests] | Partial: agreement versions exist; calculation-engine identity missing #45 |
| BR-012 | [AM] candidateForProfile; [PROFILE] review | [RuleScopeRegressionTests] previewIsReadOnlyAndCorrectionIsExplicit | Partial: numerical guards exist; inaccurate dated consent #15, pending PR #34 |
| BR-013 | [DM], [TL], [AM] period windows | [AgreementTimelineTests], [ReadinessBoundaryTests] | Partial: payroll timezone explicit; statutory week/non-midnight contract day not represented (#42/#14); repeat DST #40 |
| BR-014 | [AM] correctCurrentPeriod | [ReadinessTests] periodCorrectionRejectsMovingWorkOrOverlap | S: containment, overlap and invalidation paths exist; old no-op-date defect not reopened |
| BR-015 | [DM] AgreementSource.ruleKey; [PROFILE] | [AppFailurePathTests] profileDraftKeepsScheduleSourceAndEffectiveDates | S: per-rule references; external preset approval remains #26 |
| BR-020 | [DM] WorkInterval; [PC] guarantee category | [PayCalculatorInvariantTests] actualCalloutBreakAndGuaranteedPayStaySeparate | Partial: worked/paid equivalents separated, physical event identity #41 |
| BR-021 | [DM] guards; [AM] add/update/delete | [AppModelContractTests] workGuardsAndUndoAreSafe | S plus gap: row ID/overlap validation does not establish independent callout triggers (#41) |
| BR-022 | [WORK] repeatDates and break offsets; [AM] lastWork | [ScreenContractTests] addEditAndRepeatFormsRetainTheirWorkFacts | Partial: rollover reuse exists; DST construction counterexample #40 |
| BR-023 | [AM] draft save/discard; [STATE] | [ReadinessTests] workAndIntakeDraftsSurviveNewModel; [JOURNEY] | S: draft/context persistence represented; native interruption acceptance separate |
| BR-024 | [AM] deleteWork/restoreDeletedWork | [ReadinessTests] staleUndoCannotMoveWorkToNextPeriod / undoRejectsAnInterveningEdit | S: period/revision-bound Undo present; old defect not reopened |
| BR-025 | [AM] archiveCurrentPeriod and historical confirm | [IntegratedReadinessTests] sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules | Partial: normal delayed-paycheck path exists; unpriceable-A path #44 |
| BR-026 | [STATE] AuditRevision; [AM] confirmPaystub | [ReadinessTests] closedAuditCorrectionsAppendRevisions | Partial: immutable facts/rules/results present; calculator identity #45 |
| BR-027 | [LEDGER] close confirmation; [HISTORY] | [PeriodAndEvidenceTests] periodCadencesAndArchive | Partial: priceable unaudited periods can await pay; unpriceable closed state #44 |
| BR-028 | [AM] calculation/error paths; [LEDGER] | [AuditScopeRegressionTests] missingAndStaleCalculationsAreNotSuccess | S plus lifecycle gap: reject false success without blocking subsequent work (#44) |
| BR-030 | [IMPORT], [OCR], DocumentScannerView | [DocumentPipelineTests], [JOURNEY] | S: shared confirmation path; native scanner/device permission acceptance unverified here |
| BR-031 | [PARSER], [OCR], [SOURCE] | [OCRParserTests] currentNeverSelectsYTD / repeatedLabelsDoNotGuess | S: provenance and abstention present, not universal layout coverage |
| BR-032 | [OP], [IMPORT] | [PaystubImportOperationTests] cancelledReadCannotClaimOrFinishANewerImport | S: token-bound intake/cancellation present |
| BR-033 | [DECIMAL], [PARSER], [AM] | [PaycheckAssessmentTests], [ParserAndFormatTests] | P/S: strict domain parsing passed portably; native document tests not rerun |
| BR-034 | [AM] confirmPaystub; [ASSESS] facts | [IntegratedReadinessTests] partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess | Partial: completeness/date/currency guards present, contradictory paid totals #38 |
| BR-035 | [ASSESS], [IMPORT] basis controls | [PaycheckAssessmentTests] premiumOnlyLayoutAndHours / perDiemExcludedFromWageGross | P/S: explicit mappings represented; source subtotal consistency #38 |
| BR-036 | [ASSESS], AuditAssessment, [REPORT] | [PaycheckAssessmentTests] matchingGrossDoesNotHideOffsettingErrors | Partial: old offsetting case addressed; new contradiction #38 and legal scope #14 |
| BR-037 | [RECEIPT], [SOURCE], [LEDGER], AuditDetailView | [JOURNEY] testAuditVerdictsAndEvidenceRoutes; [ScreenContractTests] | S: in-app trace present; private PDF preview #20/PR #34 |
| BR-038 | [ASSESS], AuditStatusView, AboutLinePayView | [ParserAndFormatTests] statusIsTextualAndHasAnIcon | S plus review: neutral labels present; deadline/support/copy controls #29 |
| BR-040 | [STORE], [PAYWALL] | [StoreKitLifecycleTests], [SubscriptionBehaviorTests] | S: existing IDs/localized catalog; live storefront #18 |
| BR-041 | [AM] canAudit/confirmPaystub access | [IntegratedReadinessTests] paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry | S: independent Free allowance and already-authorized rechecks represented |
| BR-042 | [FIRST], [ROOT], [PAYWALL] | [IntegratedReadinessTests] firstRealResultSurvivesInterruptionAndOnlyAppearsOnce | S: proof then optional offer exists; optional reminder scope #47 |
| BR-043 | [STORE], [OPS] | [StoreKitLifecycleTests], [SubscriptionBehaviorTests] | S: verified lifecycle branches/tests present; native and live evidence #18/#37 |
| BR-044 | [STORE] load/refreshEntitlements | [SubscriptionBehaviorTests] existingOwnershipSurvivesCatalogFailure | S: earlier catalog-gating problem addressed; not reopened |
| BR-045 | [AM] access gate; [HISTORY], [SETTINGS] | [IntegratedReadinessTests], [SubscriptionBehaviorTests] | S: saved record/export access not treated as a new audit; live/copy verification #18 |
| BR-046 | [AM] sampling state; [BACKUPMAP] | [BackupTests] preservesFreeAllowance; [IntegratedReadinessTests] | S: local backup cannot grant verified Pro; no account required |
| BR-050 | [LOCAL], [EVIDENCE], [BACKUP], [SETTINGS] | [BackupValidationTests]; backup-consent Maestro | S plus external gap: provider/export behavior distinct; doc-branch copy drift #17/PR #12 |
| BR-051 | [AM] confirmPaystub/removeEvidence | [PeriodAndEvidenceTests] manualCorrectionPreservesOriginalAndFailedReplacementRollsBack | S: manual correction retains original by default; old defect not reopened |
| BR-052 | [AM] retryEvidenceDeletion; [EVIDENCE]; TemporaryExports | [ReadinessTests] failedEvidenceDeletionRemainsRetryable; [AppFailurePathTests] | Partial: cleanup queue exists; expanded temporary-sharing boundary #21/#20/PR #34 |
| BR-053 | [LOCAL], [VALIDATE], [AM] commit | [StorageContractTests], [AppFailurePathTests] | S: atomic/failure fixtures present; native filesystem tests not rerun |
| BR-054 | [BACKUP], [BACKUPMAP], BackupRestoreView | [BackupValidationTests], [BackupConcurrencyTests], [BackupTests] | S: validation/staging/rollback represented; actual provider evidence #21 |
| BR-055 | [STATE], [BACKUPMAP], [VALIDATE] | [TimelinePersistenceTests]; [IntegratedReadinessTests] staticV1FixturePreservesHistoricalMeaningAndOriginal | Partial: historical values/versions preserved; calculation-engine identity #45 |
| BR-056 | [REPORT], [RECEIPT] | [ReportExporterTests], [DocumentPipelineTests] | Partial: comparison engine shown, pay-calculation engine missing #45; private sharing #20 |
| BR-057 | DesignTokens, [RECOVERY], [SETTINGS], [PAYWALL] | [ScreenContractTests], [JOURNEY]; adaptive-layout Maestro | S plus unverified: representative tests are not all-screen/device acceptance (#31/#37) |

## Pay-rule mapping: all 18 concepts

The catalog enumerates questions and boundaries, not 18 promised shipped features. Do not file a new release-blocking implementation task for every deliberately excluded payment type. Unsupported categories still require truthful scope/claim handling.

| ID | Concept | Implementation / related coverage | Status and remaining boundary |
|---|---|---|---|
| PAY-01 | Base/effective wages | [DM], [TL], [PC]; [AgreementTimelineTests] | P/S: date-level changes; intraday boundary #46; classification/preset review #26 |
| PAY-02 | Daily overtime | [PC] overtimeSlices; [PayCalculatorTimeAndTierTests] | P: midnight-local day; non-midnight workday excluded (#14), rounding #39 |
| PAY-03 | Weekly overtime | [DM], [PC] only daily accumulation | Missing reference layer #42; disclosure #14 |
| PAY-04 | Outside schedule | [DM] RegularScheduleWindow; [PayCalculatorScheduleTests] | P: same-day windows; overnight schedule windows explicitly rejected |
| PAY-05 | Weekend/date premiums | [PC]; [PayCalculatorScheduleTests] | P: explicit configured multipliers; no universal holiday/stacking inference |
| PAY-06 | Callout minimum | [PC] calloutGuarantees; [CaliforniaOutsideLineFixtureTests] | Partial: isolated variant; event identity #41, unpriceable rollover #44 |
| PAY-07 | Rest/fatigue | No rest state machine in [DM] | Unsupported by design; disclose #14 and review named clauses #26 |
| PAY-08 | Meal entitlement | [DM] actual unpaid breaks, not meal-payment events | Unsupported payment type; break subtraction is not meal-penalty coverage |
| PAY-09 | Travel | [DM] WorkKind.other is not a travel rule | Unsupported classification/payment; preserve facts and disclose limits |
| PAY-10 | Standby/on-call | No restriction/standby allowance model | Unsupported; do not classify every standby hour as worked |
| PAY-11 | Reporting/show-up | Callout category is not reporting pay | Unsupported; do not fabricate work for a non-work entitlement |
| PAY-12 | Per diem | [PC] perDiemComponents; [PayCalculatorTimeAndTierTests] | P: flat per-work-date variant only; full eligibility/tax/subsistence outside scope |
| PAY-13 | Mileage/expenses | No distance/receipt/rate-unit model | Unsupported by design; not automatically a 1.0 omission |
| PAY-14 | Shift/hazard/storm supplements | [DM] schedule/day/date multipliers | Partial: no assignment-triggered supplement or regular-rate inclusion layer |
| PAY-15 | Bonus/retroactive adjustment | No remuneration/allocation model | Unsupported reference layer #42; audit revision support is not bonus allocation |
| PAY-16 | Paid leave/non-work holiday | Actual WorkInterval is not paid non-work time | Unsupported; do not turn leave into fabricated work |
| PAY-17 | Benefits/fringes | [DM] categories are workedHours/calloutGuarantee/perDiem | Unsupported; total package is not cash gross; #14/#26 |
| PAY-18 | Deductions/net | [ASSESS] gross/earnings comparison only | Explicitly excluded; no new net-tax feature task; preserve #27/#29 claim limits |

## Example mapping: all 34 vectors

An exact new probe is distinguished from a related existing regression. App tests listed here were inspected, not run natively. Statutory examples remain reference calculations under their stated applicability assumptions.

| ID | Source / related regression | Evidence and scope |
|---|---|---|
| EX-01 | [PayCalculatorScheduleTests] scheduledStraightTime | Related regression passed portably; handbook $50 variant not newly executed |
| EX-02 | [PayCalculatorTimeAndTierTests] dailyOvertimeThreshold | Related daily-threshold regression passed portably |
| EX-03 | [PayCalculatorTimeAndTierTests] secondOvertimeTier | Related second-tier regression passed portably |
| EX-04 | [PayCalculatorBreakTests] | Related exact-break regression passed; legal compensability remains input/scope |
| EX-05 | [PayCalculatorScheduleTests] premiumsDoNotPyramid | Related configured highest-applicable regression passed |
| EX-06 | [PayCalculatorScheduleTests] calloutMinimum; R3 probe | Exact isolated $400 reproduced; split-event gap #41 |
| EX-07 | [PayCalculatorTimeAndTierTests] perDiemOncePerDate | Related per-date deduplication regression passed |
| EX-08 | [AgreementTimelineTests] ratesApplyByWorkDateAndKeepSourceVersions | Across-date variant represented; clarify unspecified intraday interpretation #46 |
| EX-09 | [TL] date-only change | Same-day rate split not representable; preserve $600 reference and classify #46 |
| EX-10 | [PC] daily-only accumulation; R4 probe | Observed configured $2,400; restricted $2,600 weekly reference missing #42 |
| EX-11 | No statutory workweek model | Reference-only $4,250 for the stated 50h/30h weeks; #42 |
| EX-12 | No bonus/allocation model | Reference-only $2,860 under specified bonus assumptions; #42 |
| EX-13 | No regular-rate model | Final pinned doc: 30h@$40 +20h@$60 => $2,640; not older equal-hours $2,600. #42 correction comment |
| EX-14 | No separate credit layer | Reference-only $2,800 contract cash/$0 extra under the specified lawful-credit assumptions; #42 |
| EX-15 | [PaycheckAssessmentTests] perDiemExcludedFromWageGross | Related domain regression passed; wage/allowance separation present |
| EX-16 | [PaycheckAssessmentTests] matchingGrossDoesNotHideOffsettingErrors | Related regression passed; different paid-source contradiction is #38 |
| EX-17 | [ASSESS], [PaycheckAssessmentTests] | Full-rate mapping represented; related domain tests passed |
| EX-18 | [PaycheckAssessmentTests] premiumOnlyLayoutAndHours | Related base-plus-premium regression passed |
| EX-19 | [PaycheckAssessmentTests] uncertainComponentsAndUnsupportedRulesCannotPassCleanly | Flagged omissions handled; known omitted layers still #14 |
| EX-20 | [IntegratedReadinessTests] partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess | App regression present, not rerun natively |
| EX-21 | [PaycheckAssessmentTests] completeNumbers | Grouped numeric domain tests passed portably |
| EX-22 | [PaycheckAssessmentTests] rejectsPrefixesAndAmbiguousFormatting; [AuditScopeRegressionTests] | Domain parser passed; native/currency application tests present only |
| EX-23 | [OCRParserTests] currentNeverSelectsYTD; [DocumentPipelineTests] | Parser/Vision tests present; no native OCR execution here |
| EX-24 | [PayCalculatorTimeAndTierTests] springDSTUsesElapsedTime | Domain elapsed-time regression passed; template construction #40 is separate |
| EX-25 | [PayCalculatorTimeAndTierTests] fallDSTUsesElapsedTime | Domain regression passed; repeated local input still requires explicit resolution |
| EX-26 | [IntegratedReadinessTests] sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules; [JOURNEY] | Normal path represented; unpriceable-A variant missing #44 |
| EX-27 | [ReadinessTests] staleUndoCannotMoveWorkToNextPeriod | Native regression present; old issue not reopened |
| EX-28 | [PeriodAndEvidenceTests] manualCorrectionPreservesOriginalAndFailedReplacementRollsBack | Source-retention regression present |
| EX-29 | [ReadinessBoundaryTests], [TimelinePersistenceTests], [HISTORY], [REPORT] | Frozen context represented; native acceptance not rerun |
| EX-30 | [ReadinessTests] workAndIntakeDraftsSurviveNewModel; [JOURNEY] | Recovery tests present; physical interruption acceptance separate |
| EX-31 | [StorageContractTests], [AppFailurePathTests], [ReadinessTests] | Fault tests present; expanded temporary-sharing boundary #21/PR #34 |
| EX-32 | [SubscriptionBehaviorTests] existingOwnershipSurvivesCatalogFailure | Source/regression present; live commerce #18 |
| EX-33 | [IntegratedReadinessTests] paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry | Independent Free-audit regression present |
| EX-34 | [BackupTests] preservesFreeAllowance; [OPS] verified store boundary | Backups preserve local sampling, not verified subscription authority |

## Workflow, pricing and evidence ownership

| Workflow | Actual route | Remaining acceptance |
|---|---|---|
| Setup and first personal result | [ROOT] -> [PROFILE] -> [FIRST] -> [WORK] -> [LEDGER] | Core route present; #14 scope disclosure; invented sample data cannot count as personal proof |
| Repeated work | Today/lastWork -> [WORK] draft -> [AM] save | #40 DST and #41 physical callout identity |
| Close work / late payday | [LEDGER] -> [AM] archive -> [HISTORY] -> historical [IMPORT] | Normal A/B separation present; #44 unresolved calculation |
| Scan/photo/PDF/manual | [IMPORT] -> [OP] -> original saved -> [OCR]/[PARSER] -> confirmation -> [ASSESS] | Device scanner acceptance and #38 source consistency |
| Explain/correct | AuditDetail -> [RECEIPT] -> [SOURCE] -> confirmed revision | Source retention present; report privacy/version gaps #20/#45 |
| Annual trial after actual value | [FIRST] -> [PAYWALL] -> [STORE]/[OPS] | Eligibility-aware flow exists; actual storefront #18, optional reminder #47 |
| Renewal/expiry/restore | [STORE] -> Settings/paywall -> retained local records | Live/store evidence #18/#37; no local timer grants Pro |
| Backup/delete/recover | Settings -> [BACKUP]/[BACKUPMAP]/[LOCAL]/[EVIDENCE]/[RECOVERY] | Fault/restore test source present; actual provider #21, calculation identity #45 |
| Measurement/experiments | App Store reports/direct observation per onboarding specification | Proposed events/targets are not implemented analytics or measured performance; no SDK added |

Pricing remains the $9.99 monthly / $79.99 yearly hypothesis with eligible seven-day annual introduction and an independent first Free audit. Historical no-trial guidance is superseded. PR #12 integration must preserve newer main legal guardrails/private-by-default wording rather than restoring old active-copy claims. The dated onboarding inspection at `03dedaa` is historical evidence, not today's capability inventory.

Existing issue ownership is retained: #14 scope, #15 consent, #20 private PDF preview (pending PR #34); #18 commerce; #19 renewal responsibility; #21 backup/provider/temporary boundaries; #26 named agreement approval; #27 marketing claims; #29 non-adjudicative support/copy; #31 accessibility/device evidence; #37 hosted native execution. Other #13–#33 release/legal acceptance is not closed by this map.

## Completion standard

Fix or explicitly gate current correctness failures before expanding the catalog. #42 is a supported-scope decision, not authorization to build a nationwide legal engine. #46/#47 may be resolved through honest deferral/classification where their acceptance permits it. For every closed issue preserve the exact fix/tested revisions, commands/results, evidence, and native/device limits. Do not turn generated checklists into owner/counsel approval or earlier passing tests into proof for a later commit.

This task changed documentation/issue tracking only. No application fix, merge, release, or legal compliance certification is implied.

## Pinned implementation and test links

[AM]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppModel.swift
[STATE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppState.swift
[WORK]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AddWorkView.swift
[PROFILE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayProfileSetupView.swift
[LEDGER]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayLedgerView.swift
[HISTORY]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/HistoryView.swift
[IMPORT]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubImportView.swift
[OP]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubImportOperation.swift
[OCR]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubOCRService.swift
[PARSER]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubTextParser.swift
[STORE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SubscriptionStore.swift
[OPS]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SubscriptionOperations.swift
[FIRST]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/FirstPayResultView.swift
[ROOT]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/RootView.swift
[PAYWALL]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/OnboardingPaywallView.swift
[LOCAL]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/LocalStateStore.swift
[VALIDATE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppStateValidation.swift
[EVIDENCE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/EvidenceStore.swift
[RECEIPT]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/EvidenceReceiptView.swift
[SOURCE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SourceEvidenceView.swift
[REPORT]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/ReconciliationReportExporter.swift
[BACKUP]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/BackupArchive.swift
[BACKUPMAP]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/BackupStateMapping.swift
[RECOVERY]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/DataRecoveryView.swift
[DM]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/DomainModels.swift
[PC]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PayCalculator.swift
[TL]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/AgreementTimeline.swift
[ASSESS]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PaycheckAssessment.swift
[DECIMAL]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/StrictDecimal.swift
[AppModelContractTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/AppModelContractTests.swift
[AppFailurePathTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/AppFailurePathTests.swift
[AuditScopeRegressionTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/AuditScopeRegressionTests.swift
[BackupConcurrencyTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/BackupConcurrencyTests.swift
[BackupTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/BackupTests.swift
[BackupValidationTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/BackupValidationTests.swift
[DocumentPipelineTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/DocumentPipelineTests.swift
[IntegratedReadinessTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/IntegratedReadinessTests.swift
[OCRParserTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/OCRParserTests.swift
[ParserAndFormatTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ParserAndFormatTests.swift
[PaystubImportOperationTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/PaystubImportOperationTests.swift
[PeriodAndEvidenceTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/PeriodAndEvidenceTests.swift
[ReadinessBoundaryTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ReadinessBoundaryTests.swift
[ReadinessTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ReadinessTests.swift
[ReportExporterTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ReportExporterTests.swift
[RuleScopeRegressionTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/RuleScopeRegressionTests.swift
[ScreenContractTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ScreenContractTests.swift
[StorageContractTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/StorageContractTests.swift
[StoreKitLifecycleTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/StoreKitLifecycleTests.swift
[SubscriptionBehaviorTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/SubscriptionBehaviorTests.swift
[TimelinePersistenceTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/TimelinePersistenceTests.swift
[AgreementTimelineTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/AgreementTimelineTests.swift
[CaliforniaOutsideLineFixtureTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/CaliforniaOutsideLineFixtureTests.swift
[PayCalculatorBreakTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorBreakTests.swift
[PayCalculatorInvariantTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorInvariantTests.swift
[PayCalculatorScheduleTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorScheduleTests.swift
[PayCalculatorTimeAndTierTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorTimeAndTierTests.swift
[PaycheckAssessmentTests]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PaycheckAssessmentTests.swift
[JOURNEY]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppUITests/PaydayJourneyTests.swift
