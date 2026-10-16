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
| Foundation: funnel measurement | Pending | Content-free event schema; consent/data-flow decision; observable funnel |
| Website/store consistency | Pending | Inspect real website/listing and update only supported claims |
| First-value onboarding | Existing, needs assessment | Minimal confirmed rules → work → credible expected pay |
| Paycycles and period matching | Implemented; focused native tests passed | Weekly, biweekly, semi-monthly, custom; timezone boundaries; mismatch guard |
| OCR reliability | Pending | Multi-page source/confidence and explicit confirmation; evaluated synthetic corpus |
| Resolution workflow | Implemented; initial UI journeys passed; final verification running | Saved finding/status/notes/history and shareable evidence packet |
| Accessibility | Pending | VoiceOver, large text, contrast/motion and critical native journeys |
| Free web calculators | Pending | Exact arithmetic, stated assumptions, browser flow and app CTA |
| Agreement extraction | Pending | Document/page citations, confirmation, effective dates, conflict abstention and corpus |
| Benefits audit | Pending | Benefits separate from wages; confirmed rates/units; unavailable-statement handling |
| Verified rule sources | Pending | Rights, version/effective dates, scope, freshness and no silent history mutation |
| Voice logging | Pending | Native transcription → editable draft → explicit confirmation |
| Referrals | Pending | Content-free attribution with explicit data-flow/commerce boundaries |
| Encrypted sync/account | Pending | Optional architecture, encryption/recovery, offline independence and provider proof |
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
