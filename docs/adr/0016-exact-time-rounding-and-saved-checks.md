# ADR 0016: exact time through money rounding

Status: implementation in progress, October 17, 2026. No new release is implied.

Shared client-fixture work reproduced a real cent-boundary defect in calculation version 2:

- USD 18/hour × one second is exactly USD 0.005; half-up rounding must produce USD 0.01, not zero.
- USD 58.50/hour × one minute is exactly USD 0.975; it must produce USD 0.98, not USD 0.97.
- Splitting work must not lower the category target. At USD 19.99/hour, 1 + 1,799 seconds total
  exactly USD 9.995, rounded once to USD 10.00 under the stated pay-category policy.

Decimal is required but not sufficient: dividing seconds into recurring decimal hours *before*
multiplication can put an exact half-cent below the boundary. Do not mask this with an epsilon,
weaker expectations, a formatting adjustment or a binary floating-point calculation.

Keep elapsed quantities/daily-tier positions in exact second-based Decimal values. Carry exact
rate × seconds × multiplier numerators through category aggregation, divide by 3,600 only at the
rounding boundary, and allocate ledger cents with exact numerator remainders. Callout minimums
subtract exact worked seconds; guaranteed time remains separate from work. Preserve the existing
rounding mode/scale/scope and premium-combination rules. No agreement entitlement has changed.

Calculation provenance becomes `linepay.configured-pay/3` with
`exact-seconds-snapshot-rounding/2`. Storage admits this exact pair and the earlier version-2 pair;
unknown combinations remain rejected. No new persisted field/schema is needed. Transient exact
numerators are derived from the existing work/rule facts, not an alternative source of truth.

History is not silently repriced. Reading a closed period retains the saved estimate and recorded
revisions. Unchanged active ledger prices retain the prior check/provenance; affected active rows
require explicit re-review, and stale comparisons cannot support a current result/report/offer.
An explicit closed-period paycheck review uses current precision and appends its new calculation
with the new audit revision. The original period estimate and earlier revisions stay intact. The
current comparison display/validation uses the calculation belonging to that current paystub's
recorded revision, not an unrelated original estimate. The intake states this precision transition.

The shared fixture corpus records independent half-cent expectations and partition cases. Native
app regressions verify affected active review, unchanged-price provenance, frozen closed results
and explicit closed re-review. Simulator confirmation/save verifies the USD 0.98 result. Complete
native, report, backup/restore, adaptive and release checks must be recorded before shipping; earlier
passing suites did not contain these newly discovered boundaries and are not proof of this fix.
