# ADR 0021: versioned effective-date browser calculations

Status: accepted for the owner's all-stage v2 request, October 17, 2026. Complete native/platform,
source/applicability and release proof remain separate gates.

Preserve `payroll.mjs` / `linepay.web.configured-pay/1` unchanged for historical receipts. Introduce
`payroll-v2.mjs` / `linepay.web.configured-pay/2` for explicitly confirmed effective-date plans. The
separate implementation is a historical ownership boundary; do not refactor/reprice legacy saved
results through a newer algorithm. Shared exact-time/decimal helpers stay deterministic.

Apply immutable snapshots from payroll-local midnight on their effective date, preserving actual
instants, timezone, unpaid breaks and daily positions. Compatible currency/rounding policy and
highest-applicable premia remain required. Category/multiplier grouping spans compatible rate
versions before monetary rounding. Binding callout minima across a change refuse. Record exact
quantity, applied base rate/version, retained plan ID and complete rule snapshots in v2 results.
No device timezone, clock, network, UI or storage enters the pay function.

Web state v5 adds append-only `ruleTimelines`: confirmed ID/period/creation context plus dated,
immutable copies of confirmed source profiles. Use fresh rule versions under the period agreement
identity. Validate exact shape, source/snapshot consistency, unique compatible dates/versions and
bounds. A revised plan is another retained record; no plan is edited or silently removed. The
open ledger uses the latest explicit plan. A closed period keeps that plan and cannot adopt a later
one. Existing old-schema records gain only empty plan metadata; no price or event is invented.

A saved audit replays its recorded engine. v1 uses its original baseline; v2 resolves the exact
retained plan ID, never the current/latest plan. Missing plans or unknown engines fail closed.
Closed results and stored v2 rule snapshots must reproduce exactly. The frozen synthetic v4
fixture was generated/validated using actual `f7cbe82` modules. Snapshot-container/encryption stay
v1. Native financial-state interchange remains unsupported pending full schema migration.

Adding/revising a plan is a preview-first explicit confirmation. Dates mean the period's fixed
payroll timezone. Material edits invalidate preview/confirmation. Show current/proposed amounts
and all configured parameters; never infer a rate, allowance, timing or waived obligation. Saved
checks using earlier context remain identifiable and unchanged. Reports read their exact saved
plan/rate references, not the latest profile/plan; optional imported-draft attribution uses only
sources retained by that audit's plan.

Prevent data-entry loss during asynchronous saves. Capture handler/form values synchronously,
then disable the pre-existing enabled controls until the operation settles. Preserve independently
disabled controls and do not resurrect detached DOM. A completed render supplies fresh controls;
failed writes leave entered values and prior readable state. Do not make later clicks disappear
behind a hidden busy flag while the UI still looks editable.

Use the [independent temporal corpus](../../shared/contracts/payroll/effective-date-v1.md) in Swift,
Kotlin and browser tests, plus actual open-ledger revision/old-report/close/backup/reset/recovery.
The corpus exposed Kotlin accepting a mode change that native AgreementTimeline refuses; align
that guard rather than weakening the fixture. Do not equate bounded shared tests with complete
CBA/statutory/weekly/timezone or actual Android/iOS device readiness.
