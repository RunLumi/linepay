# On-device voice work verification

[Testing](README.md) · [Architecture decision](../adr/0014-on-device-voice-work-drafts.md)

## Proven layers and remaining boundary

`VoiceWorkTests` exercises explicit parsing, selected payroll timezone, overnight dates, break
validation, DST refusal, real Speech request flags and scoped temporary-audio deletion. The native
`VoiceWorkJourneyTests` types a synthetic reading into the real review screen, confirms it, saves
work separately and verifies relaunch. Its typed input does **not** prove microphone capture,
transcription accuracy, permission dialogs, interruptions or offline recognition.

No connected physical iPhone was available in the October 16 development check. Record device,
iOS version, candidate source/build and actual outcomes below before claiming the speech path is
release-verified. Do not turn a missing asset, simulator limitation or skipped test into a pass.

## Physical-device procedure — not yet executed

Use only a synthetic profile: USD 50/hour, America/Chicago, a selected October 16, 2026 work date,
with no saved work and no configured premium triggered by this ordinary eight-hour interval.
Do not overwrite a real worker's existing installation/data to establish this fixture.

1. Open Add work → Use a voice work draft. Check the date/timezone. Record the synthetic sentence:
   “Regular from seven AM to three thirty PM. Unpaid break from noon to twelve thirty PM.”
2. Stop and read. Compare the actual reading to the spoken sentence; edit every misread fact.
   Review must show October 16 07:00–15:30 CDT and a 12:00–12:30 unpaid break. No work should have
   been committed. Confirm and apply; only the editor draft changes. Save work separately and
   verify eight worked hours and USD 400 expected wages, then relaunch and inspect the record.
3. Repeat with networking unavailable (airplane mode, Wi-Fi disabled). On-device-capable recognition
   must either produce the reading locally or report unavailability. Never enable server fallback
   to make the test pass. Record actual model/language availability and any OS asset requirements.
4. Deny microphone permission, then speech permission independently in fresh synthetic permission
   states. Manual entry must stay usable. Review the actual purpose strings. Do not reset unrelated
   app permissions/device settings; restore only task-owned test changes afterward.
5. Start, cancel, reopen and start again. Cancel while permission is pending. Stop rapidly, switch
   apps, interrupt with another audio session and terminate while capturing/transcribing. Old
   callbacks must not update a new session, keep the microphone active or create saved work.
6. Let a recording reach its one-minute limit. Verify the visible capture state ends, transcription
   times out/reports failure safely when necessary, and the ordinary editor remains available.
7. Check temporary CAF removal after success/cancel and abandoned cleanup after relaunch. Financial
   backups and data exports must contain no temporary audio or un-applied transcript. All-data
   deletion retries owned-audio removal and must report failure if it cannot complete.
8. Edit a confirmed reading or selected date: confirmation and proposal must clear. Try an ambiguous
   clock, DST fold/gap, missing break facts, an overnight end without “next day”, an overlap and a
   callout touching another callout. Existing work validation/event review must remain authoritative.
9. Run light/dark, large text and VoiceOver review. Reach record/stop/cancel, editable reading,
   proposed timestamps, confirmation and separate Save work. Device-local activity must record
   a new work entry only after successful saving, not on recording or draft preview.

Retain only synthetic/redacted screenshots and status evidence. Do not attach recordings of people,
real work details or a full user backup to a public issue. A clean App Privacy Report is supporting
network evidence, not a guarantee about payloads or future OS behavior. App Privacy owner review
for the v2 permission/data-flow change remains separate from these engineering checks.
