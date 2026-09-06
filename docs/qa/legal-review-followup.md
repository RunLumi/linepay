# Legal-remediation review follow-up — September 6, 2026

This continues [PR #34](https://github.com/streamentry/linepay/pull/34) and the
[earlier verification record](legal-remediation.md). It is not release approval.

## Dated changes between manual periods

Review comment `3943129714` identified that closing a manual period and then
saving a dated rule change replaced the profile baseline and removed its schedule.
A new period beginning before the promised date could consequently use the new
rate. The correction must not rewrite archived work or recalculate old audits.

Test-first commit `cd5a5e80096600f2701f50e017daa25b8088aed3` adds
`NoOpenPeriodRuleTests.swift`. Implementation commit
`38f27cff2187eb36f6b4eb48c7de1152872e1557` changes only the no-open-period branch of
`AppModel.candidateForProfile`:

- Explicit dated changes keep the previous baseline and other scheduled dates.
  Replacing a scheduled date replaces only that date.
- The fallback date and existing payroll timezone match the consent flow.
  A timezone change is rejected rather than reinterpreting the schedule.
- A prospective date cannot precede or touch the last recorded work date,
  including an overnight tail. Archived snapshots stay unchanged.
- Whole-period correction without an open period fails without saving.
  Undated next-period replacement and first setup retain their prior behavior.

Eight new test functions cover previews without saves, persistence/relaunch,
old/new-rate work, multiple scheduled dates, same-date replacement, date fallback,
backdating, timezone changes, save failure, and undated compatibility. Tests use
synthetic data. Manual end dates are inclusive in these fixtures.

## Verification limits of the isolated core run

The local environment is Swift 6.2.1 on Linux, not Xcode or an Apple SDK. Its
Observation library failed to link before any test ran. To exercise the money and
state transitions independently, an **isolated temporary test package** removed
only `import Observation`, `@Observable`, and three `@ObservationIgnored` markers
from its copied `AppModel.swift`. It retained `@MainActor`, all methods, and all
other concurrency checks. It also copied the existing `AuditDisplayStatus`
extension verbatim into a Foundation-only file because its original file imports
SwiftUI. The temporary package uses the installed 6.2 toolchain manifest.

**These adaptations are not committed to production.** The repository keeps its
Observation instrumentation, Swift 6.3/Xcode 26.6 baseline, and full native gates.
This run does not test Observation invalidation, SwiftUI, PDFKit, CoreTransferable,
StoreKit, device storage protection, or iCloud.

Against the pre-fix method, six of the new functions failed with 17 reported
assertion issues. After the narrow correction, **99 test functions in 10 suites
passed** in that isolated package, including the existing domain and open-period
scope regressions. The command used warnings-as-errors and complete strict
concurrency. The committed production AppModel blob is
`7d3bed3a6dd4f22babe8b32760de52f8f131e0ce`; the prior blob was
`ae1a63d4102bc594bd5bc2f13c89327bff0fa70f`.

This is useful red-to-green evidence for the state transition, **not a native iOS
pass or permission to merge unverified native code**.

## Real sharing acceptance, not a screenshot-only test

Review comment `3943129715` identified that tapping Share and taking a screenshot
could pass even if no activity opened. `LegalJourneyTests` now requires the system
**Save to Files** activity, enters the Files destination picker, verifies its Save
and Cancel controls, and cancels without selecting a recipient or saving to a
personal provider. Locale is fixed to English. A missing handoff fails the test.

`ReportTransferTests` invokes the actual `Transferable.exported(as:)` implementation
for PDF before and after working-file cleanup. It compares the resulting bytes,
opens the returned PDF, checks the amount and disclosures, and verifies saved
records remain unchanged. A PDF-only payload must reject a plain-text request.
The API contract is documented by [Apple](https://developer.apple.com/documentation/coretransferable/transferable/exported(as:)).

Both new suites are explicitly selected by the focused native legal workflow,
alongside the original legal regressions and UI journeys. **These Apple-framework
and interaction tests have not executed in the local Linux environment.** Syntax
parsing and portable tests do not validate SDK availability or actual selectors.
Resolve any target-SDK/compiler/interaction failure once native jobs execute;
do not replace these assertions with screenshots or expected-failure wrappers.

## Merge and closure gates

[Issue #37](https://github.com/streamentry/linepay/issues/37) tracks hosted jobs
that stopped before any execution steps. Keep the PR draft until the exact current
head passes the full native build/tests and relevant UI journeys. Review retained
logs and xcresult results; a requested rerun is not a completed test.

[LEGAL-03 / #15](https://github.com/streamentry/linepay/issues/15) and
[LEGAL-08 / #20](https://github.com/streamentry/linepay/issues/20) retain their native
acceptance criteria. Other findings needing actual storefront, device, ownership,
privacy-operation, or professional-review evidence remain open. No App Store
mutation, authenticated approval, or blanket legal clearance is created here.

## Local Mac continuation — September 6, 2026

Integration commit `b94114fcf0868ad382ab5681a458d462cd4d04b3` (tree
`0277978eff19fab33db5e8b080ae784cda5b87cc`) includes current `main`, the PR changes, and
native-discovered corrections. Environment: macOS 26.6.2, Xcode 26.6 (`17F113`), Swift 6.3.3,
XcodeGen 2.46.0.

- The first native run found that `Transferable.exported(as:)` is iOS 18.2+. The two tests now
  carry that availability boundary without raising the app's iOS 18.0 deployment target.
- A focused iOS 26.5 app run passed 30 tests in five suites: `LegalRegressionTests`,
  `LegalConsentAndReportTests`, `ReportShareSessionTests`, `NoOpenPeriodRuleTests`, and
  `ReportTransferTests`. The retained result is `/private/tmp/linepay-legal-unit-green.xcresult`.
- The actual share journey passed on an iPhone 16 Pro / iOS 18.5 simulator. It reached the system
  activity, entered Save to Files, observed Save, then dismissed the native sheet without writing.
  The retained result is `/private/tmp/linepay-share-ui-final.xcresult`.
- The three-scope largest-text journey still fails because the promised explanation is not
  discoverable after scrolling in the accessibility hierarchy. It is not skipped or weakened.
  Therefore the full native/UI acceptance gate is **not passed**, and PR #34 must remain draft and
  unmerged.
- Native execution also exposed and fixed locale-specific decimal assertions and a real symlink
  substitution gap: replacing the previewed file with a same-content symlink now revokes sharing.

GitHub jobs at prior head `15cec8849864ba9dee0a4a5bba69e114b088370a` never started. The
check-run annotations for jobs `101443879286` and `101443879071` state that recent account payments
failed or the Actions spending limit must be increased. The GitHub account owner must repair that
external condition and rerun the exact final head; repository workflow changes cannot resolve it.
