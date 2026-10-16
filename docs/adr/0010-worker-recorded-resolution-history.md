# ADR 0010: worker-recorded paycheck follow-up

Status: accepted October 16, 2026 for [v2](../plan/v2-execution.md).

A resolution is a worker's statement about a follow-up, not a changed payroll calculation,
a legal entitlement, employer acknowledgement or verified recovery. Save append-only events
with the period ID, exact confirmed paycheck ID, status, note, timestamp and stable event ID.
A new paycheck revision retains earlier notes, explicitly labelled as different-revision notes. An action opened from a historical audit
keeps that selected paycheck identity; it cannot silently target the latest revision.

Schema 5 adds an optional resolution-event collection to the local document. Versions 1–4
migrate without creating notes or recalculating history. All existing windows, rule snapshots,
paystub revisions and audit access remain unchanged. Events survive archive, local backup and
restore; deleting a period removes its follow-ups, while deleting all local records resets them.
Invalid references, duplicate event IDs, overlong notes and excessive histories fail validation.
Saving remains atomic through the existing state store.

Show the history from Paycheck result and allow recording notes without Pro. No employer,
union, server, email or notification is contacted. Default PDF reports exclude all follow-up
notes. An independent, default-off toggle includes them only in a newly previewed report,
using the existing byte-bound share permission. Source-detail permission does not imply
permission to include follow-up notes.

Tests must prove unchanged money/verdict, revision identity, failed-save rollback, migration,
archive/backup/relaunch, deletion and report opt-in. Native interaction remains a separate gate.
