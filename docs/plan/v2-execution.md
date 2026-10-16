# V2 implementation and release checkpoint

[Plan index](README.md) · [Source roadmap](v2.md) · [Release procedure](../release/api-and-testflight.md)

## Authority and acceptance

On October 16, 2026 (Asia/Ho_Chi_Minh), the owner requested completion of the entire
roadmap, explicitly including its gated platform work, followed by App Store submission
and manual public release after Apple approval. This supersedes the roadmap's demand-based
sequence, not payroll correctness, local-first defaults, confirmation, privacy or release evidence.
No new analytics provider, cloud processor, named agreement rights or compliance declaration
has been selected or professionally verified by this authorization.

Completion means working vertical slices, relevant regression/native/browser evidence,
a reproducible release binary, submission readback, and public storefront readback after approval.
An implementation, test result, upload, review submission and public release are separate states.

## Work and evidence ledger

| Workstream | State | Acceptance still required |
|---|---|---|
| Foundation: funnel measurement | Implemented; full native gate passed | Final release-candidate/device checks; no production cohort/completeness claim |
| Website/store consistency | Readback and tested local correction complete; publication approval pending | Approved push/PR/deploy, then public readback |
| First-value onboarding | Existing, needs assessment | Minimal confirmed rules → work → credible expected pay |
| Paycycles and period matching | Implemented; focused native tests passed | Weekly, biweekly, semi-monthly, custom; timezone boundaries; mismatch guard |
| OCR reliability | Implemented and locally verified | Broader employer-layout/independent precision evaluation; final release gate |
| Resolution workflow | Implemented; native/UI/storage/privacy checks passed | Saved finding/status/notes/history and shareable evidence packet |
| Accessibility | Pending | VoiceOver, large text, contrast/motion and critical native journeys |
| Free web calculators | Existing public calculator; 7 arithmetic tests passed | Exact arithmetic, stated assumptions, browser flow and app CTA |
| Agreement extraction | Implemented; 282 app tests and focused native journeys passed | Broader independent document corpus, actual Files-provider transfer and final release gates |
| Benefits audit | Implemented; complete native iOS gate passed | Final release-candidate/device checks after remaining v2 work |
| Verified rule sources | Pending | Rights, version/effective dates, scope, freshness and no silent history mutation |
| Voice logging | Implemented; full native iOS gate passed | Actual physical microphone/offline recognition, accessibility/device checks and v2 privacy review pending |
| Referrals | Pending | Content-free attribution with explicit data-flow/commerce boundaries |
| Encrypted sync/account | Accounts/sync superseded; encrypted manual native workflow implemented | Full native gate running; two-device/provider checks and Android/PWA state adoption pending |
| Full PWA | Pending | Actual workflows, offline/storage/restore safety and browser verification |
| Agreement library | Pending | Source rights, review/moderation and immutable versions |
| Android | Pending | Native app plus shared deterministic fixture parity and runtime evidence |
| Localization | Pending | Spanish terminology/context QA, all primary states |
| Crew templates | Pending | Explicit template export/import without personal pay records |
| App Store release | Pending | Full native/release gates, signed binary/hash, receipt, MANUAL review/public readbacks |

## Initial verified state

- Entry: `3205dab`; owner concurrently committed the provided roadmap as `d6d7db3`.
  No unrelated work was overwritten.
- October AI-practice review already recorded on October 4; no duplicate monthly review needed.
- Agent doctor: root guidance exceeds its 12,000-byte budget. Moving detailed guidance to
  its canonical engineering document, preserving the contract and attribution.
- 74 repository Python tests passed in the initial quick check. SwiftPM was blocked by
  sandbox access to compiler caches; rerunning with approved access. No domain PASS yet.
- Xcode 27.0 / Swift 6.4; repository compiler baseline remains Xcode 26.6 / Swift 6.3.
- Existing compatible device selected for the batch:
  `2E105F49-8763-4777-B5FD-03DE29EB17CD`, iOS 26.5, initially shut down.
  No concurrent xcodebuild/Maestro process observed. No device/runtime was created.
- Maestro and XcodeBuildMCP are absent from PATH. XCTest journeys remain available;
  missing Maestro is not a passing Maestro result.
- Disk readback: system volume 36 GiB available; SSD 565 GiB available.

## Resume protocol

Re-read this ledger, inspect checkout/diff and active processes, and verify evidence against
the actual source before continuing. Keep all incomplete rows visible. Do not mark the goal
complete from a subset of the roadmap or from a submitted-but-unapproved build.

## Foundation checkpoint, October 16

- Harness size/routing checks now pass with unchanged authority and attribution.
- Baseline quick verification passed: 74 repository tests and 109 domain tests.
- Focused native run: `xcodebuild test` with `PayPeriodScheduleTests` and
  `PaycheckResolutionTests`, iOS 26.5 / selected UDID above: **13 tests passed in 2 suites**.
  Bundle: `.build/v2-focused-20261016.xcresult`; log: `/private/tmp/linepay-v2-focused.log`.
- Follow-up UI journeys (normal and accessibility XXXL) are running separately;
  bundle `.build/v2-follow-up-ui-20261016.xcresult`. Do not claim them passed yet.
- Full native gate was interrupted after Apple's StoreKit test service failed saving its
  configuration (`SKInternalErrorDomain Code=3`) and stalled. App suites before commerce
  executed, but the gate is **not PASS**. Its result/log remain under
  `.build/v2-native-20261016/` and `/private/tmp/linepay-v2-native.log`.
  The error matches [Apple forum thread 826971](https://developer.apple.com/forums/thread/826971),
  which includes Apple DTS acknowledgement of the CLI/runtime defect. Similarity is diagnostic
  evidence, not proof that this checkout has no commerce regression. Do not skip the release gate.
- Active-copy/inventory check passed. Local docs: 967 links, 0 errors; 5 docs-tool tests passed.
  Re-run freshness after further mapped UI edits. The user-guide build is blocked because the
  pinned Hugo 0.165.0 executable is absent; no Hugo PASS is claimed.
- Live website inspection found the public calculator and current monthly/annual pricing at
  `https://linepaycheck.com` and `/lineman-pay-calculator`. Therefore the roadmap's “missing
  calculator” claim is stale outside this app repository. Browser interaction remains unverified.
- The supplied roadmap's 40 ST + 20 OT at 1.5 × $58.40 example was arithmetically wrong:
  independent result is $2,336 + $1,752 = **$4,088 wages**, plus $980 allowance = $5,068.
  Corrected the quoted wages in `v2.md`.
- Removed the task-created duplicate browser calculator after finding the canonical website
  checkout at `/Volumes/SSD/linepaycheck.com`. Reuse its existing arithmetic/tests and public
  acquisition surface. A full personal-record PWA remains separate, pending implementation.
- Awaiting optional owner choice for cloud/account/analytics data flow; continue independent
  local features. No provider, telemetry transport, account or cloud upload has been added.

- Follow-up UI: both initial XCTest journeys passed (normal and accessibility XXXL), including
  actual save/relaunch and unchanged possible-shortfall result. Attachments exported to
  `.build/v2-follow-up-ui-attachments/`. An additional existing keyboard-dismiss modifier was
  then added; running both journeys again with all non-StoreKit app tests and two new storage
  regressions in `.build/v2-foundation-native-20261016.xcresult`.
- `agent-doctor.sh` now passes, with only optional Maestro/XcodeBuildMCP warnings.
- Canonical website calculator: `node --test /Volumes/SSD/linepaycheck.com/tests/pay-calculator.test.mjs`
  passed **7 tests**. Website checkout is clean on main; no website source/deployment was changed.

- Additional non-StoreKit native batch: **248 tests in 36 suites passed**; normal follow-up UI
  passed after the keyboard control addition. The largest-text runner unexpectedly exited and
  xcodebuild stalled finalizing its bundle; this aggregate run is **incomplete, not PASS**.
  Log: `/private/tmp/linepay-v2-foundation-native.log`. The initial isolated UI run remains a
  valid receipt for its earlier source, not the newer edits.
- Review found and fixed an exact-revision bug before handoff: follow-up from a historical
  audit must bind to the selected paycheck ID, not the latest paycheck for that period.
  Historical PDF contexts now carry only that revision's follow-ups; unknown IDs fail closed.
  Added a regression. Also added explicit keyboard focus dismissal after successful save.
  These latest edits still need native verification.

- Latest focused run after the revision-binding/privacy changes: **16 tests passed in 2 suites**;
  `.build/v2-revision-binding-20261016.xcresult`, `/private/tmp/linepay-v2-revision-binding.log`.
  Current isolated UI recheck uses explicit 360-second default / 720-second maximum test limits:
  `.build/v2-follow-up-current-ui-20261016.xcresult`; log `/private/tmp/linepay-v2-follow-up-current-ui.log`.
- Working branch is `codex/v2-e2e`; no commit, push, PR, upload or submission yet.

- Runtime availability refreshed after CoreSimulator initialized: the existing iOS 18.5 runtime
  and `LinePay Release iPhone 18` (`7DE1B778-AB9B-478B-9E1A-027E1106814A`) are now available.
  Use this existing device in a separate StoreKit batch after the current UI job; no runtime
  install or device creation is necessary. Keep jobs serial and shut down this task's idle device
  when changing batches to limit host pressure.

- Current isolated UI rerun: normal and accessibility XXXL follow-up save/relaunch journeys
  both passed (2 tests, 0 failures). Log reports 214.252 seconds for the pair.
  The subsequent copy-only change labels other audit versions “Different paycheck revision”;
  no calculation, persistence or interaction semantics changed.

- StoreKit fallback batch started on the existing iOS 18.5 device above, after shutting down
  this task's idle iOS 26.5 device. Serial command selects only `StoreKitLifecycleTests`, with
  explicit timeouts. Log: `/private/tmp/linepay-v2-storekit-ios18.log`; bundle:
  `.build/v2-storekit-ios18-20261016.xcresult`. Outcome still pending.

## Recoverable source checkpoint

- Committed Foundation code and documentation as `2e2cac65c856f337fd869adc1357139575551e8e`
  on `codex/v2-e2e`. Working tree was clean after the commit. No push, PR or release yet.
- StoreKit fallback **passed**: all 7 lifecycle tests on existing iOS 18.5, completed result bundle
  `.build/v2-storekit-ios18-20261016.xcresult`, `TEST SUCCEEDED` in
  `/private/tmp/linepay-v2-storekit-ios18.log`. Purchase/renewal/cancellation/expiration,
  refund, billing grace, annual trial, native cancellation, pending approval and interrupted
  purchase are covered by those tests. This is local StoreKit Test evidence, not TestFlight or
  production storefront purchase proof.
- Release-configuration generic Simulator build started against this checkpoint. Log:
  `/private/tmp/linepay-v2-release-build.log`; shared derived data `.build/v2-derived`.
- Next implementation work: evaluate/finish OCR confidence and source UX using the existing
  multi-page parser, then local funnel measurement/activation and agreement/benefits slices.
  Keep all remaining roadmap rows pending until each actual vertical slice is verified.

- Release generic Simulator build **passed** (`BUILD SUCCEEDED`) at source checkpoint `2e2cac6`;
  `/private/tmp/linepay-v2-release-build.log`. This is unsigned Release compilation, not an
  archive/upload/TestFlight/public release receipt.
- Final follow-up screenshots were exported to `.build/v2-follow-up-current-attachments/`
  and visually inspected: normal and accessibility XXXL show the saved note without the keyboard
  obscuring history. No dark-mode or VoiceOver certification is claimed from these two images.
- Resolving the missing Hugo tool through the official pinned release, verified SHA-256,
  workspace-local package extraction only. No system installation or user-wide tool change.

- Documentation build prerequisite resolved: official Hugo 0.165.0 macOS package SHA-256
  `10ea75335975a13d0e73ac298402179335c55fa4e99d1687452d9cfa70b30d16` verified against the
  official GitHub release asset digest; extracted under `.build/tools/hugo-0.165.0/`.
  `PATH="$PWD/.build/tools/hugo-0.165.0/Payload:$PATH" bash user-guide/scripts/check.sh`
  **passed**: root and `/linepay/` builds, internal links/assets, deterministic search,
  source freshness and 4 screenshot provenance records. Log `/private/tmp/linepay-v2-guide-current.log`.
- All current command sessions completed. The source checkpoint remains local; remaining roadmap
  implementation, complete final native/UI gates, signed archive, Apple submission and manual
  release remain outstanding. Goal stays active. The cloud/account/analytics preference question
  is still unanswered; no network data flow has been introduced.

## OCR confidence/source slice (after `5f0c3b8`)

- Added `OCRFieldProvenanceView`: original OCR reading, one-based source page, recognition
  confidence and explicit non-verification wording. Main gross review and optional-field review
  show it; a disclosure exposes date provenance. Confirmation requirements are unchanged.
- Low-confidence dates now carry an explicit warning, matching the existing numeric warning.
- The first selected test run exercised only 5 existing parser tests because app test sources are
  an explicit XcodeGen group. Regenerated the disposable project without changing Package.resolved;
  the actual corpus was then discovered: **10 tests in 2 suites passed**, including 27 positive
  text cases and 7 ambiguous-row cases. Bundle `.build/v2-ocr-corpus-current-20261016.xcresult`.
- Added 8 strict PDF/Vision cases: four independently specified literal gross amounts, each on a
  one-page and two-page PDF. All 8 passed in the currently running native batch; remaining
  document/UI checks are not yet reported complete. Log `/private/tmp/linepay-v2-ocr-native.log`,
  bundle `.build/v2-ocr-native-20261016.xcresult`; active exec session was `44735`.
- Wrote [OCR evaluation scope](../testing/ocr-evaluation.md). No 98% real-world precision or
  independent-holdout claim is made. The UI confidence fixture is explicitly synthetic.
- Swift lint, legal active-copy/inventory and the Hugo guide checks passed for this slice.
  User guide now explains recognition confidence separately from confirmation and correctness.

- Rendered PDF batch: **14 tests in 3 app suites passed**, including all 8 strict PDF/Vision
  cases and the original page-limit/report checks. Its UI assertion initially failed because
  the test queried the percentage as a standalone accessibility text; the combined row's
  stable identifier now exposes and tests the actual 72% label.
- A second UI attempt passed the score check but failed its literal source-section header query.
  Strengthened the check to require the evidence navigation screen, a loaded original field crop,
  and the complete-original action, while scrolling the source link clear of the pinned audit
  action. The resulting isolated UI test **passed** in 24.146 seconds; bundle
  `.build/v2-ocr-source-ui-20261016.xcresult`.
- Visual review confirmed the loaded original crop and an uppercase system section header.
  It also showed the confidence row at the screen's bottom edge, so the screenshot test now
  scrolls the full score row above the pinned action. Removed a duplicate OCR warning and
  supplied the recognized source excerpt to the main original-view route.
- Current final check runs the source journey at both normal and accessibility XXXL text,
  plus the receipt corpus: `.build/v2-ocr-final-ui-20261016.xcresult`, log
  `/private/tmp/linepay-v2-ocr-final-ui.log`, exec session `11367`. Do not claim it passed yet.
- Failed-run logs and artifacts remain available. One failed Xcode driver stalled in result
  finalization after its test host exited; it was explicitly terminated before rerunning.
  A post-test simctl screenshot timed out without an active surface; the actual XCTest PNG
  attachments were used for visual inspection. A separate AVFoundation video-frame helper
  could not decode the failed-run recording; no app code or source artifact depended on it.

- Final normal + accessibility XXXL OCR journeys both **passed**, including the percentage row,
  a real loaded source crop, recognized source text, and an unconfirmed comparison remaining
  disabled. Bundle `.build/v2-ocr-final-ui-20261016.xcresult`; log
  `/private/tmp/linepay-v2-ocr-final-ui.log` (46.856s / 23.722s for the UI cases).
- Review found a draft-validation gap: confirmed audits checked OCR regions/confidence, but
  saved drafts did not. Shared the existing checks with drafts, added rejection regressions for
  invalid page IDs and nonfinite/out-of-range confidence, and guarded the display's page increment.
  Invalid draft save must leave prior state unchanged. Native check is running in
  `.build/v2-ocr-validation-20261016.xcresult`, log `/private/tmp/linepay-v2-ocr-validation.log`,
  exec session `52753`.

- Draft-validation batch **passed**: 18 tests in 3 suites (OCR corpus, backup validation,
  document pipeline), including invalid page IDs/confidence and unchanged prior state after
  rejected draft saves. `TEST SUCCEEDED` in `/private/tmp/linepay-v2-ocr-validation.log`.
- Final normal/largest-text screenshots were exported under
  `.build/v2-ocr-final-ui-attachments/` and inspected. Both show the actual 72% row above the
  pinned action; the source screenshot shows the retained PDF crop and recognized-text excerpt.
- Lint, all 74 script tests, 5 docs-tool tests, legal active-copy/inventory, local links and guide
  builds passed. Current OCR Release build is running in the active xcodebuild process (check its
  log/handle on resume); log `/private/tmp/linepay-v2-ocr-release.log`.
- Next: complete local agreement PDF → cited candidate rules → explicit review/apply, with
  effective-date/conflict/unsupported handling and immutable source retention. Keep calculations
  deterministic. Analytics/cloud preference remains unanswered; no upload path has been added.

- OCR slice Release generic Simulator build **passed** (`BUILD SUCCEEDED`), log
  `/private/tmp/linepay-v2-ocr-release.log`. All OCR check sessions are now terminal.
  This checkpoint has not been pushed, merged, uploaded or submitted for review.

## Owner data-flow decision, October 16, 2026

The owner answered the pending architecture question: **“Keep everything local; export diagnostics
and backups manually.”** This supersedes the earlier authorization to implement optional
sync/accounts and remote funnel telemetry. Preserve the rest of the v2 goal: native Android,
local PWA workflows, agreement/benefit verification, templates, diagnostics and App Store release.
Use manual, user-directed transfer for portability and source/template exchange. Do not add a
LinePaycheck account, automatic sync, analytics collector or remote pay/document processing.
Local exports are not anonymous, encrypted or successfully delivered merely because a file was
created; describe and verify each property separately.

## Local agreement import checkpoint

- Added retained local PDF imports and a bounded embedded-text/Vision reader. Each candidate keeps
  a physical PDF page, quote and file fingerprint. Conditional/low-confidence/conflicting text does
  not silently choose a wage rule. Supported preparation uses existing engine semantics; unsupported
  benefits/weekly/meal/differential conditions remain limitations for their later roadmap slices.
- Saved per-clause decisions, currency, timezone, applicability and effective-date review feed an
  editable rule draft. Import and preparation cannot activate rules. The existing editor keeps final
  scope/confirmation authority; replacing an unfinished draft needs an explicit action.
- Schema 6 preserves old snapshots and adds document ownership. Exact original files participate in
  backup/restore; removing one keeps source citations. Reattachment requires the same bytes, cited
  imports are protected from unused deletion, and failed saves preserve prior state. Fixed an existing
  backup-mapping omission that dropped closed-period calculation issues and work-correction history.
- Optional report source details now include agreement quotes/page/fingerprint; default minimized
  reports exclude them. Updated manual setup, evidence, backup and deletion guidance. Architecture:
  [ADR 0011](../adr/0011-local-agreement-import.md); [evaluation limits](../testing/agreement-import.md).
- Focused initial agreement/lifecycle batch passed **17 tests in 2 suites**:
  `.build/v2-agreement-lifecycle2-20261016.xcresult`, log
  `/private/tmp/linepay-v2-agreement-lifecycle2.log`. Quick gate passed 74 script tests, strict lint
  and **112 domain tests in 15 suites**. Both guide base-path builds, search, source review,
  screenshot provenance, 975 local doc links and 5 docs-tool tests passed before the last copy edit.
- Initial native QA: first-run import entry passed; largest-text query needed scrolling before
  asserting a virtualized candidate, and the activation flow's confirmation switches remained off.
  Retained failed log `/private/tmp/linepay-v2-agreement-ui.log`; its driver stalled finalizing after
  test hosts exited and was terminated. Updated tests to tap the actual switch side and assert each
  confirmation. Moved detailed applicability guidance to its own section to shorten the opening.
- Current native batch: `.build/v2-agreement-ui2-20261016.xcresult`, log
  `/private/tmp/linepay-v2-agreement-ui2.log`, exec session `96640`. Includes the real raster-only
  PDF/Vision regression, which passed with the 8-test agreement suite. UI results still pending.
  Do not claim completion or release from these partial results.

- Largest-text candidate review/relaunch passed in the second batch (116.275s). Its later normal
  journey failed a switch assertion, so that mixed bundle was not a passing batch and did not
  finalize. An isolated diagnosis identified native switch frames ending at x=355 within the
  larger labelled row: the 95% tap landed in trailing padding. A 90% tap targets the actual switch;
  each of five values was asserted on before preparing. No confirmation requirement was relaxed.
- Final activation journey **passed** (89.496s), finalized bundle
  `.build/v2-agreement-switch-20261016.xcresult`, log
  `/private/tmp/linepay-v2-agreement-switch.log`. It viewed the actual retained PDF, edited 60.00
  to 60.50, reviewed unsupported meal terms as unresolved, explicitly confirmed the editor change,
  preserved prior-period 550 and produced 484 for eight hours in the next period. Screenshot
  attachments were exported to `.build/v2-agreement-ui-attachments/` and inspected: retained source,
  prepared rate, final review and next-period result. Debug frame logging/captures were then removed.
- Broad app regression **passed: 282 tests in 40 suites**, including the seven native StoreKit
  lifecycle tests, migration/backup and all OCR adapters. Finalized bundle
  `.build/v2-agreement-all-app-20261016.xcresult`, log
  `/private/tmp/linepay-v2-agreement-all-app.log`.
- Current final evidence batch (exec `17080`): largest-text review plus the report preview/share
  journey in `.build/v2-agreement-final-ui-20261016.xcresult`, followed on success by a Release
  Simulator build. Logs `/private/tmp/linepay-v2-agreement-final-ui.log` and
  `/private/tmp/linepay-v2-agreement-release.log`. Refresh the changed report guide screenshot
  from its named attachment after inspecting it. No outcome is claimed yet.
- Maestro remains absent. These are XCTest native journeys and adapter receipts, not proof of an
  actual external Files-provider import, physical-camera scan, hosted CI, signed archive or store
  release. Full exact-candidate native/release gates and updated public guide captures remain due.

- Saved implementation as `ee932833e8f8f2fd37d1aae0c1e784ab47a82927` (44 files). No push or
  store write. The final mixed UI batch again passed largest-text review/relaunch (130.213s),
  but the existing report journey failed to find Preview after tapping a partially visible export
  row. It therefore did not run its conditional Release build and is not a passing batch. The
  driver again stalled finalizing after hosts exited and was terminated.
- Current in-scope QA repair scrolls the audit export action fully above the actual pinned Pro
  button, asserts the Prepare report navigation before continuing, and scrolls the frontmost
  window for the modal fallback. It changes the test, not report consent or app pay behavior.
  Isolated report check is running in `.build/v2-agreement-report-ui-20261016.xcresult`, log
  `/private/tmp/linepay-v2-agreement-report-ui.log`, exec `34929`; Release build follows only if
  that succeeds. Check this handle/process on resume; no report or Release PASS is claimed yet.

## Benefits domain and QA continuation

- Previous goal turn made implementation/evidence progress; the later instruction interruption did
  not authorize a reset. Revalidated checkout `ee93283` and all process handles on resume.
- Agreement-slice Release Simulator build **passed**, log
  `/private/tmp/linepay-v2-agreement-release.log`, before the new benefits code. The report privacy
  options and exact PDF preview were asserted/visually inspected. Its later Files step skipped;
  this is not an export receipt. Updated the guide's Prepare report PNG with source/device/build
  provenance, explicitly recording that limit. Guide builds/search/freshness/screenshots, 982 doc
  links, 5 docs-tool tests and legal inventory checks passed.
- The interrupted iOS 18 report rerun found Save to Files in the app namespace, then its saved query
  disappeared after that action. The process is terminal; no largest-text follow-on ran. Guarded
  against retrying a vanished activity action and included a SpringBoard-hosted Save control.
  The iOS 26.5 report still skipped its Files step. No successful Files destination claim is made.
- That iOS 26.5 mixed run also executed **zero** Payday cases despite selecting the largest-text
  method. Changed the method to the throwing XCTest signature used by existing working journeys;
  the isolated rerun now actually starts that method. Standardized the remaining 16 nonthrowing
  test entry points in that file; their discovery/full execution remains to be checked. Never treat
  a green zero-test selection as acceptance. Current live check: exec `90579`, bundle
  `.build/v2-agreement-largest26-20261016.xcresult`, log
  `/private/tmp/linepay-v2-agreement-largest26.log`. Revalidate it before any new Simulator job.
- Added a separate pure employer-contribution model: stable fund identity, immutable rate snapshots,
  explicit eligible hours/days/earnings/fixed-period amounts, dates/timezone/currency/source context,
  per-fund rounding, and exact arithmetic failure on overflow/precision loss. Expected wages,
  allowances and employee deductions are not combined with employer benefits.
- Missing/unconfirmed statement remains unverified; incompatible fund/date/timezone/currency is not
  comparable; unit-only and amount-only comparisons disclose their limits. The saved result retains
  the original statement and rule/fact segments, not just a difference. Fixed amounts cannot be
  duplicated by splitting the same period.
- Current benefits quick gate **passed: 74 script tests, strict lint, 125 domain tests in 16 suites**,
  including 13 new benefits tests. Log `/private/tmp/linepay-v2-benefits-quick.log`. Independent
  example: 40 × 8.75 = 350; confirmed 35.5 hours and 310.63 gives 4.5 hours and 39.37 possible
  differences. This is synthetic arithmetic, not a legal entitlement or end-to-end benefits claim.
- [ADR 0012](../adr/0012-confirmed-benefit-contributions.md) and BR-060–064 state the semantics.
  Next: local saved benefits draft → explicit review → immutable comparison/revision → source and
  separate report, with migration/backup/failed-save and native evidence. All other v2 rows and
  App Store submission/manual public release remain in scope and incomplete.

- Benefits domain checkpoint committed as `db1d894`; native benefits still pending. Final domain
  review added regressions refusing a fixed monthly amount treated as a weekly contribution and
  refusing conflicting snapshots with the same rule UUID. These 15 focused tests passed in
  `/private/tmp/linepay-v2-benefits-domain5.log`; the updated quick gate is running next.
- The isolated iOS 26.5 largest-text journey **actually executed and passed** (132.586s), finalized
  `.build/v2-agreement-largest26-20261016.xcresult`. Exported/inspected the real selected unresolved
  action at accessibility XXXL under `.build/v2-agreement-largest26-attachments/`. The live exec
  `90579` is now terminal. No Simulator test process remains from these batches.
- Standardized XCTest signatures still need the full suite's actual case inventory checked before
  release; do not generalize one discovered/passing method to all newly discoverable methods.
  The report Files destination remains unproven: the iOS 26 mixed batch skipped it. Retain that
  explicit limitation and repair/inspect the actual runtime activity destination in final QA.

- Final benefits quick gate **passed: 127 tests in 16 domain suites, 74 repository tests and strict
  Swift lint**, log `/private/tmp/linepay-v2-benefits-quick-final.log`. Final doc links (983), 5
  docs-tool tests, diff check and legal active-copy/inventory also passed. This does not replace
  the final native/StoreKit/release candidate gate after the remaining app changes.
- All known check handles are terminal at this checkpoint. No branch push, hosted CI, signed
  archive, App Store upload/submission, or public release has occurred. Continue with the native
  benefits draft/revision/backup/report vertical slice; preserve all other pending v2 work.

## Native benefits workflow checkpoint

- Continuing from `ef6b7e6`, implemented native fund/period drafts, explicit eligibility/rule/statement
  review, immutable preview/save, append-only corrections, older-revision selection, another-period
  checks, original statement PDFs and separate minimized reports. Schema 7 adds optional benefits
  records/drafts; versions 1–6 migrate without repricing wage history. Existing agreements cited by
  benefits drafts/history remain protected from unused-source deletion.
- Numeric input retains its explicit separator and rounding scale. Material edits invalidate relevant
  confirmations in the model; a stale preview or another unfinished draft cannot overwrite newer
  input. Original PDFs bind to a draft and SHA-256; late intake is rejected after statement withdrawal.
  Backup/restore remaps physical filenames while preserving original bytes, identities and results.
- The pure result now retains per-segment unrounded contributions for explanation. Expected amounts
  round once per fund; subtracting a confirmed statement does not round its extra precision away.
  USD 350 versus confirmed 350.001 is a possible -0.001 difference, not a false match. Pension,
  annuity, health/welfare and other configured contributions stay separate from wages/allowances
  and employee deductions; no fund membership, full benefits or legal/project compliance is inferred.
- Initial storage batch passed **17 tests in 2 suites** (`v2-benefits-storage2-20261016.xcresult`).
  Expanded original/backup/privacy/review tests passed **22 tests in 3 suites**
  (`v2-benefits-evidence-20261016.xcresult`). These preceded later component/precision/cleanup work.
- First native attempt had a test query compilation error; corrected the keyboard-button query.
  Next identified a real accessibility issue: a verdict identifier exposed its decorative image name.
  The verdict now exposes one explicit text label. Logs retained under `/private/tmp/linepay-v2-benefits-ui*.log`.
- The full normal journey passed (182.354s) in `.build/v2-benefits-ui3-20261016.xcresult`: forty
  synthetic actual worked hours at 50 retain wage estimate 2,000; a separate 40 eligible units at
  8.75 gives 350; missing statement remains unverified; a later 35.5 / 310.63 statement appends a
  correction with 4.5 units / 39.37 possible differences. No wage audit access is consumed.
- Runtime review found the result list stayed at its prior scroll position after correction. Reset
  list identity when selecting a different revision, and made difference rows explicit accessible
  values. Final normal + accessibility XXXL journeys passed (138.983s / 114.352s) in
  `.build/v2-benefits-ui-final-20261016.xcresult`, including old revision remaining unverified, an
  actually loaded original PDF, fresh confirmations and a minimized exact PDF preview.
- Inspected captures under `.build/v2-benefits-ui-final-attachments/`. At XXXL the long save label
  consumed excessive space; accessibility sizes now use short Preview check / Save check labels.
  A separate dark/XXXL journey passed (174.713s), including PDF viewport >100 pt, in
  `.build/v2-benefits-large-dark-20261016.xcresult`. Its real captures were inspected. The report
  warning was visibly truncated, so it now wraps fully; its repeat journey passed (182.817s) in
  `.build/v2-benefits-warning-layout-20261016.xcresult`, followed by a successful Release Simulator
  build (`/private/tmp/linepay-v2-benefits-release.log`). These are Simulator receipts, not an archive.
- Broad app regression passed **295 tests in 42 suites**, including StoreKit lifecycle, in
  `.build/v2-benefits-all-app-20261016.xcresult`. A later broad run (298 tests) had one test-only
  assertion error: withdrawn intake correctly created no directory, but the test tried to enumerate
  it. Fixed the assertion to accept absent or empty storage; this failed batch remains a failure.
- Review found and reproduced a genuine privacy-cleanup mismatch: TemporaryExports accepted only
  audit filenames while the new exporter created benefits filenames. A standalone real-code probe
  failed with unsafePath, then passed after allowing exactly those two report prefixes. Added an
  actual preview-discard regression, preserving unrelated files/symlink guards. Cleanup/privacy/
  transfer batch passed **18 tests in 3 suites**, `.build/v2-benefits-cleanup-20261016.xcresult`.
- Region recovery now losslessly reformats fully parseable saved numbers for the current region,
  clears confirmations and preserves partial input unchanged on conversion failure. Corrected a
  Character interpolation warning without disabling strict warnings. Current sequential check:
  exec `34142`, `.build/v2-benefits-format2-20261016.xcresult` then
  `.build/v2-benefits-region-ui-20261016.xcresult`, logs
  `/private/tmp/linepay-v2-benefits-format2.log` and `/private/tmp/linepay-v2-benefits-region-ui.log`.
  Revalidate that handle/process before starting another device job. No current outcome claimed yet.
- Added unreleased-v2 benefits guide and updated backup/privacy/history/report scope. The guide
  validator originally expected 20 articles; intentionally updated to 21 and added benefits search
  relevance. Full guide/source-freshness, script/native and Release checks still need final readback
  after the latest region-recovery edits. Do not claim full v2, hosted CI, actual provider delivery,
  physical-device behavior, signed archive or App Store release from this work.

- Region-recovery adapter batch passed **18 tests in 2 suites** in
  `.build/v2-benefits-format2-20261016.xcresult`; actual comma-draft conversion/relaunch passed
  (36.681s) in `.build/v2-benefits-region-ui-20261016.xcresult`. Original numeric values stay exact;
  partial values are not guessed or discarded. Current-number formatting is required before preview.
- Complete `agent-verify.sh ios` was actually run using the existing iOS 18.5 UDID and
  `.build/v2-benefits-full-gate-20261016`. Its **128 domain tests and 300 app tests passed**;
  all three benefits UI methods executed/passed. Final result is **Failed**, 324 cases total:
  321 passed, 1 failed, 2 skipped. Failure: native Files destination was not reached. Critical
  skip: largest-text New rules from a date menu option was not exposed. The other skip was the
  intentionally opt-in store-screenshot journey. Do not call this a passing native gate; its
  conditional Release step did not run. Log `/private/tmp/linepay-v2-benefits-full-gate.log`.
- Inspected the retained system-share screenshot: the activity sheet had accessibility-sized text,
  with Save to Files below the visible actions. The test had materialized an offscreen cell and
  tried a blind center tap. Repaired it to scroll until an actually hittable Files action appears,
  with no skip/fallback coordinate pretending to reach the destination. The isolated native
  destination/preview journey **passed** (80.954s), reaching actual Files and cancelling without
  selecting a recipient or persisting a report.
- Also brought the scope menu fully above the pinned save action before tapping and retained menu
  captures. Current check is exec `1712`, `.build/v2-provider-scope-20261016.xcresult`, log
  `/private/tmp/linepay-v2-provider-scope.log`; its largest-text scope case is still live at this
  checkpoint. Revalidate before another UI job. App source has stayed fixed during these checks.
- Final guide verification passed for both base paths: 24 HTML pages, 21 indexed guides, internal
  links/assets, benefits search relevance, 46 reviewed source blobs and screenshot provenance.
  Local docs: 985 links and 5 tool tests passed; legal active-copy/inventory passed. No publication
  or external professional approval follows from those checks.

- The first repaired provider/scope batch passed the actual Files destination but still skipped
  dated scope. Retained captures showed the scope menu was not open after a center tap. Queried
  the actual Button (rather than inherited-label identifiers), supplied a rectangular label hit
  area and pressed the visible label after revealing it above Save. No test-only scope mutation
  hook or pay assertion was removed. The isolated largest-text three-scope journey then **passed**
  (109.806s), `.build/v2-scope-label-20261016.xcresult`, log
  `/private/tmp/linepay-v2-scope-label.log`: future/date retain 550; explicitly current recalculation
  becomes 660. The earlier skipped results remain recorded as skips.

- Second complete native gate again passed **128 domain / 300 app tests**, plus all normal benefits,
  region and legacy checks, but failed the dark XXXL report-preview action once: the body button was
  only partially visible. Its actual PDF-sharing assertion stayed in place. The helper now brings
  that body action fully within the modal viewport and captures before/after the tap. The isolated
  XXXL original/review/report journey passed (181.067s), `.build/v2-benefits-preview-target-20261016.xcresult`.
  This does not erase the failed full-gate result in `.build/v2-benefits-complete-gate-20261016`.
- Started the independent Foundation website consistency work while native gates ran. Verified the
  public App Store listing still shows 1.0.5, USD 9.99 monthly / 79.99 annual and Data Not Collected;
  public home matches those prices. Found the public /features table and FAQ incorrectly treating
  first-check scanning and saved history/reports as Pro-only, contrary to the canonical pricing
  contract and home page. Sources: https://linepaycheck.com/features and
  https://apps.apple.com/us/app/linepaycheck-lineman-pay/id6808889292 (October 16 readback).
- Isolated website checkout `/private/tmp/linepaycheck-v2-consistency-20261016`, branch
  `codex/v2-plan-consistency`, base `56dd690`. Only the Features copy and its registry date changed;
  existing v2 availability remains unadvertised. Primary `/Volumes/SSD/linepaycheck.com` is unchanged.
  `pnpm check` passed with the project-selected 10.11.0, and the real production build passed all
  23 browser checks in both Chromium and WebKit, including narrow/enlarged/no-JS states. Local
  preview is exec `25352`, port 4338; stop only that owned process after review. No web deployment.

- Final corrected target now passed: `.build/v2-benefits-preview-target-20261016.xcresult`
  (181.067s), while actual share availability and PDF viewport assertions remain. The newest full
  gate is live as exec `34159`, `.build/v2-benefits-verified-gate-20261016`, log
  `/private/tmp/linepay-v2-benefits-verified-gate.log`. It has freshly passed 128 domain and 300
  app tests, plus the two long benefits flows; do not claim its overall result before completion.
- Website production-build browser inspection passed in Chromium and WebKit (23 checks each), plus
  focused actual table-cell and 320/390px enlarged-text captures in `artifacts/consistency/` of the
  isolated site worktree. Its task-created Python environment was moved out of the checkout to
  `/private/tmp/linepaycheck-v2-browser-env-20261016`; only two source files are modified. No site
  deployment, pull request, branch push or App Store write has occurred.

- Native implementation checkpoint is committed as `cd267f2`; source tree was clean after commit.
  Isolated website correction is committed as `0ddbb02` on `codex/v2-plan-consistency`. Neither
  branch has been pushed or deployed. The task-owned preview on port 4338 was stopped after QA.
- Newest full iOS gate is still live as exec `34159` at this checkpoint. It has passed all 300 app
  tests, 128 domain tests, all three benefits UI cases, both previously failing/skipped legal cases,
  and continued legacy UI journeys. Inspect `/private/tmp/linepay-v2-benefits-verified-gate.log`
  and the actual handle/process on resume; the final Release/coverage result is not yet claimed.
  Preserve this exact candidate and all earlier failing/skipped evidence. Full v2 / App Store
  submission and manual public release remain incomplete, with the rest of the work ledger intact.

## Completed benefits gate and current delivery boundary

- Final canonical `agent-verify.sh ios` **passed** (exec `34159`, exit 0), including strict Swift
  formatting, privacy checks, 128 domain tests, 74 repository tests, Xcode generation/lockfile
  preservation, simulator app/UI tests and the generic Release Simulator build.
- Finalized `.build/v2-benefits-verified-gate-20261016/AppTests.xcresult`: **324 cases total,
  323 passed, 0 failed, 1 skipped**. The only skip is the deliberately opt-in store-screenshot
  fixture. All 300 app tests and all critical UI journeys actually executed, including the three
  benefits methods, real Files destination and all largest-text rule scopes. Source app code is
  the committed benefits checkpoint `cd267f2`; later native commits were task-record only.
- Website code `0ddbb02` remains local in its isolated checkout. The attempted command to push
  `codex/v2-plan-consistency` and create a PR in `RunLumi/linepaycheck.com` was **rejected before
  execution by automatic approval review**: the exact remote destination/branch publication had
  not been explicitly authorized. Do not bypass via another tool or deploy the same private source
  indirectly. Asked the owner asynchronously to approve that exact push/PR/merge and deployment
  to Worker `linepaycheck-com` / `linepaycheck.com`; no reply or approval is assumed.
- No website push, PR, deployment, iOS archive, App Store upload/submission or new public app
  release has occurred. The full v2 goal remains active; independent native work is available.
  Next: implement content-free, device-local funnel milestones and manual diagnostic export,
  without a collector or restoring diagnostic observations as historical install/conversion facts.
- All verification processes from the benefits gate are terminal. The preview server was already
  stopped. Revalidate clean checkouts and exact evidence on resume; keep earlier failed and skipped
  results distinct from this final passing gate.

## Local activity and manual diagnostics checkpoint

- Implemented a separate versioned, device-local ledger with a closed vocabulary, bounded UTC
  daily history/deduplication, lifetime totals, opt-out, activity-only clear and known-gap disclosure.
  No wage/document/free-text attributes, collector, account or analytics SDK. Internal hashed
  identities never enter the diagnostic export; usage days/counts remain potentially personal.
- Financial writes commit before observation; recording failure cannot roll back pay. Financial
  backup restore does not backfill activity. Explicit all-data deletion clears activity while
  retaining the recording preference. ADR 0013 owns this boundary.
- `v2-local-activity-commerce-20261016.xcresult` passed: 23 tests across three suites, including
  nine activity regressions and actual local StoreKit trial-to-paid/refresh deduplication.
  Existing-subscription/renewal observations are explicitly distinct from new-customer conversion.
- Native `LocalActivityJourneyTests` passed in 116.975s on the existing iOS 18.5 device:
  exact JSON preview, actual Files picker (Browse/Move), cancellation without saving, opt-out
  surviving relaunch, largest accessibility text/dark appearance and activity-only clearing while
  the synthetic $2,000 wage result remains intact. Captures exported to
  `.build/v2-local-activity-ui-picker-attachments` and visually inspected. No provider save, upload
  or cross-device arrival is claimed.
- Earlier UI attempts are retained: one incorrect test-target selection ran no cases; subsequent
  failures assumed Files always exposes Cancel, whereas the actual folder showed Browse/Move.
  The final test asserts the real picker and dismisses it. Failed drivers were stopped only after
  failure and test-host exit; no simulator was created, erased or upgraded.
- Guide build/search/freshness (50 tracked sources), 986 documentation links, five doc tests and
  legal inventory passed. Targeted privacy/backup guidance documents this unreleased workflow;
  the original full-site review baseline remains distinct.
- Initial full-gate attempt `39951` stopped at two long test lines before native execution;
  Swift formatting was corrected. Full canonical iOS gate is running as exec `20102`, log
  `/private/tmp/linepay-v2-local-activity-final-gate.log`, results
  `.build/v2-local-activity-final-gate-20261016`. Do not claim its final pass before completion.
- Website publication approval remains pending; native branch is local, public version unchanged,
  and no archive, App Store upload/submission or new public release has occurred.

## Completed local-activity native gate

- Source checkpoint `d7c0ddd` completed the canonical `agent-verify.sh ios` gate (exec `20102`,
  exit 0). Final result `.build/v2-local-activity-final-gate-20261016/AppTests.xcresult`: **334
  total, 333 passed, 0 failed, 1 skipped**. The only skip is the opt-in store-screenshot fixture;
  all 309 app tests and critical native UI cases actually ran. Release Simulator build, privacy,
  coverage and dependency-lockfile preservation passed. This is simulator/build evidence, not
  signed-device, App Store or production-conversion evidence.
- Documentation checks now cover 989 links and five doc tests; guide build/search, 50 source
  freshness mappings and four screenshot-provenance entries passed. Architecture documentation
  now names the actual atomic versioned-file adapter, and links the separate local ledger.
- Native working tree was clean after implementation commit. No native test job remains. Website
  source `0ddbb02` is still local with publication approval pending. No archive, App Store upload,
  submission or new public release has occurred. The overall goal remains active; remaining
  roadmap stages retain their actual pending states above. Next independent native slice: private
  on-device voice capture into an editable work draft with explicit confirmation, never direct
  payroll writes or remote transcription. Re-read platform availability and nearest work-draft
  contracts before implementation.

## Voice work implementation checkpoint

- Added native, capability-checked English capture with a one-minute protected temporary recording,
  mandatory on-device Speech request, no server fallback, explicit permission actions, bounded
  transcription wait and foreground/cancellation cleanup. Owned audio is excluded from financial
  state/backups; startup and all-data deletion retry its removal. ADR 0014 owns this data flow.
- Added an editable reading and explicit clock-fact proposal, selected local work date/timezone,
  next-day endpoint markers and required break facts. Ambiguous clocks, DST gaps/folds, overlaps
  among breaks and extra instructions are rejected. Confirmation applies only to the current work
  draft; ordinary Save work and existing callout/overlap/period validation remain separate.
- Seven focused app tests passed in `.build/v2-voice-contract-20261016.xcresult`. Two native typed-
  reading journeys passed in `.build/v2-voice-ui-review-20261016.xcresult`: synthetic eight hours
  at USD 50 → USD 400 only after explicit save/relaunch; ambiguous large-text reading stays blocked.
  Captures exported and inspected. Earlier compilation and toggle-hit failures are retained; the
  confirmation now uses the established full-row ConfirmationCheckRow.
- No physical phone appeared in `devicectl list devices`; microphone capture, actual recognition
  accuracy and offline runtime remain **unproven**. `docs/testing/voice-work.md` gives exact
  synthetic device checks. No real audio was recorded in the simulator journeys.
- The reviewed mechanical inventory change is only the two microphone/speech purpose strings in
  project.yml. No new runtime package, capability, background mode or collector. V2 privacy review
  remains pending (#22 trigger); the 1.0.5 owner declaration is not reused as new approval.
- Full canonical native gate is live as exec `22948`, log `/private/tmp/linepay-v2-voice-gate.log`,
  results `.build/v2-voice-gate-20261016`. It passed all 316 app and 128 domain tests and is
  progressing through UI journeys. Do not claim its final outcome before completion.
- Guide build/search/freshness passed (53 mapped sources); docs/legal active-copy/inventory
  checks passed without implying owner/counsel/release approval. Website publication remains
  pending the exact remote/branch approval already requested; no push/deployment/store write.

## Completed voice-work native gate

- Implementation checkpoint `e4aaf22` passed the full canonical `agent-verify.sh ios` gate (exec
  `22948`, exit 0): **343 total cases, 342 passed, 0 failed, 1 skipped**. All 316 app tests and
  critical native UI methods ran; only the deliberately opt-in store-screenshot fixture skipped.
  Strict formatting, privacy checks, 128 domain tests, repository tests, coverage, Release
  Simulator build and dependency-lockfile preservation passed.
- Final results: `.build/v2-voice-gate-20261016/AppTests.xcresult`; summary
  `/private/tmp/linepay-v2-voice-summary.json`; log `/private/tmp/linepay-v2-voice-gate.log`.
  Final UI captures in the result's `screenshots/` directory were inspected: correct October 16
  07:00–15:30 CDT and noon–12:30 break, whole-row unconfirmed review control, separately disabled
  Apply, and visible ambiguous-clock recovery at accessibility XXXL in dark mode.
- Generated app Info.plist confirms both microphone/speech purpose strings, no background mode,
  unchanged `com.streamentry.linepay` identity and 1.0.5 (11) development version. No signed-device
  recognition, archive, TestFlight upload, App Store submission or new public release is claimed.
- Asked the owner asynchronously whether a physical test iPhone can be connected; no reply is
  assumed. Website publication permission is also still pending. These do not block other native
  implementation: next independent slice is encrypted manual backup/restore portability, keeping
  legacy snapshots readable, passwords off disk/logs and all financial replacement confirmation
  and failure guarantees. Inspect the existing BackupArchive/BackupIO and platform cryptography
  documentation before choosing the exact interoperable envelope.
- Native test jobs are terminal and the implementation working tree was clean after its commit.
  Overall v2 remains active, with all still-pending platform/release requirements above preserved.

## Optional protected-backup implementation checkpoint (October 17)

- Added optional per-copy password protection to manual backup with NFC-normalized passwords,
  bounded 600,000-round PBKDF2-HMAC-SHA256, random salt/nonce, AES-256-GCM and an authenticated
  versioned header. No password/key storage, server, account, synchronization or Pro restriction.
  Legacy unprotected copies remain readable. Protected payload uses versioned JSON with decimal
  Unix-second date strings, preserving subsecond values without lossy epoch shifting.
- ADR 0015 and the shared backup transport specify limits, exact bytes, normalization and existing
  financial restore ownership. Password confirmation and separate password-kept acknowledgement
  precede export; unlock/validation is distinct from replacement. Bad passwords/tampering cannot
  produce financial preview/state changes, and unsupported versions/costs fail before derivation.
- Initial focused native suites passed 18 tests (five crypto cases, legacy originals/restore and
  concurrent operation guards). The later full-gate candidate includes an additional future-
  payload-version regression; all 322 app tests have passed so far.
- Native actual Files journey passed in 76.243s in
  `.build/v2-encrypted-backup-ui-import-20261017.xcresult`: protected copy saved specifically under
  On My iPhone → disposable synthetic data deleted → exact saved file selected → password required
  → wrong password refused → correct unlock → separate replace confirmation → synthetic USD 550
  restored. This proves local-provider persistence/readback; no remote upload/two-phone delivery.
- Actual UI testing found the prior app-root `.disabled(session.isBusy)` reset the backup sheet's
  state on iOS 18.5 during preparation. The busy interaction lock now belongs to the backup modal;
  backend AppSession exclusion, disabled Done/actions and interactive-dismiss protection remain.
  Switching Transferable to FileDocument did not fix it and was reverted. Earlier failing evidence
  remains. The test also targets the largest app window instead of a retained 131×284 provider
  window; final assertions preserve actual file selection, unlock and replacement.
- Shared synthetic vector SHA-256 `42aef4cc154a19d0c58db94bfb30182200d29ebb433abb60a066a93c4175ae1c`
  matched CommonCrypto/CryptoKit, Node crypto, Node WebCrypto, actual Chromium 155.0.8059.85 and
  Playwright WebKit 26.0. Both browsers rejected wrong passwords, changed authenticated headers
  and tags. Browser reports are `.build/backup-crypto-browser/{chromium,webkit}.json`; this is
  transport conformance, not a working PWA/Android restore client. No external pay data was used.
- Mechanical resource inventory change is only project.yml (test vector resource and corrected
  Apple-OS-only cryptography comment). No new runtime package. #32 export-declaration review is
  pending for v2; no old owner approval, App Store write or new release is implied.
- Full canonical native gate is running as exec `12921`, log
  `/private/tmp/linepay-v2-encrypted-backup-gate.log`, results
  `.build/v2-encrypted-backup-gate-20261017`. Revalidate the handle and final result before claiming
  a pass. Guide build/search/freshness (55 mapped sources), docs and legal checks passed.
- Website exact push/PR/deploy approval and physical iPhone availability remain unanswered; neither
  is assumed. Native branch is local and App Store version remains unchanged. Overall v2 active.
