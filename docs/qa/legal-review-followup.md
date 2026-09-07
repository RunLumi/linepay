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
that stopped before any execution steps. PR #34 was merged by the repository owner as
`19264cf0728a01bd3ee6cacda291ebeff692622b` before the later Picker/accessibility and
receipt commits landed. Those post-merge commits remain a follow-up candidate and must
still satisfy the hosted checks and retained exact-head receipts; a requested rerun is
not a completed test.

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

## Final candidate refresh — September 6, 2026

The current production/test candidate is commit `28ee8ee` (tree
`738fb3a8153cfe691aa46c8a2f4a79137f09af7f`), based on merged `main`
`19264cf0728a01bd3ee6cacda291ebeff692622b`. It adds stable accessibility identifiers to every
scope option and makes the XXXL scope journey assert each step before selecting the option. The
bounded final press retry is only for a simulator event that can be dropped at the largest text
size; the assertion still requires the editor to reach the review screen.

The exact current-source receipts were run with Xcode 26.6 (`17F113`), Swift 6.3.3, on the existing
iPhone 16 Pro / iOS 18.5 simulator (`A80C669E-2B6A-4380-B39A-5FA5CA7C193D`):

- `/Volumes/SSD/linepay-pr34-evidence/followup-legal-28ee8ee.xcresult`: 30 focused legal tests in five suites passed at commit `28ee8ee` / tree `738fb3a…`.
- `/Volumes/SSD/linepay-pr34-evidence/followup-share-28ee8ee.xcresult`: the Save-to-Files activity journey passed at commit `28ee8ee` / tree `738fb3a…`.
- `/Volumes/SSD/linepay-pr34-evidence/followup-scope-28ee8ee.xcresult`: all three rule-scope edits passed at XXXL text at production/test tree `738fb3a…`.

The earlier `current-head-*` receipts remain historical evidence for their recorded executable
tree, not proof of this final candidate. The three current receipts were separate bounded
invocations; the combined hosted workflow remains the authoritative rerun once Issue #37’s
external GitHub billing/spending-limit condition is repaired. That hosted condition cannot be
resolved by repository changes, so PR #57 must not be merged until its required checks execute and
pass on the exact final head.

## Integrated current-main candidate — September 7, 2026

After PRs #58, #59 and #66 advanced `origin/main` to `dcd23bc6f9121cad29b43cd42a3b8e78e45ccf0e`,
the follow-up branch was merged with that current main in integration commit `6bb14e5c54f5b50ed86fa935828174b522b15476`
(tree `d4e7477fbe2a0d25935a048e0fe3eb181d844b03`). The merge was conflict-free and the previous
PR #57 head is protected by backup ref `backup/pr57-before-main-sync-20260906`.

The full native gate was rerun on the integrated candidate with Xcode 26.6 (`17F113`), Swift 6.3.3,
macOS 26.6.2, and the existing iPhone 16 Pro / iOS 18.5 simulator
(`A80C669E-2B6A-4380-B39A-5FA5CA7C193D`). `bash scripts/agent-verify.sh ios` passed 212 tests,
with 0 failures, 0 skips and 0 expected failures; the retained result is
`/Volumes/SSD/linepay-pr34-evidence/integrated-ios-6bb/AppTests.xcresult`. The app coverage report
was 85.30% (13,625 / 15,973 lines). The pure-domain portion passed 104 tests, including the merged
weekly regular-rate and product-correctness suites.

The critical UI journeys were then run as separate bounded invocations at the same integrated tree:

- `/Volumes/SSD/linepay-pr34-evidence/integrated-share-6bb14e5.xcresult`: Save-to-Files appeared,
  Save was observed, and the native sheet was dismissed without writing.
- `/Volumes/SSD/linepay-pr34-evidence/integrated-scope-6bb14e5.xcresult`: all three scope effects
  passed at XXXL text, including `$550.00`, `$550.00`, and `$660.00` outcomes.

The legal register and this receipt are documentation-only changes after the executable integration
commit; they do not change the tested app/source tree. Hosted branch-protection checks still need to
execute on the pushed final head before merge. Physical VoiceOver, two-device/provider behavior,
storefront transactions, publisher identity, trademark, ownership, counsel and operational-support
acceptance remain separate external obligations.

## Latest integrated candidate — September 7, 2026

`origin/main` subsequently advanced with merged PR #68 (`d05428e34103088dd85179ad39c74b904df10061`),
which adds explicit DST review to Repeat Shift. The follow-up branch integrated it in merge commit
`2e45223b7a241b23e523ba7606a290d209948228` and then fixed only the formatter and Swift Testing
compile violations exposed by the pinned Xcode 26.6 gate in commit
`cd68adb9cb5aebb5c0987418bcfd262200ce526c` (tree `aa19b228da10a5c9d329bc3fd6ca338801a5ec3c`).

The corrected full native gate passed on the existing iPhone 16 Pro / iOS 18.5 simulator with
Xcode 26.6 (`17F113`) and Swift 6.3.3: 221 total tests, 314 configured device executions, 0
failures, 0 skips and 0 expected failures. App coverage was 83.21% (14,665 / 17,625 lines). The
retained exact-current result is `/Volumes/SSD/linepay-pr34-evidence/integrated-ios-d054-final/AppTests.xcresult`.
The isolated StoreKit lifecycle retry also passed all seven tests at
`/Volumes/SSD/linepay-pr34-evidence/storekit-suite-retry.xcresult` after one transient full-suite
notice race.

The earlier integrated Save-to-Files and XXXL scope receipts were run against the same app source
before the formatter/test-only correction and remain valid for those unchanged flows; the full
gate reran both UI journeys successfully after the correction. The latest branch is not yet pushed
after these commits. Hosted branch-protection checks remain the merge gate and Issue #37 remains
open while GitHub rejects job startup for account billing/spending-limit reasons.

## Final exact candidate — September 7, 2026

The final executable source/test candidate is `edda6f9` (tree
`68189cf218c301d0ba69e972bbd05493fd10ebac`), with documentation/source-map follow-up at
`612b7b3` (tree `d63dd1c8aea634ddb47ac5c3b0e39da962c63b94`). It includes the stable in-app User
Guide link, targeted public-help corrections for rule changes and report sharing, the Repeat Shift
formatter/Swift Testing fixes, and the integrated current-main payroll/report/DST changes.

The exact final native receipt is `/Volumes/SSD/linepay-pr34-evidence/integrated-ios-final-candidate/AppTests.xcresult`:
221 tests passed, 0 failed, 0 skipped, 0 expected failures, on the iPhone 16 Pro / iOS 18.5
simulator with Xcode 26.6 / Swift 6.3.3. The focused large-text User Guide entry journey passed at
`/Volumes/SSD/linepay-pr34-evidence/guide-link2.xcresult`. The public-guide static gate could not
run because Hugo 0.165.0 is not installed on this Mac; no guide build pass is claimed.

This receipt proves current local native execution only. The hosted required checks remain the merge
gate, and external legal, storefront, physical-device, VoiceOver, support-operations, ownership,
trademark and counsel obligations remain open under the issue ledger.

## Current-main exact candidate — September 7, 2026

`origin/main` later advanced through PRs #69 and #72 (plus the already integrated #41 callout work)
to `92e5bfb738a2816e6ec63b59643e9fd98e601d0c`. The follow-up branch integrated that main and the
final callout test ordering fix in candidate `7ca4820461e89d3f74c68ed3f67f5c05db882b9a`, tree
`1738ec551cb2dbf39a190553c5714484fdd5b0c0`.

The exact native gate at that candidate passed on macOS 26.6.2, Xcode 26.6 (`17F113`), Swift 6.3.3,
and iPhone 16 Pro / iOS 18.5 (`A80C669E-2B6A-4380-B39A-5FA5CA7C193D`): 229 tests passed, 0
failures, 0 skips and 0 expected failures across 322 configured device executions. The retained
result is `/Volumes/SSD/linepay-pr34-evidence/integrated-ios-final-current-main/AppTests.xcresult`.
The pure-domain portion passed 105 tests. The targeted callout-event suite passed 7 tests at
`/Volumes/SSD/linepay-pr34-evidence/callout-fixed.xcresult`; the large-text User Guide entry passed
at `/Volumes/SSD/linepay-pr34-evidence/guide-link2.xcresult`.

This exact local evidence does not satisfy hosted branch protection or physical-device/provider
acceptance. The final required GitHub jobs still need to start and pass; Issue #37 remains open for
the account-owner billing/spending-limit repair. Hugo 0.165.0 was unavailable, so the public-guide
static check remains unrun and is not claimed as passed.
