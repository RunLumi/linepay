# LinePaycheck test contract

## What this suite proves

The unit and adapter suites exercise the code currently in this repository. They do not certify that the entire iOS 1.0 plan is implemented, that an agreement is legally authoritative, or that a rendered screen is accessible. A green test run is not a product-release sign-off.

Use the production Swift 6 language mode and pinned Xcode toolchain. There is no runtime test SDK, backend, analytics dependency, global clock override, or Apple account requirement for unit tests.

```bash
python3 -m unittest discover -s scripts/tests -v
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

The full native gate runs strict formatting, privacy checks, domain tests, script tests, application/adapter tests on iOS Simulator, and a Release Simulator build. It retains:

- `.test-results/AppTests.xcresult`: test outcomes and simulator coverage.
- `.test-results/app-coverage.json` and `.txt`: per-file Xcode coverage.
- `.test-results/domain-coverage.json`: SwiftPM LLVM coverage.

CI uploads the results even on failure when any results exist, for seven days. Local reruns require a fresh `LINEPAY_TEST_RESULTS_DIR` so a previous result cannot be mistaken for the new run. Coverage is evidence about executed lines, not proof that every scenario has an assertion. Do not report a percentage without naming the target, revision, and actual generated report. There is deliberately no invented 100% threshold, nor exclusion of hard code merely to inflate a score.

## Coverage map

| Production surface | Test ownership | Scope / remaining boundary |
|---|---|---|
| DomainModels.swift | DomainContractTests; existing calculator tests | Constructors, invalid values, duplicate IDs, work/break rules, date ordering, Codable value round trips. Synthesized decoding alone does not validate external data. |
| Money.swift | MoneyTests; ExactMoneyContractTests | Exact arithmetic, currency isolation, rounding modes, zero and signed values. |
| PayCalculator.swift | Existing schedule/time/break/California fixtures; PayCalculatorInvariantTests | Thresholds, multiple tiers, DST, midnight, effective dates, schedules, premium precedence, guarantees, per diem, empty work, input order, amount/hour conservation. |
| AgreementTimeline.swift | AgreementTimelineTests; RuleScopeRegressionTests; TimelinePersistenceTests | Date-specific snapshot selection, DST, guarantee ambiguity, provenance and schema migration. |
| AuditAssessment.swift | AuditScopeRegressionTests; ReportExporterTests | Gross-only versus entered-item scope, money/hour conflicts, stale/currency states and history/PDF parity. |
| Reconciliation.swift | ReconciliationTests; ExactMoneyContractTests | Sign, match scope, rounding thresholds, currency errors, preserved inputs. |
| AppModel.swift / PayProfileDraft / PaystubConfirmationDraft | AppModelTests; AppModelContractTests; PeriodAndEvidenceTests | Input grammar, optional rules, profile reconstruction, period lifecycle, work mutations, audit access, field preservation, save-failure atomicity, source corrections, reset and history. |
| AppState.swift | StorageContractTests; PresentationValueTests; period/backup tests | Saved value semantics, identity, enums, exclusive period bounds, complete snapshot round trip. |
| LocalStateStore.swift | StorageContractTests; existing BackupTests | Missing versus corrupt state, future schemas, no silent reset, directory errors, relaunch, memory isolation. Real iOS file-protection behavior still needs device validation. |
| EvidenceStore.swift | StorageContractTests; PeriodAndEvidenceTests; BackupTests | Generated paths, unique originals, original-byte preservation, deletion/idempotency, failed replacement. |
| AppSession.swift | BackupTests; BackupValidationTests; BackupConcurrencyTests | Replace-not-merge, staged originals, state commit, rollback, cleanup warnings, unreadable-state consent, navigation lifetime, exclusion of concurrent operations, cancellation. |
| BackupArchive.swift | BackupTests; BackupValidationTests | Envelope/version/checksum/size, invalid snapshots, missing/duplicate/extraneous originals, safe filenames, preserved archive input. Checksums are not authentication. |
| BackupStateMapping.swift | BackupValidationTests; BackupTests | Physical-path remapping preserves identities, source metadata, exact historical calculations and times. |
| BackupIO.swift | BackupTests; BackupValidationTests; BackupConcurrencyTests | Actual local-file round trip, bad URL/missing source, and injected suspended/failing IO. Tests are not an iCloud upload receipt. |
| PaystubTextParser.swift | PaystubParserTests | Source text preservation, supported labels, grouped positive amounts; refuse ambiguous current/YTD columns, signed adjustments, duplicated labels and malformed amounts. No claim to parse arbitrary payroll layouts. |
| PaystubOCRService.swift | PaystubParserTests (corrupt document adapter tests) | Unit tests do not retest Apple's Vision recognition model. Real image/PDF accuracy, page limits, confidence/provenance UI and device scanning remain separate checks. |
| SubscriptionStore.swift | SubscriptionStoreTests; SubscriptionBehaviorTests | Instance-injected commerce, ownership independent of catalog failure, product filtering, every purchase outcome, restore/failure, entitlement loss, disabled mode. |
| SubscriptionOperations.swift | SubscriptionBehaviorTests | Deterministic SDK boundary and unavailable-product rejection. Apple transaction verification, update delivery, renewal/grace/refund timing need StoreKit Test and sandbox integration, not invented signed transactions. |
| LinePayFormat.swift | PresentationValueTests | Exact decimal text, sign, localized period context, break display; no global locale mutation. |
| ReconciliationReportExporter.swift | ReportExporterTests | Real PDF generation, comparison/disclaimer content and multipage ledger tail. Not pixel-perfect report or arbitrary-paragraph pagination certification. |
| ReportShareSession.swift | ReportShareSessionTests; ReportTransferTests | Preview-bound immutable bytes, option invalidation, failed preparation/cleanup, path scope, symlink substitution, exact CoreTransferable export and unsupported receiver types. Native UI/provider handoff remains separate. |
| ReportSharingView.swift | LegalConsentAndReportTests; LegalJourneyTests | Default-private options, explicit sensitive source-detail consent, preview-before-share, warning copy, cancellation and three rule scopes at largest text. PDFKit rendering and physical-provider behavior remain separate. |
| TemporaryExports.swift | ReportShareSessionTests; ReportTransferTests | UUID-scoped temporary report cleanup, idempotence, unrelated/symlink refusal and preservation of user-owned exports. Parent-directory tamper resistance and forensic erasure are not claimed. |
| AppLog.swift | Error-path tests and privacy review | Static logger categories are not a second domain; tests only log synthetic failure categories, not worker data. |
| DocumentScannerView.swift | Native compiler gate; device scanner checklist | Apple controller/delegate/camera integration is not proved by a mock UIViewController. |
| DesignTokens.swift / AuditStatusView.swift | BrandAssetTests; enum presentation tests; adaptive-layout Maestro flow | Runtime asset presence and status data are testable; contrast and assistive interaction require rendered review. |
| All SwiftUI screens and composition | Existing onboarding/adaptive-layout Maestro flows plus application intent tests | Add/Edit Work, Audit Detail, Backup Restore, Recovery, History, Main Tabs, Onboarding/Paywall, Pay Ledger, Profile Setup, Root, Settings, Start Period, Today and LinePayApp are compiled. No test pretends that constructing a View verifies taps, layout or accessibility. Missing UI journeys remain release work. |
| import-design-assets.py | scripts/tests/test_import_design_assets.py | Whole-package verification, no overwrite, atomic prevalidation, paths/symlinks, manifests/digests/size/type, dry run, repeat import. All data synthetic. |
| bootstrap-ios.sh / check-ios.sh / agent-verify.sh / install-xcodegen.sh / test-ios-maestro.sh | scripts/tests/test_command_guards.py; native CI | Hermetic fail-fast argument/tool/version guards; real success paths run in native CI or documented mobile QA, not a test that mocks a successful Xcode build. |
| agent-context.sh / agent-doctor.sh / check-agent-harness.sh | Harness CI and existing validation contract | Environment inspection and config/shell validation, not iOS unit code. |
| Android and shared/contracts | No executable implementation yet | Do not add empty Kotlin tests or claim cross-platform parity before the client exists. |

## Tests that exposed narrow production fixes

1. Manual paystub corrections now retain an existing original unless a new original successfully replaces it. Failed field validation or state save removes only newly staged evidence.
2. Undo rejects a work interval outside the currently active period rather than moving old work into a new payroll window.
3. Catalog failure no longer skips verified current-entitlement evaluation.
4. OCR text mapping is a small deterministic boundary. Ambiguous current/YTD or signed values now remain blank for manual confirmation instead of choosing the last number or losing a sign.

These fixes do not change the supported agreement policy or silently reprice historical snapshots.

## Resolved payroll contracts

The former `KnownProductGapTests` expected-failure wrappers are removed. `RuleScopeRegressionTests` verifies dated changes without repricing earlier work, explicit previewed corrections, failure atomicity, and archive/relaunch behavior. `AuditScopeRegressionTests` verifies one scoped verdict across current state, history and PDFs, including offsetting components and confirmed-hour conflicts. `AgreementTimelineTests` owns date-boundary and rule-selection calculations. `TimelinePersistenceTests` covers schema-1 migration and complete timeline/evidence backup round trips.

Do not reintroduce `withKnownIssue` around these contracts to make a build green. See [ADR 0005](adr/0005-effective-dated-rules-and-audit-scope.md) for scope and the explicit cross-boundary callout review condition.

Native CI additionally runs Maestro 2.7.0 (release ZIP digest pinned) on a standard light device, plus the two payroll regressions on a compact dark device at the largest accessibility text size. The focused legal workflow selects `LegalRegressionTests`, `LegalConsentAndReportTests`, `ReportShareSessionTests`, `NoOpenPeriodRuleTests`, `ReportTransferTests`, and `LegalJourneyTests`. Results/screenshots are retained separately from unit coverage. `.xcresult` coverage still describes the app-test run; Maestro screenshots do not magically turn its percentage into complete UI coverage. Source: [official release](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.7.0).

Other product gaps, including auditing an earlier closed period after its paycheck arrives, comparable allowance/gross basis, durable drafts, and OCR provenance UI, remain on the product readiness checklist. Physical-device and signed-commerce checks are not substituted with mocks.

## Test design rules

Use fixed synthetic work facts, independent exact-money expectations, unique temporary directories, and injected failure outcomes. Do not derive every expected answer by calling the same implementation under test. Parameterize boundary tables rather than copying similar tests. Do not sleep to synchronize tests: the backup concurrency tests use explicit continuations and cancellation.

`SubscriptionOperations` and `BackupHandling` are narrow platform seams. The production implementations remain StoreKit and the existing file coordinator/actor. Do not replace those adapters with test doubles in Release or add a framework to exercise a handful of async branches.

Money/history/backup tests should compare semantic facts and source bytes, not incidental generated UUIDs or filesystem paths. Avoid changing process-wide locale, timezone, or environment in parallel tests. PDF tests are serialized because the existing exporter uses a date-based temporary filename.

## Checks a unit test cannot substitute for

A release still requires real scanner use, two-device Files/iCloud transfer, signed StoreKit scenarios, minimum/current iOS and phone-size coverage, all required user journeys, VoiceOver and large-text review. The existing Maestro flows do not cover the entire 46-state mockup inventory. Review coverage artifacts and the 1.0 acceptance plan together; neither alone proves the product is complete.
