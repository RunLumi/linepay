# Confirmed employer-contribution fixtures v1

[Shared contracts](../README.md)

`confirmed-fund-v1.json` is independent synthetic arithmetic and comparison-scope evidence, consumed
by Swift, Kotlin and the browser client. It does not establish actual eligibility, agreement authority, contribution
remittance, a debt, recovery, statutory fringe coverage or a working client UI.

One calculation has one fund, currency and explicit complete contribution period. Period dates use
ISO local dates with an exclusive end and a payroll timezone. Each eligibility segment has a stable
identity and immutable fund-rule ID/version/effective period. Rates and quantities are decimal
strings, never binary floating point. Sources/eligibility are worker-confirmed inputs; overtime
multipliers are not automatically applied to eligible units or mapped from cash wages.

Bases are eligible hour, eligible day, percent of explicitly eligible earnings, and fixed period.
A fixed-period rule requires quantity one and exactly the full calculation/effective period; no
proration is inferred. Segments do not overlap. A reused rule ID cannot silently change definition.
Different bases can contribute money to the same fund, but their quantities cannot be summed.

Multiply each confirmed rate/quantity exactly, dividing a percentage by 100. Keep unrounded
components, sum within the fund, then round once using the stated policy. Example: two 0.005
components total 0.01, not 0.02 from independently rounded components. Funds stay separate from
cash gross, per diem and employee deductions.

Missing/unconfirmed statement values remain unknown. A comparison requires the same fund, dates,
timezone and currency. Compare amount and units independently on their confirmed basis; an amount
can be comparable while reported units use a different basis. Preserve actual confirmed precision:
350 expected minus 350.001 confirmed is -0.001, not zero. A units-only result does not verify money.

The thirteen cases cover missing/unconfirmed statements, hourly/day/percentage/fixed expectations,
fund-level rounding, mixed bases, amount/unit differences, raw precision, units-only comparison and
fund/date/basis mismatch. Boundary suites separately reject incomplete confirmation, overlap,
inconsistent snapshots, fixed-scope misuse and invalid observations. These cases are not complete
agreement or platform parity.

Verify the native corpus with `bash scripts/agent-verify.sh quick`; use the pinned commands in
[Android](../../../apps/android/README.md) for the independent JVM consumer. The browser consumer
runs with `node --test apps/web/tests/benefits.test.mjs` from the repository root; its actual local
workflow/state/recovery checks are documented in [web](../../../apps/web/README.md). Simulator/device,
persistence/restore, source rights and release evidence remain separate requirements.
