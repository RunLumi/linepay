# Configured-gross paycheck comparison v1

[Shared contracts](../README.md)

`configured-gross-v1.json` contains sixteen synthetic, independently calculated comparisons consumed
by the existing Swift paycheck assessor and the Kotlin gross assessor. All money uses explicit
currency and decimal strings. Each case supplies real instants and a payroll timezone for synthetic
work; the 48-hour case deliberately leaves weekly review pending. No actual worker data is included.

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

This subset does not implement full-rate/premium-only wage-line mapping, paid-equivalent hours,
guarantee mapping, period selection/matching, weekly entitlement or complete platform parity.
The Kotlin caller must establish period matching and all review flags before invoking it. Its
weekly flag represents an outstanding review, not a weekly-pay implementation. The current corpus
uses one explicit rule snapshot; broader timeline/rounding transitions require separate checks.

Run `bash scripts/agent-verify.sh quick` and the pinned JVM command in
[Android](../../../apps/android/README.md). JVM/Swift domain tests do not establish Android UI,
persistence/history, OCR, migration/restore, actual devices or App Store release readiness.
