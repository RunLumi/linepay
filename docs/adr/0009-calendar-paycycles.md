# ADR 0009: explicit calendar paycycles

Status: accepted October 16, 2026 for the owner-authorized [v2 work](../plan/v2-execution.md).

## Decision

Extend the existing persisted `PayPeriodCadence` with `semimonthly`. Its visible label explicitly
means periods starting on the 1st and 16th: 1–15 and 16–month-end. Other cutoff pairs remain custom
manual dates, not guessed employer schedules. An unsupported start is rejected atomically.

A Foundation-only `PayPeriodSchedule` builds windows and the setup preview from the same
confirmed payroll timezone. Calendar operations preserve local midnight through DST and leap
months. Ends stay exclusive; displayed final dates remain inclusive. Archiving continues at the
prior exclusive end. Changing cadence applies to future windows without recalculating history.

## Compatibility

Existing weekly, biweekly and manual raw values and historical windows are unchanged. No required
persisted field is added for cadence; existing schema-v4 snapshots remain decodable.
The accompanying schema-5 follow-up migration is covered by [ADR 0010](0010-worker-recorded-resolution-history.md). New semi-monthly values
round-trip through the existing JSON/backup path and state validation. Older binaries cannot read
the new enum value; do not suggest downgrading a store with semi-monthly records. Recovery must
preserve original bytes if a version cannot decode them, as with any unsupported store.

## Verification

Focused app tests cover explicit month boundaries, leap February, year rollover, both DST
transitions, rejected cutoffs, automatic continuation, snapshot round-trip and old raw values.
Execution evidence belongs in the v2 checkpoint; this decision is not a passing test receipt.
