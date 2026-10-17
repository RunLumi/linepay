# ADR 0025: versioned weekly paycheck safeguards

Status: implemented for the owner's all-stage v2 request, October 17, 2026. Native execution,
visual/PDF/provider acceptance and full weekly-to-paycheck integration remain pending.

Assessment v3 inferred safety from one pay period's hours and the presence of an attached weekly
result. Neither establishes complete workweek coverage or allocation into the paycheck being
compared. New `PaycheckAssessor` v4 keeps a weekly-mapping review reason whenever the supplied
agreement, retained calculation snapshots or attached weekly result indicate weekly scope. This
applies below, at and above 40 period hours; attached results cannot clear it. Scope amounts and
individual comparisons remain available, but the verdict is Needs review, not match/shortfall/
overpayment. Unknown gross basis or incomplete work still produces Not comparable.

This preserves the existing review-only boundary: weekly premium is not silently added to the daily
ledger. A verified period/week/paid-basis integration and its evidence remain separate required work.
There is deliberately no caller Boolean or arbitrary-result bypass for v4's missing mapping.
Nonweekly configured-scope comparisons retain their existing behavior and legal-scope limits.

Native state schema 9 admits the new comparison producer; schemas 1–8 retain their recorded
assessments/calculations without repricing. A schema8 synthetic state assembled with actual old
v3 domain receipts exercises the admission path in App test source. Those App tests still require
runtime execution. V4 state validation rejects a forged weekly match or missing mapping reason;
v1–v3 receipts remain readable as their original records. Backup/container encryption is unchanged.
No new field is inferred as proof of weekly verification.

An active old weekly comparison needs an explicit new review under v4. Loading changes neither
stored verdict/amounts nor revisions; presentation marks it out of date and the next confirmation
appends a new revision. Calculation-precision review remains a separate flag/reason. Archived
comparisons retain their original verdict and amounts, with an Earlier weekly comparison note.
Historical PDF copies label Recorded verdict and disclose that missing mapping; current outdated
copies do not render an old difference as a current directional conclusion. New v4 weekly results
remain Needs review until actual integration is implemented.

Settings/history/pay/import/report routes carry the assessment-review flag consistently. A Pro
message may name a possible shortfall only for a current open comparison whose actual verdict is
Possible shortfall; a Needs review amount cannot become an advertising claim.

`native-assessment-v3.json` was emitted from actual `614d360` domain sources. Five synthetic
receipts cover configured 8-hour, configured+unmapped weekly, unconfigured+attached weekly, no
weekly scope, and a 60-hour case already marked Needs review by v3. Original v3 verdicts/amounts survive round-trip; explicit v4 reviews change only the
scope verdict/reasons for affected cases. The fixture is wired only to LinePayAppTests, not the
shipping app target. The reviewed project.yml inventory hash is mechanical test-resource bookkeeping,
not legal/source/release approval. No new runtime dependency, permission, account or network flow.

Verify domain bypass/negative controls and actual legacy fixtures, then native migration, active
re-review, failed-write, archive/backup/relaunch and PDF/UI states. SDK typechecking does not run
those tests. #42/source/applicability review, weekly mapping, device and App Store gates remain open.


Computed receipts from known producers 3/4 have an explicit `reproduceRecorded` verification path:
use the retained original calculation, snapshot and facts, apply that producer's scope semantics,
and require the full reproduced object to equal the receipt. A mismatch refuses. This does not
create a new current result, authenticate authorship or reuse the weaker v3 guard for current
assessments. Older 1/2 receipts stay readable; this API makes no replay claim for those producers.
Five actual v3 receipts cover original matches and original review reasons, rather than verifying
history merely by serialization. No recorded-result replay is triggered automatically on load.
