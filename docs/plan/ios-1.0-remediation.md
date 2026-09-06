# iOS 1.0 readiness remediation

Companion to the [original audit](../linepay-1.0-readiness-audit.md), which remains byte-for-byte intact at its pinned `fb913f3ed65a47006fb88a20005b11e6cf189505` revision. This record distinguishes implementation, native tests, simulator interactions and external release acceptance.

Branch: `fix/ios-1.0-readiness`; [PR #2](https://github.com/streamentry/linepay/pull/2). Integrated main: `2bf0d3d45123df2eb64c13156b2bd7475ac1820e`. Public brand: LinePaycheck; bundle: `com.streamentry.linepay`.

## Current evidence

Verified native source: **`a6e9dcefb28fb99e12c23f9437fc09a087d8f121`**. Its full `agent-verify.sh ios` gate exited **0** on September 6, 2026. The `apps/ios` tree is `0b061dbe080e5c26ecbcb002ed69e36da8308549`.

| Executed gate | Result |
|---|---|
| Strict Swift formatting and privacy-manifest validation | Pass |
| Pure domain | 82 tests passed |
| Repository scripts | 29 tests passed |
| App tests, including native StoreKitTest and view contracts | 169 tests passed |
| XCTest UI | All 7 journeys passed |
| Generic iOS Simulator Release, arm64/x86_64 | Build passed; launch configuration and dependency lock preserved |
| Standard light / Reduce Motion enabled | 9/9 Maestro flows passed in 11m 1s on `95dd0e8` |
| Compact dark / maximum text | Complete audit correction/relaunch passed on `95dd0e8`; complete rule correction passed on `4c15b53` |

The native result bundle reports **176 passed, 0 failed, 0 skipped, 0 expected failures** (169 app tests plus 7 XCTest UI journeys). Toolchain: Xcode 26.6 (`17F113`), Swift 6.3.3, XcodeGen 2.46.0. Native runtime: iPhone 16 Pro / iOS 18.5 (`6CB95D1F-BC8E-4C06-B8C4-606F58AA02A9`).

```bash
LINEPAY_RESULTS_DIR="$PWD/.build/merge-review/native-final" \
IOS_SIMULATOR_DESTINATION='platform=iOS Simulator,id=6CB95D1F-BC8E-4C06-B8C4-606F58AA02A9' \
bash scripts/agent-verify.sh ios
```

Native log, result bundle, coverage, summary and exported screenshots: `.build/merge-review/verify-ios-final.log` and `.build/merge-review/native-final/`.

The standard suite ran on an isolated iPhone 16 Pro / iOS 18.5 (`1098F918-AF29-48AE-9DF9-8DEB861F0367`), light appearance and normal text. Reduce Motion was enabled through Settings and read back as `1` in `.build/readiness/1369414/reduce-motion-enabled.json`. Log: `.build/readiness/95dd0e8/standard-ui.log`.

```bash
JAVA_HOME="$(/usr/libexec/java_home -F -v 21)" \
/private/tmp/linepay-maestro-2.7/cli/maestro/bin/maestro \
  --udid 1098F918-AF29-48AE-9DF9-8DEB861F0367 test \
  --test-output-dir .build/readiness/95dd0e8/standard-ui .maestro
```

Between that complete standard pass and `4c15b53`, **only rule-flow navigation changed**; application and native-test sources remained identical. The later pre-merge storage fixes below leave UI code unchanged and passed the full native gate, including all seven UI journeys. The changed complete rule flow then passed in both standard and maximum-text appearances on `4c15b53`. Logs: `.build/readiness/4c15b53/rule-standard.log` and `rule-maximum.log`. The maximum-text audit's complete subflow is recorded as passed in `.build/readiness/95dd0e8/maximum-text.log`; the wrapper later failed at the rule picker before the fix. The compact device was iPhone SE / iOS 18.5 (`9872181E-9E62-4DD3-A0B9-7F925D83B9C5`), dark, `accessibility-extra-extra-extra-large`.

A readback of the final standard UI's synthetic state verified **gross difference 0, regular-pay difference +50, overtime difference -50, scope `confirmedLines`, verdict `needsReview`**. This rules out a generic unmapped-evidence warning masquerading as the intended component result.

Maestro was the CI-pinned **2.7.0**, verified against SHA-256 `a4ccab6b604617e7aef6db4f885666056eabe5cfa32befaa3bc994041b8fcbb5`, with Java 21 LTS. The existing installation was preserved. Shipped bytecode confirms integer division in percentage normalization, so final helpers use 100% visibility. Short native choice pages are selected directly; centering drags could leave the intended sheet. No verdict or amount assertion was removed. The optional XcodeBuildMCP tool was unavailable; standard Xcode/XCTest, simctl and Maestro performed the checks.

Earlier failures remain separate evidence: a new simulator's keyboard tutorial interrupted input; tap-position errors were repaired; one accelerated StoreKit grace observation failed during concurrent UI activity; and a later linker stopped with `errno=28` before tests. The final isolated native run passed, including grace and expiration. Only task-created QA simulators, disposable build output and the downloaded installer archive were removed to recover disk space; logs/results/screenshots were preserved. Recreate equivalent QA simulators with fresh IDs to repeat the UI commands above.

Representative synthetic [screenshots and the app-generated PDF](../qa/ios-1.0/README.md) are committed for review. Both PDF pages were rendered and inspected. Public support/privacy URLs returned HTTP 200 with normal network access.

## Pre-merge review

The user authorized review and merge after the implementation handoff. Review found and fixed two data-integrity gaps:

- `528abf2`: saving could exceed the reader's 8 MB limit and make the next launch unable to load its own file. Save and load now share the same encoded-byte limit. Plain and JSON-escaped oversized drafts are rejected before replacing the existing file; regression tests verify byte preservation and successful reload.
- `a6e9dce`: stored comparison differences and gross summaries were not fully cross-checked. Validation now checks expected-minus-paid with the saved rounding policy and verifies the gross comparison agrees with its summary. Synthetic inconsistent records are rejected without recalculating historical payroll results.

Both regression groups and the full native gate passed on `a6e9dcefb28fb99e12c23f9437fc09a087d8f121`. No other blocking finding remained in the reviewed payroll, period lifecycle, import, restore, entitlement and validation paths. Hosted CI remains separate from these local results.

## Findings, implementation and regression evidence

The tested native application SHA for every row is `a6e9dcefb28fb99e12c23f9437fc09a087d8f121`. The UI-only follow-up revisions and executed artifacts are identified above.

| Audit | Implemented behavior | Executed evidence and remaining limit |
|---|---|---|
| A01 | Native compilation, launch sizing, strict concurrency and Release boundary repaired | Full native and Release passes above; GitHub jobs did not start because of account billing |
| A02–A03 | Confirm full work period, gross basis, earnings/hour/callout layouts; separate wages/per diem; qualify missing or offsetting evidence | `PaycheckAssessmentTests`, `AuditScopeRegressionTests`, `DocumentPipelineTests`; simulator verdict matrix. `$400 + $150` vs `$350 + $200` cannot become a clean component match |
| A04 | Close A, record B, then audit A; append corrections to frozen evidence; consistent paid access | Native two-period UI journey; `sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules` proves A at $50, B at $60, Thursday A audit, unchanged B |
| A05 | Preserve main's dated timeline and component rule versions; explicit whole-period correction and read-only preview | `AgreementTimelineTests`, `RuleScopeRegressionTests`, `TimelinePersistenceTests`; compact correction flow passed with preview/money assertions |
| A06 | Whole-string decimal-point/grouping policy; no prefix parsing; conservative current/YTD and negative-adjustment handling | `StrictDecimalTests`, parser regressions and real Vision on synthetic documents. Decimal-comma input is rejected with an explicit policy; punctuation keyboard permits the declared format |
| A07 | Persist setup/new/edit-work/paycheck-field drafts and staged originals; single-owner import operations; page/region provenance | Native new/edit-work and interrupted paycheck-field/source journeys passed. Field editors save directly while their parent is inactive. OCR reads at most 8 pages and discloses the limit |
| A08 | Frozen payroll/work timezone; explicit non-overlapping boundary after timezone change | DST/overnight/domain and app regressions; old-period export uses recorded timezone. A new zone may require choosing a later non-overlapping start |
| A09 | Undo carries period and revision; intervening work/rule changes invalidate it; repeat can use closed-period work | Stale-Undo and scheduled-rule regressions; standard work/Undo flow passed |
| A10 | Corrections retain sources and audit revisions; deletion is explicit, scoped and retryable | Original-retention, deletion/save fault injection, interrupted-file discovery and relaunch tests; external exported copies are preserved |
| A11 | Entitlements independent of catalog; actual eligible annual trial; Pro preserves unused Free audit; signed access may settle briefly after purchase | Native Xcode StoreKit tests cover purchase, cancel, pending approval, interrupted recovery, renewal, trial-to-paid, expiry, refund, grace, restore and catalog failure. This is not sandbox/TestFlight proof |
| A12 | Schema 3 distinguishes the combined writer; migrate both schema-2 variants and v1 without recomputing history; validate/restore with rollback | Static v1 fixture, both v2 migration variants, malformed-state recovery, full original-byte backups, failed state/evidence writes and cleanup tests |
| A13 | Progressive setup and final rule confirmation; supported tier/weekday editors; missing-rule disclosure; grouped ledger and component-specific receipts | View contracts, native setup and evidence journeys; the complete standard suite and compact payroll journeys |
| A14 | Unavailable calculations remain unavailable; preserve ambiguous spanning-callout work without inventing pay; block audit/archive | Domain/app failure tests, view contracts and rendered uncertainty states |
| A15 | Preserve main's assets and data controls; local About/legal/recovery plus published links; adaptive values and semantic colors | Native light/dark/largest-text captures, completed compact payroll journeys and standard flows with Reduce Motion; resolved semantic contrast tests; public privacy/support URLs returned HTTP 200. Physical VoiceOver/field usability remains open |

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

Merge to main through PR #2 is authorized after review. TestFlight distribution, App Review submission and release remain separate and have not been performed.
