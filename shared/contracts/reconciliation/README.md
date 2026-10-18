# Paycheck comparison contracts v1

[Shared contracts](../README.md)

## Configured gross comparison

`configured-gross-v1.json` contains sixteen synthetic, independently calculated comparisons consumed
by the Swift paycheck assessor and Kotlin gross assessor. All money uses explicit currency and
decimal strings. Each case supplies real instants and a payroll timezone for synthetic work; the
48-hour case deliberately leaves weekly review pending. No actual worker data is included.

A full-period expected gross requires explicitly confirmed complete work and a confirmed gross
basis. Cash wages exclude separately configured per diem unless the worker confirms the printed
gross includes it. Missing per-diem observations remain unknown, not zero. A missing calculation
has no expected gross or difference; it cannot imply the expected amount was zero.

Keep observed gross precision. Subtract expected minus observed, then round the difference using
the explicit money policy: 400 minus 399.995 becomes 0.01, whereas 400 minus 400.004 becomes zero
at two decimals. This is the existing wage-comparison policy; employer-fund comparison separately
preserves unrounded statement differences in the [fund contract](../benefits/README.md).

Matching gross never verifies unentered hours, every earnings line or legal coverage. Unreviewed
fields, unsupported rules, pending weekly review and legacy rounding require review. A matching
gross with a separately confirmed allowance difference also requires review. Positive/negative
differences are possible shortfalls/overpayments within configured scope, never a debt finding.
Each comparison traces to the component IDs included in that basis. Save the assessment with its
work/rule/statement snapshots; reopening history must not rerun it with newer rules.

## Configured earnings and hour lines

`configured-lines-v1.json` contains 29 synthetic cases with independently stated arithmetic. The
same fixture is consumed by Swift, Kotlin and the browser implementation. It covers full-rate and
premium-only layouts, actual-work and paid-equivalent hours, separate or included callout
guarantees, line conflicts and offsetting differences, per-diem observations, unusual or unknown
mappings, weekly-review guards, and exact-seconds rounding across fragments. The cents and hours
remain decimal strings; source component IDs are checked alongside amounts.

Money-line differences use the configured wage rounding policy. Displayed hour amounts are rounded
to four places, while the hour difference is calculated from exact seconds and then rounded
half-up to four places, independently of the wage rounding mode. A source-period confirmation must
match the target local dates and timezone before comparison. That confirmation is a worker assertion,
not independent source verification. A weekly-review flag is an outstanding review, not a weekly
paycheck allocation or legal-coverage implementation.

These contracts verify deterministic configured-rule arithmetic and comparison mapping. They do not
establish statutory or agreement completeness, Android Compose behavior, native persistence/history,
OCR, migration/restore, device/provider behavior, App Store readiness, or a legally owed amount.
Historical results must retain their original facts, calculation and rule snapshots; a new assessor
must not rewrite old receipts.

Run the Swift package tests and the pinned JVM command in [Android](../../../apps/android/README.md).
The browser consumer runs with `node --test apps/web/tests/*.test.mjs`. Their results are separate
from native UI, persistence/history, OCR, migration/restore, actual-device, provider and App Store
release evidence.


## Native assessment v3 history fixture

`native-assessment-v3.json` contains five original synthetic receipts emitted by compiling actual
`614d360` sources. These are native-domain JSON wire records, not portable financial backup input.
Three weekly-scoped matches demonstrate the old guard's limitations; they remain historical
software behavior, not correct current paycheck conclusions. The 60-hour weekly case preserves its
original review reason, and the nonweekly case is the negative control. Current Swift tests replay known v3 receipts against
the original facts/snapshots and require exact equality, reject changed-fact replay, explicitly invoke v4 and retain
identical known amounts/comparisons while affected verdicts become Needs review.

See [ADR0025](../../../docs/adr/0025-versioned-weekly-assessment-safeguards.md). V4 does not implement
weekly-paycheck allocation or certify legal coverage. Native App/runtime migration and cross-platform
adoption remain separate gates. The resource is copied only into the native App test target.
