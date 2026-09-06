# Product-to-code traceability

[Product handbook](README.md) · [Business rules](business-rules.md) · [Payroll coverage](payroll/coverage-and-gaps.md) · [Documentation home](../README.md)

**Review date: September 6, 2026. This is an evidence map, not release approval or a claim of complete US payroll compliance.**

## 1. Baselines and how to read this map

- Product specification: `990154cb517773036c29d8051a30e7e0edf9feaa`, the handbook on PR #12. The handbook was not merged when this review began.
- Application and tests: `4fe319dc13836eb4e061442f2f9aae53c4d3b00a`, the separately read live `main` reference. Its application trees are unchanged from `105b024e283c70e07375f53cc4da11010441e5a2`; newer main changes concern legal controls, documentation and release tooling.
- All code/test links below are pinned to the reviewed application commit. Do not equate the handbook branch's older application tree with current `main`, or a pending PR with a shipped fix.
- Existing issues #13–33 and #37 were reviewed before filing additional work. PR #34 contains pending native legal/disclosure/report changes; it is not treated as merged or native-verified here. #37 already owns the runner-startup blocker.
- This map enumerates **45 BR business rules, 18 PAY catalog concepts and 34 EX acceptance vectors**. Catalog questions and reference examples are not silently promoted into launch commitments.

### Evidence vocabulary

| Mark | Meaning |
|---|---|
| Source matched | The named implementation represents the described narrow behavior. This is not a claim that every input, screen or device was tested. |
| Domain tested | The corresponding production domain test was executed in the portable run described below. Its particular assertions passed, not all adjacent requirements. |
| Test present | A named app/UI test exists and its assertions were inspected. It was not executed in this review. |
| Partial / defect | A requirement has a concrete representation, interaction, calculation or provenance gap. See the linked issue. |
| Missing capability | The required variant cannot currently be represented or computed. A scope decision and disclosure do not make the algorithm implemented. |
| Deferred / conditional | The handbook explicitly treats a capability as unsupported, reference-only or optional. Do not build it merely to increase completion counts. |
| External verification | Native device, actual storefront, real provider, user comprehension or attributable source/owner review is still required. |

A generic test-file name below identifies relevant existing evidence, not an assertion that it proves the entire row. The issue acceptance criteria identify the missing regression.

## 2. Executed checks and limits

The complete production `LinePayDomain/Sources` and existing domain tests were copied without source edits into an isolated package. Only that disposable package's manifest selected tools 6.2 because this environment has **Swift 6.2.1 on x86_64 Linux** rather than the repository's Xcode/Swift 6.3 toolchain.

- Existing domain suite: **82 tests passed**.
- Additional characterization probes: **7 passed**, meaning they reproduced the observed behavior below. They are not seven fixes or seven satisfied product acceptance criteria.
- One parser probe used the complete unchanged `PaystubTextParser.swift`, production `LinePayFormat.swift`, and exact supporting type excerpts. It did not invoke Vision, a scanner or SwiftUI.
- The repeat-break probe executes the Foundation transformation used in the view, not an automated interaction with that view.
- No native app test, Release build, StoreKit sandbox, simulator journey, physical-device interaction or legal certification was performed for this mapping.

The local snapshot was matched to fresh GitHub tree hashes, not accepted merely because its filename looked current:

| Source/test tree | Git tree SHA |
|---|---|
| `apps/ios/App` | `e57e993d805267404e1aa29acb1b5878437f788b` |
| `apps/ios/AppTests` | `49bf43c5c3f0cb64bb889e21eccdde35b021c380` |
| `apps/ios/AppUITests` | `397354932576ef581cfd39b31da4f9d5b94e86cf` |
| `LinePayDomain/Sources` | `0098636fa4702e54782c93eaa5152ab6c6bee467` |
| `LinePayDomain/Tests` | `ceae6beb49f750aa90a1edcb541213c9688e472d` |

### Observed synthetic boundaries

| Probe | Actual observed result | Interpretation / issue |
|---|---|---|
| Expected wages $550; confirmed paid gross $500 but paid regular $400 + OT $150 | `possibleShortfall`, no review reasons | Contradictory paid facts are not qualified. [#38][I38] |
| Same two minutes at $50: one entry versus two adjacent one-minute entries | $1.67 versus $1.66 | Internal partition determines rounding. An approved aggregation boundary is missing. [#39][I39] |
| Repeat New York March 7, 2026 00:00 start and 04:00 break onto March 8 | Copied break becomes 05:00 | Start uses wall time, break uses elapsed offset. [#40][I40] |
| Same two-hour callout at $50 with four-hour minimum, recorded once versus split into two callout rows | $200 versus $400 at 1x | No shared dispatch identity distinguishes one event from two. Two genuine calls are a different input. [#41][I41] |
| Six eight-hour days at $50, daily OT after eight only | $2,400 | No weekly statutory layer; EX-10's restricted reference is $2,600. [#43][I43] |
| Two-hour callout spanning a date-effective rate change with a four-hour minimum | `calloutGuaranteeNeedsReview`, no result | The domain abstention is correct; source tracing then shows period rollover blocked. [#44][I44] |
| OCR `Pay period ending 09/05/2026` | Suggests both start and end as `2026-09-05` | An end-only source does not establish the start. [#48][I48] |

The monetary examples above are synthetic and do not determine a real worker's legal entitlement. For the statutory reference, retain every assumption in EX-10. Rounding and callout policy must be sourced for the admitted variant, not invented from these probes.

## 3. Business-rule mapping

### Identity, scope and setup

| ID | Current implementation and relevant tests | Assessment / work item |
|---|---|---|
| BR-001 | [project configuration][S-project], `LinePayDomain`, existing StoreKit IDs; root agent contract | Source matched. Public branding is deliberately separate from installed identity. |
| BR-002 | [AppSession][S-session], [local state store][S-store], [OCR service][S-ocr], native StoreKit adapter | Local architecture represented. Apple commerce and user-chosen file providers remain separate external paths; no new account/backend issue. |
| BR-003 | [AppState.PayProfile][S-state], [AppModel.candidateForProfile][S-model], [futureRateDoesNotRepriceExistingWork][T-readiness] | One profile and retained historical rules represented; test present. Intraday scope is separate, #46. |
| BR-004 | [PaycheckAssessor][S-assessor], [PayPresentation][S-presentation], ledger and report | Partial: existing scoped verdicts are real, but automatic statutory omissions and calculation-engine identity are incomplete. #14, #43, #45. |
| BR-005 | [rule setup][S-setup], manual sources and confirmation metadata | Partial source/applicability boundary. #14 and #26 own disclosure and actual preset approval; confirmation is not a waiver or external verification. |
| BR-006 | `unsupportedRuleNotes`, [assessor review reasons][S-assessor], [uncertainComponentsAndUnsupportedRulesCannotPassCleanly][T-assessment] | Domain-tested for explicit unsupported flags. Blank notes do not establish complete coverage; #14. |
| BR-010 | [PayProfileSetupView][S-setup], [OnboardingFlowView][S-onboarding], [ScreenContractTests][T-screen] | Progressive fields and review exist. Unsupported-scope explanation remains #14; do not recreate the old missing-onboarding finding. |
| BR-011 | [AgreementSnapshot][S-domain], [AgreementTimeline][S-timeline], [ratesApplyByWorkDateAndKeepSourceVersions][T-timeline] | Domain-tested date-based versions. Pay-calculation engine identity missing (#45); same-day rate changes unrepresented (#46). |
| BR-012 | [candidateForProfile / previewProfileChange][S-model], [RuleScopeRegressionTests][T-rule-scope] | Runtime scopes represented; native tests present. Three choices still have a contradictory two-way consent explanation on main: existing #15, pending PR #34. |
| BR-013 | [WorkInterval / RegularScheduleWindow][S-domain], [period window][S-state], [time/tier tests][T-time] | Instant/timezone behavior domain-tested. Contract workday is calendar midnight; separate workweek/intraday context missing. #14, #40, #43, #46. |
| BR-014 | [correctCurrentPeriod / validateNewWindow][S-model], [periodCorrectionRejectsMovingWorkOrOverlap][T-readiness] | Containment, overlap and audit invalidation represented; test present. No old ineffective-date-control issue reopened. |
| BR-015 | [AgreementSource.ruleKey][S-domain], [EvidenceReceiptView][S-evidence], [source round-trip tests][T-contract] | Narrow per-rule provenance represented. Rights, applicability and reviewer approval are external gates in #26, not implied by a URL. |

### Work, periods and historical records

| ID | Current implementation and relevant tests | Assessment / work item |
|---|---|---|
| BR-020 | [WorkInterval versus PayComponentCategory][S-domain], [calloutGuarantees][S-calculator], [invariant tests][T-invariants] | Actual time and paid equivalents separated and domain-tested. Event identity and minimum interaction remain #41. |
| BR-021 | [addWork / updateWork / delete / restore][S-model], [workGuardsAndUndoAreSafe][T-model-contract], domain overlap/break tests | Validation represented and domain tests passed for their cases. Callout entitlement can still be duplicated by splitting one event into rows (#41). |
| BR-022 | [AddWorkView.init / repeatDates / moveTemplate][S-add], [addEditAndRepeatFormsRetainTheirWorkFacts][T-screen] | Partial: reusable draft and history template exist; DST break copy and gap/fold resolution wrong/incomplete. #40. |
| BR-023 | [EntryDrafts][S-drafts], [saveSetupDraft / saveWorkDraft / savePaystubDraft][S-model], [workAndIntakeDraftsSurviveNewModel][T-readiness] | Durable drafts and context guards represented; tests present. No assertion of physical interruption testing in this review. |
| BR-024 | [DeletedWorkUndo][S-drafts], [restoreDeletedWork][S-model], [staleUndoCannotMoveWorkToNextPeriod][T-readiness], [scheduledRuleChangeRejectsUndoWhoseWorkCouldBeRepriced][T-integrated] | Source matched; regressions present. The earlier stale-Undo defect should not be filed again. |
| BR-025 | [periodContext / historical confirmPaystub][S-model], [sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules][T-integrated] | Normal late-paycheck path represented. Unpriceable A cannot close to permit B (#44); existing success-path test does not cover it. |
| BR-026 | [AuditRevision][S-state], [confirmPaystub][S-model], [closedAuditCorrectionsAppendRevisions][T-readiness] | Snapshots and audit revisions represented. Separate pay-calculation version missing (#45). |
| BR-027 | [period finishing UI][S-ledger], [archiveCurrentPeriod][S-model], [HistoryView][S-history], [periodCadencesAndArchive][T-period] | Explicit close and awaiting-paycheck state exist for calculable work. Unresolved-close representation missing (#44). |
| BR-028 | [recalculate / calculate / validate][S-model], [AuditAssessment][S-audit-state], [missingAndStaleCalculationsAreNotSuccess][T-audit-scope] | Guard against invented zero/success exists; test present. Preserve this guard while removing the rollover dead end (#44). |

### Source acquisition, numbers and comparisons

| ID | Current implementation and relevant tests | Assessment / work item |
|---|---|---|
| BR-030 | [PaystubImportView][S-import], [DocumentScannerView][S-scanner], [OCR service][S-ocr], [DocumentPipelineTests][T-document] | Scan/photo/PDF/manual routes exist. Actual scanner/device permission acceptance remains external, not established here. |
| BR-031 | [PaystubTextParser][S-parser], `OCRFieldSuggestion` / `SourceRegion`, [currentNeverSelectsYTD][T-ocr-parser] | Conservative YTD path represented and previously tested in repo; current parser probe finds end-only date mapped to both boundaries (#48). |
| BR-032 | [PaystubImportOperation][S-operation], [import view][S-import], [PaystubImportOperationTests][T-import-operation] | Single operation/context and cancellation guards represented; tests present. No reopening of the original competing-import bug without a new counterexample. |
| BR-033 | [StrictDecimal][S-decimal], app conversion helpers, [StrictDecimalTests][T-assessment], [AppModelContractTests][T-model-contract] | Whole-string domain number tests passed. Suggestions still need correct date direction (#48); statutory rounding/aggregation is a separate gap (#39). |
| BR-034 | [confirmPaystub][S-model], [PaycheckFacts / assessor][S-assessor], [partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess][T-integrated] | Period, currency and work-completeness guards exist. Contradictory paid gross and paid subtotal not qualified (#38). |
| BR-035 | [PaystubGrossBasis / LineLayout / HoursBasis / GuaranteeLayout][S-assessor], [premiumOnlyLayoutAndHours][T-assessment] | Domain-tested selected mappings. Unknown and unusual multipliers are qualified; not universal payroll-provider support. #38 covers paid-fact consistency, #41 the underlying event unit. |
| BR-036 | [PaycheckAssessor verdict][S-assessor], [matchingGrossDoesNotHideOffsettingErrors][T-assessment], [AuditScopeRegressionTests][T-audit-scope] | Equal-gross offsetting errors correctly need review. Inverse contradictory-paid-total case remains #38; legal completeness remains #14. |
| BR-037 | [EvidenceReceiptView][S-evidence], [SourceEvidenceView][S-source-view], [AuditDetailView][S-audit], report | Relevant component/rule/source drill-down exists. Calculation identity (#45) and privacy-safe exact report preview (#20) remain separate. |
| BR-038 | [PaycheckVerdict][S-assessor], [PayPresentation][S-presentation], [status tests][T-screen] | Neutral direction terms represented. Broader support/report claims and deadlines stay in existing #29. |

### Pricing, trial and access

| ID | Current implementation and relevant tests | Assessment / work item |
|---|---|---|
| BR-040 | [SubscriptionStore][S-subscription], [ProPaywallView][S-paywall], [StoreKitLifecycleTests][T-storekit] | One entitlement/two products and localized metadata represented. Live approval/pricing evidence remains #18. |
| BR-041 | [canRunAudit / confirmPaystub][S-model], [paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry][T-integrated], backup access guards | Separate Free allowance and same-period authorization represented; tests present. Do not remove the annual trial or consume Free during Pro because of older chat policy. |
| BR-042 | [RootView][S-root], [FirstPayResultView][S-first], [paywall][S-paywall], [firstRealResultSurvivesInterruptionAndOnlyAppearsOnce][T-integrated] | First real value and optional offer exist; eligibility tests present. Reminder roadmap remains a conditional scope decision (#47), not a mandatory unimplemented paywall. |
| BR-043 | [SubscriptionStore][S-subscription], [SubscriptionOperations][S-subscription-ops], [SubscriptionBehaviorTests][T-subscription], [local StoreKit tests][T-storekit] | Verified purchase/status logic represented. Native/storefront proof remains #18/#37; debug commerce bypass is not proof of production access. |
| BR-044 | [load / refreshEntitlements][S-subscription], [existingOwnershipSurvivesCatalogFailure][T-subscription] | Metadata and entitlement loading separated; test present. Do not reopen the old metadata-ordering defect. |
| BR-045 | [HistoryView][S-history], [SettingsView][S-settings], [AppSession backup][S-session], app access checks | Existing records and backup not deleted on expiry. Wording in pricing that calls history/export Pro must not override this invariant; #18/#17 cover alignment. |
| BR-046 | [AppSession.restore][S-session], [preservesFreeAllowance][T-backup], [SubscriptionStore][S-subscription] | Restored local records do not constitute verified Pro. Local anti-reset trade-off preserved; no backend requested. |

### Data, recovery and reports

| ID | Current implementation and relevant tests | Assessment / work item |
|---|---|---|
| BR-050 | [AppSession / BackupIO][S-session], [SettingsView][S-settings], local evidence stores | User-directed file/export architecture represented. Newer main active privacy-copy controls supersede older absolute slogans on the handbook branch: #17/#21/#22 and PR #12 integration note below. |
| BR-051 | [confirmPaystub / removeEvidence][S-model], [manualCorrectionPreservesOriginalAndFailedReplacementRollsBack][T-period] | Retain/replace/delete paths and revisions represented; test present. Editing an amount no longer implicitly deletes original evidence. |
| BR-052 | [pendingEvidenceDeletions / retryEvidenceDeletion][S-model], [EvidenceStore][S-evidence-store], [failedEvidenceDeletionRemainsRetryable][T-readiness] | Retryable deletion and recovery represented. Full device/provider/temp exposure acceptance stays #21; no unrelated external-file deletion authorized. |
| BR-053 | [VersionedLocalStateStore][S-store], [AppStateValidation][S-validation], [StorageContractTests][T-storage] | Atomic/size/semantic validation and recovery represented; tests present. A source read is not a new fault-injection/native run. |
| BR-054 | [AppSession.restore][S-session], [BackupArchive][S-backup], [BackupStateMapping][S-backup-map], [BackupTests][T-backup], [BackupValidationTests][T-backup-validation] | Archive validation, staging and rollback represented. Two-device real-provider acceptance remains #21. |
| BR-055 | [schema mapping][S-backup-map], [AppStateValidation][S-validation], [bothSchemaTwoVariantsUpgradeWithoutDroppingTheirEvidence][T-integrated], [staticV1FixturePreservesHistoricalMeaningAndOriginal][T-integrated] | Frozen monetary/source/history data has migration tests. Pay-calculation version cannot survive when never stored (#45). |
| BR-056 | [ReconciliationReportExporter][S-report], [reportUsesComparableWagesAndPaginatesLongEvidence][T-document] | Scoped totals, saved assessment and comparison version exist. Original pay-calculation identity absent (#45); raw OCR-source detail and exact preview remain #20/PR #34. |
| BR-057 | [ScreenContractTests][T-screen], [PaydayJourneyTests][T-ui], checked-in Maestro flows | Representative automation exists. No current all-screen/physical accessibility sign-off in this review; reuse #31/#37. Support data-minimization is #23. |

## 4. Payroll rule catalog mapping

The catalog enumerates rule-discovery questions, not eighteen launch promises. Implemented primitives do not establish employer, classification, jurisdiction or agreement applicability.

| Rule | Actual model/path | Current boundary and issue |
|---|---|---|
| PAY-01 Base wages | [AgreementSnapshot.hourlyRate][S-domain], [AgreementTimeline][S-timeline] | Date-effective configured rates work; exact intraday variant not represented (#46), separate calculation provenance #45. |
| PAY-02 Daily overtime | `DailyOvertimeTier`, [overtimeSlices][S-calculator], [daily tier tests][T-time] | Cumulative local-calendar-day hours; non-midnight workday and broader statutory coverage not established (#14/#43). |
| PAY-03 Weekly overtime | No workweek/regular-rate/credit model in current snapshot | Missing capability #43, distinct from disclosure #14. EX-10–14 reference-only. |
| PAY-04 Outside schedule | `RegularScheduleWindow`, [split / applicableBaseMultiplier][S-calculator] | Non-overnight windows representable in domain. Overnight templates explicitly rejected; split/variable schedules are not equivalent to the UI's simple shared daily window. Keep unsupported variants disclosed (#14/#26). |
| PAY-05 Weekday/date premiums | `WeekdayPremium`, `DatePremium`, `highestApplicable` | Domain-tested configured maximum, not additive entitlement or an automatic holiday/observance pack. #26 before named preset claims. |
| PAY-06 Callout minimum | `CalloutMinimumRule`, [calloutGuarantees][S-calculator] | Isolated same-policy arithmetic exists. Minimum unit/event ownership incomplete (#41); safe abstention can block period lifecycle (#44). |
| PAY-07 Rest/fatigue | Unsupported-rule notes only; no rest entitlement state machine | Explicitly deferred/unsupported, not a missing toggle to invent. #14/#26 gate any broader claim. |
| PAY-08 Meal-related pay | Exact unpaid `WorkBreak` spans, but no meal-entitlement/event model | Break subtraction is not proof of paid meal, statutory penalty or allowance coverage. Deferred, #14/#26. |
| PAY-09 Travel | `WorkKind.other` can hold an interval, not classify compensability | No travel-specific entitlement model. Deferred, #14/#26; do not turn notes or GPS into entitlement. |
| PAY-10 Standby/on-call | No restriction/standby allowance model | Deferred; actual response can be logged, broader time classification not checked. #14/#26. |
| PAY-11 Reporting/show-up | No no-work reporting entitlement model | Callout minimum is not a universal show-up guarantee. Deferred, #14/#26. |
| PAY-12 Subsistence/per diem | `FlatPerDiemRule`, [perDiemComponents][S-calculator], [perDiemOncePerDate][T-time] | One flat allowance per worked local date implemented; other eligibility/shift/trip/tax variants unrepresented. #14/#26. |
| PAY-13 Mileage/expenses | No distance/receipt/rate model | Deferred. Wage-gross comparison must not claim these payments were checked. #14/#26. |
| PAY-14 Shift/hazard/storm supplements | A configured date/weekday/schedule multiplier is possible | No event-triggered hazard/storm/differential engine or universal storm rule. Deferred variants, #14/#26. |
| PAY-15 Bonus/retroactive adjustment | Audit revisions and date rates exist; no earned-week compensation allocator | Missing regular-rate layer #43. Historical manual correction is not statutory retroactive allocation. |
| PAY-16 Paid leave/holiday not worked | No paid non-work event category | Deferred; do not fake a WorkInterval to create leave wages. #14/#26. |
| PAY-17 Benefits/fringe/cash-in-lieu | No benefit/contribution/project classification model | Deferred. A wage package is not cash gross; full project compliance unclaimed. #14/#26. |
| PAY-18 Deductions/net pay | Paystub fields and assessor compare configured gross, not net tax/deductions | Explicitly outside gross-comparison scope. No new net-tax feature issue; #29 owns non-adjudicative boundaries. |

## 5. Acceptance-vector map

“Mechanism covered” below does not mean the exact handbook numbers are already a named executable EX fixture. Several repository tests use different synthetic rates/dates for the same mechanism. The shared/contracts directory presently contains instructions and README, not a complete executable EX vector corpus.

| EX ID | Code / existing regression | Evidence / gap |
|---|---|---|
| EX-01 | [PayCalculator][S-calculator]; [ReadinessTests configured work][T-readiness], domain regular-day tests | Basic wages mechanism covered; beware rounding variants #39. |
| EX-02 | [dailyOvertimeThreshold][T-time] | Domain-tested tier mechanism. |
| EX-03 | [secondOvertimeTier][T-time] | Domain-tested multiple-tier mechanism. |
| EX-04 | [unpaidBreakIsExcludedFromWorkedPay / breakDoesNotCreateFakeOvertime][T-break] | Domain-tested exact-break mechanism; no legal classification inferred. |
| EX-05 | [weekendPremiumWinsOverOvertime][T-time] | Domain-tested configured maximum, not universal premium precedence. |
| EX-06 | [californiaCalloutMinimum][T-california], [callout guarantee invariants][T-invariants] | Isolated arithmetic covered; not multiple calls/overlap. #41. |
| EX-07 | [perDiemOncePerDate][T-time] | Domain-tested work-date deduplication. |
| EX-08 | [ratesApplyByWorkDateAndKeepSourceVersions][T-timeline] | $460 can be represented over two work dates; the handbook leaves the boundary unspecified. Clarify date versus intraday, #46. |
| EX-09 | [AgreementTimeline][S-timeline] accepts LocalDate only | Same-workday $50 to $60 change is not representable. Reference/unsupported classification and scope decision #46. Do not claim date-change tests cover it. |
| EX-10 | [PayCalculator][S-calculator] day accumulation only | Missing weekly layer #43; portable example returns $2,400, restricted reference $2,600. |
| EX-11 | No independent complete-workweek model | Reference-only, #43. Do not average the 50h and 30h weeks. |
| EX-12 | No includable-bonus/earned-week model | Reference-only, #43. Preserve the stated $2,860 vector. |
| EX-13 | No weighted statutory regular-rate model | Reference-only, #43. **Pinned handbook: 24h at $40 plus 24h at $60, total $2,600.** A 30h/20h $2,640 variant is a different example, not a replacement. |
| EX-14 | No approved premium-credit model | Reference-only, #43. Contractual highest-multiplier selection is not a federal-credit calculation. |
| EX-15 | [perDiemExcludedFromWageGross][T-assessment] | Domain-tested wage/allowance separation mechanism; existing test uses a different wage amount. |
| EX-16 | [matchingGrossDoesNotHideOffsettingErrors][T-assessment] | Exact $400/$150 versus $350/$200 shape covered and passed. Inverse gross/subtotal inconsistency is different, #38. |
| EX-17 | [PaycheckAssessor fullRateBuckets][S-assessor], [assessor/app scope tests][T-audit-scope] | Supported line layout represented; native tests not rerun. |
| EX-18 | [premiumOnlyLayoutAndHours][T-assessment] | Exact $500 base + $50 premium layout passed. |
| EX-19 | [uncertainComponentsAndUnsupportedRulesCannotPassCleanly][T-assessment] | Explicit unsupported flag is tested. Automatically admitting unknown coverage still #14. |
| EX-20 | [partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess][T-integrated] | Test present; code gates incomplete work. |
| EX-21 | [completeNumbers][T-assessment] | Grouped whole-string parsing passed. |
| EX-22 | [rejectsPrefixesAndAmbiguousFormatting / precisionAndRange][T-assessment], currency guards | Domain negative-input mechanisms passed. |
| EX-23 | [currentNeverSelectsYTD][T-ocr-parser], [localVisionDoesNotPreferYTDOverCurrentGross][T-document] | Parser/Vision tests present. No native OCR execution here; end-only dates are separately wrong (#48). |
| EX-24 | [springDSTUsesElapsedTime][T-time] | Domain DST elapsed-time mechanism passed. Does not test Repeat draft construction (#40). |
| EX-25 | [fallDSTUsesElapsedTime][T-time] | Domain repeated-hour mechanism passed. Does not establish an explicit ambiguous-time selector (#40). |
| EX-26 | [sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules][T-integrated], [PaydayJourneyTests][T-ui] | Normal two-period behavior has tests. Unpriceable prior period missing (#44). |
| EX-27 | [staleUndoCannotMoveWorkToNextPeriod][T-readiness] | Context-bound Undo represented; test present. |
| EX-28 | [correctionsRetainOriginalWithoutReloadingBytes][T-readiness], [manualCorrectionPreservesOriginalAndFailedReplacementRollsBack][T-period] | Evidence retention and revisions represented; tests present. |
| EX-29 | [timeZoneChangeClosesWithoutOverlapAndKeepsHistory][T-boundaries], historical context/report source | Frozen-period timezone represented. New runtime/device proof not claimed. |
| EX-30 | [workAndIntakeDraftsSurviveNewModel][T-readiness], [PaydayJourneyTests][T-ui] | Persisted draft tests present; no real device interruption test here. |
| EX-31 | [StorageContractTests][T-storage], [BackupTests][T-backup], deletion fault tests | Meaningful failure tests exist. Actual provider/device acceptance remains #21/#37. |
| EX-32 | [existingOwnershipSurvivesCatalogFailure][T-subscription], [StoreKit lifecycle test][T-storekit] | Adapter and native tests present; no new storefront proof, #18/#37. |
| EX-33 | [paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry][T-integrated] | Explicit Pro/Free independence test present. |
| EX-34 | [AppSession.restore][S-session], [preservesFreeAllowance][T-backup], StoreKit outside local state | Source boundary represented; restored data is not verified subscription authority. |

## 6. Other product documents and non-runtime obligations

| Document / section | Mapping and disposition |
|---|---|
| `app-workflows.md` first launch / first work | Onboarding, FirstWorkIntroductionView, FirstPayResultView and RootView implement the sequence. BR-010/042; new performance/comprehension numbers require real worker observations, not code inspection. |
| `app-workflows.md` daily logging / payday | AddWorkView, TodayView, PayLedgerView, importer, AppModel and history. BR-020–038; #38–41/#44/#48 cover specific new counterexamples. |
| `app-workflows.md` corrections / failure / recovery | AppModel revisions and persistent drafts, AppSession rollback, DataRecoveryView. BR-023–028/051–055; no old blanket “no persistence” claim. |
| `onboarding.md` annual offer / first free audit | FirstPayResultView, ProPaywallView, SubscriptionStore, canRunAudit and confirmPaystub. Tests in IntegratedReadinessTests and StoreKitLifecycleTests. Actual offer approval and receipts remain #18. |
| `onboarding.md` optional reminder roadmap | No scheduler/permission preference in the reviewed app tree. Text itself conditions the renewal offer on implementation. Resolve explicit defer/admit status in #47; not automatically a release blocker. |
| `onboarding.md` activation metrics / pricing experiments | Business validation requirements, not missing Swift features. Do not add tracking SDKs to manufacture observability; preserve the documented aggregate/interview approach. |
| `pricing.md` prices / duration / Free ownership | Current code has one entitlement and two products with localized display. Store configuration and subscribed-account testing are #18. BR-045 wins over an imprecise “Pro history/export” feature list. |
| `payroll/README.md`, `sources.md`, `us-legal-baseline.md` | Applicability/source-governance requirements. No source URL, fixture, AI review or checkbox proves an externally verified agreement. Reuse #14/#26 and existing legal-owner gates. |
| `payroll/coverage-and-gaps.md` | GAP-01/02 mapped to #43. GAP-03–07 remain explicit unclaimed/deferred layers and admission gates, not seven mandates to build a universal payroll/tax app. |
| Historical audit / remediation / QA records | Evidence for the revision they identify, not proof the current main or submitted App Store binary has the same behavior. #13/#31/#37 cover those distinct boundaries. |

### Handbook integration drift

The new handbook remains based on a pre-legal-controls revision. Current main deliberately changed active privacy/marketing language and release controls after that baseline. Integrating PR #12 must preserve those newer decisions rather than restore older absolute privacy slogans or overwrite the legal directory's navigation. Use the live diff and existing #17/#18/#27, not an automatic ours/theirs merge. This is a documentation integration concern, not proof of an application privacy regression.

## 7. Deduplicated issue map and sequencing

| Issue | Kind / priority | Principal contract |
|---|---|---|
| [#38][I38] Contradictory paid totals | Defect, P1 | BR-034–036; reconciliation consistency |
| [#39][I39] Segmentation-dependent rounding | Computational-policy gap, P1 | Calculation §3; BR-011/036/055 |
| [#40][I40] Repeat/DST wall-time handling | Defect, P1 | BR-013/022; calculation §2 |
| [#41][I41] Callout trigger versus row identity | Representation gap, P1 | PAY-06; BR-020/021 |
| [#43][I43] Reviewed weekly/regular-rate layer | Missing capability, P1 before claiming it | PAY-03/15; GAP-01/02; EX-10–14 |
| [#44][I44] Unpriceable period blocks subsequent work | Lifecycle defect, P1 | BR-025/027/028; EX-26 boundary |
| [#45][I45] Pay-calculation engine identity | Provenance gap, P2 | BR-011/026/055/056 |
| [#46][I46] Intraday examples versus date-only timeline | Documentation/scope gap, P2 | EX-08/09; PAY-01/02 |
| [#47][I47] Optional reminders' release status | Conditional scope gap, P2 | Onboarding roadmap/acceptance |
| [#48][I48] End-only OCR date assigned to start | Parser defect, P2 | BR-031/033/034 |

#42 was a concurrent duplicate of #43 and was closed as duplicate, not fixed. The exact EX-13 correction was posted on #43. Do not create a second workweek implementation issue.

Reuse existing issues rather than opening more: #14 supported-rule disclosure; #15 consent scopes; #18 live commerce; #20 report privacy/preview; #21 data/provider failure acceptance; #26 named-pack approval; #29 non-adjudicative boundaries; #31 native accessibility evidence; #37 runner-startup failure. Pending PR #34 is relevant to several of these, but not a completed fix.

Recommended order is a product-risk judgment: correct misleading current results and fact construction (#38–41/#48), remove the work-logging dead end (#44), introduce calculation-version support alongside any changed algorithm (#45), resolve scope wording (#14/#46/#47), then admit a reviewed weekly layer (#43) when its sources, inputs and tests are actually ready. No task may bypass historical-data or source-applicability safeguards to improve a completion percentage.

## 8. Maintenance and closure

For each change, update its BR/PAY/EX mapping with the implementation symbol, meaningful regression, tested candidate SHA and observed result. Keep separate fields for represented, implemented, regression-tested, native-verified, source/applicability-reviewed and released. Historical findings stay pinned; append new evidence instead of rewriting an old failure as a retroactive pass.

An issue is not closed merely because code was generated, a screenshot looks plausible, an empty CI list contains no failure, or another branch contains a fix. A changed docs statement may resolve a genuine scope contradiction, but cannot itself implement missing pay calculations.

[S-project]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/project.yml
[S-domain]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/DomainModels.swift
[S-calculator]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PayCalculator.swift
[S-timeline]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/AgreementTimeline.swift
[S-assessor]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PaycheckAssessment.swift
[S-decimal]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/StrictDecimal.swift
[S-model]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppModel.swift
[S-state]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppState.swift
[S-session]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppSession.swift
[S-store]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/LocalStateStore.swift
[S-validation]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AppStateValidation.swift
[S-drafts]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/EntryDrafts.swift
[S-setup]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayProfileSetupView.swift
[S-onboarding]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/OnboardingFlowView.swift
[S-root]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/RootView.swift
[S-first]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/FirstPayResultView.swift
[S-add]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AddWorkView.swift
[S-ledger]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayLedgerView.swift
[S-history]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/HistoryView.swift
[S-settings]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SettingsView.swift
[S-presentation]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PayPresentation.swift
[S-audit-state]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AuditAssessment.swift
[S-audit]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/AuditDetailView.swift
[S-import]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubImportView.swift
[S-operation]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubImportOperation.swift
[S-scanner]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/DocumentScannerView.swift
[S-ocr]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubOCRService.swift
[S-parser]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/PaystubTextParser.swift
[S-evidence]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/EvidenceReceiptView.swift
[S-source-view]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SourceEvidenceView.swift
[S-evidence-store]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/EvidenceStore.swift
[S-report]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/ReconciliationReportExporter.swift
[S-backup]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/BackupArchive.swift
[S-backup-map]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/BackupStateMapping.swift
[S-subscription]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SubscriptionStore.swift
[S-subscription-ops]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/SubscriptionOperations.swift
[S-paywall]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/App/Sources/OnboardingPaywallView.swift
[T-assessment]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PaycheckAssessmentTests.swift
[T-time]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorTimeAndTierTests.swift
[T-break]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorBreakTests.swift
[T-timeline]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/AgreementTimelineTests.swift
[T-contract]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/DomainContractTests.swift
[T-invariants]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/PayCalculatorInvariantTests.swift
[T-california]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/Packages/LinePayDomain/Tests/LinePayDomainTests/CaliforniaOutsideLineFixtureTests.swift
[T-readiness]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ReadinessTests.swift
[T-integrated]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/IntegratedReadinessTests.swift
[T-model-contract]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/AppModelContractTests.swift
[T-rule-scope]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/RuleScopeRegressionTests.swift
[T-audit-scope]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/AuditScopeRegressionTests.swift
[T-screen]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ScreenContractTests.swift
[T-document]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/DocumentPipelineTests.swift
[T-ocr-parser]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/OCRParserTests.swift
[T-import-operation]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/PaystubImportOperationTests.swift
[T-period]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/PeriodAndEvidenceTests.swift
[T-boundaries]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/ReadinessBoundaryTests.swift
[T-storage]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/StorageContractTests.swift
[T-backup]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/BackupTests.swift
[T-backup-validation]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/BackupValidationTests.swift
[T-subscription]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/SubscriptionBehaviorTests.swift
[T-storekit]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppTests/Sources/StoreKitLifecycleTests.swift
[T-ui]: https://github.com/streamentry/linepay/blob/4fe319dc13836eb4e061442f2f9aae53c4d3b00a/apps/ios/AppUITests/PaydayJourneyTests.swift
[I38]: https://github.com/streamentry/linepay/issues/38
[I39]: https://github.com/streamentry/linepay/issues/39
[I40]: https://github.com/streamentry/linepay/issues/40
[I41]: https://github.com/streamentry/linepay/issues/41
[I43]: https://github.com/streamentry/linepay/issues/43
[I44]: https://github.com/streamentry/linepay/issues/44
[I45]: https://github.com/streamentry/linepay/issues/45
[I46]: https://github.com/streamentry/linepay/issues/46
[I47]: https://github.com/streamentry/linepay/issues/47
[I48]: https://github.com/streamentry/linepay/issues/48
