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
| Foundation: funnel measurement | Pending; owner chose local-only | Content-free local milestones and manual diagnostic export; no collector |
| Website/store consistency | Pending | Inspect real website/listing and update only supported claims |
| First-value onboarding | Existing, needs assessment | Minimal confirmed rules → work → credible expected pay |
| Paycycles and period matching | Implemented; focused native tests passed | Weekly, biweekly, semi-monthly, custom; timezone boundaries; mismatch guard |
| OCR reliability | Implemented and locally verified | Broader employer-layout/independent precision evaluation; final release gate |
| Resolution workflow | Implemented; native/UI/storage/privacy checks passed | Saved finding/status/notes/history and shareable evidence packet |
| Accessibility | Pending | VoiceOver, large text, contrast/motion and critical native journeys |
| Free web calculators | Existing public calculator; 7 arithmetic tests passed | Exact arithmetic, stated assumptions, browser flow and app CTA |
| Agreement extraction | Implemented; 282 app tests and focused native journeys passed | Broader independent document corpus, actual Files-provider transfer and final release gates |
| Benefits audit | Pending | Benefits separate from wages; confirmed rates/units; unavailable-statement handling |
| Verified rule sources | Pending | Rights, version/effective dates, scope, freshness and no silent history mutation |
| Voice logging | Pending | Native transcription → editable draft → explicit confirmation |
| Referrals | Pending | Content-free attribution with explicit data-flow/commerce boundaries |
| Encrypted sync/account | Superseded by explicit local-only owner choice | Encrypted manual backup/restore portability; no account or automatic sync |
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
