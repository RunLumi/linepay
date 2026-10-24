# ADR 0033: Android confirmed employer contribution receipts

Status: accepted for implementation. October 22, 2026. Owner-authorized Android v2 scope;
local-only data-flow decision remains binding.

[Android local state](0030-android-local-native-state-and-export.md) · [Payroll coverage](../product/payroll/coverage-and-gaps.md)

## Context

Android has a pure confirmed-benefit calculator but no usable entry, saved evidence or replay path.
A contribution comparison must preserve its own eligibility, rule dates and statement scope; wage
amounts and a worker's checkbox cannot establish legal eligibility or agreement applicability.

## Decision

- Add one separate Compose review for a fund display name plus a separate source-specific fund identifier/reference, uppercase currency and explicit local
  date period with time zone. End dates are exclusive. The user supplies bounded, non-overlapping,
  explicitly confirmed eligibility segments, exact decimal quantities and rates, effective dates,
  source version/title/reference and eligibility evidence. Support the domain's four existing bases.
- Optional statements preserve missing and confirmed zero, exact fund/currency/date/time-zone scope,
  independently confirmed values and source reference. Exact fund identifier spelling/case is significant; display names alone never establish matching scope.
  Stable domain fund UUIDs are derived from the worker-entered source identifier without sending it anywhere. Mismatches
  remain not comparable. Units-only comparisons never claim verified payment.
- Use the existing pure calculator, combined-total two-place half-up rounding, unrounded components,
  and explicit limitations. Do not infer employer benefits from wage work or alter paycheck results.
- Schema 4 adds `benefitReviews` to app-private state and the existing encrypted manual backup.
  Schema 3 migrates by adding an empty collection without rewriting existing profile/work/check/
  weekly JSON trees. Schemas 1 and 2 retain their existing safety migrations before that addition.
  Reject legacy payloads that smuggle nonempty benefit receipts and current payloads missing the
  new collection. No Android automatic backup, network permission or new runtime dependency.
- Every decoded or saved receipt validates bounded source metadata, canonical UUIDs, strict decimal
  entry and all domain invariants; recompute the result and require exact snapshot equality. Save
  only after an explicit preview. Any input edit invalidates the preview. Saved snapshots include
  all input rules/segments/statement, result, engine and rounding semantics for reproducible history.
- Append revisions with a new receipt identity and a retained earlier receipt link. Never mutate
  original receipts. Bound receipt count to 128 and segments per receipt to 100. A confirmed delete
  removes the selected receipt plus all descendant revisions and leaves work/paycheck records intact.
- Settings and History expose the separate receipts. Manual restore previews include their count.
  Local activity remains excluded. Warn before discarding an unsaved contribution form.

## Consequences and evidence boundary

This is employer-contribution arithmetic for a user-confirmed scope, not independent applicability
review, employee-deduction reconciliation, fund balance/vesting verification, tax treatment or
prevailing-wage compliance. Ineligible-time decisions and source rights remain the user's evidence;
no named agreement pack or professional verification is invented. Device-local source notes are
private pay data and may leave the device only through the existing explicit encrypted backup.

App-unit regressions cover independent arithmetic, zero/missing, mismatched scopes, units-only,
effective dates, percent/fixed-period boundaries, exact rounding, append-only revision and deletion,
malformed results/sources/IDs, schema migration and encrypted round trips. The checked-in Compose
journey exercises entry, preview, save, history, Activity recreation, revision and local backup with
synthetic data. A test existing or compiling is not a device execution receipt; report actual host,
emulator, physical-device and store evidence separately.
