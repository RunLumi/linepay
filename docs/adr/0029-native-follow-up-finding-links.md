# ADR 0029: native follow-up finding links

Status: accepted October 19, 2026 for v2.

## Context

Native follow-up events were bound to a pay period and confirmed paycheck revision, but not to a
specific comparison item. The report exporter accepted comparison findings while the native share
flow passed an empty array. A saved note could therefore say that a worker shared a question without
preserving which line the question concerned.

## Decision

- A follow-up may target one monetary comparison from the exact saved paycheck revision, or remain
  paycheck-level when the worker selects that broader scope.
- The stored `findingID` is the saved assessment comparison ID. The app validates it against the
  referenced `ConfirmedPaystub` when recording and when loading local or imported state. Unknown
  IDs and IDs belonging to another revision fail closed.
- App-state schema 11 adds the optional field. Schemas 1–10 retain their existing notes with no
  inferred finding association.
- The UI previews the selected line's expected amount, confirmed amount and difference. Choosing
  or saving a finding never changes work, pay rules, calculation or comparison verdict.
- A report is bound to the selected paycheck revision. The finding reference and associated note
  appear only when the user opts into follow-up history and reviews the exact report copy. Default
  reports continue to omit notes and follow-up scope. Nothing is sent automatically.

## Consequences

The PDF can carry a worker-authored question back to the specific compared earnings line while
preserving the selected audit's original evidence. This still records the worker's report; it does
not verify employer acknowledgement, payment, recovery, legal entitlement or resolution.

Tests cover exact-revision admission, unknown-reference refusal, schema-10 migration without
inferred links, backup round-trip, report opt-in, and the native select/save/relaunch journey.
