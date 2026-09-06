# Product-to-code traceability map

[Product home](README.md) · [Business rules](business-rules.md) · [Payroll coverage](payroll/coverage-and-gaps.md) · [Remediation tracker #49](https://github.com/streamentry/linepay/issues/49)

**Reviewed September 6, 2026. Canonical mapping of 45 BR rules, 18 PAY concepts and 34 EX vectors. This is not a release certificate.**

## Baselines and evidence

| Source | Revision |
|---|---|
| Product handbook | `990154cb517773036c29d8051a30e7e0edf9feaa`, PR #12, unmerged at review |
| Application and tests | `4fe319dc13836eb4e061442f2f9aae53c4d3b00a` on main |
| Related native remediation | PR #34, head `15cec8849864ba9dee0a4a5bba69e114b088370a`, draft/unmerged at review |

The local application snapshot was matched to live Git tree hashes: App `e57e993d805267404e1aa29acb1b5878437f788b`, AppTests `49bf43c5c3f0cb64bb889e21eccdde35b021c380`, AppUITests `397354932576ef581cfd39b31da4f9d5b94e86cf`, domain Sources `0098636fa4702e54782c93eaa5152ab6c6bee467`, domain Tests `ceae6beb49f750aa90a1edcb541213c9688e472d`. The application trees are unchanged from `105b024`; later main changes in this comparison concern documentation/legal controls. The handbook branch's older runtime tree is not substituted for main.

**Executed in this review:** 82 existing domain tests passed on Swift 6.2.1/Linux. Only the isolated copied manifest changed tools-version 6.3 to 6.2; production domain Swift files remained byte-identical. Four additional characterization tests reproduced rounding, source inconsistency, callout splitting and weekly scope. A separate extracted Foundation probe reproduced repeat-template DST behavior. One additional parser characterization executed the complete unchanged `PaystubTextParser.swift` with exact supporting model and formatter excerpts and reproduced the end-only-date problem. Characterization tests assert observed behavior, including defects; they are not passing fix regressions.

**Not executed here:** Xcode, native AppModel/StoreKit/Vision/UI tests, device interaction, live storefront checks or professional legal/applicability review. A test file existing, a prior CI result, a passing portable test and a verified release are different evidence.

### Status legend

- **P:** related existing domain regression executed portably; its assertions passed, not every adjacent requirement.
- **S:** implementation and related tests inspected in source, not natively executed here.
- **Partial:** a concrete gap or explicitly limited subset.
- **Unsupported/reference:** outside current represented capability, not automatically a new 1.0 feature.
- **External/unverified:** device, source/applicability, owner or storefront evidence remains necessary.

Do not collapse these into a completeness percentage. Code establishes implemented behavior; it does not establish what a particular worker is legally owed.

## Issues and counterexamples

| Issue | Type | Finding |
|---|---|---|
| [#38](https://github.com/streamentry/linepay/issues/38) | P1 behavior | Contradictory paid gross/components can produce an unsupported directional verdict |
| [#39](https://github.com/streamentry/linepay/issues/39) | P1 calculation policy | Internal segmentation changes rounded wages without changing the rate or work |
| [#40](https://github.com/streamentry/linepay/issues/40) | P1 time entry | Repeat moves breaks across DST and silently normalizes nonexistent local times |
| [#41](https://github.com/streamentry/linepay/issues/41) | P1 event model | Physical callout identity is conflated with each work-entry row |
| [#42](https://github.com/streamentry/linepay/issues/42) | P1 scoped capability | Bounded weekly layer implemented and native review flow present; source/applicability review and broader statutory/CBA admission remain open |
| [#44](https://github.com/streamentry/linepay/issues/44) | P1 lifecycle | An unpriceable saved period A blocks closing A and recording B |
| [#45](https://github.com/streamentry/linepay/issues/45) | P2 provenance | Calculation-engine identity is missing from saved calculation results |
| [#46](https://github.com/streamentry/linepay/issues/46) | P2 specification | EX-08 is represented only across date boundaries; same-day EX-09 remains reference-only because the timeline is midnight-effective |
| [#47](https://github.com/streamentry/linepay/issues/47) | P2 scope | Optional work-log and renewal reminders are deliberately deferred from iOS 1.0; no notification permission or scheduler is shipped |
| [#48](https://github.com/streamentry/linepay/issues/48) | P2 parser | An end-only pay-period OCR row also supplies an unsupported start date |

Use #42 as the canonical weekly-capability issue and #43 as its duplicate. Concurrent mapping work also produced #44 and #48; their findings are incorporated rather than refiled. Existing legal/acceptance ownership is retained below.

| Probe | Synthetic input | Observed result | Meaning |
|---|---|---|---|
| R1 | $50/hour, 08:00–08:02, 1x everywhere | $1.67 as one segment; $1.66 as two one-minute entries OR the same entry with an irrelevant 08:01 schedule boundary | #39: the approved rounding boundary must be explicit; no universal legal rounding policy is inferred |
| R2 | Expected $550; confirmed paid gross $500, regular $400 and OT $150 | `possibleShortfall`, $50 difference, no review reason | #38: paid-source facts contradict each other |
| R3 | One two-hour Tuesday callout, $50, 2x, four-hour minimum | One record $400; two adjacent records $800 | #41: one physical event is not necessarily two qualifying calls; do not merge genuinely separate calls automatically |
| R4 | Six eight-hour days, $50, only daily 1.5x after eight configured | Configured daily $2,400; bounded weekly layer $2,600 under explicit assumptions | #42: source/applicability admission remains separate |
| R5 | New York March 7, 2026 00:00–08:00 with 04:00 break, repeated March 8 | Shift 00:00–08:00; break 05:00; repeated 02:30 normalizes to 03:00 | #40: extracted Foundation path, not a native UI run |
| R6 | OCR `Pay period ending 09/05/2026` | Both periodStart and periodEnd suggested as `2026-09-05` | #48: complete production parser executed without Vision; the source provides no start |

#44 is source-traced: the domain rejects an ambiguous spanning-callout guarantee; AppModel retains the genuine work with no calculation; archive requires a calculation; starting B requires no active period. Its extended native close/relaunch/start-B test still needs to execute. Refusing an invented audit is correct; blocking all subsequent work logging is a different behavior.

## Business-rule mapping: all 45 IDs

Code links below are pinned. Test identifiers refer to files under [App tests][AT], [domain tests][DT] or [native UI tests][UT]; file presence is not an assertion that all clauses have been proven.

| ID | Implementation | Related regression | Status and remaining boundary |
|---|---|---|---|
| BR-001 | [STATE], [STORE], [project][PROJECT] | LaunchConfigurationTests, identity/configuration contracts | S: public and technical identities remain distinct |
| BR-002 | [AM], [LOCAL], [OCR], [STORE] | StorageContractTests, SubscriptionBehaviorTests | S: core local; deliberate exports and Apple commerce are separate external paths |
| BR-003 | [STATE] PayProfile; [AM] candidateForProfile | RuleScopeRegressionTests | S: one-profile scope; no multi-employer statutory aggregation implied |
| BR-004 | [LEDGER], [ASSESS], [REPORT] | AuditScopeRegressionTests | Partial: legal coverage disclosure #14 and calculation identity #45 |
| BR-005 | [PROFILE], [ASSESS] | ScreenContractTests | Partial: confirmation is not externally reviewed coverage; #14/#26 |
| BR-006 | [PROFILE] unsupported notes; [ASSESS] reviewReasons | PaycheckAssessmentTests.uncertainComponentsAndUnsupportedRulesCannotPassCleanly | P/S: explicit omitted-rule flag handled; known missing layers still need #14 |
| BR-010 | [PROFILE], [ROOT] | ScreenContractTests; onboarding Maestro | S: progressive setup exists; #14 disclosure, not a missing-onboarding rewrite |
| BR-011 | [TL], [DM] snapshots/results | AgreementTimelineTests, TimelinePersistenceTests | Partial: dated rule versions exist; calculation identity #45 |
| BR-012 | [AM] candidateForProfile; [PROFILE] review | RuleScopeRegressionTests.previewIsReadOnlyAndCorrectionIsExplicit | Partial: numerical protection exists; inaccurate dated consent #15, pending PR #34 |
| BR-013 | [DM], [TL], [AM] windows | AgreementTimelineTests, ReadinessBoundaryTests | Partial: payroll timezone explicit; statutory week/non-midnight contract day not represented; #42/#14 and repeat DST #40 |
| BR-014 | [AM] correctCurrentPeriod | ReadinessTests.periodCorrectionRejectsMovingWorkOrOverlap | S: containment, overlap and invalidation paths exist; old no-op date defect not reopened |
| BR-015 | [DM] AgreementSource.ruleKey; [PROFILE] | AppFailurePathTests.profileDraftKeepsScheduleSourceAndEffectiveDates | S: per-rule source references; actual preset/source approval #26 |
| BR-020 | [DM] WorkInterval; [PC] guarantee category | PayCalculatorInvariantTests.actualCalloutBreakAndGuaranteedPayStaySeparate | P/Partial: worked/paid equivalents separate; physical event identity #41 |
| BR-021 | [DM] validation; [AM] work operations | AppModelContractTests.workGuardsAndUndoAreSafe; domain overlap tests | Partial: row identity/overlap checks do not establish separate callout triggers #41 |
| BR-022 | [WORK] repeatDates and break offsets; [AM] lastWork | ScreenContractTests.addEditAndRepeatFormsRetainTheirWorkFacts | Partial: rollover reuse exists; DST construction #40 |
| BR-023 | [AM] save/discard drafts; [STATE] | ReadinessTests.workAndIntakeDraftsSurviveNewModel; PaydayJourneyTests | S: durable draft/context represented; device interruption acceptance separate |
| BR-024 | [AM] deleteWork/restoreDeletedWork | ReadinessTests.staleUndoCannotMoveWorkToNextPeriod / undoRejectsAnInterveningEdit | S: period/revision-bound Undo present; old defect not reopened |
| BR-025 | [AM] archive and historical confirmation | IntegratedReadinessTests.sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules | Partial: normal delayed-paycheck path exists; unpriceable-A path #44 |
| BR-026 | [STATE] AuditRevision; [AM] confirmPaystub | ReadinessTests.closedAuditCorrectionsAppendRevisions | Partial: immutable facts/rules/results present; calculation identity #45 |
| BR-027 | [LEDGER] close confirmation; [HISTORY] | PeriodAndEvidenceTests.periodCadencesAndArchive | Partial: priceable unaudited periods can await pay; unresolved closed state #44 |
| BR-028 | [AM] calculation/error paths; [LEDGER] | AuditScopeRegressionTests.missingAndStaleCalculationsAreNotSuccess | S plus gap: reject false success without blocking all subsequent work #44 |
| BR-030 | [IMPORT], [OCR], DocumentScannerView | DocumentPipelineTests, PaydayJourneyTests | S: shared confirmation path; actual scanner/device permission behavior unverified here |
| BR-031 | [PARSER], [OCR], [SOURCE] | OCRParserTests.currentNeverSelectsYTD / repeatedLabelsDoNotGuess | Partial: conservative amounts/provenance exist; end-only date counterexample #48 |
| BR-032 | [OP], [IMPORT] | PaystubImportOperationTests.cancelledReadCannotClaimOrFinishANewerImport | S: token-bound intake/cancellation present |
| BR-033 | [DECIMAL], [PARSER], [AM] | PaycheckAssessmentTests; ParserAndFormatTests | P/S: strict full-string Decimal parsing passes; unsupported date suggestion #48 |
| BR-034 | [AM] confirmPaystub; [ASSESS] facts | IntegratedReadinessTests.partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess | Partial: completeness/date/currency guards exist; contradictory paid totals #38; date suggestion #48 does not bypass those guards |
| BR-035 | [ASSESS], [IMPORT] basis controls | PaycheckAssessmentTests.premiumOnlyLayoutAndHours / perDiemExcludedFromWageGross | P/Partial: explicit mappings exist; paid-source consistency #38 |
| BR-036 | [ASSESS], AuditAssessment, [REPORT] | PaycheckAssessmentTests.matchingGrossDoesNotHideOffsettingErrors | Partial: earlier offsetting case addressed; new contradiction #38 and legal scope #14 |
| BR-037 | [RECEIPT], [SOURCE], [LEDGER], AuditDetailView | PaydayJourneyTests.testAuditVerdictsAndEvidenceRoutes; ScreenContractTests | S: in-app trace present; private PDF preview #20/PR #34 |
| BR-038 | [ASSESS], AuditStatusView, AboutLinePayView | ParserAndFormatTests.statusIsTextualAndHasAnIcon | S plus review: neutral labels exist; deadline/support boundaries #29 |
| BR-040 | [STORE], [PAYWALL] | StoreKitLifecycleTests, SubscriptionBehaviorTests | S: stable IDs/localized catalog; live storefront #18 |
| BR-041 | [AM] audit-access/confirmPaystub | IntegratedReadinessTests.paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry | S: independent Free allowance and previously authorized rechecks represented |
| BR-042 | [FIRST], [ROOT], [PAYWALL] | IntegratedReadinessTests.firstRealResultSurvivesInterruptionAndOnlyAppearsOnce | S: actual proof then optional offer; optional reminder scope #47 |
| BR-043 | [STORE], [OPS] | StoreKitLifecycleTests, SubscriptionBehaviorTests | S: verified lifecycle branches/tests present; actual native/live evidence #18/#37 |
| BR-044 | [STORE] load/refreshEntitlements | SubscriptionBehaviorTests.existingOwnershipSurvivesCatalogFailure | S: earlier metadata-gating defect addressed; not reopened |
| BR-045 | [AM] access gate; [HISTORY], [SETTINGS] | IntegratedReadinessTests, SubscriptionBehaviorTests | S: saved record/export access not treated as a new audit; live/copy verification #18 |
| BR-046 | [AM] sampling; [BACKUPMAP] | BackupTests.preservesFreeAllowance; IntegratedReadinessTests | S: local backup cannot grant verified Pro; no account required |
| BR-050 | [LOCAL], [EVIDENCE], [BACKUP], [SETTINGS] | BackupValidationTests; backup-consent Maestro | S plus external: provider/export separate; preserve newer main copy during PR #12 integration #17 |
| BR-051 | [AM] confirmPaystub/removeEvidence | PeriodAndEvidenceTests.manualCorrectionPreservesOriginalAndFailedReplacementRollsBack | S: manual corrections retain originals by default; old defect not reopened |
| BR-052 | [AM] retryEvidenceDeletion; [EVIDENCE]; TemporaryExports | ReadinessTests.failedEvidenceDeletionRemainsRetryable; AppFailurePathTests | Partial: retryable cleanup exists; expanded temporary-sharing boundary #21/#20/PR #34 |
| BR-053 | [LOCAL], [VALIDATE], [AM] commit | StorageContractTests, AppFailurePathTests | S: atomic/failure fixtures exist; native filesystem checks not rerun |
| BR-054 | [BACKUP], [BACKUPMAP], BackupRestoreView | BackupValidationTests, BackupConcurrencyTests, BackupTests | S: validation/staging/rollback; actual provider receipt #21 |
| BR-055 | [STATE], [BACKUPMAP], [VALIDATE] | TimelinePersistenceTests; IntegratedReadinessTests.staticV1FixturePreservesHistoricalMeaningAndOriginal | Partial: historical values/versions preserved; independent calculator identity #45 |
| BR-056 | [REPORT], [RECEIPT] | ReportExporterTests, DocumentPipelineTests | Partial: comparison engine shown; calculator version #45 and private sharing #20 |
| BR-057 | DesignTokens, [RECOVERY], [SETTINGS], [PAYWALL] | ScreenContractTests, PaydayJourneyTests; adaptive-layout Maestro | S/unverified: representative tests do not prove all-screen/device acceptance #31/#37 |

## Pay-rule mapping: all 18 concepts

The catalog describes required facts and coverage boundaries, not eighteen promised shipped features. Deliberately excluded payment types are not automatically new release blockers. They still require truthful scope/claim handling.

| ID | Concept | Implementation / related coverage | Status and boundary |
|---|---|---|---|
| PAY-01 | Base/effective wages | [DM], [TL], [PC]; AgreementTimelineTests | P/S: date-level changes; intraday #46; actual classification/preset review #26 |
| PAY-02 | Daily overtime | [PC] overtimeSlices; PayCalculatorTimeAndTierTests | P: calendar-midnight workday only; rounding #39 and non-midnight scope #14 |
| PAY-03 | Weekly overtime | `WeeklyRegularRateCalculator`; `WeeklyRegularRateTests`; native review flow | Restricted complete-week profile only; #42 source/applicability admission remains open |
| PAY-04 | Outside schedule | [DM] RegularScheduleWindow; PayCalculatorScheduleTests | P: same-day windows; overnight schedule windows explicitly rejected |
| PAY-05 | Weekend/date premiums | [PC]; PayCalculatorScheduleTests | P: explicit multipliers; no universal holiday/stacking inference |
| PAY-06 | Callout minimum | [PC] calloutGuarantees; CaliforniaOutsideLineFixtureTests | Partial: isolated variant, event identity #41, unpriceable rollover #44 |
| PAY-07 | Rest/fatigue | No rest state machine in [DM] | Unsupported by design; disclose #14, review named clauses #26 |
| PAY-08 | Meal entitlement | [DM] actual unpaid breaks, not meal-payment events | Unsupported payment type; break subtraction is not meal-penalty coverage |
| PAY-09 | Travel | [DM] WorkKind.other is not a travel rule | Unsupported classification/payment; preserve genuine facts and disclose limits |
| PAY-10 | Standby/on-call | No restriction/standby allowance model | Unsupported; do not classify every standby hour as actual work |
| PAY-11 | Reporting/show-up | Callout category is not reporting pay | Unsupported; no fabricated work for non-work entitlements |
| PAY-12 | Per diem | [PC] perDiemComponents; PayCalculatorTimeAndTierTests | P: flat per-work-date variant only; full subsistence eligibility/tax treatment excluded |
| PAY-13 | Mileage/expenses | No distance/receipt/rate-unit model | Unsupported; not automatically a new 1.0 commitment |
| PAY-14 | Shift/hazard/storm supplements | [DM] schedule/day/date multipliers | Partial: no assignment-triggered supplement or full regular-rate layer |
| PAY-15 | Bonus/retroactive adjustment | `WeeklyRemunerationFact`, explicit bonus/credit classification, deterministic allocation | Multi-week retroactive adjustment and alternative-method coverage remain outside #42 scope |
| PAY-16 | Paid leave/non-work holiday | WorkInterval represents actual work | Unsupported; do not transform leave into worked hours |
| PAY-17 | Benefits/fringes | [DM] workedHours/calloutGuarantee/perDiem categories | Unsupported; total package is not cash gross; #14/#26 |
| PAY-18 | Deductions/net | [ASSESS] earnings/gross only | Explicitly excluded; no net-tax feature required; #27/#29 claim limits |

## Acceptance-vector mapping: all 34 examples

Related tests can use different synthetic rates/dates for the same mechanism. That does not make the exact EX vector an executable fixture. Shared contracts are not yet a complete executable EX corpus. Statutory examples remain reference calculations under their stated applicability assumptions.

| ID | Code / related regression | Evidence and scope |
|---|---|---|
| EX-01 | [PC]; PayCalculatorScheduleTests.scheduledStraightTime | Related basic-wage mechanism passed portably; arbitrary rounding partitions #39 |
| EX-02 | PayCalculatorTimeAndTierTests.dailyOvertimeThreshold | Related daily-threshold regression passed |
| EX-03 | PayCalculatorTimeAndTierTests.secondOvertimeTier | Related second-tier regression passed |
| EX-04 | PayCalculatorBreakTests | Exact-break mechanism passed; compensability remains an applicability/input question |
| EX-05 | PayCalculatorScheduleTests.premiumsDoNotPyramid | Configured highest-applicable mechanism passed, not universal premium precedence |
| EX-06 | PayCalculatorScheduleTests.calloutMinimum; R3 | Isolated $400 reproduced; one event split into rows #41 |
| EX-07 | PayCalculatorTimeAndTierTests.perDiemOncePerDate | Related allowance-unit deduplication passed |
| EX-08 | AgreementTimelineTests.ratesApplyByWorkDateAndKeepSourceVersions | Across-date variant represented; intraday interpretation remains out of scope #46 |
| EX-09 | [TL] LocalDate-only changes | Same-day $600 vector retained as unsupported/reference until an intraday timeline is deliberately implemented #46 |
| EX-10 | WeeklyRegularRateTests.ordinaryFortyEightHourWeek | Bounded engine returns $2,600 under explicit applicability and complete-week assumptions; source admission remains #42 |
| EX-11 | WeeklyRegularRateTests.separateWeeksRemainSeparate | Bounded engine preserves 50h + 30h as separate weeks: $2,750 + $1,500; #42 |
| EX-12 | WeeklyRegularRateTests.allocatedBonusChangesRegularRate | Includable bonus produces $2,860 under explicit classification; #42 |
| EX-13 | WeeklyRegularRateTests.weightedMultipleRates | **Pinned final source: 30h@$40 + 20h@$60 = 50h, R $2,400, RR $48, extra $240, total $2,640.** #42 |
| EX-14 | WeeklyRegularRateTests.eligiblePremiumCreditIsNotWholeOvertimeLine | Eligible extra-premium credit reduces remaining premium without crediting the whole overtime line; #42 |
| EX-15 | PaycheckAssessmentTests.perDiemExcludedFromWageGross | Wage/allowance separation mechanism passed |
| EX-16 | PaycheckAssessmentTests.matchingGrossDoesNotHideOffsettingErrors | Related offsetting-lines regression passed; different source contradiction #38 |
| EX-17 | [ASSESS] fullRateBuckets | Full-rate mapping represented; related domain coverage passed |
| EX-18 | PaycheckAssessmentTests.premiumOnlyLayoutAndHours | Base-plus-premium mapping passed |
| EX-19 | PaycheckAssessmentTests.uncertainComponentsAndUnsupportedRulesCannotPassCleanly | Explicit unsupported flags tested; known inherently missing layers #14 |
| EX-20 | IntegratedReadinessTests.partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess | Native regression exists; not rerun here |
| EX-21 | PaycheckAssessmentTests.completeNumbers | Grouped whole-string domain parsing passed |
| EX-22 | PaycheckAssessmentTests.rejectsPrefixesAndAmbiguousFormatting; AuditScopeRegressionTests | Domain parser passed; native/currency application checks inspected only |
| EX-23 | OCRParserTests.currentNeverSelectsYTD; DocumentPipelineTests | Conservative current/YTD tests exist; no native OCR run; end-only date is separate #48 |
| EX-24 | PayCalculatorTimeAndTierTests.springDSTUsesElapsedTime | Domain elapsed-time check passed; template construction #40 not covered by it |
| EX-25 | PayCalculatorTimeAndTierTests.fallDSTUsesElapsedTime | Domain elapsed-time check passed; repeated local input still needs explicit resolution |
| EX-26 | IntegratedReadinessTests.sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules; PaydayJourneyTests | Normal path represented; unpriceable-A boundary #44 |
| EX-27 | ReadinessTests.staleUndoCannotMoveWorkToNextPeriod | Period-bound regression exists; earlier defect not reopened |
| EX-28 | PeriodAndEvidenceTests.manualCorrectionPreservesOriginalAndFailedReplacementRollsBack | Original-retention/revision regression exists |
| EX-29 | ReadinessBoundaryTests, TimelinePersistenceTests; [HISTORY], [REPORT] | Frozen context represented; native acceptance not rerun |
| EX-30 | ReadinessTests.workAndIntakeDraftsSurviveNewModel; PaydayJourneyTests | Durable recovery tests exist; actual device interruption separate |
| EX-31 | StorageContractTests, AppFailurePathTests, ReadinessTests | Fault tests exist; sharing/provider boundaries #21/PR #34 |
| EX-32 | SubscriptionBehaviorTests.existingOwnershipSurvivesCatalogFailure | Independent catalog/entitlement path exists; live commerce #18 |
| EX-33 | IntegratedReadinessTests.paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry | Pro/Free independence regression exists |
| EX-34 | BackupTests.preservesFreeAllowance; [OPS] verified-store boundary | Backups preserve local sampling, not verified subscription authority |

EX-13 was re-read directly from its pinned source during consolidation; do not silently replace it using an older local archive. The synthetic arithmetic is not a claim about a particular worker's applicable rate or entitlement.

## Workflow, pricing and scope ownership

| Workflow | Actual route | Remaining acceptance |
|---|---|---|
| Setup and first personal proof | [ROOT] -> [PROFILE] -> [FIRST] -> [WORK] -> [LEDGER] | Present; #14 coverage disclosure; sample work cannot count as personal proof |
| Repeated work | Today/lastWork -> [WORK] draft -> [AM] save | #40 DST and #41 callout-event identity |
| Close work and delayed paycheck | [LEDGER] -> [AM] close -> [HISTORY] -> historical [IMPORT] | Normal A/B independence present; #44 unresolved calculation |
| Scan/photo/PDF/manual | [IMPORT] -> [OP] -> original saved -> [OCR]/[PARSER] -> confirmation -> [ASSESS] | Actual device scanner acceptance; #38 paid-source consistency, #48 dates |
| Explain and correct | AuditDetail -> [RECEIPT] -> [SOURCE] -> confirmed revision | Original retained; report/privacy/version gaps #20/#45 |
| Annual introduction after value | [FIRST] -> [PAYWALL] -> [STORE]/[OPS] | Eligibility-aware flow present; actual storefront #18; optional reminders #47 |
| Renewal, expiry and restore | [STORE] -> Settings/paywall -> retained records | Native/live receipts #18/#37; no local timer or backup grants Pro |
| Backup, deletion and recovery | [SETTINGS] -> [BACKUP]/[BACKUPMAP]/[LOCAL]/[EVIDENCE]/[RECOVERY] | Fault/restore tests exist; actual providers #21; engine identity #45 |
| Measurement and experiments | Aggregate App Store reports/direct observation per handbook | Proposed metrics are not measured outcomes or missing Swift features; no analytics SDK added |

Pricing remains the $9.99 monthly / $79.99 yearly hypothesis, eligible seven-day annual introduction and independent first Free audit. Earlier no-trial guidance is superseded. BR-045's continued access to owned records must not be contradicted by an imprecise Pro feature list.

Integrating PR #12 must retain newer main's legal guardrails and private-by-default wording rather than restoring obsolete absolute privacy/marketing claims. A dated onboarding or readiness report is evidence for its revision, not today's implementation inventory.

Existing issue ownership: #14 supported-rule limits, #15 dated consent and #20 private report preview (pending PR #34); #18 live commerce; #19 renewal responsibility; #21 backup/provider/privacy boundaries; #26 named agreement approval; #27 claims/assets; #29 non-adjudicative explanations; #31 accessibility/device evidence; #37 hosted execution. Other #13–#33 legal/release criteria remain independently applicable. This audit does not close them.

## Maintenance and completion

Fix or explicitly gate current misleading results and fact construction before expanding the catalog. Resolve the work-logging dead end without inventing pay. Add version identity alongside changed algorithms. #42 is a bounded supported-scope decision, not authorization to build a nationwide legal engine. #46/#47 can be resolved by honest deferral where their acceptance permits it.

Every closure records the actual fix/tested commit, meaningful regression, commands/results and remaining native/device limits. Preserve historical findings; append new evidence rather than rewriting old failures as retroactive passes. A generated checklist is not owner/counsel approval. A pending PR is not a shipped fix.

This task changed documentation and issue tracking only. No application fix, merge, release or compliance certification is implied. The overlapping earlier `code-traceability.md` is a navigation entry to this consolidated map rather than a second independently maintained specification.

## Pinned code and test roots

[AT]: https://github.com/streamentry/linepay/tree/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources
[DT]: https://github.com/streamentry/linepay/tree/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests
[UT]: https://github.com/streamentry/linepay/tree/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppUITests
[PROJECT]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/project.yml
[AM]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppModel.swift
[STATE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppState.swift
[WORK]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AddWorkView.swift
[PROFILE]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayProfileSetupView.swift
[LEDGER]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayLedgerView.swift
[HISTORY]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/HistoryView.swift
[SETTINGS]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SettingsView.swift
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
