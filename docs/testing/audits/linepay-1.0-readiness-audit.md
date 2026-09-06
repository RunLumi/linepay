# LinePay 1.0 readiness audit

**Verdict: not feature-complete, not verified end to end, and not release-ready.**

Reviewed on September 5, 2026. Repository: `streamentry/linepay`. Public brand in the current agent contract: **LinePaycheck**. Technical identifiers remain `LinePay` and `com.streamentry.linepay`.

**Pinned source revision:** `fb913f3ed65a47006fb88a20005b11e6cf189505` (merged PR #1). Findings apply to this revision, not hypothetical later fixes. No repository files were changed during this audit.

**Final drift check:** `main` advanced during the audit to `b349b3d7d4976766c30b9e92e7a1c6d1936fa6fc`. The single intervening commit modifies **DESIGN.md only** (design revision 2.0), not application code, tests, the 1.0 plan, or mockups. The functional findings therefore still apply to the latest app code checked. CI results below refer to the unchanged app code at the merged commit; no successful new app build is inferred from a documentation-only commit. Detailed screen acceptance is anchored to the plan/mockups at the pinned revision, not a claim of full visual validation against the newly edited design document.

## Scope and evidence standard

Compared the canonical [iOS 1.0 plan](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/plan/ios-1.0.md) and all **46 numbered screens/states** in [mockups.md](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/plan/mockups.md) against current source, test definitions, and the merged commit's CI logs. The matrix is structural and behavioral source review, not a claim that 46 screens were rendered or tapped.

A shared native screen can satisfy several mockups. The issue is missing behavior, not the number of Swift files. Source presence does not establish working behavior. No screenshot, physical-device, VoiceOver, StoreKit sandbox, or simulator execution was performed in this audit session. The available execution environment was Linux, not Xcode/macOS.

Three evidence levels are kept separate:

- **Observed CI evidence:** a command actually ran in the repository's recorded CI job.
- **Confirmed source finding:** control flow or absent capability is directly visible in the pinned files. Reproductions described below are source-derived scenarios unless explicitly marked executed.
- **Isolated executed reproduction:** selected parsing routines were copied into a standalone Swift/Foundation script and run on Linux. This is not an iOS app test; add equivalent Darwin/Xcode tests before release.

## 1. Build and test status

[iOS workflow run 33952712842, job 101270358554](https://github.com/streamentry/linepay/actions/runs/33952712842/job/101270358554): **failed**. Xcode 26.6, Swift 6.3.3.

| Gate | Observed result |
|---|---|
| Swift format | Passed in this run |
| Privacy manifest plist syntax | Passed; syntax is not a privacy/compliance review |
| Pure-domain Swift tests | 37 passed |
| XcodeGen | Project generated |
| App compilation before simulator tests | Failed |
| App-layer simulator tests | Cancelled because compilation failed |
| Full paycheck E2E | Not demonstrated |
| Pixel/interaction/accessibility review | Not demonstrated |
| Agent Harness workflow | Passed; not evidence of app correctness |

The compiler diagnostic is at `apps/ios/App/Sources/DocumentScannerView.swift:29:40`: conformance of `DocumentScannerView.Coordinator` to `VNDocumentCameraViewControllerDelegate` crosses into main actor-isolated code and can cause data races. The delegate methods have `@MainActor`, while the conformance needs a coherent isolation strategy. Fix the actual isolation, not by disabling strict checking. More diagnostics may emerge after this blocker is fixed.

## 2. What is genuinely present

The native four-tab shell, no-account onboarding, deterministic pay-calculator foundation, work CRUD with explicit break spans, repeat/undo entry points, local JSON state, separate paystub files, gross reconciliation, audit/history views, photo/file/manual intake, OCR adapter, first-audit allowance, StoreKit adapter, PDF export and raw JSON export are real source implementations. They are not merely plan text.

There are useful domain regressions and app test definitions. However, the current app test suite did not execute successfully on this commit.

The JSON persistence choice is **not itself a defect**. [ADR 0004](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/adr/0004-versioned-local-document-store.md) explicitly accepts it in place of SwiftData. Safety and lifecycle gaps need repair without adding a backend or changing storage frameworks by default.

## 3. Prioritized findings

### A01. Release blocker: app does not compile

**Evidence:** recorded CI and [DocumentScannerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/DocumentScannerView.swift).

Until this is fixed, no end-to-end claim for this revision is defensible. Require a successful app build and app tests on the same commit before proceeding to UI sign-off.

### A02. Audit verdict is not evidence-aware

**Severity:** release-blocking financial correctness.

`confirmPaystub` calls a gross-only `PayReconciler`. `auditStatus` maps that gross direction directly to the main verdict. `auditFindings` separately compares some money buckets, but those results do not affect the verdict. Entered regular/OT/double-time **hours** are stored but are not reconciled by these methods. `needsReview` mainly means an old audit was invalidated; there is no `notComparable` state.

**Source-derived reproduction:** expected regular $400 and OT $150; confirmed regular $350 and OT $200; both gross $550. The header can say Matches despite two component differences. Gross matching is a valid limited observation, but should not masquerade as a clean component audit.

**Required fix:** explicitly model comparison scope/completeness and mapping semantics. Distinguish Gross total matches from All supported confirmed components match; incompatible/missing material evidence requires a qualified verdict. Do not assume that a paystub's overtime line is full premium wages rather than premium-only, or that callout top-ups always have separate payroll lines.

**Evidence:** [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [AppState.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppState.swift), [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift) and [PayCalculator](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PayCalculator.swift).

### A03. Per diem is indiscriminately included in the value compared with gross

**Severity:** release-blocking comparability issue.

`PayCalculator` adds per-diem components into `calculation.total`; confirmation compares that aggregate to the entered Gross pay field without describing or selecting what the stub's gross includes.

**Synthetic scenario:** the worker earns $400 wages plus $125 separately reimbursed per diem. The stub's gross-wage field is $400 and its separate reimbursement is $125. All $525 is paid. This implementation compares $525 to $400 and flags a $125 shortfall. This scenario is an explicit test assumption, not a universal assertion about every employer's paystub.

**Required fix:** separate wage gross, allowances/reimbursements, and comparable totals. Ask the user to confirm the relevant mapping; do not infer tax treatment or legal entitlement.

**Evidence:** [PayCalculator](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PayCalculator.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift).

### A04. The next work period cannot coexist with a prior period awaiting its paycheck

**Severity:** core recurring-use blocker; this exposes a product-design gap as well as missing behavior.

There is one `activePeriod`. Adding work outside its bounds is rejected, and starting another period is rejected until the current one is archived. Archiving permits no paystub, but History has no operation to attach/audit a later paycheck. `confirmPaystub` only targets the active period.

**Source-derived reproduction:** period A ends Sunday; its check arrives Thursday. On Monday, the user must either stop recording new work or archive A. After archiving A, Thursday's check cannot be audited against A through the available UI.

**Required fix:** separate Work period closed / Awaiting paycheck / Audited / Archived. Allow one current work period plus earlier periods pending a paycheck. Preserve original work/rule snapshots and append a new audit revision rather than rewriting old evidence. This does not require accounts or a server.

**Evidence:** [AppState.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppState.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [HistoryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/HistoryView.swift).

### A05. Rule edits reprice all current work and period-date edits are ineffective

**Severity:** high financial correctness and configuration reliability.

`saveProfile` replaces the active period's entire agreement and recalculates its existing work. There is no apply-from date or current-versus-future confirmation. Archived agreement snapshots are preserved, which is good, but already logged work in the active period is repriced. Selecting an effective date can also leave existing work outside the new agreement's range after saving.

The editor displays Next period starts for an existing profile, but `saveProfile` does not save that date into an existing period or the profile, and rollover calculates from the old period end. There is no Correct current dates use case.

**Source-derived reproduction:** log 8h at $50, then edit the profile rate to $60 as a future rate. The active total becomes $480 instead of retaining $400 for that shift. Alternatively change Next period starts and save; the value is not applied to rollover.

**Required fix:** explicit effective-date/apply scope and before/after review. Correct current boundaries with containment/overlap validation; never silently move work.

**Evidence:** [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift).

### A06. Numeric input can be accepted partially; OCR can choose YTD as current gross

**Severity:** high financial input integrity.

Executed isolated checks use the same `Decimal(string:locale:)` parsing pattern and `lastCurrencyLikeNumber` regex-selection routine as the reviewed source. On Swift 6.2.1/Linux:

```text
manual input "1000.00" -> 1000
manual input "1,000.00" -> 1
manual input "58oops" -> 58
OCR "Gross pay: Current $1,000.00 YTD $12,000.00" -> 12000.00
```

The regex deliberately returns the last currency-like number in a matching line. It has no current-versus-YTD column model. Input confirmation does not make misleading suggestions or partial string parsing safe.

**Required fix:** strict whole-string parsing with an explicit locale/grouping policy, range/precision validation and meaningful errors. OCR must identify current-period columns or abstain. Add equivalent Xcode tests; this local reproduction is not a claim of iOS runtime execution.

**Evidence:** [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [PaystubOCRService.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubOCRService.swift). Executed artifacts: `parsing-repro.swift`, `parsing-repro-output.txt` in this audit bundle.

### A07. OCR review lacks field provenance, confidence, date/hour extraction and durable drafts

**Severity:** required feature incomplete; input trust and recovery risk.

`OCRPaystubResult` has raw text plus five optional amount strings. It contains no per-field bounding boxes/pages, confidence, confirmation state, date fields or hours. Vision observations are flattened to strings. The review form shows raw OCR text, not the original crop beside a field. Period dates are prefilled from the active period, not extracted from the stub. PDF OCR silently limits itself to the first eight pages.

Work/setup/review drafts and the imported document before confirmation live in view state. `AppPersistentState` contains no drafts or unconfirmed intake session. A force-quit does not have a implemented resume path for these drafts.

**Required fix:** a small persisted intake/draft model and field-to-source references; show uncertain fields and limited audit scope. Keep manual input first-class. Document page limits explicitly; do not build an AI interpretation layer to compensate.

**Evidence:** [PaystubOCRService.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubOCRService.swift), [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift), [AppState.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppState.swift), [AddWorkView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AddWorkView.swift).

### A08. Historical and work-entry timezone paths are inconsistent

**Severity:** high time-context integrity.

Frozen period timezones are stored, and the History row uses the helper correctly. But `HistoricalPayPeriodView` passes the *current profile timezone* into both its audit-detail route and its direct PDF export. `AddWorkView` also selects the current profile timezone, while `AppModel.addWork` assigns the active period's frozen timezone.

**Required fix:** use the period/work context consistently for display, entry, comparison and export. Test a profile timezone change while a period is active and while viewing/exporting an archived period. Do not rely only on a unit test of the helper.

**Evidence:** [HistoryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/HistoryView.swift), [AddWorkView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AddWorkView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [app tests](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/AppTests/Sources/AppModelTests.swift).

### A09. Undo can restore work into the wrong period

**Severity:** high data-integrity edge case.

The Today view retains a deleted `WorkEntry`. `restoreWork` validates calculator compatibility but does not check the active period window or the original period ID. The entry lacks an ownership check in this operation.

**Source-derived reproduction:** delete an entry in A, switch to Pay, archive A and create B, return to Today, tap the surviving Undo. The app-level method can insert A's work into B. Simulator reproduction of the retained-view scenario remains required; the method-level missing guard is directly visible.

**Required fix:** bind undo commands to period ID and revision; reject stale commands and clear them on rollover. Always validate restored work against its target window.

**Evidence:** [TodayView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/TodayView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift).

### A10. Correcting a paycheck can discard its original evidence without explicit deletion

**Severity:** high evidence preservation/privacy reliability.

Replace or correct paycheck opens a new chooser rather than editing the existing confirmed draft. Manual entry has no source bytes. On successful confirmation, `savedEvidence` is nil and `confirmPaystub` deletes the old evidence when it differs. The separate Re-run audit route tries to reload original bytes, but failed file reads fall through to the same no-source behavior.

Several evidence-removal operations commit metadata removal and then swallow disk-deletion errors with `try?`. Settings also removes current evidence directly without the explanatory confirmation used on the audit screen.

**Required fix:** distinguish retain existing source, replace source, and explicitly remove source. Never interpret absent new bytes as permission to delete old evidence. Preserve a retryable deletion record and report failures truthfully.

**Evidence:** [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [EvidenceStore.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/EvidenceStore.swift).

### A11. StoreKit is implemented partially but its real lifecycle is not verified

**Severity:** release gate and paid offline-access risk.

The adapter contains purchases, restore, transaction updates and current entitlements. However, a new store starts `isPro = false`, and `load` refreshes entitlements only after fetching products succeeds. A product request failure can therefore prevent a valid locally available entitlement from being consulted on startup. This is a specific error-path risk, not a claim that every offline launch fails.

Ordinary Debug builds bypass audit gating. The three StoreKit tests exercise disabled commerce, not purchases, renewal, revocation, expiration, grace, interrupted checkout or offline access. No `.storekit` configuration file was found in the pinned tree. App Store Connect product configuration cannot be established from this repository alone.

**Required fix:** refresh entitlements independently of product metadata, create a local StoreKit configuration, and test entitlement transitions with commerce enabled. Preserve access to worker-owned data when purchases are unavailable. Reconcile the marketing promise of Pro history/export with the actual unrestricted history/report paths rather than retroactively locking existing records.

**Evidence:** [SubscriptionStore.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SubscriptionStore.swift), [OnboardingPaywallView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingPaywallView.swift), [HistoryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/HistoryView.swift), [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift), [StoreKit tests](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/AppTests/Sources/SubscriptionStoreTests.swift).

### A12. Recovery/export is narrower than the earlier completion claim

**Severity:** required recovery gaps plus documentation/packaging mismatch.

The store writes a versioned JSON document atomically. It supports only the current schema, has no migration transformer, and the inspected test is a same-schema round trip, not upgrade migration or fault injection. Recovery offers a raw file export and reset, not Try again/reload or restore. No work/review draft resume is implemented.

Prepare local backup writes JSON metadata and facts, not an archive of original source documents, and there is no import/restore action. An encrypted full backup/import is explicitly post-1.0 in the plan, so its absence alone is not a 1.0 failure. The action should be labeled an export until restore semantics exist. Generated temporary backup/report copies are not removed by Delete all data.

**Required fix:** test the existing simple store, add schema evolution fixtures and retry/resume behavior, and make recovery/export wording truthful. Avoid a framework rewrite unless measured requirements demand it.

**Evidence:** [LocalStateStore.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/LocalStateStore.swift), [DataRecoveryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/DataRecoveryView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [ReconciliationReportExporter.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/ReconciliationReportExporter.swift), [ADR](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/adr/0004-versioned-local-document-store.md).

### A13. Core interaction craft and source explanations are incomplete

**Severity:** required product-scope gaps, not cosmetic preference.

Onboarding is Welcome -> one large Form -> main app. Missing are progressive basics/period/rules steps, final confirmation and unsupported-rule flow. The editor supports one OT tier and Sunday only even though domain types can represent more.

The ledger is flat, not grouped by date. Its disclosure lacks the full arithmetic/work/rule-source ladder. Discrepancy detail shows the complete ledger for every finding and only gross in its Paystub fact section. The Line Gap mark is fixed decoration in the unaudited ledger header; audited comparison uses a Divider rather than a value-driven mark.

**Required fix:** complete the small number of trust-critical interactions before adding new feature categories. A custom control framework is unnecessary.

**Evidence:** [OnboardingFlowView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingFlowView.swift), [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift), [OnboardingPaywallView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingPaywallView.swift) and the canonical mockups.

### A14. Failure states sometimes communicate zero rather than unknown

**Severity:** high trust issue.

`TodayView.expectedPayText` and `PayLedgerView.expectedPayText` return `$0.00` whenever calculation is nil. The Pay ledger then shows empty-work wording. Today has a separate calculation error label; Pay does not consistently expose the reason. A failed calculation and a legitimate empty period are different states.

**Required fix:** render Calculation unavailable / Review rules instead of zero, disable final audit/archive when results are invalid, and show actionable error details.

**Evidence:** [TodayView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/TodayView.swift), [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift).

### A15. Release presentation and accessibility remain open

**Severity:** release gates, with several confirmed missing destinations.

Settings has a disclaimer but not the specified versioned About page, Terms, privacy-policy and acknowledgement destinations. The pinned app resources list has only a string catalog and privacy manifest; no AppIcon asset was found in the tree. The paywall uses fixed USD fallback prices when StoreKit metadata is missing, rather than a clean unavailable-price state.

Dynamic Type styles, light/dark tokens and accessibility identifiers exist, but there is no evidence of completed screen-by-screen large-text, VoiceOver, contrast, Reduce Motion or field-use verification. Onboarding has an unconditional animation and a non-scrolling welcome composition; these need targeted testing rather than a claim of visual perfection. Report rendering in dark appearance and with long content also needs inspection.

**Evidence:** [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [OnboardingPaywallView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingPaywallView.swift), [OnboardingWelcomeView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingWelcomeView.swift), [OnboardingFlowView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingFlowView.swift), [DesignTokens.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/DesignTokens.swift), [ReconciliationReportExporter.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/ReconciliationReportExporter.swift).

## 4. All 46 planned screens/states

**All rows are unverified at app-runtime/visual level for this revision.** Source present means the basic view and entry point exist, not that its underlying data is correct or that the screen passes the release gate. Partial means an implementation exists but misses required behavior. Missing means the specified behavior is not found in the reviewed routes/models. Build-blocked highlights the direct compiler failure.

| ID | Planned screen/state | Source assessment | Gap or qualification | Source |
|---:|---|---|---|---|
| 1 | Welcome | Source present | Promise, privacy, setup action exist. Fixed-height/non-scrolling composition needs small-device and largest-text validation. | [OnboardingWelcomeView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingWelcomeView.swift) |
| 2 | Pay basics | Partial | Fields exist inside a single long setup form, not the specified progressive step. | [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift) |
| 3 | Pay period setup | Partial | Cadence/date inputs exist. No progressive preview/confirmation flow; current-period correction is absent. | [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 4 | Optional rules | Partial | Only one daily OT threshold and a Sunday premium are editable; no general weekday-premium editor, unsupported-rule route, or advanced disclosure sequence. | [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 5 | Confirm pay rules | Missing | Save commits immediately; there is no final plain-English review with Use these rules. | [OnboardingFlowView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingFlowView.swift), [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift) |
| 6 | Unsupported rule explanation | Missing | No I do not see my rule route, recorded unsupported-rule state, or incomplete-estimate warning. | [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [AppState.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppState.swift) |
| 7 | Today: empty current period | Source present | Empty work list and Add work exist. Visual and interaction verification remain outstanding. | [TodayView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/TodayView.swift) |
| 8 | Today: active period | Partial | Summary, work list, edit, delete, and repeat exist. Calculation failure is rendered with a $0.00 fallback; no verified field-use timing. | [TodayView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/TodayView.swift) |
| 9 | Add work | Partial | Time, kind, exact break span, note, and save exist. No durable draft; payroll timezone can disagree with the active period after profile edits. | [AddWorkView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AddWorkView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 10 | Repeat last shift / quick draft | Partial | Uses the full work form, not the compact quick draft. Last entry lookup only searches the active period; reuse disappears at rollover. | [AddWorkView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AddWorkView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 11 | Edit work | Partial | Editing exists, but drafts are volatile and the editor uses profile rather than frozen period timezone. | [AddWorkView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AddWorkView.swift) |
| 12 | Work validation error | Partial | Errors display after Save. No identified conflicting entry, View conflicting entry action, or full actionable domain-error mapping. | [AddWorkView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AddWorkView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 13 | Delete + Undo | Partial | Undo exists, but the removed entry is not tied to its original period; restoring after rollover lacks a period-containment guard. | [TodayView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/TodayView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 14 | Pay: no work | Partial | Empty ledger exists. Audit action is still offered on an empty period; calculation failure also falls back to zero/empty wording. | [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift) |
| 15 | Pay: expected ledger | Partial | Flat component list rather than date-grouped ledger. No per-component rate/source drill-down; gross/allowance comparability is unresolved. | [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift) |
| 16 | Why this amount? | Partial | Disclosure shows date, hours, multiplier and a reason string, not the complete work facts, arithmetic, applied rule and source ladder. | [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift) |
| 17 | Rule source detail | Partial | Agreement source text exists in audit details, but there is no focused per-rule view, confirmation timestamp path, or working Open source link control. | [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift), [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift) |
| 18 | Paycheck source chooser | Source present | Scan when supported, photo, file, and manual entry are offered. Runtime behavior is not verified. | [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift) |
| 19 | System document scanner handoff | Build-blocked | Delegate conformance fails Swift 6 compilation at DocumentScannerView.swift:29:40. | [DocumentScannerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/DocumentScannerView.swift) |
| 20 | OCR review | Partial | Editable confirmation form exists. No field-level confidence/Ready/Check model; dates and hours are not extracted. | [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift), [PaystubOCRService.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubOCRService.swift) |
| 21 | OCR field/source detail | Missing | No field-to-page/rectangle provenance, crop display, or per-field correction view. | [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift), [PaystubOCRService.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubOCRService.swift), [AppState.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppState.swift) |
| 22 | Manual paystub entry | Source present | First-class entry route and confirmation fields exist. Full-string/locale-safe amount validation needs repair. | [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 23 | Incomplete evidence / needs confirmation | Missing | No explicit limited-audit confirmation state; missing optional fields do not qualify the final verdict. | [PaystubImportView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PaystubImportView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 24 | Audit: Matches | Partial | Rendered from gross equality even when entered component amounts disagree; comparison scope is not distinguished. | [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 25 | Audit: Possible shortfall | Partial | Verdict and amount exist; gross comparability, mapping semantics, and prioritized explainable causes are incomplete. | [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 26 | Audit: Possible overpayment | Partial | Verdict exists, but shares the gross-only and mapping limitations. No contextual Review rules action on the verdict. | [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift) |
| 27 | Audit: Needs review | Partial | Used when reconciliation is nil after edits, not for uncertain/unmapped source evidence. notComparable is absent. | [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [AppState.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppState.swift), [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift) |
| 28 | Discrepancy detail | Partial | Shows every calculation component and paystub gross instead of just implicated work/rules and the corresponding paystub field. | [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift) |
| 29 | Paystub evidence viewer | Partial | Whole-document Quick Look exists. No highlighted field, confirmed field overlay, or direct edit-confirmed-value action. | [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift) |
| 30 | Finish pay period | Partial | Confirmation and archive exist but no final expected/paid/difference confirmation summary. Closing unaudited periods strands later paystubs. | [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 31 | History: empty | Source present | Empty-state text exists; planned Go to current pay period shortcut is absent. | [HistoryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/HistoryView.swift) |
| 32 | History: list | Partial | Periods, expected/paid values and status exist. Difference column and month grouping are absent. | [HistoryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/HistoryView.swift) |
| 33 | Historical period detail | Partial | Frozen values exist. No late-paystub audit path; audit/report routes still use current profile timezone in two places. | [HistoryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/HistoryView.swift) |
| 34 | Post-first-audit Pro offer | Source present | A user-triggered Keep auditing with Pro offer appears after a completed audit when commerce is enabled. Real purchase flow unverified. | [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [OnboardingPaywallView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingPaywallView.swift) |
| 35 | Second-audit paywall | Partial | New-period access check exists, but ordinary Debug builds bypass commerce. Production purchase and entitlement transitions remain untested. | [PayLedgerView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayLedgerView.swift), [SubscriptionStore.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SubscriptionStore.swift) |
| 36 | Store unavailable / restore result | Partial | Unavailable/error/restore messages exist. No explicit retry button; entitlement refresh depends on successful product loading. | [SubscriptionStore.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SubscriptionStore.swift), [OnboardingPaywallView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingPaywallView.swift) |
| 37 | Settings | Source present | Core settings, rule summary, Pro, restore and data actions exist. Some planned sub-destinations are combined or absent. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift) |
| 38 | Pay profile summary | Partial | Summary is inline in Settings; no focused effective-date/future-rule summary as specified. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift) |
| 39 | Edit pay rules | Partial | Editor exists but lacks before/after review and apply-from policy; saving replaces the active period agreement. | [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 40 | Pay period settings | Missing | No Correct current dates action or period-update use case; edited Next period starts value is not persisted for an existing profile. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 41 | Rule sources | Partial | Source strings can be entered and displayed, but there is no source-management list or per-rule attachment map. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [PayProfileSetupView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/PayProfileSetupView.swift), [AuditDetailView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AuditDetailView.swift) |
| 42 | Privacy & local data | Partial | Local-data messaging and actions exist. Settings removes the current original without the explanatory confirmation used in Audit; deletion failures are swallowed. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 43 | Export data | Partial | JSON export and PDF report exist. No selective export screen, original-file package, restore/import, or report creation timestamp. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift), [ReconciliationReportExporter.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/ReconciliationReportExporter.swift) |
| 44 | Delete all data confirmation | Partial | Confirmation and deletion of primary state/evidence exist. Generated temporary exports are not cleaned and failure paths are untested. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [AppModel.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/AppModel.swift) |
| 45 | About / legal | Partial | An inline disclaimer exists, not the planned About page with version, privacy policy, Terms and acknowledgements destinations. | [SettingsView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/SettingsView.swift), [OnboardingPaywallView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/OnboardingPaywallView.swift) |
| 46 | Local data recovery | Partial | Raw state export and destructive reset exist. No Try again reload, import/restore, or support destination. | [DataRecoveryView.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/DataRecoveryView.swift), [LocalStateStore.swift](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/App/Sources/LocalStateStore.swift) |

## 5. Feature acceptance map

| Feature | Requirement | Assessment |
|---|---|---|
| F1 | First-run trust | Basic source present; largest-text and motion behavior unverified. |
| F2 | Pay-profile setup | Partial: progressive setup, final confirmation, unsupported rules and full tier/weekday editors missing. |
| F3 | Pay-period model | Partial: basic cadence exists; correction and delayed-paycheck lifecycle unresolved. |
| F4 | Work logging | Partial: CRUD/break/repeat/undo exist; context, draft recovery and stale undo gaps. |
| F5 | Expected pay | Domain foundation tested; unsafe amount parsing/comparability and user-facing coverage gaps remain. |
| F6 | Pay Ledger | Partial: no date grouping or full explanation ladder. |
| F7 | Rule detail/evidence | Partial: broad source strings, not field/component-specific provenance. |
| F8 | Paystub acquisition | Source present across four routes; scanner compile-blocked; real-device verification missing. |
| F9 | OCR review | Partial: no confidence/source crop/date-hour extraction or durable intake state. |
| F10 | Reconciliation | Partial: gross-only verdict and naive component buckets; hours and scope not reconciled. |
| F11 | Line Gap visualization | Not implemented as specified: fixed mark, no match/difference-dependent comparison. |
| F12 | Local persistence | Accepted JSON adapter implemented; upgrade, fault, semantic-validation and recovery gates incomplete. |
| F13 | History | Partial: frozen values exist; late audits and timezone-correct exports incomplete. |
| F14 | Archive/close | Partial: explicit confirmation exists; final summary and pending-paycheck lifecycle inadequate. |
| F15 | StoreKit/Pro | Partial: adapter and gated entry exist; real commerce lifecycle and local config missing verification. |
| F16 | Export/share (P1) | PDF and JSON source present; selective export/metadata and presentation incomplete. CSV is not mandatory if PDF fulfills scope. |
| F17 | Privacy/data | Local-first architecture present; evidence deletion semantics and temporary-file lifecycle incomplete. |
| F18 | Accessibility/field usability | Foundations present; runtime/visual/real-user acceptance not demonstrated. |
| F19 | Failure/recovery | Partial: inline errors and raw recovery export; durable drafts/retry/specific errors incomplete. |
| F20 | Sample/demo (P1) | Not found; optional validation tool, not a reason alone to block 1.0. |

## 6. Minimum regression and E2E work before sign-off

Prioritize proof of correctness, not test-count targets.

| Journey/case | Required evidence |
|---|---|
| Fresh install -> confirmed rules -> logged shift -> restart | Runtime automation; exact rate/hours/total survive |
| Work period A -> new work period B -> delayed paycheck A | A can be audited while B remains usable |
| $400 wages + $125 separate reimbursement | Correct comparable totals; no invented shortfall |
| Equal gross, offsetting regular/OT component differences | Qualified or review verdict rather than unconditional clean match |
| Full-pay versus premium-only OT statement lines | Explicit mapping; no guessing from labels alone |
| Manual `1,000.00`, trailing text, local decimal separators | Correct full parsing or clear rejection on target Swift/iOS |
| OCR current/YTD, separated columns, missing/negative amounts, >8-page PDF | Correct extraction or explicit abstention and visible scope limits |
| Edit future rate; edit timezone; export old period | Old work/history unchanged unless explicit new revision; dates stay correct |
| Delete work in A -> finish A -> Undo | No work inserted into B |
| Correct manual values after scanned evidence | Original retained unless explicitly replaced/deleted |
| Evidence deletion/save failure; corrupt and prior-schema state | Previous data preserved, honest error, retry/recovery paths |
| Kill app during work edit and OCR confirmation | Draft and source recover or user is explicitly warned before loss |
| Purchase, cancel, restore, renew, expire, grace, revoke, offline start | Real StoreKit tests with commerce enabled; no dependency on product fetch for local entitlement |
| Small iPhone + largest text + VoiceOver + dark/light | Actual screen captures and interaction evidence for the 46-state matrix |

Only one checked-in Maestro flow was found in `.maestro/flows`: `onboarding-smoke.yaml`. That is not a full payday regression suite. The app test file has useful orchestration and same-schema persistence tests; the subscription test file checks the disabled-commerce path. Expand the critical journeys instead of adding unrelated test infrastructure.

## 7. Recommended work order and stop conditions

**First: restore a trustworthy executable.** Repair the compiler issue, run app tests, then fix amount parsing, comparison scope/gross categories, rule/date/timezone handling and evidence preservation with regressions. Do not bypass warnings or relabel failing tests.

**Second: finish the actual recurring workflow.** Model a prior period awaiting its paycheck, correct current dates safely, preserve drafts, and implement progressive setup, confirmation, unsupported-rule handling and focused OCR/rule evidence views. Update plan checkboxes only when the behavior and its evidence exist.

**Third: verify and finish craft.** Add the narrow E2E suite, exercise StoreKit, inspect every required screen in light/dark/large text and VoiceOver, supply app assets and policy destinations, and test real payday flows with consenting target users. No employer integration, accounts, backend, widgets, Android, tax forecasts or AI chat is needed for these fixes.

**Release stop condition:** any known silent monetary miscomparison, evidence loss, inability to process the next payday, compiler failure, or missing required recovery/confirmation behavior blocks public 1.0.

**Release acceptance:** the same candidate commit passes domain, app, StoreKit and critical UI journeys; all required screen behaviors are accounted for; current/past periods remain correct across relaunch, rate/timezone edits and failures; and actual users can complete the repeated payday loop without help. Optional P1/post-1.0 features do not need to be promoted to satisfy this gate.

## 8. Scope exclusions and confidence

The absence of Android, Apple Watch, widgets, iCloud sync, employer integration, net-tax forecasting or a central backend is intentional and is **not** counted as incompleteness. Full encrypted backup/import is listed post-1.0. JSON versus SwiftData is an accepted architecture decision, not an automatic defect.

Confidence is **high** that this revision is incomplete and not release-ready: a recorded compile failure and multiple source-level required-feature gaps are conclusive. Confidence in specific UX appearance/timing is intentionally withheld: no rendered-screen test ran here. Financial/data issues have concrete source traces; except the isolated parsing checks, their end-to-end UI reproductions still need a working iOS build.

## References

Repository requirements: [AGENTS](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/AGENTS.md), [DESIGN](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/DESIGN.md), [plan](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/plan/ios-1.0.md), [mockups](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/plan/mockups.md), [pricing](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/pricing.md), [persistence ADR](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/docs/adr/0004-versioned-local-document-store.md).

Repository tests: [AppModelTests](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/AppTests/Sources/AppModelTests.swift), [SubscriptionStoreTests](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/apps/ios/AppTests/Sources/SubscriptionStoreTests.swift), [Maestro smoke](https://github.com/streamentry/linepay/blob/fb913f3ed65a47006fb88a20005b11e6cf189505/.maestro/flows/onboarding-smoke.yaml).

Platform verification guidance (external context, not evidence that this app passed): [Apple StoreKit testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode), [Apple accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility/), [Apple larger text evaluation](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria).
