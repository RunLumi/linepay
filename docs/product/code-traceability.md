# Product-to-code traceability

[Product home](README.md) · [Business rules](business-rules.md) · [Coverage](payroll/coverage-and-gaps.md) · [Documentation home](../README.md)

**Reviewed September 6, 2026. This is a requirements/evidence map, not release approval or certification of US payroll compliance.**

## Baselines and evidence levels

Specification: `990154cb517773036c29d8051a30e7e0edf9feaa`, handbook PR #12, unmerged when reviewed. Application/tests: `4fe319dc13836eb4e061442f2f9aae53c4d3b00a`, independently read from main. Application trees are unchanged from `105b024e283c70e07375f53cc4da11010441e5a2`; newer main changes concern legal controls, documentation and release tooling. Pending PR #34 is not treated as merged or tested. Issue #37 already owns the hosted-runner startup blocker.

All code pointers below refer to the **pinned application commit**. Counts: **45 BR rules, 18 PAY concepts, 34 EX vectors**. A catalog entry is not automatically a 1.0 promise.

- **Represented:** inspected source implements the narrow mechanism. Not proof of every boundary or screen.
- **Domain passed:** relevant existing domain test passed in the portable run below, not native iOS acceptance.
- **Test present:** app/UI regression exists and was inspected, but was not run here.
- **Partial/defect:** a concrete requirement mismatch has a linked issue.
- **Missing/conditional:** a variant is unrepresented or explicitly deferred; don't invent a broad feature merely to fill a checklist.
- **External:** native device, real storefront/provider, user comprehension or attributable source review still required.

### Verification actually performed

The production domain sources and original domain tests were copied unchanged to a disposable package. Only its manifest selected tools 6.2 for **Swift 6.2.1, x86_64 Linux**. The production manifest/toolchain was not changed.

**82 existing domain tests passed. Seven additional characterization probes reproduced the observations below.** Their passing assertions describe current behavior, including defects; they are not fixes. The parser probe used the complete production parser/formatter and exact supporting type excerpts. The repeat probe exercised the Foundation transformation, not SwiftUI. No native app tests, Release build, StoreKit sandbox, simulator/device journey or legal certification ran for this mapping.

Local source identity was verified against fresh GitHub tree hashes:

| Tree | Git SHA |
|---|---|
| `apps/ios/App` | `e57e993d805267404e1aa29acb1b5878437f788b` |
| `apps/ios/AppTests` | `49bf43c5c3f0cb64bb889e21eccdde35b021c380` |
| `apps/ios/AppUITests` | `397354932576ef581cfd39b31da4f9d5b94e86cf` |
| `LinePayDomain/Sources` | `0098636fa4702e54782c93eaa5152ab6c6bee467` |
| `LinePayDomain/Tests` | `ceae6beb49f750aa90a1edcb541213c9688e472d` |

## Code and test entry points

These links are pinned. File and function names in the matrices refer to these directories, not an assumed future main.

| Area | Source | Existing tests |
|---|---|---|
| Domain | [DomainModels.swift][domain], [PayCalculator.swift][calculator], [AgreementTimeline.swift][timeline], [PaycheckAssessment.swift][assessor], [StrictDecimal.swift][decimal] | [Domain test directory][dt]: time/tier, break, invariant, timeline, assessment, value and California fixture suites |
| App orchestration | [AppModel.swift][model], [AppState.swift][state], [EntryDrafts.swift][drafts] | [App test directory][at]: ReadinessTests, IntegratedReadinessTests, AppModelContractTests, RuleScopeRegressionTests, ReadinessBoundaryTests |
| Work / setup | [AddWorkView.swift][add], [PayProfileSetupView.swift][setup], RootView, FirstPayResultView | [App tests][at]: ScreenContractTests; [PaydayJourneyTests][ui] |
| Paycheck source | [PaystubTextParser.swift][parser], PaystubImportView, PaystubImportOperation, PaystubOCRService, DocumentScannerView | [App tests][at]: OCRParserTests, DocumentPipelineTests, PaystubImportOperationTests |
| Audit / report | [AuditAssessment.swift][auditstate], PayLedgerView, HistoryView, AuditDetailView, EvidenceReceiptView, SourceEvidenceView, [ReconciliationReportExporter.swift][report] | [App tests][at]: AuditScopeRegressionTests, PeriodAndEvidenceTests, ReportExporterTests |
| Storage / backup | [AppSession.swift][session], LocalStateStore, AppStateValidation, EvidenceStore, BackupArchive, BackupStateMapping | [App tests][at]: StorageContractTests, BackupTests, BackupValidationTests, BackupConcurrencyTests, AppFailurePathTests |
| Commerce | [SubscriptionStore.swift][commerce], SubscriptionOperations, OnboardingPaywallView, SettingsView | [App tests][at]: SubscriptionBehaviorTests, StoreKitLifecycleTests |

## Reproduced boundaries

All inputs are synthetic. Statutory reference assumptions remain those in the handbook; no example determines an actual worker's entitlement.

| Probe | Observed | Consequence / ticket |
|---|---|---|
| Expected wages $550; paid gross $500 but paid regular $400 + OT $150 | `possibleShortfall`, no review reasons | Contradictory paid facts unqualified: #38 |
| Two minutes at $50 as one entry versus two adjacent one-minute entries | $1.67 versus $1.66 | Entry partition chooses monetary rounding: #39 |
| Repeat New York March 7, 2026 00:00 start / 04:00 break onto March 8 | Break moves to 05:00 | Wall-time endpoints mixed with elapsed-offset breaks: #40 |
| One two-hour callout at $50, four-hour minimum, entered once versus split in two callout rows | $200 versus $400 at 1x | Missing dispatch identity; two genuinely separate calls are different facts: #41 |
| Six eight-hour days at $50, daily OT after eight only | $2,400 | No weekly layer; restricted EX-10 reference $2,600: #43 |
| Two-hour callout spanning a date-effective rate change, four-hour minimum | `calloutGuaranteeNeedsReview`, no result | Correct domain abstention; source trace shows subsequent period blocked: #44 |
| OCR `Pay period ending 09/05/2026` | Both start and end suggested as `2026-09-05` | End-only evidence does not establish start: #48 |

## 45 business rules

A test named here establishes relevant existing coverage, not automatic closure of every condition in its row. Native tests marked present were not executed in this review.

| Rule | Code / relevant existing test | Assessment and remaining work |
|---|---|---|
| BR-001 | `project.yml`, bundle/product IDs, root AGENTS | Identity represented. Branding must not rename installed identity. |
| BR-002 | AppSession, local store, OCR service, native StoreKit adapter | Local architecture represented; Apple commerce and user-chosen file providers are separate external paths. |
| BR-003 | AppState.PayProfile; AppModel.candidateForProfile; ReadinessTests.futureRateDoesNotRepriceExistingWork | One profile and historical rules represented; test present. Intraday scope #46. |
| BR-004 | PaycheckAssessor, PayPresentation, ledger/report | Partial: scoped results exist; systematic omitted-rule disclosure #14; weekly capability #43; calculation identity #45. |
| BR-005 | Rule confirmation, manual source metadata | Confirmation is not external legal review. Disclosure #14 and preset approval #26 remain separate. |
| BR-006 | unsupportedRuleNotes; PaycheckAssessmentTests.uncertainComponentsAndUnsupportedRulesCannotPassCleanly | Explicit unsupported flag domain-passed. Blank notes do not establish complete coverage: #14. |
| BR-010 | PayProfileSetupView, OnboardingFlowView; ScreenContractTests | Progressive setup/review exists; tests present. Don't reopen the old missing-onboarding claim. Missing scope explanation #14. |
| BR-011 | AgreementSnapshot / AgreementTimeline; ratesApplyByWorkDateAndKeepSourceVersions | Date-effective versions domain-passed. Missing calculation version #45; intraday boundary #46. |
| BR-012 | candidateForProfile / previewProfileChange; RuleScopeRegressionTests | Runtime scopes represented. Existing consent-copy mismatch #15, pending PR #34, not a missing entire rule editor. |
| BR-013 | WorkInterval, RegularScheduleWindow, PayPeriodWindow; PayCalculatorTimeAndTierTests | Instants/timezones domain-passed. Non-midnight workday and statutory week unrepresented; #14/#43. Repeat ambiguity #40; intraday rates #46. |
| BR-014 | correctCurrentPeriod / validateNewWindow; periodCorrectionRejectsMovingWorkOrOverlap | Containment, overlap and audit invalidation represented; test present. |
| BR-015 | AgreementSource.ruleKey; EvidenceReceiptView; DomainContractTests.invalidCurrencyAndSourceRoundTrip | Narrow provenance represented. Actual rights/applicability/reviewer evidence remains #26. |
| BR-020 | WorkInterval versus PayComponentCategory; PayCalculatorInvariantTests | Actual work separate from paid equivalents, domain-passed. Guarantee event/unit gap #41. |
| BR-021 | addWork/updateWork/deleteWork/restoreWork; workGuardsAndUndoAreSafe; domain overlap/break tests | Validation represented. Splitting one callout into rows can still duplicate a trigger: #41. |
| BR-022 | AddWorkView.init/repeatDates/moveTemplate; addEditAndRepeatFormsRetainTheirWorkFacts | Partial: reviewable repeat and historical template exist; DST break/time resolution #40. |
| BR-023 | EntryDrafts; saveSetupDraft/saveWorkDraft/savePaystubDraft; workAndIntakeDraftsSurviveNewModel | Durable draft/context paths represented; native interruption tests present, not run here. |
| BR-024 | DeletedWorkUndo; AppModel.restoreWork; staleUndoCannotMoveWorkToNextPeriod and scheduledRuleChangeRejectsUndoWhoseWorkCouldBeRepriced | Context/revision guards represented; don't recreate the old stale-Undo bug. |
| BR-025 | periodContext / historical confirmPaystub; sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules | Normal delayed paycheck represented. Unpriceable A prevents moving to B: #44. |
| BR-026 | AuditRevision / confirmPaystub; closedAuditCorrectionsAppendRevisions | Historical snapshots/revisions represented; original calculation-engine version absent: #45. |
| BR-027 | PayLedgerView close confirmation, archiveCurrentPeriod, HistoryView; periodCadencesAndArchive | Close/awaiting-paycheck state exists for calculable work. Unresolved-close representation missing: #44. |
| BR-028 | recalculate/calculate/validate; AuditAssessment; missingAndStaleCalculationsAreNotSuccess | Guards reject invented zero/success. Preserve them while repairing #44's rollover dead end. |
| BR-030 | PaystubImportView, scanner, OCR service; DocumentPipelineTests | All acquisition routes represented. Actual scanner and permission acceptance remains device verification. |
| BR-031 | PaystubTextParser, OCRFieldSuggestion/SourceRegion; currentNeverSelectsYTD | Conservative YTD path and tests exist. End-only date produces an unsupported opposite-boundary suggestion: #48. |
| BR-032 | PaystubImportOperation / importer; PaystubImportOperationTests | Operation/context/cancellation guards represented; tests present. |
| BR-033 | StrictDecimal / application conversion; StrictDecimalTests / AppModelContractTests | Whole-string numeric domain tests passed. OCR date direction #48 and rounding aggregation #39 are distinct gaps. |
| BR-034 | confirmPaystub / PaycheckFacts; partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess | Period/currency/completeness gates represented. Contradictory paid gross/subtotal requires review: #38. |
| BR-035 | GrossBasis/LineLayout/HoursBasis/GuaranteeLayout; premiumOnlyLayoutAndHours | Selected mappings domain-passed, not every provider layout. Unusual multipliers qualified. Paid consistency #38; callout unit #41. |
| BR-036 | PaycheckAssessor; matchingGrossDoesNotHideOffsettingErrors; AuditScopeRegressionTests | Equal-gross offset errors correctly need review. Inverse paid-total inconsistency #38; legal scope #14. |
| BR-037 | EvidenceReceiptView, SourceEvidenceView, AuditDetailView, report | Relevant drill-down represented. Calculation identity #45; private report/preview #20. |
| BR-038 | PaycheckVerdict, PayPresentation; semantic status tests | Neutral direction terms represented. Support/deadline/adjudication boundaries remain #29. |
| BR-040 | SubscriptionStore, ProPaywallView; StoreKitLifecycleTests | One entitlement, two products, localized metadata represented. Live approval/pricing evidence #18. |
| BR-041 | canRunAudit / confirmPaystub; paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry | Separate Free allowance and authorized-period retries represented; test present. Pro does not consume global Free allowance. |
| BR-042 | RootView, FirstPayResultView, paywall; firstRealResultSurvivesInterruptionAndOnlyAppearsOnce | Real-first-value and optional eligible offer represented. Reminder roadmap conditional, #47. |
| BR-043 | SubscriptionStore/Operations; SubscriptionBehaviorTests/StoreKitLifecycleTests | Verification/status paths represented. Native/storefront proof #18/#37; debug bypass is not production evidence. |
| BR-044 | load/refreshEntitlements; existingOwnershipSurvivesCatalogFailure | Metadata and entitlements separated; test present. Old loading-order finding not reopened. |
| BR-045 | HistoryView, SettingsView, AppSession backup and audit access check | Owned records/backup not deleted on expiry. Imprecise Pro history/export marketing must not override ownership; #18/#17. |
| BR-046 | AppSession.restore, preservesFreeAllowance, StoreKit independent of local state | Restore does not constitute verified Pro. Local anti-reset trade-off retained; no backend requested. |
| BR-050 | AppSession/BackupIO, SettingsView, evidence store | User-directed export represented. Preserve newer main privacy controls when merging handbook: #17/#21/#22. |
| BR-051 | confirmPaystub/removeEvidence; manualCorrectionPreservesOriginalAndFailedReplacementRollsBack | Retain/replace/delete and revisions represented; manual correction no longer implicitly deletes original. |
| BR-052 | pendingEvidenceDeletions/retryEvidenceDeletion; failedEvidenceDeletionRemainsRetryable | Retryable cleanup represented; full physical provider/temp-file acceptance #21. Never delete unrelated external copies. |
| BR-053 | VersionedLocalStateStore, AppStateValidation; StorageContractTests | Atomic/size/semantic validation and recovery represented; native fault tests present, not rerun. |
| BR-054 | AppSession.restore, BackupArchive, BackupStateMapping; BackupTests/BackupValidationTests | Archive validation/staging/rollback represented. Actual two-device provider acceptance #21. |
| BR-055 | Schema mapping; bothSchemaTwoVariantsUpgradeWithoutDroppingTheirEvidence, staticV1FixturePreservesHistoricalMeaningAndOriginal | Frozen data migration tests present. Calculation version cannot survive when never stored: #45. |
| BR-056 | ReconciliationReportExporter; reportUsesComparableWagesAndPaginatesLongEvidence | Scope/saved assessment/comparison version represented. Missing original pay-engine identity #45; OCR detail/private preview #20. |
| BR-057 | ScreenContractTests, PaydayJourneyTests, Maestro flows | Representative automation exists, not all-screen/physical accessibility sign-off. #31/#37; support minimization #23. |

## 18 payroll concepts

The catalog is a rule-discovery register, not eighteen mandatory launch features. Implemented primitives do not prove employer/classification/jurisdiction applicability.

| Rule | Implementation | Boundary / issue |
|---|---|---|
| PAY-01 Base wages | AgreementSnapshot.hourlyRate / AgreementTimeline | Date-effective configured rates; intraday example ambiguity #46; calculation version #45. |
| PAY-02 Daily overtime | DailyOvertimeTier / overtimeSlices / cumulativeHoursByDay | Local-midnight day supported. Non-midnight day and separate weekly obligations not established; #14/#43. |
| PAY-03 Weekly overtime | No workweek/regular-rate/credit model | Missing capability #43; disclosure #14; EX-10–14 reference-only. |
| PAY-04 Outside schedule | RegularScheduleWindow / applicableBaseMultiplier / split | Non-overnight windows in domain; overnight schedule rejected. Complex/variable window UI not equivalent to the simple shared window. Gate unsupported variants #14/#26. |
| PAY-05 Weekday/date premiums | WeekdayPremium, DatePremium, highestApplicable | Selected maximum domain-tested; not additive rules or an automatic observed-holiday pack. #26 before named coverage. |
| PAY-06 Callout minimum | CalloutMinimumRule / calloutGuarantees | Isolated arithmetic exists. Trigger identity #41; unresolved calculation blocks rollover #44. |
| PAY-07 Rest/fatigue | Unsupported notes, no rest-pay state machine | Explicitly deferred/unsupported, not a guessed eight-hour toggle. #14/#26. |
| PAY-08 Meal pay | WorkBreak subtraction, no meal-entitlement model | Breaks are not meal penalties/allowances. Deferred variants #14/#26. |
| PAY-09 Travel | WorkKind.other can record time | No travel compensability/entitlement classification. Deferred #14/#26. |
| PAY-10 Standby | No standby restrictions/allowance model | Actual responses can be recorded; broader classification deferred #14/#26. |
| PAY-11 Reporting/show-up | No no-work reporting entitlement | Callout minimum is not universal show-up pay. Deferred #14/#26. |
| PAY-12 Subsistence | FlatPerDiemRule / perDiemComponents | Once per worked local date supported; trip/shift/eligibility/tax variants not represented. #14/#26. |
| PAY-13 Mileage/expenses | No distance/receipt/rate model | Deferred; wage-gross verdict must not imply these checked. #14/#26. |
| PAY-14 Shift/hazard/storm | Some configured schedule/date multipliers | No event-specific storm/differential engine or universal multiplier. Deferred #14/#26. |
| PAY-15 Bonus/retroactive pay | Audit revisions/date rates, no earned-week allocator | Missing regular-rate layer #43; manual correction is not statutory allocation. |
| PAY-16 Non-work leave/holiday | No paid non-work category | Deferred; never fake work intervals to create leave wages. #14/#26. |
| PAY-17 Benefits/fringe | No contribution/cash-in-lieu/project model | Deferred; total wage package is not cash gross. #14/#26. |
| PAY-18 Deductions/net | Gross fields/assessor only | Explicitly outside scope; no automatic net-tax feature request. Non-adjudicative boundary #29. |

## 34 acceptance vectors

Mechanism coverage does not mean the exact EX numbers are already a named executable fixture. Some existing tests use different synthetic amounts/dates. `shared/contracts` currently contains instructions and README, not a complete executable EX corpus. Native tests below were inspected, not executed here.

| Vector | Existing code/test | Status |
|---|---|---|
| EX-01 | PayCalculator; regular-day domain cases; app configured-work tests | Basic wage mechanism covered; rounding variants #39. |
| EX-02 | dailyOvertimeThreshold | Domain mechanism passed. |
| EX-03 | secondOvertimeTier | Domain mechanism passed. |
| EX-04 | unpaidBreakIsExcludedFromWorkedPay / breakDoesNotCreateFakeOvertime | Domain break mechanism passed; legal classification not inferred. |
| EX-05 | weekendPremiumWinsOverOvertime | Domain configured-maximum mechanism passed. |
| EX-06 | californiaCalloutMinimum / invariant tests | Isolated mechanism passed, not multiple/overlap calls; #41. |
| EX-07 | perDiemOncePerDate | Domain work-date deduplication passed. |
| EX-08 | ratesApplyByWorkDateAndKeepSourceVersions | $460 can span two dates; source boundary unspecified. Clarify date versus intraday in #46. |
| EX-09 | AgreementTimeline accepts LocalDate | Same-day rate change unrepresentable. Mark reference/unsupported and decide scope: #46. |
| EX-10 | Daily accumulation only | Missing weekly layer #43; observed $2,400 versus restricted $2,600 reference. |
| EX-11 | No independent complete workweek | Reference-only #43; don't average 50h and 30h. |
| EX-12 | No includable-bonus/earned-week model | Reference-only #43; preserve stated $2,860. |
| EX-13 | No weighted statutory regular rate | Reference-only #43. Pinned vector is **24h@$40 + 24h@$60, total $2,600**. A 30h/20h $2,640 case is a different example. |
| EX-14 | No approved premium-credit model | Reference-only #43; maximum multiplier is not statutory credit. |
| EX-15 | perDiemExcludedFromWageGross | Domain separation mechanism passed with a different wage amount. |
| EX-16 | matchingGrossDoesNotHideOffsettingErrors | Exact $400/$150 versus $350/$200 shape passed. Inverse paid-total conflict remains #38. |
| EX-17 | PaycheckAssessor fullRateBuckets; AuditScopeRegressionTests | Mapping represented; app tests present. |
| EX-18 | premiumOnlyLayoutAndHours | Exact $500 base + $50 premium layout passed. |
| EX-19 | uncertainComponentsAndUnsupportedRulesCannotPassCleanly | Explicit unsupported flag passed; automatic omitted-rule disclosure remains #14. |
| EX-20 | partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess | Test present; code gates incomplete work. |
| EX-21 | StrictDecimalTests.completeNumbers | Whole-string grouping passed. |
| EX-22 | rejectsPrefixesAndAmbiguousFormatting / precisionAndRange / currency guards | Domain rejection mechanisms passed. |
| EX-23 | currentNeverSelectsYTD / localVisionDoesNotPreferYTDOverCurrentGross | Parser/Vision tests present; no native OCR execution here. Date direction separately #48. |
| EX-24 | springDSTUsesElapsedTime | Domain elapsed-time mechanism passed, not Repeat draft construction (#40). |
| EX-25 | fallDSTUsesElapsedTime | Domain fold-duration mechanism passed, not an explicit fold selector (#40). |
| EX-26 | sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules / PaydayJourneyTests | Normal two-period tests present; unpriceable A missing #44. |
| EX-27 | staleUndoCannotMoveWorkToNextPeriod | Context-bound Undo test present. |
| EX-28 | correctionsRetainOriginalWithoutReloadingBytes / manualCorrectionPreservesOriginalAndFailedReplacementRollsBack | Retention/revision tests present. |
| EX-29 | ReadinessBoundaryTests.changedTimezoneClosesOldPeriodWithoutOverlap / frozen report context | Source represented; native test present. |
| EX-30 | workAndIntakeDraftsSurviveNewModel / PaydayJourneyTests | Durable draft tests present; physical interruption not tested here. |
| EX-31 | StorageContractTests / BackupTests / deletion fault tests | Meaningful failure tests present; device/provider acceptance #21/#37. |
| EX-32 | existingOwnershipSurvivesCatalogFailure / StoreKitLifecycleTests | Adapter/native tests present; actual storefront #18/#37. |
| EX-33 | paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry | Explicit Pro/Free test present. |
| EX-34 | AppSession.restore / preservesFreeAllowance / independent StoreKit | Restore boundary represented; local records aren't subscription authority. |

## Other product documents and scope obligations

| Source | Mapping / disposition |
|---|---|
| App workflows: first launch/work | RootView, onboarding, FirstWorkIntroductionView, FirstPayResultView implement the sequence. BR-010/042. The two-minute usability target requires actual user observation, not source inference. |
| App workflows: daily logging/payday | AddWorkView, TodayView, ledger, importer, AppModel/history. BR-020–038. Specific new boundaries #38–41/#44/#48. |
| App workflows: correction/recovery | Audit revisions, durable drafts, AppSession rollback, DataRecoveryView. Do not repeat obsolete blanket “no persistence” claims. |
| Onboarding: eligible offer and first Free | FirstPayResultView, paywall, StoreKit, canRunAudit/confirmPaystub; IntegratedReadinessTests/StoreKitLifecycleTests. Live product/account evidence #18. |
| Onboarding: reminders | No scheduler/permission preference in the complete inspected App tree. Text itself makes the renewal offer conditional on implementation. Explicit defer/admit decision #47, not automatically a release blocker. |
| Onboarding/pricing: activation metrics/experiments | Business validation, not missing Swift features. Do not add tracking SDKs just to manufacture measurement. |
| Pricing: ownership and price | One Pro/two localized products represented; actual storefront approval #18. BR-045 overrides imprecise “Pro history/export” language. Keep the current annual trial, not the superseded no-calendar-trial policy. |
| Payroll README/sources/legal baseline | Applicability and source-governance documents. No URL, AI approval or fixture proves externally verified agreement coverage. Existing #14/#26 and owner gates apply. |
| Coverage-and-gaps | GAP-01/02 -> #43. GAP-03–07 are explicit unclaimed/deferred layers, not a mandate to build universal payroll/tax software. |
| Historical audit/remediation/release evidence | Applies to its stated revision. Not proof of this main or an uploaded binary. #13/#31/#37 remain distinct gates. |

### Handbook integration drift

PR #12's handbook is based on a revision preceding newer main legal controls. Preserve newer active privacy/marketing changes and legal navigation when integrating it. Do not restore absolute privacy slogans or use an automatic ours/theirs merge. Use the actual diff and existing #17/#18/#27. This is a documentation-integration concern, not proof of an application privacy regression.

## Issue map and priorities

| Issue | Classification | Contract |
|---|---|---|
| [#38][i38] Contradictory paid totals | Defect, P1 | BR-034–036 / reconciliation consistency |
| [#39][i39] Segmentation rounding | Computational-policy gap, P1 | Calculation §3; history/versioning |
| [#40][i40] Repeat/DST handling | Defect, P1 | BR-013/022 |
| [#41][i41] Callout event versus row | Representation gap, P1 | PAY-06; BR-020/021 |
| [#43][i43] Workweek/regular-rate layer | Missing capability, P1 before claiming coverage | PAY-03/15; GAP-01/02; EX-10–14 |
| [#44][i44] Unpriceable-period rollover | Lifecycle defect, P1 | BR-025/027/028 |
| [#45][i45] Calculation-engine identity | Provenance gap, P2 | BR-011/026/055/056 |
| [#46][i46] Intraday example classification | Docs/scope gap, P2 | EX-08/09 |
| [#47][i47] Optional reminder status | Conditional scope gap, P2 | Onboarding acceptance |
| [#48][i48] End-only OCR period date | Parser defect, P2 | BR-031/033/034 |

#42 was a concurrent duplicate of #43 and was closed **as duplicate, not fixed**. A correction on #43 preserves the actual EX-13 vector. Do not create another weekly-engine issue.

Existing work reused: #14 disclosure; #15 consent; #18 live commerce; #20 report privacy/preview; #21 provider/deletion acceptance; #26 named-pack approval; #29 non-adjudication; #31 accessibility; #37 runner startup. PR #34 is pending work, not completion evidence.

Suggested sequencing is a product-risk judgment: fix misleading result/fact construction (#38–41/#48), remove the new-work dead end (#44), persist calculation identity alongside algorithm changes (#45), resolve scope (#14/#46/#47), and admit a narrowly reviewed weekly layer (#43) when its facts/sources/tests are ready. Never trade away history or source applicability to improve a completion percentage.

## Maintenance

For each changed BR/PAY/EX record the symbol, regression, tested candidate SHA and result. Keep **represented, implemented, regression-tested, native-verified, source-reviewed and released** separate. Append evidence; never rewrite a historical failure as a retroactive pass.

A generated function, plausible screenshot, empty CI list or pending PR is not closure. A documentation correction can resolve scope ambiguity, not implement missing calculations. No application code or payroll policy was changed by this mapping.

[domain]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/DomainModels.swift
[calculator]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PayCalculator.swift
[timeline]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/AgreementTimeline.swift
[assessor]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PaycheckAssessment.swift
[decimal]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/StrictDecimal.swift
[dt]: https://github.com/streamentry/linepay/tree/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests
[at]: https://github.com/streamentry/linepay/tree/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources
[model]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppModel.swift
[state]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppState.swift
[drafts]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/EntryDrafts.swift
[add]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AddWorkView.swift
[setup]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayProfileSetupView.swift
[ui]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppUITests/PaydayJourneyTests.swift
[parser]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubTextParser.swift
[auditstate]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AuditAssessment.swift
[report]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/ReconciliationReportExporter.swift
[session]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppSession.swift
[commerce]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SubscriptionStore.swift
[i38]: https://github.com/streamentry/linepay/issues/38
[i39]: https://github.com/streamentry/linepay/issues/39
[i40]: https://github.com/streamentry/linepay/issues/40
[i41]: https://github.com/streamentry/linepay/issues/41
[i43]: https://github.com/streamentry/linepay/issues/43
[i44]: https://github.com/streamentry/linepay/issues/44
[i45]: https://github.com/streamentry/linepay/issues/45
[i46]: https://github.com/streamentry/linepay/issues/46
[i47]: https://github.com/streamentry/linepay/issues/47
[i48]: https://github.com/streamentry/linepay/issues/48
