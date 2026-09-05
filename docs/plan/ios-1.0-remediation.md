# iOS 1.0 readiness remediation

This is the implementation and verification companion to [the original readiness audit](../linepay-1.0-readiness-audit.md). The original report is preserved, including its pinned revision and findings. This document does not retroactively change that report into a successful release review.

Branch: `fix/ios-1.0-readiness`, PR #2. Public brand: LinePaycheck. Bundle: `com.streamentry.linepay`.

## Acceptance bar

A source fix is not release acceptance. Require native compilation, domain/app/StoreKit tests, the two-period UI journey, and explicit screen review. A failing gate remains open. Do not bypass strict concurrency, waive failed monetary tests, or claim physical-device evidence from simulator runs.

## Findings mapped to repairs

| Audit | Repair implemented | Primary regression evidence |
|---|---|---|
| A01 | Coherent scanner isolation; explicit Repeat Shift binding closure; native launch dictionary to prevent legacy screen-size fallback | Native compiler gate; `LaunchConfigurationTests`; actual UI journeys |
| A02 | Evidence-aware assessment, explicit scope, hours comparison, qualified matches and unresolved mappings | `PaycheckAssessmentTests`, especially offsetting components and hours cases |
| A03 | Separate expected wages and per diem; worker-confirmed gross basis | Per-diem comparability and premium-only layout domain tests; synthetic PDF report test |
| A04 | Close work while awaiting paycheck; audit a closed period from History without replacing the next period's work | `nextWorkCanBeLoggedBeforePriorPaycheckArrives`; two-period UI journey |
| A05 | Future-only rule changes by default; explicit current-period changes; validated period correction | `futureRateDoesNotRepriceExistingWork`, invalid-current-rule and period-correction tests |
| A06 | Strict whole-string numeric parsing; current/YTD-aware conservative extraction and abstention | `StrictDecimalTests`, `OCRParserTests`, native Vision synthetic-document test |
| A07 | Persisted drafts and staged originals; source regions/field confirmation; explicit eight-page OCR limit; single-owner input loading | Draft round trip; `DocumentPipelineTests`; `PaystubImportOperationTests` |
| A08 | Frozen period/work timezone for entry, historical display and export; explicit new boundary after timezone change | Existing frozen-timezone tests; `changedTimezoneClosesOldPeriodWithoutOverlap` |
| A09 | Undo bound to period and work revision; containment validation | Stale-Undo and intervening-edit regressions |
| A10 | Retain originals on correction; append audit revisions; explicit removal and retryable physical cleanup | Correction-retains-original test; cleanup fault injection; unconfirmed-original boundary tests |
| A11 | Signed entitlement refresh independent of product loading; real local StoreKit configuration and lifecycle tests; no guessed live prices | Purchase/renewal/cancellation/restore/expiry, refund, metadata-failure and grace tests |
| A12 | Schema-2 decoding and v1 migration; reload/recovery; full backup integration; protected temporary export cleanup | Migration/corrupt-state tests; backup/restore atomicity tests |
| A13 | Progressive setup and confirmation; unsupported-rule explanation; multiple tiers/weekday rules; grouped ledger and focused evidence receipts | UI journeys and screen captures, not source presence alone |
| A14 | Unknown calculation renders Unavailable with actionable context; invalid results cannot finalize an audit | Calculation error source paths plus runtime acceptance |
| A15 | About/privacy/terms/acknowledgements; adaptive presentation and reduced-motion behavior; existing shared icon retained; launch configuration corrected | Brand/launch tests and light/dark/large-text UI evidence; physical review remains separate |

The [ADR](../adr/0006-evidence-aware-payday-records.md) supersedes the old plan's gross-total-only and single-period lifecycle assumptions. ADR 0004 remains the accepted JSON-store decision; an unchecked SwiftData item in the original planning sequence is not a direction to rewrite persistence.

## Current execution checkpoint — September 5, 2026

Live checkout began clean at `859167a1a8d5dacfb879336f6910a8e1876d0a6f`. PR #2 was open/conflicting; fetched `origin/main` was `f0449710d6a2bff2e259cfaa1cf0f5aa142d5e8f`. Integration is in progress, retaining main's backup, branding, release records, contrast and coverage work. Do not use the older checkpoint below as current acceptance.

Baseline `agent-doctor.sh`: exit 0. Baseline `agent-verify.sh ios`: exit 65; 47 domain tests passed, 55/56 app tests and 3/4 UI journeys passed on iPhone 16 Pro / iOS 18.5 (`6CB95D1F-BC8E-4C06-B8C4-606F58AA02A9`), Xcode 26.6 / Swift 6.3.3 / XcodeGen 2.46.0. The two failing tests assumed US currency display on a simulator using decimal-comma formatting. Release did not run after that failing test gate. Logs and screenshots: `.build/readiness/859167a/`.

Integrated `build-for-testing` succeeded on iOS 26.5. That runtime's StoreKitTest service rejected configuration with `SKInternalErrorDomain Code=3`, ignored dialog suppression and opened checkout. This is not passing commerce evidence. Native commerce verification will use the working iOS 18.5 runtime; current-runtime UI checks remain independent.

Integrated app run `.build/readiness/integration/app-tests-18b.xcresult`: 121 app tests passed on iOS 18.5, including native seven-day trial-to-paid, cancellation, pending approval, interrupted purchase, grace, restore and refund; static v1 migration, malformed saved values and interrupted-file recovery passed. This run preceded the final UI fixes and work-completeness requirement, so it is an intermediate checkpoint.

UI execution exposed missed rate-field focus and an inactive-parent save callback that lost pushed field edits on interruption. The controls now own focus explicitly and the field editor persists directly. The new work-completeness confirmation prevents a partial work log from producing a full-paycheck verdict. A stale simulator test-runner installation was removed after Xcode reported a deleted container; no worker data was reset. The repaired two-period and interrupted-paycheck-field UI journeys passed. Main then advanced to `2bf0d3d45123df2eb64c13156b2bd7475ac1820e` with dated rules, additional screen tests and accessible data controls; these are now integrated. The combined quick gate passed 82 domain tests and the combined native app suite passed 164 tests. Edited-work draft resumption, draft-safe period closing and final combined UI/native/Release gates remain pending on the final candidate.

## Recorded verification checkpoint

On source `3b007475cdcd987ab6d9f306ab94a13ce02cbf4f`, native workflow run `33970361677` compiled the app and executed tests on iPhone 17 Pro Simulator with Xcode 26.6 / Swift 6.3.3:

- 47 pure-domain tests passed.
- 51 of 53 app tests passed. Passing tests included native Vision current/YTD handling, page-limit disclosure, PDF pagination, monetary/data regressions, purchase/renewal/restore/expiry and refund handling.
- The backup test detected an unnecessary second save when the deletion queue was empty. Restore now avoids that no-op cleanup write; rerun required.
- The grace test reached the grace state, then used an invalid forced-expiration operation on an already expired transaction. The revised test waits for actual accelerated grace expiry and still requires loss of paid access; rerun required.
- Four UI journeys failed. Captured runtime hierarchy showed a 320-by-480 legacy window; the app had no launch-screen declaration. A native launch dictionary and regression test have been added. Full UI rerun and screenshot review are required, not waived.

This checkpoint is **not green** and does not approve release. Newer verification must record the exact source SHA from the artifact's `commit.txt`, not merely the workflow's triggering commit.

## Screen evidence

The 46-state source inventory remains in the original audit and `mockups.md`. Shared native views legitimately serve several states. `PaydayJourneyTests` covers setup, work, relaunch, delayed paycheck, audit verdicts/evidence, the second-audit paywall, draft recovery, large text/dark appearance, settings/legal and corrupt-data recovery. Its attachments are exported from `.xcresult` by `scripts/check-ios.sh`.

Do not equate these journeys with a completed manual review of all 46 states. Before release, record any remaining scanner permission/cancellation, source field/crop, deletion/Undo, backup/restore, reduced-motion, VoiceOver and smallest-supported-device checks explicitly.

## External release gates

Keep these open until actual evidence exists:

- Real-iPhone scanner, camera-denied/cancel behavior, interrupted file-provider downloads, and manual iCloud Drive backup/restore.
- App Store Connect products, localized pricing, public privacy/support URLs, sandbox/TestFlight purchase and restore on the release candidate.
- VoiceOver, largest text, sunlight/night contrast, physical-device memory/performance, and the remaining required screen states.
- Consenting lineworkers completing realistic consecutive work/pay periods and explaining discrepancies without assistance.

No account, backend, Android implementation, tax forecasting, widgets, or agreement interpretation service is needed to satisfy this remediation.
