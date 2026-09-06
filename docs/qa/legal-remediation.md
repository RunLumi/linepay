# Legal remediation: implementation and verification receipt

Date: September 6, 2026. Native work: PR #34. Release tooling: PR #35.
This receipt does not close external legal, storefront, ownership or physical-device findings.

## Actual implementation

- Accurate, exhaustive consent for future periods, a prospective date, and explicit whole-period
  correction. Effective-date fallback matches AppModel; the frozen timezone, record count and
  before/after values remain visible. No payroll or persistence algorithm was changed.
- Canonical supported/unsupported comparison disclosure before rule confirmation, in audit detail,
  About and PDFs, including matched outcomes. Support avoids legal adjudication and deadline claims.
- Default PDF minimization, explicit optional source-detail consent, immutable byte preview and
  explicit user sharing. Source records remain intact. Shared payload bytes survive working-file
  cleanup; stale, changed or unreadable files cannot authorize a different copy.
- Path-restricted, idempotent report cleanup with failure/retry and symlink-refusal tests.
- Existing long-source pagination assertions now explicitly select the source-detail option;
  all prior amount, comparison-basis, pagination and end-of-content assertions remain.

## Test-first evidence

The original `LegalRegressionTests.swift` blob is unchanged:
`5584a78030bbeebefc359610c13a144a9d8a60dd`.
It was committed before the fixes at `b60b3cf0bbe1fc7cf63f4460d1db55f3da363c1b`.
[Native red run 34006101764](https://github.com/streamentry/linepay/actions/runs/34006101764)
produced artifact 9981042817. Its retained summary was inspected: five test functions / nine
parameterized executions failed against the old implementation. They are not skipped, weakened or
wrapped as expected issues. The failures cover wrong consent, missing scope, sensitive PDF content
and unsafe initial support guidance.

## Verification performed in the current continuation

- `ReportShareSession.swift` and `TemporaryExports.swift`, copied byte-for-byte into a temporary
  Swift 6.2 package on Linux: **9 tests passed**. The test source is the checked-in
  `ReportShareSessionTests.swift` with only its test-module import changed from LinePay to ReportCore.
  No mock replacement for these production implementations was used. These tests do not exercise
  UIKit, PDFKit, CoreTransferable integration or the iOS filesystem/runtime.
- Strict `swift format` and Swift frontend syntax checks for the changed Swift files: passed.
  Syntax parsing is explicitly not an Apple-SDK typecheck or iOS build.
- PR #35's executed Python/code inputs were verified against their committed Git blob hashes:
  **57 tests passed**, including the release-documentation regression. Harness and active-copy /
  resource-inventory checks passed. These results concern tooling, not native app correctness.

## Native acceptance still required

The hosted jobs inspected on September 6 terminate before any steps run, including retry of
[Legal controls run 34010803570](https://github.com/streamentry/linepay/actions/runs/34010803570).
That is neither a test failure in the new native implementation nor a passing native result.
The cause has not been established. This environment has no Xcode or iOS Simulator.

Run the complete gate on the exact proposed head:

```bash
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

The focused `Legal regressions` workflow additionally selects `LegalRegressionTests`,
`LegalConsentAndReportTests`, `ReportShareSessionTests` and `LegalJourneyTests`. It preserves
assertion logs, xcresult, JSON summaries and screenshot attachments. It does not replace the full
native/StoreKit/UI gate, change compiler checks, or reclassify failing assertions.

Before native merge/release, inspect the generated PDFs and screenshots, confirm that all three
scope choices preserve their promised effects, test current/history/revision report paths,
preview/options/back/share cancellation, and verify source bytes remain intact. Real VoiceOver,
file-provider and two-device iCloud acceptance remain separate. Neither this receipt nor green
source tests constitutes trademark clearance, ownership proof, consumer-law approval or permission
to distribute an unverified App Store binary.

The portable subset is reproducible without editing the app or its package/toolchain baseline:

```bash
bash scripts/test-report-core.sh
```

It creates a disposable Swift 6.2+ test package outside the repository, copies the two actual
production files byte-for-byte, changes only the test-module import, runs the nine assertions and
cleans up. It neither replaces `agent-verify.sh ios` nor marks a native issue resolved.
