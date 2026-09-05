# iOS 1.0 readiness remediation

Companion to the [original audit](../linepay-1.0-readiness-audit.md), which remains byte-for-byte intact at its pinned `fb913f3ed65a47006fb88a20005b11e6cf189505` revision. This record distinguishes implementation, native tests, simulator interactions and external release acceptance.

Branch: `fix/ios-1.0-readiness`; [PR #2](https://github.com/streamentry/linepay/pull/2). Integrated main: `2bf0d3d45123df2eb64c13156b2bd7475ac1820e`. Public brand: LinePaycheck; bundle: `com.streamentry.linepay`.

## Current evidence

Application source **`bf823340c76da64c917d05cc8bf42d8143ceef2b`** passed the native and Release portions of `agent-verify.sh ui`:

| Executed gate | Result |
|---|---|
| Strict Swift formatting and privacy-manifest validation | Pass |
| Pure domain | 82 tests passed |
| Repository scripts | 29 tests passed |
| App tests, including native StoreKitTest and view contracts | 167 tests passed |
| XCTest UI | All 6 journeys passed |
| Generic iOS Simulator Release, arm64/x86_64 | Build passed; launch configuration and dependency lock preserved |

Toolchain: Xcode 26.6 (`17F113`), Swift 6.3.3, XcodeGen 2.46.0. Native runtime: iPhone 16 Pro / iOS 18.5 (`6CB95D1F-BC8E-4C06-B8C4-606F58AA02A9`). Exact command and logs: `.build/readiness/bf82334/verify-ui.log`; result bundle and exported screenshots: `.build/readiness/bf82334/native/`.

```bash
LINEPAY_RESULTS_DIR="$PWD/.build/readiness/bf82334/native" \
IOS_SIMULATOR_DESTINATION='platform=iOS Simulator,id=6CB95D1F-BC8E-4C06-B8C4-606F58AA02A9' \
MAESTRO_IOS_DEVICE='LinePay Readiness QA 20260906' \
bash scripts/agent-verify.sh ui
```

The combined command remains **non-green** because the additional compact Maestro suite initially failed. The native/Release successes above are not inferred from that command's final exit. On the isolated iPhone SE / iOS 18.5 (`9872181E-9E62-4DD3-A0B9-7F925D83B9C5`), updated flows passed setup, backup consent, delete/cancel/reset/relaunch, landscape/large monetary values, and dismissible Pro options. All nine compact flows passed across focused reruns after correcting navigation/scroll targets, giving the scope picker a native selection page, and fixing a dismissed editor that recreated its saved work draft. A consolidated final run on the final candidate is pending; no monetary assertion was waived.

The production-store compact journey found and reproduced work-draft resurrection after save, which the original fixture-based journeys did not expose. Editors now suppress draft writes during completion, and work forms do not persist untouched defaults on presentation.

Local Maestro 2.6.1 was found during investigation; the remaining flows use the repository-pinned **2.7.0**, verified against SHA-256 `a4ccab6b604617e7aef6db4f885666056eabe5cfa32befaa3bc994041b8fcbb5`, with installed Java 21 LTS. An independent XCTest correction-route regression passed on both the iPhone 16 Pro and the exact compact simulator. Logs: `.build/readiness/bf82334/native-correction*.log`.

## Findings, implementation and regression evidence

The tested application SHA for these rows is `bf823340c76da64c917d05cc8bf42d8143ceef2b`. UI test/flow-only follow-ups are separately identified in Git and the PR.

| Audit | Implemented behavior | Executed evidence and remaining limit |
|---|---|---|
| A01 | Native compilation, launch sizing, strict concurrency and Release boundary repaired | Full native and Release passes above; GitHub jobs did not start because of account billing |
| A02–A03 | Confirm full work period, gross basis, earnings/hour/callout layouts; separate wages/per diem; qualify missing or offsetting evidence | `PaycheckAssessmentTests`, `AuditScopeRegressionTests`, `DocumentPipelineTests`; simulator verdict matrix. `$400 + $150` vs `$350 + $200` cannot become a clean component match |
| A04 | Close A, record B, then audit A; append corrections to frozen evidence; consistent paid access | Native two-period UI journey; `sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules` proves A at $50, B at $60, Thursday A audit, unchanged B |
| A05 | Preserve main's dated timeline and component rule versions; explicit whole-period correction and read-only preview | `AgreementTimelineTests`, `RuleScopeRegressionTests`, `TimelinePersistenceTests`; compact correction flow remains in final QA |
| A06 | Whole-string decimal-point/grouping policy; no prefix parsing; conservative current/YTD and negative-adjustment handling | `StrictDecimalTests`, parser regressions and real Vision on synthetic documents. Decimal-comma input is rejected with an explicit policy; punctuation keyboard permits the declared format |
| A07 | Persist setup/new/edit-work/paycheck-field drafts and staged originals; single-owner import operations; page/region provenance | Native new/edit-work and interrupted paycheck-field/source journeys passed. Field editors save directly while their parent is inactive. OCR reads at most 8 pages and discloses the limit |
| A08 | Frozen payroll/work timezone; explicit non-overlapping boundary after timezone change | DST/overnight/domain and app regressions; old-period export uses recorded timezone. A new zone may require choosing a later non-overlapping start |
| A09 | Undo carries period and revision; intervening work/rule changes invalidate it; repeat can use closed-period work | Stale-Undo and scheduled-rule regressions; compact work/Undo flow still in final QA |
| A10 | Corrections retain sources and audit revisions; deletion is explicit, scoped and retryable | Original-retention, deletion/save fault injection, interrupted-file discovery and relaunch tests; external exported copies are preserved |
| A11 | Entitlements independent of catalog; actual eligible annual trial; Pro preserves unused Free audit; signed access may settle briefly after purchase | Native Xcode StoreKit tests cover purchase, cancel, pending approval, interrupted recovery, renewal, trial-to-paid, expiry, refund, grace, restore and catalog failure. This is not sandbox/TestFlight proof |
| A12 | Schema 3 distinguishes the combined writer; migrate both schema-2 variants and v1 without recomputing history; validate/restore with rollback | Static v1 fixture, both v2 migration variants, malformed-state recovery, full original-byte backups, failed state/evidence writes and cleanup tests |
| A13 | Progressive setup and final rule confirmation; supported tier/weekday editors; missing-rule disclosure; grouped ledger and component-specific receipts | View contracts, native setup and evidence journeys; remaining compact actions noted above |
| A14 | Unavailable calculations remain unavailable; preserve ambiguous spanning-callout work without inventing pay; block audit/archive | Domain/app failure tests, view contracts and rendered uncertainty states |
| A15 | Preserve main's assets and data controls; local About/legal/recovery plus published links; adaptive values and semantic colors | Native light/dark/largest-text captures; resolved semantic contrast tests; public privacy/support URLs returned HTTP 200. Physical VoiceOver/field usability remains open |

A shared native view satisfies multiple mockup states. The original 46-state matrix is preserved; these tests and screenshots are **not** a claim that every state was manually operated with every accessibility setting.

## Storage and authority

[ADR 0005](../adr/0005-effective-dated-rules-and-audit-scope.md) owns dated rule semantics; [ADR 0006](../adr/0006-evidence-aware-payday-records.md) combines evidence-aware assessments, drafts, revisions and schema 3. The JSON store from ADR 0004 remains in place. Backup envelope version 1 and the physical `state-v1.json` location remain unchanged. Older schema-2 apps reject newly saved state; keep a complete backup before changing versions.

No account, pay-data backend, analytics/ad SDK, cloud OCR, automatic sync or runtime third-party dependency was introduced. ViewInspector is test-only and pinned.

## External blockers and release gates

GitHub Actions runs [33986619605](https://github.com/streamentry/linepay/actions/runs/33986619605) and [33986619611](https://github.com/streamentry/linepay/actions/runs/33986619611) failed **before any step started**. GitHub's annotations state that recent account payments failed or the spending limit needs increasing. No hosted build/test success is claimed and no protection was bypassed. After billing is restored, rerun the standard workflows on the final PR head.

Keep separate until performed:

- Real-iPhone scanner, permission-denied/cancel behavior and provider download interruptions.
- Real iCloud Drive backup transfer/restore between devices.
- StoreKit sandbox/TestFlight, actual storefront/billing behavior and release-candidate restore. A local iOS 26.5 StoreKitTest attempt rejected configuration with `SKInternalErrorDomain Code=3`; successful local commerce proof is iOS 18.5.
- Physical VoiceOver, sunlight/night use, performance/memory and remaining screen/accessibility combinations.
- Consenting lineworkers completing consecutive periods and explaining discrepancies without assistance.

No merge into main, TestFlight distribution, App Review submission or release was performed by this repair task.
