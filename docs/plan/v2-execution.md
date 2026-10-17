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
| Paycycles and period matching | Shared calendar corpus and browser source-period guard verified; native adapter updated | Current native App/Simulator regression, physical timezone/provider checks and final release gate |
| Weekly review correctness | Weekly v2 and assessment v4 bypass guard implemented; domain/SDK evidence recorded | Verified weekly-to-paycheck allocation, native App/visual/accessibility execution, persistent evidence and Android/PWA adoption remain pending |
| OCR reliability | Implemented and locally verified | Broader employer-layout/independent precision evaluation; final release gate |
| Resolution workflow | Native workflow plus browser append-only follow-up/reviewed reports implemented | Saved finding/status/notes/history and shareable evidence packet |
| Accessibility | Pending | VoiceOver, large text, contrast/motion and critical native journeys |
| Free web calculators | Existing public calculator; 7 arithmetic tests passed | Exact arithmetic, stated assumptions, browser flow and app CTA |
| Agreement extraction | Implemented; 282 app tests and focused native journeys passed | Broader independent document corpus, actual Files-provider transfer and final release gates |
| Benefits audit | Implemented; complete native iOS gate passed | Final release-candidate/device checks after remaining v2 work |
| Verified rule sources | Pending | Rights, version/effective dates, scope, freshness and no silent history mutation |
| Voice logging | Implemented; full native iOS gate passed | Actual physical microphone/offline recognition, accessibility/device checks and v2 privacy review pending |
| Referrals | Pending | Content-free attribution with explicit data-flow/commerce boundaries |
| Encrypted sync/account | Accounts/sync superseded; encrypted manual native gate and focused adaptive checks passed | Two-device/provider checks, release declaration review and Android/PWA state adoption pending |
| Full PWA | Local wage/fund, dated rules, reports and recovery browser-verified; full parity pending | Complete rule/state/feature parity, native interchange, installed/physical PWA, localization and publication |
| Agreement library | Pending | Source rights, review/moderation and immutable versions |
| Android | JVM configured-pay/fund/gross comparison and encrypted transport and calendar boundaries implemented; 111 JVM tests passed | Native Compose app, full parity, state portability and Android runtime/E2E remain pending |
| Localization | Pending | Spanish terminology/context QA, all primary states |
| Crew templates | Browser exchange/recovery verified; native Files/UI/adoption/state implementation added | Native App tests/Simulator/visual/provider execution, Android adoption, physical transfer and actual crew use remain unverified |
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

- Protected-backup implementation checkpoint committed as `426f237`. The pre-commit secret hook
  initially rejected inline **synthetic** test password constants. Without disabling/bypassing it,
  tests were changed to load explicitly public fixture inputs from the shared vector; commit then
  passed. Added the same test-only vector resource to the UI-test target. No production code
  changed after the full gate began. The loader/resource change needs a focused rerun after the
  live gate finishes; do not regenerate the Xcode project concurrently with that gate.
- Finalized vector metadata (adds only public ASCII UI input) has SHA-256
  `9026839609df397a6cee379084555ad6b3a8d6f48e173cd407f6792b5bc9d1df`; crypto inputs/output remain
  unchanged. Node and actual Chromium/WebKit conformance were re-run and passed on that file.
- Added a largest-text/dark-mode mismatched-password UI method **after** the full gate compiled.
  It is not part of that running binary. Pending follow-up: regenerate Xcode, run
  BackupEncryptionTests and both EncryptedBackupJourneyTests, inspect final adaptive/error captures,
  then checkpoint actual results. The only current uncommitted code is that added UI test method.
- Read-only next-platform assessment: Android remains a placeholder, with native Kotlin/Compose
  and independent shared-contract fixtures required. The owner's explicit all-stages decision
  authorizes beginning it despite the old demand gate. Existing Android SDK directory and Temurin
  21/24 JDKs are present; no Android scaffold, emulator, runtime installation or device change was
  made. Native Android/PWA workflows are still pending, not established by browser crypto parity.

## Completed protected-backup verification and first payroll treaty

- Canonical full native gate (exec `12921`) exited 0: **350 total cases, 349 passed, 0 failed,
  one intentional store-screenshot skip**; 322 app and 128 domain tests, script/privacy/coverage
  checks, Release Simulator build and lockfile preservation passed. Final result is
  `.build/v2-encrypted-backup-gate-20261017/AppTests.xcresult`, summary
  `/private/tmp/linepay-v2-encrypted-backup-summary.json`.
- After that gate ended, regenerated Xcode for the final public fixture loaders/resource and ran
  the six crypto tests plus both backup UI methods. All **8 passed** (exec `97102`, exit 0),
  `.build/v2-encrypted-backup-final-focus-20261017.xcresult`. Actual local Files round trip passed
  again; largest-text dark mismatch rejected export and preserved synthetic USD 550. Final
  mismatch, wrong-password and unlocked-preview captures exported and visually inspected under
  `.build/v2-encrypted-backup-final-focus-attachments`. No iCloud/two-device or store claim.
- Added the first platform-neutral payroll treaty: fourteen independently calculated synthetic
  cases covering daily tiers, breaks, midnight, DST, physical callout identity, separate per diem,
  highest-premium precedence, fractional time rounding and currency. Native consumer verifies
  category sums, worked time, multipliers, dates and snapshot/source-work references. No production
  engine code changed. `agent-verify.sh quick` passed **129 domain tests in 17 suites**, including
  the fourteen-case consumer; final focused run also passed after explicit timestamp/reference
  assertions. Broader legal/weekly/effective-date/benefits/refusal parity remains pending.
- Implementation source is `426f237`; its full gate started before test-only fixture-loader changes.
  The focused follow-up verifies those changes and the added adaptive method. All native jobs are
  terminal. The total v2 goal, physical-device gates, external approvals and public release remain
  open. Next: complete shared parity coverage/native clients while retaining every pending stage.

## Exact-time precision defect found by shared fixtures (October 17)

- After the fourteen-case treaty passed, added fixed independent half-cent cases. The real version-2
  engine failed nine assertions across three cases: USD 18/hour × one second returned 0.00 instead
  of 0.01; USD 58.50/hour × one minute returned 0.97 instead of 0.98, including partitioned work.
  Reproduction: `/private/tmp/linepay-v2-half-cent-reproduction.log`. Expectations were not weakened.
- Corrected arithmetic to retain exact second-based daily positions/slices and exact rate-times-
  seconds-times-multiplier numerators until the declared rounding boundary. Category targets sum
  numerators before division; largest remainders use numerator units. Callout worked/minimum time
  uses exact seconds without inserting guarantees into work. No rate/premium policy changed.
- New provenance is calculation `/3`, rounding `exact-seconds-snapshot-rounding/2`; old `/2` plus
  `explicit-snapshot-rounding/1` remains admitted as its exact pair. Unknown pairs still fail.
  No new persisted field/schema. ADR 0016 records algorithm/version and history boundaries.
- Affected active saved checks require re-review; unchanged ledger prices keep their recorded
  provenance. New explicit reviews use current precision. Closed-period reads remain frozen;
  explicit closed review appends a new audit calculation while preserving the original period
  estimate and prior revisions. Display/validation follows the current paystub's recorded revision,
  not an unrelated original estimate. History and intake disclose the distinction.
- Shared treaty now contains **19 cases**, adding exact single-second/minute and aggregate-before-
  division half-hour partition boundaries. All 129 domain tests passed; quick repository checks and
  final guide build/search/freshness (58 mappings), 1008 docs links and legal checks passed.
- App precision/audit/report regression bundle passed 13 cases, then final precision/legacy-backup/
  encrypted-backup bundle passed **21 cases** in
  `.build/v2-exact-seconds-final-policy-20261017.xcresult`. It proves old estimates/provenance and
  revisions survive load/archive/backup, affected checks require review, and explicit current/closed
  review records `/3` without rewriting `/2`. Earlier failed admission was an unextended provenance
  allowlist, fixed by adding only the exact new pair, not removing validation.
- Native one-minute review/save journey passed (21.319s),
  `.build/v2-exact-seconds-ui-20261017.xcresult`: synthetic USD 58.50/hour, 07:00–07:01 with no
  unpaid break → explicit review/apply/save → visible USD 0.98. Typed input does not prove speech.
- Comprehensive native gate is now live as exec `69702`, log
  `/private/tmp/linepay-v2-exact-seconds-gate.log`, results `.build/v2-exact-seconds-gate-20261017`.
  Earlier 350-case passing gate did not contain these new boundaries; do not use it as proof of
  this correction. Inspect the current handle/outcome and final captures before claiming completion.
- No App Store/archive/website write. Full v2 remains active, with native Android/PWA, further
  parity/independent-corpus/accessibility/source-rights/crew/localization and release evidence still
  pending. Website publication and physical-phone questions remain unanswered. Do not bypass the
  earlier rejected remote publication or infer external approvals.

- Precision implementation checkpoint is `bc698f9`; source tree was clean at that commit. The first
  full precision gate `69702` ran 326 app cases: **325 passed, one failed** solely because
  ScreenContractTests still expected the former literal “Work or rules changed.” The actual new
  message includes calculation changes. Updated only that assertion; its needs-review and original-
  evidence-preservation assertions remain intact. Do not describe that first gate as passed.
- Cancelled the already-failed owned run; SIGINT stopped the test hosts but Xcode reported an
  internal cancellation/run-operation error and retained its driver. After host exit, terminated
  only PID 62052. Session `69702` is terminal (143); it is not waiting/running anymore.
- Fresh canonical gate now runs as exec `94858`, log
  `/private/tmp/linepay-v2-exact-seconds-verified-gate.log`, results
  `.build/v2-exact-seconds-verified-gate-20261017`. Revalidate it on resume and keep all earlier
  failure evidence. No source arithmetic/history behavior changed after the first gate began;
  the follow-up change is the obsolete copy expectation only.

- Gate `94858` ran 326 app tests with one failure: the unchanged real StoreKit refund test threw
  local `ASOctaneSupportXPCService` connection error 4097. This is a failed integration receipt,
  not a passing run. Separately, actual screenshot inspection showed a misleading rounded-hour
  equation (“0.02 h × $58.50”) beside the correctly calculated minute amount USD 0.98.
- Cancelled that already-failed run to correct the confirmed display issue. SIGINT stopped hosts;
  after the same Xcode cancellation error retained its driver, terminated only PID 65588. Session
  `94858` is terminal (143). No simulator erase/runtime installation. Agent doctor passed with
  the two known optional tool warnings; that is not StoreKit proof by itself.
- Display-only duration formatting now shows minutes/seconds and explicit hourly-rate units, with
  ≈ on normalized quantities. Summary, add/repeat preview, ledger/evidence and PDF formula paths
  no longer claim that rounded decimal hours multiply exactly into the money result. The money
  kernel is unchanged by this follow-up. Missing recorded multipliers no longer invent a formula.
- A first narrow StoreKit method selector selected an empty suite; it did NOT execute refund and
  is not its proof. Then ran the whole real local StoreKit suite: all seven lifecycle cases actually
  executed and passed, including refund (0.730s). Duration/report tests also passed: 11 Swift Testing
  methods across three suites; native corrected-cent/formula journey passed in 22.618s with actual
  AX label “Regular hours, $0.98, ≈1 min at $58.50/h” and absence of “0.02 h”.
- Final focused evidence `.build/v2-duration-and-storekit-20261017.xcresult`; log
  `/private/tmp/linepay-v2-duration-and-storekit.log`; captures exported under
  `.build/v2-duration-and-storekit-attachments` and visually inspected. New controls/layout remain
  native. A one-time compile warning from an unused multiplier binding was fixed, not suppressed.
- Latest quick passed 129 domain tests and 74 repository tests; guide checks passed (58 sources),
  with current reviewed wording. Fresh comprehensive gate is live as exec `69768`, log
  `/private/tmp/linepay-v2-precision-duration-gate.log`, result directory
  `.build/v2-precision-duration-gate-20261017`. Do not claim its outcome before completion. All other
  native jobs are terminal. Preserve every earlier failed/cancelled receipt distinctly.

## Native Android foundation checkpoint (October 17)

- Owner authorization explicitly begins Android despite the former demand deferral. Implemented
  independent Kotlin JVM `domain` and separate JCA `backup` modules; no shared Swift runtime,
  account/backend/collector or production payroll SDK. Native Compose app/workflow/runtime is still
  pending, not replaced by these libraries.
- Official Gradle 9.4.1 wrapper JAR verified against its published SHA-256; distribution hash pinned.
  Kotlin 2.4.0, installed Temurin JDK 21 and JVM-17 bytecode target; warnings-as-errors, dependency
  locks and SHA-256 verification metadata. Development caches are repository-local. Gson/JUnit
  are test-only. Strict offline verification passed, with actual JUnit XML confirming no skips.
- Configured-pay model defensively copies facts/rules, preserves explicit timezones/instants and
  immutable IDs/versions, prices exact second-products with BigDecimal, supports daily/schedule/
  weekday/date/effective-date configuration, guarded callout minima and separate per diem. Selected
  highest-premium trace is explicit; broader statutory/benefits/reconciliation support remains
  pending. Ambiguous schedule boundary clocks fail closed rather than normalize into work.
- Domain tests: all **19 shared fixtures plus 9 boundary cases passed**. Covers exact cent/tier
  partition behavior, identity/overlap refusals, currency/immutability, rate transitions, highest
  premia, daily-position conservation, guarantee interaction and clock-gap refusal.
- Backup transport tests: **4 passed** using the same independent Unicode/AES-GCM/PBKDF2 vector,
  header/cipher/tag tampering, wrong passwords, fixed bounded work factors and random exports.
  This is JDK/JCA transport interoperability, not Android-provider/runtime or financial-state restore.
- Evidence: `/private/tmp/linepay-v2-android-trace-verified.log`; actual XML under ignored
  `apps/android/{domain,backup}/build/test-results/test/`. README/ADR 0017 state limitations and
  reproducible commands. The Android SDK location is a symlink to an **empty** target; the prior
  note that its directory existed did not establish installed platforms/build tools. No SDK,
  system image, device/emulator/runtime or license acceptance was performed.
- Current native iOS gate `69768` remains live but has a real failed receipt: encrypted-backup UI
  saved a synthetic copy then could not select it for restore. All 328 app tests and earlier money/
  duration cases passed, but that does not make the entire gate pass. Let the confirmed live job
  finish and inspect the finalized Files screenshot/AX evidence; do not skip the case or blindly
  repeat it. Verify actual provider-save success before deleting synthetic data, explicit restore
  folder/search state and accessible file role/name. All current native production code is unchanged.
- Android stage still requires full parity, native UI/state/migrations/history, real snapshot
  adoption, local OCR/voice/commerce choices, localization/accessibility and actual runtime proof.
  iOS physical-device and external publication/release approvals remain pending. Overall goal active.

## Native host setup changed during the run; next required checks

- Gate `69768` finished all 30 UI assertions with **one failure and one intentional skip**; the
  sole failure is `EncryptedBackupJourneyTests` locating the locally exported synthetic file.
  All 328 app tests passed. This is not a full gate pass and Release was not reached.
- Xcode's result finalization then stalled: PID 70425 had zero CPU, both test hosts had exited and
  result Data stopped advancing at suite completion. Terminated only that driver; session `69768`
  is terminal (143). Its diagnostic child remained independently alive; do not treat the old gate
  as live or restart solely from a polling timeout.
- Strengthened the backup test to require the actual “Saved to your selected location” status
  before deleting synthetic records, plus retained initial/missing picker screenshots and AX tree.
  No locator requirement or password/replace assertion was weakened. The change is unverified:
  focused run `.build/v2-backup-picker-observed-20261017.xcresult` ran **no tests** because devices
  could not be enumerated. Preserve that environment-failure receipt.
- Authoritative host state changed from Xcode 27.0 to **Xcode 27.1 (27A9275)**. The on-disk/loaded
  CoreSimulator is 1171.7, while the new Xcode shim requires 1174.9.2. `-license check` succeeds;
  `-checkFirstLaunchStatus` exits 69. Only Xcode.app is installed. No test app, launchd_sim or
  unrelated xcodebuild job was running during inspection.
- The simctl shim automatically invokes `xcodebuild -runFirstLaunch` on this mismatch. Its child
  PID 79905 (parent old diagnostic 79881) is waiting in PackageKit AuthorizationCopyRights, proven
  by a one-second sample. It has NOT completed installation. Asked the owner to complete the macOS
  administrator component-install prompt. No password is requested or recorded. Keep only that
  original setup request; duplicate read-query shells/children were stopped (81364/81367/81376 and
  83444/83454). Read-query session `13318` is terminal (143). Avoid calling the simctl shim again
  until setup completes, or it will create duplicate authorization prompts.
- Existing devices/runtimes were not created, erased or installed. Do not change the repo's pinned
  baseline just because this host updated. After owner setup, verify actual CoreSimulator version,
  first-launch status and existing device availability before native QA. Then inspect/reproduce
  the Files failure: save-success receipt, explicit provider/folder/search state and file AX role.
  Do not assume the failure was caused by the later Xcode update.
- Android build prerequisites: inspected Google's official command-line-tools page/repository only.
  No SDK was downloaded or license accepted. Asked the owner to authorize April 28, 2026 Android
  SDK terms and repository-local Mac ARM CLI 22/API36/Build Tools36.0.0 (no emulator/system image).
  Exact package IDs use `android-sdk-license`; primary docs require acceptance before download.
- Meaningful independent work remains: broader JVM benefits/reconciliation/contracts, native app
  source/state, full PWA, crew templates, localization, verified-source/corpus work and release.
  These host/publication/input boundaries do not by themselves block the entire goal. Keep it active.


## Confirmed fund parity checkpoint

- Added a pure Kotlin employer-contribution calculator and a shared thirteen-case synthetic corpus
  consumed independently by Swift and Kotlin. One explicitly confirmed fund/currency/period is
  priced from immutable effective rule snapshots and confirmed eligibility. Hour/day/percentage/
  fixed bases, exact raw components and one fund-total rounding remain separate from cash wages.
- Comparison preserves statement precision (350 minus 350.001 is -0.001), unknown/unconfirmed
  observations, units-only scope and fund/date/timezone/currency/basis compatibility. Mixed bases
  may sum money but never sum unrelated units. No automatic eligibility or legal-fringe claim.
- All **51 JVM tests passed**, with no failures/errors/skips in actual JUnit XML: 19 shared pay,
  9 pay boundaries, 13 shared fund, 6 fund boundaries and 4 encryption cases. Strict offline
  dependency verification succeeded. Log `/private/tmp/linepay-v2-android-benefit-final.log`.
- Quick gate passed: **74 repository tests, strict Swift format and 130 domain tests in 18 suites**,
  including the Swift thirteen-case fund consumer. Log
  `/private/tmp/linepay-v2-benefit-parity-quick.log`. Documentation checks passed (1012 links,
  5 tooling tests). No native production source changed in this slice.
- The Kotlin boundary suite rejects incomplete/unconfirmed eligibility, duplicate/overlapping
  segments, inconsistent reused rule IDs, fixed-period misuse and invalid observations. A timezone
  mismatch remains not comparable with no inferred paid/difference. Decimal capacity refusal is
  conservative; the corpus does not claim all extreme-value or platform behavior is identical.
- Android Compose app/state, full payroll/audit parity, migrations, actual provider crypto and
  runtime/E2E remain pending. Native iOS QA still awaits the already requested Xcode component
  setup, followed by diagnosis of the retained Files-provider failure. No SDK terms were accepted,
  website publication performed, archive uploaded or App Store state changed. Overall goal active.


## Scoped paycheck comparison parity checkpoint

- Added pure Kotlin configured-gross assessment plus sixteen independent shared cases consumed by
  the existing Swift assessor. Expected full-period gross requires confirmed complete work and a
  confirmed gross basis. Cash wages exclude separate per diem unless explicitly included; absent
  allowance observations stay unknown. Missing calculations never create a zero expectation.
- The corpus checks match/possible directional differences, half-cent and sub-cent wage-comparison
  rounding, missing work/basis, unsupported rules, unreviewed fields, legacy rounding, pending
  weekly review, per-diem scope and offsetting allowance differences. Paid precision and selected
  source component IDs are preserved. The 48-hour synthetic case requires weekly review; the
  Android flag represents a pending review, not a weekly-rate implementation.
- Both focused consumers passed all sixteen cases. Final strict offline Gradle suite passed;
  actual JUnit XML confirms **70 tests, zero failures/errors/skips** (67 prior/shared checks plus
  3 new negative-money/currency/immutable-receipt boundary tests). Log
  `/private/tmp/linepay-v2-gross-jvm-final.log`. Initial sandbox run could not create Gradle's
  local lock-coordination socket; the authorized retry passed without changing verification.
- Required quick gate passed: **74 repository tests, strict Swift format, 131 domain tests in
  19 suites**, log `/private/tmp/linepay-v2-gross-quick.log`. Focused native consumer log
  `/private/tmp/linepay-v2-gross-native.log`. A test-only Swift compile mistake (throwing decimal
  parsing inside nonthrowing assertion autoclosures) was fixed by parsing expected values first.
- This is configured-gross/allowance comparison, not full wage-line/hours/guarantee mapping,
  period matching, complete timeline transitions, Android app state/UI/history, actual runtime
  or legal completeness. Persisted verdicts require immutable calculation/fact snapshots; no
  Android persistence or cross-client state admission is implemented by this slice.
- Read-only host recheck still returns Xcode first-launch status **69**, CoreSimulator **1171.7**,
  with only original setup PID 79905 (diagnostic parent 79881) waiting. No duplicate Simulator
  invocation, component/runtime installation or native test was started. Owner setup/SDK-terms/
  website publication answers remain pending. No archive/upload/submission/public release.
- Overall all-stages goal remains active. Final native Files failure diagnosis, real device gates,
  full Android/PWA workflows, localization, source rights/library, templates and release remain.


## Local browser workflow and recovery checkpoint

- Added `apps/web` as an actual dependency-free browser client: confirmed profile → explicit
  period/payroll timezone → actual work/break/callout facts → explained cash wages and separate
  per diem → scope-confirmed paycheck preview → separately saved immutable check → closed
  period/history. New profiles do not change earlier periods; removing open work leaves saved
  checks on their exact earlier snapshots. Empty unaudited periods have a discard confirmation.
- Pure BigInt rational pricing consumes all **19 shared configured-pay fixtures**: local midnight,
  DST, breaks, daily tiers, highest weekday premium, physical/split callout minima, separate
  allowance and exact-second cent boundaries. Daily boundaries must be whole elapsed seconds;
  unsupported schedules/date/off-schedule/legacy production policies fail explicitly. Exact
  multiplier text is preserved. Separate gross assessment consumes **16 shared scope cases**;
  the legacy case tests a review flag against independently priced wages, not legacy admission.
- Local IndexedDB writes request strict durability, wait for transaction completion and compare
  current revision inside the write transaction. Stale tabs abort rather than overwrite newer
  state. Closed/history receipts and original rule definitions remain immutable. Added a meaningful
  regression for conflicting definitions under one rule ID/version and explicit aborted-read refusal.
  Unknown format/fields or inconsistent same-version retained receipts fail closed.
- WebCrypto password exports implement the shared authenticated AES-GCM/PBKDF2 envelope and
  public Unicode vector. Actual financial state is explicitly web snapshot/state v1; native
  snapshots are rejected until a full schema migrator can preserve their records. Export/restore
  clear password fields; input controls are disabled during protection/unlock. A real download
  is still distinct from a verified OS Files/iCloud save. Restore authentication/inspection does
  not mutate records; replacement requires a separate explicit confirmation and revision guard.
- Final Node suite **43 passed, zero failures/skips**, log
  `/private/tmp/linepay-v2-web-domain-final.log`. Includes exact money, 19 shared pay, 16 gross,
  DST gap/fold/calendar refusal, invalid/unknown state, rule identity, retained receipts, actual
  cipher-vector/wrong-password/authenticated-region rejection and fresh random transport checks.
- Real Chromium **155.0.8059.85** and Playwright WebKit **26.0** passed the nine-check local journey:
  exact 19.99 half-hour → 10.00; preview-before-save; 1.00 possible shortfall; closed snapshot
  survives a new profile; actual encrypted download; wrong password leaves current records;
  destructive synthetic reset → inspect (still empty) → explicit exact restore; stale-tab write
  refusal; narrow/dark/enlarged text; real service-worker/IndexedDB reload after origin shutdown.
  A fresh no-worker context fails against that stopped origin. Every observed app request was
  a same-origin shell GET; no pay data was sent. Reports/captures `.build/web-e2e/{chromium,webkit}/`.
- Initial Chromium failure exposed an implicit gross-basis select label including its options;
  fixed with explicit label/ID. Initial WebKit offline-emulation reload failed with an internal
  browser error, retained `/private/tmp/linepay-v2-web-webkit.log`. Upstream Playwright issue
  [42775](https://github.com/microsoft/playwright/issues/42775) reproduces this even for literal
  worker responses. Both final engines use a genuinely stopped origin and a fresh negative control,
  without intercepted successes. Prior Chromium offline-emulation itself also passed. Final logs
  `/private/tmp/linepay-v2-web-{chromium,webkit}-final2.log` follow the final rule-identity guard.
- Inspected actual mobile ledger and 320px, 26px-root dark viewport captures: reflowed controls,
  legible primary amount and no horizontal overflow. Work is presented in its saved payroll
  timezone; original UTC instants remain in the retained facts. Home-screen PNG is an unchanged
  copy of the existing native app icon. No generated/third-party brand assets were introduced.
- ADR 0018 records browser storage/privacy/state/version/update policy. Shell cache has an explicit
  asset allowlist and waits for old tabs to close; no forced form reload, user-data cache, external
  scripts/fonts or backend. Node 22 and Python suffice to run the local client. Formatter download
  via npm exec was blocked by the package-policy hook; the permitted --no-install invocation
  returned formatter 3.9.10 (with npm's installation warning), then formatted only browser source.
  No runtime package/dependency file was introduced. Do not claim the initial command succeeded.
- This is the first complete local browser journey, **not full PWA/native parity**. Weekly/legal
  entitlement, source/evidence/agreement/benefit/resolution/OCR/voice/report workflows, effective
  transitions, native financial-state interchange, commerce/localization, physical/installed-PWA
  and authorized public deployment remain pending. No Xcode/SDK setup, remote push/website
  deployment, signed archive, App Store upload/submission or public release occurred in this slice.
  The original all-stages goal remains active; release completion is unproven.

- Checkpoint checks: 1,023 local documentation links, 5 documentation-tool tests, active-copy/
  inventory checks and diff whitespace checks passed. Native production code did not change;
  no Simulator rerun was attempted while host setup remains unresolved. Added a contents-read
  GitHub workflow for the 43 domain/state/crypto checks plus both browser journeys, using the
  existing pinned checkout/artifact actions, official setup-node v6 SHA read through GitHub API,
  and locally tested Playwright 1.55.0. Hosted CI has **not run**; workflow source is not a green
  hosted receipt. Browser tools remain development-only. A package-hook parser falsely treated
  quoted prose in the file-writing command as install targets; verified the actual Playwright
  1.55.0 release at primary PyPI (August 28, 2025, all file SHA-256 metadata present) before using
  the normal patch tool for the file-only edit. No local browser/runtime install was performed.


## Browser fund workflow, immutable revisions and schema-v1 recovery

- Entry was clean `192cab9`; the previous goal turn made concrete progress with the local browser
  payday/recovery client. Continued the original all-stage objective by adding the separate fund
  workflow rather than treating that first client journey as full PWA delivery.
- Pure `linepay.web.confirmed-benefit/1` consumes all **13 shared fund fixtures** independently of
  Swift/Kotlin. Confirmed hour/day/percentage/fixed-period rules multiply explicit eligible quantities;
  raw components sum before one fund-total rounding. Mixed bases do not sum units. Fund, dates,
  timezone and currency must be comparable; missing/unconfirmed statements and units-only results
  preserve unknown amounts. Statement precision is retained: 350 minus 350.001 is **-0.001**.
- Added actual browser Benefits navigation/editor: independent contribution period and timezone,
  named fund/currency, explicit eligibility segments and effective-scope confirmation, source-reference
  note, optional confirmed/unconfirmed statement observations, review-before-save and append-only
  revisions. No wage-hour/OT mapping or eligibility is inferred. Wage records/verdicts never change.
  Material segment/scope changes clear rate/completeness confirmations; source changes clear source
  confirmation. All material edits discard the unsaved preview. References render as text, not markup.
- New web state **v2** retains separate fund checks/revisions and validates all retained inputs/results.
  Known v1 is checked against its exact original keys, copied and augmented only with empty fund
  history; reading migration does not persist, advance revision or reprice wages. Unknown v1 fields
  and future versions fail closed. Snapshot container/encryption stay v1; native snapshots still fail
  deliberately until an actual full financial-state migrator exists. ADR 0018 records the schema change.
- Frozen `apps/web/tests/fixtures/web-state-v1.json` was generated and validated through the actual
  `192cab9` modules copied into ignored `.build/web-v1-reference/`, not merely a guessed old object.
  It retains a synthetic closed 400-wage result and 25 possible-difference check. The first generator
  attempted to reuse a dotted shared-contract rule ID outside the v1 browser identity grammar and
  failed before writing; replaced it with an explicit synthetic allowed ID and verified against the
  actual v1 validator. All original profiles/work/calculations/assessments survive migration tests.
- Added negative/capacity regressions: eligibility confirmation, overlapping/duplicate segments,
  immutable rule definition (including uppercase UUID alias), fixed-scope misuse, negative/invalid
  observations and currency mismatch. Exact decimal products preserve 26 fractional places; more
  than 38 significant digits require review. Large exact totals stay internal rationals instead of
  being reparsed through the bounded input grammar. These are bounded parity checks, not complete
  native Decimal-capacity/legal equivalence.
- Final **65 Node tests passed**, no failures/skips, log
  `/private/tmp/linepay-v2-web-fund-domain-final.log`: 19 shared pay, 16 shared gross, 13 shared fund
  plus meaningful money/time/refusal/state/migration/crypto cases. Required quick gate passed:
  **74 repository tests, strict Swift formatting, 131 domain tests in 19 suites**, log
  `/private/tmp/linepay-v2-web-fund-quick.log`. No native production source changed.
- Final actual Chromium **155.0.8059.85** and WebKit **26.0** each passed **15 browser checks**,
  including eligibility/source re-confirmation, 350 missing-statement expectation, later 350.001
  statement producing -0.001 without changing the first revision or cash wages, encrypted download,
  wrong-password no-mutation, destructive synthetic reset and exact v2 recovery, actual encrypted
  v1 inspect-before-replace/migration, stale-tab refusal, and real stopped-origin offline history.
  A fresh no-worker control fails against the stopped origin; requests are only same-origin shell
  GETs. An actual offline percentage editor separately shows 61.73 expected from 5% of 1234.56,
  labels quantity as eligible earnings with currency, and leaves saved records unchanged on preview.
- Reports/captures `.build/web-e2e/{chromium,webkit}/`; final logs
  `/private/tmp/linepay-v2-web-fund-{chromium,webkit}-final3.log`. Inspected the enlarged dark fund
  and percentage viewports: 350.00 / 350.001 / -0.001 remain visibly distinct, and eligible earnings
  are displayed as USD 1234.56, not a percent or hour count. Initial browser run caught a missing
  Benefits navigation button after a text replacement missed formatted HTML; fixed the actual
  entry point and reran without weakening selectors/assertions. Failure log retained separately.
- Source-reference notes remain worker-provided; originals, verified source rights/eligibility,
  timing/fringe compliance and deductions are not added by this workflow. Full PWA feature/state
  parity, native interchange, installed/physical PWA, localization, source/evidence/report/OCR/voice/
  resolution and commerce work remain. No runtime/SDK install, new device, remote push/deploy,
  archive/upload/submission or public release occurred. Full v2/release completion remains unproven;
  the original goal stays active while independent implementation can continue.


## Portable rule drafts and independent recipient confirmation

- Previous goal turn was concrete progress (`3edf4bd`), and this turn entered a clean checkout.
  Added the actual browser crew-template workflow plus a shared native codec; kept the original
  all-stage/release objective intact. Native UI/Android and release remain pending, not replaced
  by this bounded browser/native-domain delivery.
- New UTF-8 `.linepayrules` contract v1 is **selected worker-provided parameters**, not an agreement,
  source approval or financial backup. Header records independent template UUID/revision, title,
  exact scope and **highestApplicable** precedence. Rules carry explicit currency, exact decimal
  strings, ordered daily/weekday premiums, guarded isolated minimum, distinct configured/omitted
  allowance and explicit aggregation rounding. Unsupported schedules/date/effective/weekly/legacy
  policies refuse rather than disappear. Bounds are mechanical representation limits, not wage law.
- Export defaults omit hourly wage/per-diem amounts and never copy private profile/period IDs,
  work/paycheck/fund/evidence records, identities or source annotations. Including amounts clears
  the previous exact-file/rights preview; the user explicitly re-reviews before downloading.
  Title/conditions can identify a group; no anonymous/official/verified-pack claim is made.
- Import inspection creates no profile. Omitted rate is blank, not zero. Configured allowance
  needs the recipient's own-amount/not-applicable choice; absent configuration is not waived.
  Two explicit applicability/value confirmations precede a new profile for future periods. Exact
  source packet and recipient choices/flags are retained atomically. Existing wage/fund histories
  never change or copy to the recipient. A new rate needs a new profile/confirmed choice.
- Web state **v3** adds `templateOrigins`, validates profile/packet/choice consistency, rejects
  orphaned/duplicate origins or conflicting contents under one source ID/revision, and retains
  provenance through encrypted recovery. Known v1/v2 migrate only by adding empty missing
  metadata. Frozen synthetic v2 fixture was generated/validated through actual `3edf4bd` modules,
  complementing v1 (`192cab9`). The container/encryption version stays 1; native financial-state
  admission is still unsupported. ADR 0019 and BR-070–074 define this new data/ownership boundary.
- Pure Swift `CrewRuleTemplate` and independent browser codec consume all **five shared fixtures**,
  covering omitted/included values, unconfigured allowance, multiple premia, UTF-8 title and exact
  CAD/callout/rounding. Native codec reads Data and explicit caller arguments only; no random ID,
  clock, locale, file/UI/storage/network or new runtime library. It exposes the required calculation
  policy and requires explicit own monetary values/confirmation. It does not wire native Files UI.
- Both byte decoders reject unknown/private fields, numeric money, invalid bounds/precision,
  unreviewed adoption and escaped duplicate monetary keys. Foundation/JSON.parse validate syntax;
  a bounded object-key pass rejects duplicate aliases before typed admission. Native UTF-16/raw-NUL
  files refuse the explicit UTF-8 contract. Amount strings are exported canonically without loss;
  omitted values remain null. Sender identity/display name/source rule IDs are not serialized.
- Final **77 Node tests passed**, no failures/skips, log
  `/private/tmp/linepay-v2-crew-domain-final.log`. Required quick gate passed **74 repository tests,
  strict Swift format and 134 domain tests in 20 suites**, log
  `/private/tmp/linepay-v2-crew-quick-final2.log`. Native codec's three tests include all five shared
  wire cases plus privacy/refusal regressions; no native Simulator or release-gate pass is claimed.
- Actual Chromium **155.0.8059.85** and WebKit **26.0** each passed **22 browser checks**, including
  reviewed file download, default amount/identity omission, explicit inclusion invalidation,
  escaped duplicate refusal, actual file input in a separate recipient context, no profile on
  inspection/unknown allowance, own 75 hourly/120 allowance adoption with source provenance,
  new-period expected wages 75, exact sender-history preservation, and actual recipient encrypted
  export → destructive synthetic reset → inspect (still empty) → confirmed provenance recovery.
- The same journeys also recover actual encrypted v1 **and v2** payloads with wage/fund histories
  unchanged, test stale-tab refusal, and reopen offline against a truly stopped origin with a
  failing fresh no-worker control. All observed app requests are same-origin asset GETs; no pay
  data was sent. Logs `/private/tmp/linepay-v2-crew-{chromium,webkit}-bootstrap.log`; reports/captures
  `.build/web-e2e/{chromium,webkit}/`. Inspected actual export/recipient review screens: omitted
  amounts and unreviewed allowance are visibly distinct; human-readable precedence/rounding are
  shown. Synthetic transfer is engineering evidence, not observed real-crew adoption or OS delivery.
- No third-party runtime, backend, telemetry, account, SDK/device install, external message,
  website/remote push/deploy, signed archive, App Store upload/submission or public release occurred.
  Native iOS profile-origin storage/Files/UI and Android support still need implementation/runtime
  proof. Official source rights/library, broader PWA parity, localization/device gates and all
  final native/store evidence remain part of the active goal. Existing pending owner inputs are
  unchanged; do not repeat or bypass the Xcode/SDK/site authorization boundaries.

- Startup follow-up (same slice): the final2 Chromium rerun failed opening a fresh legacy context.
  The original failure handler captured the main page, and an older green report remained present;
  those were inadequate evidence. Updated the harness to clear its prior report at start, write
  explicit failed receipts, bind receipts to the runtime source SHA-256, reject mid-run source
  changes, and capture every context plus console/resource failures. Do not count stale reports as
  passes. No startup assertion was weakened or timeout relaxed to obtain a green receipt.
- A separate 12-context probe reproduced one persistent missing-entry screen even after 15 seconds;
  eleven opened in 39–72 ms. The failing context recorded **ERR_CONNECTION_RESET** fetching
  `assessment.mjs`, a failed dynamic module import and no databases. This proves an asset delivery
  failure, not a stored-record validation failure. Current Python's default server queue was 5;
  increased the actual loopback test server to 64. With that queue and guarded bootstrap,
  **40/40 cold contexts opened normally, maximum 278 ms**. This bounded result supports the queue
  change; it is not a universal browser/network reliability claim or proof of a storage repair.
- Added real app bootstrap error/reload UI and a static reload fallback. A controlled negative
  test aborts one module in an isolated no-worker recovery context, requires the visible error,
  removes the route, and verifies real reload preserves the previously restored wage/fund state
  exactly. Positive/offline tests still use actual responses and a stopped origin, without mocked
  success. Final Chromium/WebKit bootstrap logs each passed **22 checks** with identical runtime
  SHA-256 `a9a2dc89a7d87bc11a391360b797befa7d95375149ea001fb74930a7af5b7003`.
  Logs: `/private/tmp/linepay-v2-crew-{chromium,webkit}-bootstrap.log`. Cold diagnostics are ignored
  `.build/web-startup-{diagnostic,queue64}.json`; original startup failures remain in their distinct
  `/private/tmp/linepay-v2-crew-chromium-{final2,observed,network-observed}.log` receipts.

- Final checkpoint: 1,032 local Markdown links, 5 documentation-tool tests, legal active-copy/inventory checks, agent-harness checks and diff whitespace checks passed. Inspected the actual asset-load error/reload screen and its preserved-record recovery. Latest WebKit capture rerun also passed 22 checks at the same runtime hash; no further client source changed. Hosted CI, native UI/device and store gates remain unproven.


## Browser saved-check follow-up and reviewed evidence reports

- Entered clean `5a42523`; the previous goal turn made concrete progress with crew-file exchange.
  Read-only native recheck still returns first-launch **69** / CoreSimulator **1171.7**. Did not
  invoke simctl, create a duplicate setup prompt or claim native runtime availability. Continued
  the missing browser resolution/report workflow within the original all-stage objective.
- Added the existing native six worker-reported statuses, appended to an exact saved period/check
  with a bounded nonempty note. Corrected/explained/shared never change wages, the original verdict
  or money-recovered counters, and never send a message. State validation rejects unknown status
  types, invalid Unicode/controls, duplicate IDs and orphaned/wrong-revision relationships.
- Web state **v4** adds only `resolutionEvents`; known v1/v2/v3 migrations preserve every previous
  profile, wage/fund receipt and crew origin and add no invented follow-up. Frozen synthetic v3
  fixture was generated and validated using actual `5a42523` modules in ignored `.build`.
  Container/encryption version stays 1; native financial-state portability remains unsupported.
- Reports are receipts of one selected saved calculation/assessment. No pay calculator is called
  by the renderer; a newer personal profile cannot reprice the report. Saved gross/unknowns,
  confirmed basis, period/zone, creation instant, configured rules, scope/limitations and rule/engine
  references remain traceable. Guarantee top-ups do not claim actual clock time. A worker-recorded
  correction remains distinct from the unchanged possible-shortfall comparison above it.
- Default copies exclude follow-up history, detailed clocks/breaks and imported-draft text. Each
  is an explicit opt-in for the selected check, not another revision's notes. Even minimized copies
  contain sensitive figures/dates/reference IDs and are not anonymous. Originals are not attached.
  A 2 MiB report limit refuses, never silently truncates a history or ledger tail.
- Review and actual HTML download use the same prepared UTF-8 bytes; a changed privacy choice
  invalidates actions/preview and revokes its URL. Navigation/mutation disposes previews. Only the
  real prepared Blob document enables actions, not an initial blank frame. Independent download
  URLs have bounded lifetimes so a UI refresh does not abort an initiated user save.
- Preview is a sandboxed Blob document, no scripts/forms/external resources. Parent policy permits
  Blob frames and only a SHA-256-admitted fixed inline report stylesheet; no general inline-script/
  style relaxation. Dynamic values are escaped. Print/save PDF targets the reviewed report frame,
  not the surrounding app/private forms. Actual OS dialog/provider delivery is still unverified.
- Final **86 Node tests passed**, no failures/skips, log
  `/private/tmp/linepay-v2-report-domain-final.log`. Includes all prior fixtures, relationship/Unicode/
  type/capacity refusals, old-schema no-mutation, private-by-default reports, selected-revision notes,
  exact optional-source admission, no-reprice behavior and stylesheet/parent-CSP hash agreement.
  Quick gate passed **74 repository tests, strict Swift format and 134 domain tests in 20 suites**,
  log `/private/tmp/linepay-v2-report-quick.log`; native production source did not change.
- Actual Chromium **155.0.8059.85** and WebKit **26.0** each passed **26 checks**, logs
  `/private/tmp/linepay-v2-report-{chromium,webkit}-final2.log`, source SHA-256
  `53515c1c62d3c0aa6ad32cc9463f56416513fbb8946bf082b4d78e0ba86bf4b5`.
  Saved 1.00 possible-shortfall receipt survives a corrected-status note unchanged. Real minimized/
  detailed downloads match the reviewed document, source text cannot execute, options require renewed
  review and downloads do not auto-mark shared. Encrypted reset/recovery retains follow-up exactly;
  actual old-schema 1/2/3 recovery retains original records; real stopped-origin report review works.
- The first final offline attempt tried to use report controls inside a closed saved-check disclosure
  after reload and failed in both browsers. Opened that historical check through its actual summary
  control, then reran unchanged report assertions. Failure logs remain separate from the final passes;
  no saved record or storage data was missing and no selector/assertion was weakened.
- Chromium actually printed the downloaded HTML with its PDF engine: minimized **2 pages**, detailed
  **4 pages**. Bundled pypdf **6.10.0** extracted the saved 1.00 difference/verdict, verified absence
  of private notes in the default copy, and found the complete Unicode/script-as-text note plus
  `SYNTHETIC-REPORT-TAIL` only in the opt-in copy. Poppler rendered actual pages; inspected summary,
  rules/components and note continuation/tail. Corrected a paper-column width so normal currency/
  amount pairs stay together, then regenerated and rechecked the actual PDFs. Artifacts are ignored
  `.build/web-e2e/chromium/synthetic-{minimized,detailed}-report.{html,pdf,txt}` plus rendered PNGs.
- This is browser PDF rendering/HTML/download evidence, not native iOS PDF generation on the current
  candidate, actual OS print/save, iCloud/two-device transfer, physical PWA or recipient delivery.
  No mocked successful network responses: asset GETs are local-origin; report Blob views are local.
  The existing controlled load-error test remains a negative abort/reload with unchanged records.
- ADR 0020 and BR-075–079 define data/privacy/lifecycle boundaries. No backend, collector, account,
  SDK/device install, external message, website publication, remote push, archive/upload/submission
  or public release occurred. Broader PWA/native/Android/source/library/localization/device and final
  store gates remain. Full v2/release completion is unproven; the original goal remains active.

- Final checkpoint: 1,034 local Markdown links, 5 documentation-tool tests, legal active-copy/inventory, agent-harness and diff checks passed. Inspected final printed amounts and final note continuation/tail PNGs after regeneration. CI artifact configuration now retains only the known synthetic report HTML/PDF files alongside screenshots/receipts; hosted CI itself has not run. No further runtime source changed after the source-bound 26-check passes.


## Versioned browser effective-date plans and shared temporal parity

- Entry was clean `f7cbe82`; previous turn was progress. Continued a hard payroll-parity gap, not
  a release-completion claim: original browser engine **v1 remains unchanged**, and explicit dated
  plans use **linepay.web.configured-pay/2**. Baseline/no-plan historical audits retain their exact
  v1 path; dated audits resolve their recorded immutable plan rather than the current/latest one.
- New pure v2 applies complete confirmed snapshots at payroll-local midnight. Exact instants,
  recorded timezone, unpaid breaks, daily cumulative positions and highest applicable premia stay
  explicit. Active snapshot determines rate/allowance; compatible category/multiplier numerators
  aggregate across rate versions before rounding. One second each at18 and54/hour is0.02, not0.03.
  Binding callout guarantees crossing a change refuse. Exact quantities/applied rates and full rule
  snapshots are saved with plan ID. No pay function reads a device timezone, wall clock or storage.
- Shared temporal corpus independently states **8 prices + 5 refusals**, consumed by Swift, Kotlin
  and browser. Covers rate/allowance/threshold transitions, one interval and unpaid break across
  local midnight, three versions, half cents, New York fall-back and a future change preserving
  earlier work. Duplicate dates, reused versions, currency/mode mismatch and binding guarantees
  refuse. This is bounded temporal parity, not full agreement/legal/weekly/timezone coverage.
- The actual native `AgreementTimeline` contract requires compatible rounding scale/mode. New
  Kotlin corpus initially failed exactly the mode-change refusal: **79 domain tests, 1 failure**,
  `/private/tmp/linepay-v2-timeline-android-before.log`. Added that compatibility guard instead of
  weakening the fixture. Strict offline Gradle then passed; actual JUnit XML confirms **83 tests,
  zero failures/errors/skips** including backup. Log `/private/tmp/linepay-v2-timeline-android-after.log`.
  No Android SDK/runtime/UI or source/legal review is established by JVM success.
- Web state **v5** retains append-only confirmed `ruleTimelines`: period, explicit creation context,
  source-profile copies, effective dates and fresh immutable rule versions. Preview/confirmation
  precedes adoption; edits invalidate it. Latest plan changes only the open ledger. Old plans/checks
  remain retained, and closed results cannot adopt a later plan. Missing/altered sources, plans,
  versions or unsupported engines fail closed rather than reprice. Reports use their saved dated
  rates/rule references; optional draft attribution follows that audit's retained source profiles.
- Prior schemas1/2/3/4 gain only empty missing metadata. Frozen synthetic v4 fixture was generated
  and validated through actual `f7cbe82` modules. Original profiles, wage/fund receipts, draft origins
  and follow-up survive; no historical plan/event is invented. Container/encryption version stays1;
  native financial-state interchange remains unsupported. ADR0021 and BR080–084 own these rules.
- Final browser domain suite **103 tests passed**, no failures/skips,
  `/private/tmp/linepay-v2-timeline-domain-final.log`. Native focused temporal consumer **2 tests**
  passed all13 cases, `/private/tmp/linepay-v2-timeline-swift.log`. Required quick gate passed
  **74 repository tests, strict Swift format and136 domain tests in21 suites**,
  `/private/tmp/linepay-v2-timeline-quick.log`. Existing pure native production Swift was unchanged.
- Actual Chromium155.0.8059.85 and WebKit26.0 each passed **29 browser checks**. Explicit preview
  writes nothing; confirmed Oct6 profile55/day-allowance90 produces1005 wages/170 allowance versus
  baseline950/160. Earlier950 engine-v1 audit is byte-for-value unchanged. A new1005 audit retains
  its engine-v2 plan. Revising the date toOct7 changes the current ledger back to950 while that
 1005 audit/report stays fixed. Close and actual encrypted export/reset/inspect/replace retain both
  plans and receipts. Captures include actual proposed-plan and enlarged390px dark closed history.
- First browser run exposed a real data-entry race: only the first of two rapid work saves remained
  (400 instead of950), with no storage error. The busy guard left old controls editable while a
  previous commit refreshed the form. Capture handler values synchronously, then disable prior
  enabled controls until settlement; leave separately disabled/new DOM controls owned by their
  handlers. Failed writes retain inputs. The unchanged rapid two-shift regression then passed,
  along with all prior encrypted export/restore/report/import workflows. No work/value was patched.
- Browser logs `/private/tmp/linepay-v2-timeline-chromium-final.log` and
  `/private/tmp/linepay-v2-timeline-webkit-final.log`, reports/captures `.build/web-e2e/{chromium,webkit}/`,
  identical runtime SHA256 `a772ccb91935c7568d7bcf79f1361eacc90bf2c2f7221a96c8085d44f467064c`.
  Real stopped-origin, negative no-worker, controlled module-error recovery, privacy and old-schema
 1/2/3/4 recovery remain in that run. Current branch was not pushed; hosted CI has not run.
- No native Simulator/physical-device evidence, runtime/SDK install, duplicate Xcode setup,
  external message, website publication, archive/store submission or public release occurred.
  Native/Android UI/state, wider PWA/source/library/localization/physical and final release gates
  remain required. The original all-stage objective stays active; full completion remains unproven.

- Final historical-copy check: both browsers additionally downloaded the exact selected engine-v2
  report after a newer plan existed; original plan ID/date/1005 amount remained and the newer plan
  ID was absent. Final browser count is29 per engine at the same runtime hash. Chromium printed
  that actual downloaded HTML to a3-page PDF; bundled pypdf verified1005, Oct6 and55/hour, and
  Poppler/render inspection confirmed dated snapshots and applied component rates on paper.
  `.build/web-e2e/chromium/synthetic-effective-report.{html,pdf,txt}` is synthetic local evidence,
  not OS/provider/native/device delivery. Final1,043 local Markdown links, 5 doc
  tests, legal inventory/active-copy, harness and diff checks passed. No further runtime source
  changed after the source-bound passes. Goal remains active; full v2/release is incomplete.


## Calendar paycycles and source-period comparison checkpoint

- Continued from clean `ddfc768`. Shared calendar v1 defines **14 explicit boundary cases and
  7 refusals**: weekly, biweekly, semi-monthly, custom, leap/month/year edges, LA spring/fall,
  New York 25-hour day and Sao Paulo skipped midnight. Swift and browser consume the same
  independently specified local/UTC endpoints. A paycycle does not define a statutory workweek.
- New pure Swift helper normalizes both date boundaries to the first local instant. The native
  adapter delegates only new window creation; retained historical windows are unchanged.
  Sao Paulo's November 4–11, 2018 starts at01:00 and ends at00:00: **167 hours**. Previous calendar
  addition could carry01:00 into the following week. Added an App regression, but that App test
  has **not run** while the known Xcode/CoreSimulator setup block remains. Domain success is
  not native App/Simulator evidence.
- Browser period setup previews explicit cadence/date/zone/boundaries before creation; edits
  invalidate review. New comparisons retain independently entered paycheck source dates and
  reviewed date-context timezone. Blank dates are never copied from the ledger. A wrong or
  unconfirmed scope saves a noncomparable review with null expected gross/difference and no
  directional components. Only confirmed matching dates/zone proceed through existing guards.
- Original configured-gross v1 remains unchanged for historical replay. New engine v2 retains
  source scope with its receipt. General browser state v6 adds owned schedules/scopes atomically;
  schemas1–5 gain empty metadata without invented cadence, dates or reclassification. Frozen v5
  fixture was generated/validated through actual `ddfc768` modules and includes a second dated
  600-wage receipt. Missing/orphan/changed source facts or calendar boundaries refuse recovery.
  Reports disclose saved cadence/source dates and confirmation; legacy missing provenance stays
  explicit. Container/encryption remains version1. ADR0022 and BR085–089 own these boundaries.
- Final Node suite **129 tests passed**, no failures/skips,
  `/private/tmp/linepay-v2-period-domain.log`. Focused Swift consumer **2 tests** passed all21 cases,
  `/private/tmp/linepay-v2-paycycle-swift.log`. Required quick gate passed **74 repository tests,
  strict Swift format and138 domain tests in22 suites**, `/private/tmp/linepay-v2-period-quick.log`.
- Actual Chromium and WebKit each passed **34 E2E checks**: preview writes nothing, material edits
  invalidate confirmation, LA spring weekly167h/fall biweekly337h, invalid half-month refusal,
  leap February, wrong/unknown source period gives no25 shortfall, matching dates give25, empty
  discard removes only its owned metadata, and actual encrypted export/reset/inspect/replace
  preserves three source-scope reviews and fixed calendar windows. Device-context Tokyo does not
  change LA payroll boundaries. Legacy schemas1–5 recover without fabricated source metadata.
- Initial Chromium test incorrectly assumed the last v5 period was the original400-wage record;
  fixture intentionally also retains newer600. Corrected the test to open the first historical
  record explicitly. Stored records already deep-equaled the fixture; no product behavior/data
  was patched or assertion weakened. Final logs `/private/tmp/linepay-v2-period-chromium2.log`
  and `/private/tmp/linepay-v2-period-webkit.log`; source-bound receipts/captures under
  `.build/web-e2e/{chromium,webkit}/`, identical runtime SHA256
  `27ab4fb5b519735268f494563d940c7685672f9fa8ad5b55d62d7e19b798d561`.
- Chromium printed the actual downloaded minimized HTML to a **2-page PDF**. Bundled pypdf
  extraction confirms reported source dates, confirmed-same-period disclosure and saved1.00
  difference, without private synthetic notes; rendered/inspected page1 and the real calendar
  preview. This is browser rendering evidence, not actual OS print/save or physical/native delivery.
  Stopped-origin/no-worker negatives and controlled module-abort recovery remain in both passes.
- No native Simulator/physical proof, SDK/license acceptance, website publication, push, archive,
  App Store write or public release occurred. Owner responses for host setup, Android terms,
  physical device and exact website publication scope remain outstanding. Broader native/Android/
  PWA/source/library/localization/device and final store gates remain required. Goal stays active.


## Kotlin calendar parity and whole-date regression

- Continued from clean `50e3c5d`. Added the pure Kotlin calendar helper and direct shared-fixture
  consumer, without an SDK, Android app scaffold, dependencies, backend or persistence migration.
  Exact date/zone inputs produce immutable date/instant outputs; standard cadence ignores a stale
  manual-end field. Extra tests cover explicit-zone independence, missing/out-of-range custom
  input and nonexistent boundaries. The default-zone test restores the JVM setting in `finally`;
  the current JUnit task runs these tests serially.
- Expanded shared calendar corpus to **15 positive cases +9 refusals**. A Samoa week starting
  December26,2011 ends January2 local, only **144 elapsed hours** because December30 was skipped.
  Explicit skipped start/exclusive-end dates refuse. Browser already satisfied all new cases.
  Swift failed the spanning-week date/instant assertions (returned168h) and skipped-end refusal:
  `/private/tmp/linepay-v2-skipped-date-swift-before.log`. Changed Swift to advance UTC Gregorian
  date labels first, then resolve and validate both boundaries in the explicit payroll zone.
  Existing native windows are not recalculated. Added another native adapter App regression source;
  it remains **unexecuted** while the host setup block persists.
- First Gradle attempt was sandbox-blocked before tests by its local file-lock socket. Approved
  offline rerun then caught a new-data-class copy-visibility warning under warnings-as-errors.
  Applied Kotlin's consistent visibility annotation to the new internal constructor, preserving
  strict diagnostics; no compiler flag or test was weakened. Final cached offline Gradle passed:
  `/private/tmp/linepay-v2-calendar-android2.log`, JUnit XML **106 domain +4 backup =110 tests**,
  zero failures/errors/skips. Backup was unchanged/up-to-date; calendar tests actually executed.
- Required quick gate passed **74 repository tests, strict format and138 Swift tests in22 suites**,
  `/private/tmp/linepay-v2-skipped-date-quick.log`. The two Swift calendar tests now consume24cases.
  Full Node suite passed **132 tests**, zero failures/skips,
  `/private/tmp/linepay-v2-skipped-date-node.log`; its calendar consumer executes all24cases.
  The later App-test-only addition passed focused strict formatting; no native App execution claimed.
- Browser production assets did not change after the34-check Chromium/WebKit passes at runtime
  SHA256 `27ab4fb5b519735268f494563d940c7685672f9fa8ad5b55d62d7e19b798d561`.
  New cases ran at the domain layer; no new physical/browser/device claim follows from them.
  Cross-client timezone databases, wider transitions, native UI/runtime, Android app/state and
  final release checks remain separate. No SDK/license install, publication, store write or release.

- Final admission review also found the browser/Kotlin custom-end path validated the following
  boundary but could admit a nonexistent manual last date. Added an explicit date-existence check
  and shared refusal rather than normalize it. Final corpus is **15 windows +10 refusals** in all
  three consumers; browser production runtime changed for this refusal. Final Node **133 tests**
  passed (`/private/tmp/linepay-v2-calendar-node-final.log`), strict offline Gradle passed **111
  tests** (`/private/tmp/linepay-v2-calendar-android-final.log`), and final quick passed **74 script
  tests/138 Swift tests/strict format** (`/private/tmp/linepay-v2-calendar-quick-final.log`).
  Both final v8 app-shell runs completed with terminal exit0: **34 checks each**, identical runtime
  SHA256 `26ad7cc8ff36c07ed290644c00268089e0d6b7ccdf1f8b0f033f6af0b221b3f6`.
  Logs `/private/tmp/linepay-v2-calendar-chromium-v8.log` and
  `/private/tmp/linepay-v2-calendar-webkit-v8.log`; source-bound reports and synthetic captures under
  `.build/web-e2e/{chromium,webkit}/`. The cache name advances to v8 so the earlier worker shell
  can be replaced; these tests verify fresh worker/offline paths, not an installed-device upgrade.
  Existing report/PDF evidence belongs to its recorded earlier source; report code was unchanged.
  Goal remains active; full v2 and App Store/manual public release are incomplete.


## Native crew-file workflow and retained recipient adoption

- Previous goal turn was progress (`50e3c5d`, `b49646c`); resumed at clean `b49646c` on
  `codex/v2-e2e`. The read-only `xcodebuild -checkFirstLaunchStatus` still returned69. No first-launch
  setup, duplicate admin prompt, Simulator creation/runtime/SDK install or unrelated process stop.
- Added native Settings → Crew rule drafts: fresh public template identity, omitted wage/allowance
  amounts by default, explicit rights choice and exact in-memory file review before system Files
  export. Title/revision/amount edits invalidate the prepared copy and rights review. Export never
  copies private profile/period IDs, work/audit history, notes, original sources or evidence bytes.
  The save callback distinguishes selected location from cloud upload/recipient delivery.
- User-selected import uses security-scoped coordinated reads off the UI actor, cancellation and
  a65,536-byte allocation cap. Strict UTF-8/schema/duplicate admission runs before inspection.
  Opening does not save anything. Own amount fields start blank even if draft amounts are present.
  Explicit applicability/value/currency/timezone/allowance review prepares the usual setup draft;
  unfinished setup replacement requires a separate choice. The four-step editor still owns final
  review/save, with source limitations visible. No automatic message or transfer is performed.
- New pure `CrewRuleAdoption` retains exact original bytes plus actual recipient wage/allowance
  choices, and reproduces final terms after decoding/before adoption. Native state schema8 retains
  frozen adopted agreement/version/timezone origins atomically with profile save; schemas1–7 add no
  invented origins. The existing backup state/container carries this metadata without a new crypto
  format. Domain round-trip, unknown/unconfirmed allowance, changed-term and decoded-choice tests
  passed **3 tests/1 suite**, `/private/tmp/linepay-v2-crew-adoption-domain.log`.
- Native has one profile: first-time adoption creates it; an existing worker gets a new immutable
  version for future periods only. Current-period correction and arbitrary dated scopes are blocked
  in the UI and model. Existing period/audit/history snapshots remain frozen. Incompatible currency
  or rounding refuses. Original draft and own choices remain associated with the adopted version;
  later edits cannot retain a stale adoption confirmation. No official pack/source approval is implied.
- Fixed explicit zero allowance admission in the native profile adapter (domain already allowed
  zero), retaining configured-zero versus absent. Preserve already reviewed pay-category rounding
  on subsequent manual edits, including bankers mode; legacy/manual initial defaults keep their
  existing path. Added **6 native App test sources** for inspection/preparation, unfinished/failed
  save preservation, future-only audit/history, backup/old-schema shapes, changed choices, zero and
  incompatible/preserved rounding. These tests are not executed native evidence yet.
- Direct installed-SDK compilation is available without launching Simulator. Strict language6,
  complete concurrency and warnings-as-errors checks compiled all production domain/App sources
  for arm64 iOS18 Simulator. The first attempt found an existing unnecessary `try` in the crew
  codec; removed it. A later check exposed mutable calendar capture warnings in benefits date
  bindings under the new SDK; capture the already configured calendar as a `let` instead. No
  isolation bypass, diagnostic suppression or compiler baseline change was introduced.
- Focused App-test typechecking initially lacked Apple's Testing framework/plugin paths; after
  supplying the installed originals, it caught two missing synthetic identity arguments in new
  tests. Corrected them; test-only typechecking passed. A final production+focused-test compiler
  run is in progress after the rounding-preservation review; record its terminal result below.
  This is compilation, not an app bundle/build-system/native App-test/Simulator/Files/visual PASS.
- Initial quick gate failed its guide-freshness regression, before native formatting/domain work.
  Reviewed mapped setup/privacy/support/billing/benefits/work/result pages, recorded only the five
  affected sources with specific reasons and kept unverified crew instructions internal. Corrected
  stale support-copy wording about optional v2 backup protection. Final quick gate passed **74
  repository tests, strict format and141 Swift domain tests in23 suites**,
  `/private/tmp/linepay-v2-crew-quick-final.log`; no user-guide render PASS: its required check stops
  with missing pinned Hugo0.165.0. Public guide changes were not deployed.
- ADR0023 and BR090–092 own the native state/adoption boundary. New workflow uses native Form,
  semantic tokens, explicit currency/unit labels, stable selectors, standard Files controls and
  dynamic rows. Actual light/dark/largest-text/VoiceOver/error/cancellation/Files acceptance is
  **pending**, as is native backup migration execution and physical handoff. Design is not approved
  from source inspection or the compiler. Native full gate remains blocked by host setup.
- Browser and Android sources were unchanged this turn; prior receipts are not new runs. No push,
  PR, named library/pack, external message, website publication, archive/store submission or public
  release occurred. All-stage scope and manual App Store release objective remain active/incomplete.

- Final entry-path review added optional welcome-screen inspection for a recipient without a profile;
  preparation returns to the normal onboarding setup, while Settings uses the existing editor sheet.
  Updated both affected guide-source reviews; existing manual setup instructions remain valid and
  native crew instructions are still pending actual UI acceptance. A final compiler refresh follows.

- Added native conflict admission: a retained public draft ID/revision cannot be reused with changed
  packet contents. Preparation checks existing identities; state validation uses one bounded map,
  rather than repeated pairwise decoding. Original recipient values remain separate from packet
  identity. The sixth focused App test covers this refusal; it remains execution-pending.

- Final frozen-source SDK run completed with terminal exit0: all89 production App files,14 domain
  files and2 focused test/support files compiled/typechecked (**105 sources**) for arm64 iOS18
  Simulator using the installed27.1 SDK, language6, complete concurrency and warnings-as-errors.
  No diagnostics in final log `/private/tmp/linepay-v2-crew-sdk-final.log`. Receipt
  `.build/v2-crew-typecheck/compiler-receipt.json` binds source SHA256
  `f63d7fba73a1719b041db0954aea811f8222badc98ac712c7572059f475362c5` and explicitly excludes
  linking/bundling/runtime/UI/Files delivery. One earlier run detected a source edit during compile;
  it failed and was replaced with this frozen-source pass, not relabelled green.
  Final quick at the same source passed **74 script tests/strict format/141 domain tests in23 suites**,
  `/private/tmp/linepay-v2-crew-quick-current.log`. The six App tests were **typechecked, not run**.
- Resolved the missing-Hugo build-tool block instead of treating it as a release dependency on the
  owner: downloaded the official0.165.0 Darwin universal package, verified its published SHA256
  `10ea75335975a13d0e73ac298402179335c55fa4e99d1687452d9cfa70b30d16`, and used `pkgutil
  --expand-full` inside ignored `.build/tools/hugo-0.165.0/` without installer/admin scripts or global
  installation. Official source: <https://github.com/gohugoio/hugo/releases/tag/v0.165.0>.
  Executable reports0.165.0/darwin-arm64. Required `user-guide/scripts/check.sh` now passes both root
  and `/linepay/` builds:24 HTML pages/21 search entries each, all internal links/fragments/assets,
  deterministic search tests,58 source reviews and4 screenshot-provenance checks. Log
  `/private/tmp/linepay-v2-crew-guide-check.log`. No public deployment occurred.

- Actual guide Chromium check first failed its stale no-JS browse-count20 assertion after the benefits
  page increased the generated task inventory to21. Corrected that bounded expectation, added actual
  support/benefits page coverage at each viewport and the new password-guidance assertion, and clear
  stale success receipts before running. Final **21 page/configuration checks passed** with real
  search/mobile navigation/dark preference/no-JS/keyboard/print checks,
  `/private/tmp/linepay-v2-crew-guide-browser-final.log`; synthetic captures/results under
  `user-guide/.qa/browser/`. Root/project HTML validation independently confirms21 search entries.
  This is documentation-browser evidence, not native App/Files proof or public deployment.

- Last native copy-only change displays a recoverable file-selection error instead of silently
  ignoring it. Frozen-source compiler rerun again passed with terminal exit0 and no diagnostics:
  `/private/tmp/linepay-v2-crew-sdk-checked.log`, final source SHA256
  `18317aacd815775b52968e5ce54f6b82f714f85d82b6c2827c83716d1574453e`.
  Receipt scope remains module emission/focused test typechecking, not native test execution.
  Final documentation checks:1,054 local links,5 documentation-tool tests, legal inventory/active-copy,
  agent harness and diff checks passed. New UI remains acceptance-pending; full v2/release incomplete.

- Final quick rerun after that copy change also exited0:74 repository tests, strict formatting and141
  domain tests/23 suites, `/private/tmp/linepay-v2-crew-quick-checked.log`. No native source changed
  after the final compiler receipt. Full native runtime/UI/release acceptance remains outstanding.


## Weekly review correctness before platform port

- Previous goal turn was progress (`f4dd8e1`). Resumed clean on `codex/v2-e2e`; read-only Xcode
  first-launch status still69. No Simulator/setup/admin prompt or SDK/runtime/license operation.
  Began inspecting the missing PWA weekly review, then found financially material native defects;
  corrected these before copying them to another client. PWA/Android weekly integration is still
  required; this checkpoint does not replace the all-stage objective with a narrower one.
- Added regressions against the original code:3 tests failed with12 issues,
  `/private/tmp/linepay-v2-weekly-safety-before.log`. The old engine excluded a240 noncreditable
  work premium from2400/48h regular-rate remuneration, producing2840 instead of independently
  calculated2860. It also calculated with unknown credit, negative decoded amounts, duplicate
  facts, wrong date/weekday, threshold80 and unsupported rounding. No expected answer was changed
  to fit those failures. New v2 re-admits decoded input/facts, includes confirmed non-overtime work
  premiums without credit and refuses unknown treatment or invalid arithmetic/allocation context.
- `WeeklyWorkFact` optionally retains exact worked seconds; old hours-only facts remain readable.
  Sum seconds and rate×seconds numerators before conversion. New allocation IDs derive from source
  fact identity, removing random IDs from the pure calculation; period order/residual conservation
  are deterministic. Multiply before division so a displayed rounded rate never sets the premium.
  New results use `linepay.weekly-regular-rate/2`; no automatic historical recalculation.
- New pure recorded-work collector clips both tails of crossing shifts, removes actual intersecting
  breaks, validates decoded break spans, splits at local midnights and chooses each dated snapshot.
  Retains source work/period identities, exact instants/seconds and applied references. Unrelated old
  periods no longer block a current review; relevant mixed rule/timezone context, overlapping or
  duplicate work refuse. Saved work/rules/calculations are not modified by collecting or reviewing.
- Primary-source review caught a further error in the old calendar-week assumption: the ordinary
  statutory workweek is fixed 168 elapsed hours and may begin at any hour, distinct from a paycycle.
  New collector requires an exact start instant and clips604,800 seconds. The native form requires
  explicit employer-boundary confirmation and displays its exclusive168-hour end. Configured
  weekday provides only an initial suggestion; no recurring anchor is inferred/migrated from it.
  Actual date/time/zone remain in new results; legacy missing context is not fabricated. UI lets
  the worker review non-midnight starts and local DST-shifted boundaries rather than force midnight.
- Native review now separately requires full-week work confirmation, reviewed straight-time wages,
  all other cash-payment classifications and boundary confirmation. Additional rows start unclassified;
  unknown treatment refuses. Explicitly warns that eligible extra-premium portions differ from full
  overtime lines; no inferred bonus/exclusion/credit. Material/date/rule/work edits invalidate results
  and confirmations; selecting a different week clears unsaved payment rows. Review remains ephemeral,
  separate from Pay, and does not clear paycheck weekly-review warnings or consume audit access.
- Corrected a native App-test fixture that previously called a Friday a Monday workweek: epoch
  1,800,000,000 was not the declared recurring weekday. It now uses independently checked Monday
  September7,2026 UTC. Kept its48h/2600 and two-period expectations, added reviewed remuneration/
  boundary requirements and a noncreditable-premium2860 check. Added a crossing-shift4h result
  while the original5h work stays unchanged. Four focused App tests now cover the application path;
  these have not run in Simulator while the host setup block remains.
- Generated `shared/contracts/weekly/legacy-result-v1.json` by compiling and executing **actual
  f4dd8e1 domain sources** in ignored `.build/v2-weekly-reference/`,
  `/private/tmp/linepay-v2-weekly-legacy-generation.log`. This original v1 receipt retains its known
  2840 result/allocation identity. Current regression preserves its decoded/re-encoded values, then
  explicitly calculates a separate v2 result2860. Fixture is historical synthetic software behavior,
  not correct current legal pay, a verified agreement or cross-platform backup admission.
- Focused weekly tests passed19 cases/3 suites after the fixed 168-hour correction,
  `/private/tmp/linepay-v2-weekly-fixed 168.log`. A further boundary-metadata regression is included
  in full quick: **74 repository tests, strict format and152 domain tests/25 suites passed**,
  `/private/tmp/linepay-v2-weekly-quick.log`. The new suites exercise classification, decoded input,
  seconds, legacy retention, both clipped tails/breaks, rate changes, overlap/relevant scope, spring
  168-hour Monday tail, fall excluded calendar hour and an explicit non-midnight start.
- Direct SDK compilation passed all current production and focused App/support test files with
  language6, complete concurrency and warnings-as-errors, source-bound receipt under
  `.build/v2-weekly-typecheck/`. It is not a native app build, link, App-test run or UI acceptance.
  A final copy-only credit-portion warning is being recompiled; record the final receipt below.
- ADR0024 and BR093–096 record the scope. Targeted primary eCFR778.105/778.207 review checked
  October 17; #42/legal applicability/professional review remains open. Existing native state8 and
  backup/crypto containers are unchanged. Updated candidate-labelled guide instructions and removed
  the inaccurate suggestion that an ephemeral weekly review automatically clears a paycheck warning.
  Native visual/VoiceOver, runtime, independent scope review, persistence and platform parity remain
  required. No account/backend, new dependency, actual pay-data upload or automatic transfer.

- **Remaining release blocker discovered during this review:** `PaycheckAssessment.swift` still
  gates its weekly warning on >40 hours in the single supplied calculation and the absence of any
  attached weekly result. A fragmented pay period can have <40h while its complete workweek has
  overtime, and a loosely attached weekly result does not prove mapping/coverage of that paycheck.
  Existing assessment engine3 and its ≤40h test encode this coarse contract. The native review
  remains separate and does not attach results, so the new UI cannot clear that warning. Before
  release or platform parity, implement a versioned assessment guard/mapping with historical
  engine3 preservation and appropriate regression/App evidence. Do not relabel this checkpoint
  as full weekly/paycheck correctness or bypass the remaining guard by attaching a result.
- Final source-bound SDK check exited0 with no diagnostics:107 production/test/support sources,
  language6/complete concurrency/warnings-as-errors, arm64 iOS18 Simulator target/installed27.1 SDK,
  `/private/tmp/linepay-v2-weekly-sdk-checked.log`; source SHA256
  `8a1a89e10c11de7016bfcb2f73d182f78a624a8645b22476f8b80311d714eecd`.
  This only emits modules/typechecks focused App tests; no native test/Simulator/UI/link/bundle PASS.
- Pinned workspace Hugo checks passed root and `/linepay/`:24 HTML pages/21 search entries each,
  deterministic search,59 guide-source reviews and4 screenshot-provenance checks,
  `/private/tmp/linepay-v2-weekly-guide.log`. Expanded actual Chromium coverage to weekly guidance
  and supported-limits pages. The first new wording assertion failed because Hugo renders a curly
  apostrophe; normalized that typography in the assertion without changing the content/meaning.
  Final browser receipt follows. No guide/native/public website deployment occurred.

- Final actual documentation-browser run passed **27 page/configuration checks**, including the new
  weekly guidance at desktop/mobile/small-dark widths plus search/navigation/no-JS/keyboard/print,
  `/private/tmp/linepay-v2-weekly-guide-browser-final.log`. No successful network response was mocked.
  SDK receipt remains107 sources with hash8a1a89e10c11de7016bfcb2f73d182f78a624a8645b22476f8b80311d714eecd.
  No native source changed after that receipt. No push, PR, archive, store write or public release.
  Full v2, especially versioned paycheck-scope safeguards and native/runtime/platform acceptance,
  remains incomplete; the original goal stays active.

- Final quick rerun after the credit-portion copy also exited0:74 repository tests, strict format and
  152 domain tests/25 suites, `/private/tmp/linepay-v2-weekly-quick-checked.log`. Final1,061 local
  Markdown links,5 documentation-tool tests, legal active-copy/inventory, agent-harness and diff
  checks passed. Scope remains the corrected weekly reference, not full release approval.


## Assessment v4 and preserved weekly comparison history

- Previous turn was progress (`614d360`); resumed clean on `codex/v2-e2e`. Read-only Xcode
  first-launch status still69; no setup/admin prompt, Simulator/runtime or SDK/license operation.
  Addressed the known assessment bypass before continuing platform expansion. Full weekly mapping
  is still unimplemented; the v4 guard prevents unsupported conclusions and does not claim mapping.
- New bypass regressions ran against original v3:2 tests failed with40 issues,
  `/private/tmp/linepay-v2-weekly-assessment-before.log`. Short/40h periods and unrelated attached
  weekly results could produce match/shortfall/overpayment without mapping. New v4 retains known
  amounts/comparisons but requires Needs review whenever the argument agreement, saved snapshots
  or attached weekly result indicate weekly scope. Missing/empty snapshot arrays cannot hide the
  argument's rule. No caller Boolean/arbitrary-result bypass is added. Nonweekly scope is unchanged;
  incomplete work or unknown gross basis remains Not comparable.
- New native schema9 admits producer4, while old1–8 records retain their original comparison
  versions and values. Current-v4 validation refuses a forged weekly match or missing mapping reason.
  A separate assessment-review flag marks active legacy weekly checks stale without repricing or
  saving on load. Explicit review appends v4. Archived originals remain their recorded verdicts
  with Earlier weekly comparison context; PDFs label Recorded verdict. Original comparison access
  remains available through View recorded comparison when a frozen revision exists, before closing
  the period. Calculation-precision review remains independent.
- Propagated the flag through Pay, import, detail, report preparation and PDF generation. A Pro
  amount claim additionally requires a current open Possible shortfall verdict; Needs review or
  historical difference values cannot become that advertising claim. No worker records are hidden
  behind a new subscription requirement or automatically sent anywhere.
- Generated four original native v3 receipts by compiling/executing actual **614d360** domain
  sources, `/private/tmp/linepay-v2-assessment-legacy-generation.log`, canonical fixture
  `shared/contracts/reconciliation/native-assessment-v3.json`. Original matches/amounts/component
  references remain intact; explicit v4 review changes the affected scope verdict/reasons, while
  its no-weekly negative control still matches. These are historical synthetic software receipts,
  not current legal pay conclusions or a cross-client financial backup format.
- Pure focused final suite passed **4 tests** including five hour/scope argument cases and the four
  actual legacy receipts, `/private/tmp/linepay-v2-weekly-assessment-final.log`. Existing ≤40h
  acceptance was deliberately corrected after reproducing the defect, not weakened to hide it.
- Added **five native App tests** for schema8-to9 shape admission, active legacy read without
  writes, frozen-revision reading, append-only v4 correction, archive/backup/reload, legacy PDF
  labels, unaffected scope, forged-v4 refusal and failed-save preservation. A further crew-origin
  schema8 shape check preserves original bytes. These tests are typechecked, **not executed**;
  the schema8 App seed is assembled from actual old domain receipts, not an old app runtime receipt.
- XcodeGen2.46.0 generation passed. Inspected the generated project: the new canonical JSON
  fixture is copied only by LinePayAppTests' resource phase, absent from LinePay's shipping resources.
  Inventory check initially caught project.yml drift. Reviewed that test-only wiring and refreshed
  only its mechanical hash; runtime resources, lockfile, permissions and dependencies are unchanged.
  This bookkeeping is not source-rights/legal/release approval or an actual test bundle inspection.
- Frozen-source SDK compilation/typechecking passed **109 production/test/support sources** with
  language6/complete concurrency/warnings-as-errors, arm64 iOS18 Simulator target/installed27.1 SDK;
  `/private/tmp/linepay-v2-assessment-sdk-checked.log`, receipt `.build/v2-assessment-typecheck/`,
  source SHA256 `a23e3f1d0c801fc7f04028bb914fb333f4dc62140366485c352bb3bb540b1bec`.
  No native source changed afterwards. This is module emission/typechecking, not link/bundle,
  native App-test, Simulator, PDF-render or visual/VoiceOver acceptance.
- Full quick gate passed **74 repository tests, strict format and156 domain tests/26 suites**,
  `/private/tmp/linepay-v2-assessment-quick.log`. Candidate guide review updated the affected ten
  source mappings without claiming a full release review. Pinned Hugo checks passed root and
  `/linepay/`:24 HTML pages/21 search entries each, deterministic search,59 source reviews and4
  screenshot-provenance checks, `/private/tmp/linepay-v2-assessment-guide.log`. Actual guide-browser
  evidence follows; it cannot substitute for native interaction or new native screenshot evidence.
- ADR0025 and BR097–099 own these controls. The weekly mapping/integration, source/applicability
  #42, runtime/migration/PDF/visual/provider, remaining PWA/Android/library/localization and final
  store gates remain required. No push/PR, archive/store write or public release occurred. The
  original all-stage/manual-release objective stays active and incomplete.

- History invariant review added explicit known-producer replay, rather than relying only on byte/
  value retention: `reproduceRecorded` reuses original calculation/snapshot/facts and requires exact
  equality to the recorded producer3/4 result. Unknown1/2 producers are not replayed by this API;
  their preserved read behavior remains. Current `assess` still always produces4. A mismatched
  original receipt/fact set refuses instead of silently applying current scope or changing it.
- Expanded the actual614d360 generator to **five receipts**, adding a60-hour v3 Needs review case
  that verifies the original warning text as well as the three old weekly matches and nonweekly
  control. Final generation log `/private/tmp/linepay-v2-assessment-legacy-generation-final.log`.
  New golden fixture is test-only; no app runtime resource or financial state is rewritten.
  Final replay/domain/SDK checks follow; intermediate four-case validation logs above remain historical evidence, while the canonical fixture now contains five receipts.

- Final replay check passed4 tests (including five hour/scope argument cases and five actual legacy
  receipts), `/private/tmp/linepay-v2-assessment-replay.log`. Full current quick passed **74 script
  tests/strict format/156 domain tests in26 suites**,
  `/private/tmp/linepay-v2-assessment-quick-final.log`. Original mismatch replay refuses, and v4
  current results retain their new scope even though recorded v3 can be reproduced explicitly.
- Final frozen-source SDK run exited0 with no diagnostics for109 production/test/support sources:
  `/private/tmp/linepay-v2-assessment-sdk-replay.log`, source SHA256
  `b14a2d54ca0b1d10ee8495ec241074d435a6e8e46304a10df43b19f2c8b290e0`.
  Receipt `.build/v2-assessment-typecheck/compiler-receipt.json`. No native source changed after
  this check; five new App tests and existing affected tests are typechecked, not executed.
- Actual guide-browser run passed **42 page/configuration checks**,
  `/private/tmp/linepay-v2-assessment-guide-browser.log`, including new result/history/report pages
  and navigation/search/no-JS/keyboard/print. This is documentation-browser evidence, not native UI.
  Last1,063 local Markdown links,5 doc-tool tests, legal active-copy/inventory, harness and diff checks
  passed. Complete weekly mapping, native runtime/visual/provider and remaining roadmap/release
  gates stay open. No App Store submission/public release; the original goal remains active.
