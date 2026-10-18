# ADR 0027: exact base-time evidence for premium-only comparisons

Status: v2 candidate implementation, October 18, 2026. Native App migration/history/backup, PDF
and dedicated light/maximum-text dark correction/archive/relaunch journeys passed. Final release
acceptance remains pending. This is a calculation-evidence correction, not a new pay rule.

A one-minute synthetic shift at USD58.50/hour has a base of USD0.975, rounded half-up to0.98.
Configured calculation producer3 already rounds its wage from exact rate × seconds. Assessment4
instead reconstructed premium-only base from repeating Decimal hours, yielding0.97. With a
1.5 multiplier the correct rounded gross is1.46; splitting the same bucket gives0.98 base and0.48
extra. Gross equality cannot certify those earnings lines.

New calculation producer `linepay.configured-pay/4` retains an optional exact
`baseTimeNumerator` on worked and callout-guarantee components: hourly rate × paid seconds,
before multiplier and division by3600. Rounding/allocation copies this trace unchanged. Existing
wage totals and rounding semantics remain unchanged. No binary floating point enters this path.

Assessment5 sums base numerators within the original category/multiplier/currency/rounding
bucket before dividing and rounding once. Legacy-segment snapshots still round each segment.
Different dated rates with the same bucket policy combine before rounding. A one-second USD1
fragment plus a one-second USD17 fragment gives exactly0.005 base, rounded to0.01. Optional
callout layout still determines whether guarantees enter hourly buckets or a separate line.

Older calculations without exact trace cannot support a fresh premium-only monetary comparison:
assessment5 retains gross/other independently known comparisons, omits the unsupported earnings
comparisons and requires review. It does not reverse-engineer trace from rounded hours. Full-rate
buckets keep their recorded amounts. Weekly mapping safeguards remain independent and unchanged.

State schema10 admits the new producers and trace. Schemas1–9 retain recorded results without
repricing. New calculation records require finite nonnegative trace and matching unrounded
component amounts. Active earlier premium-only monetary comparisons require explicit re-review,
even if their gross did not change. The new confirmation appends a revision. Archived checks and
historical PDFs retain earlier values with a premium-only scope note and Recorded verdict.
Existing weekly legacy notes apply only before producer4, not automatically to every old version.

Explicit replay supports known producers3,4,5 using each producer's own comparison algorithm.
The two synthetic producer4 receipts in
`shared/contracts/reconciliation/native-assessment-v4.json` were generated from actual3836154
sources using JSONEncoder directly, preserving Decimal values. Their known0.97 base defect is
historical evidence, never a current expected-pay oracle. Current arithmetic regressions calculate
the independent exact-second expectations and verify safe missing-trace handling.

No new backend, telemetry, legal coverage, recovered-money claim or release authority follows.
See [execution evidence](../plan/v2-execution.md) for actual checks and remaining gates.


The original-v4 fixture is bundled only into LinePayAppTests. The project inventory update records
that reviewed test-resource wiring; the shipping app target, dependencies, privacy declarations
and permissions are unchanged. It is mechanical bookkeeping, not rights, counsel or store approval.
