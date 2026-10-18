# ADR 0013: device-local activity and manual diagnostic export

Status: accepted for owner-authorized v2 implementation, October 16, 2026; implemented in `d7c0ddd`; the complete native iOS gate passed (334 cases: 333 passed, one intentional store-screenshot skip). Release-candidate/device and store evidence remain separate.

The owner explicitly chose local-only data flow and manual diagnostics/backups. Implement a small
closed milestone vocabulary without an analytics SDK, collector, account, remote processing or
arbitrary attributes. No wage value, payroll date, document text, employer, union or free-text value
can be passed to the recording API. Internal deduplication takes typed identities, stores SHA-256
digests locally and excludes all identities/digests from diagnostic export. Hashing is not anonymity.

A separate versioned file holds device-lifetime totals since reset, up to 400 observed UTC days,
20,000 deduplication digests, recording preference, pause counts and known observation failures.
The ledger is outside the pay-data snapshot. Restoring a pay backup does not recreate historical
opens, configuration, work or audit observations. Existing installations are not backfilled.
First observed open is not an App Store install. Retention and clock changes limit interpretation.

Financial success is committed before recording. A diagnostic save failure neither reverses money
nor reports a successful observation. Known failures remain disclosed after storage recovers. An
unreadable/future activity file is preserved; recording stops, and explicit activity-only clearing
can recover it. The worker can disable recording and clear only activity. Deleting all local data
clears activity first while retaining opt-out; a failed activity reset cannot silently claim all
local data was deleted. Essential exports and pay access remain independent of these observations.

Milestones distinguish profile start/save, new work entries, actually surfaced safe expected pay,
intake, accepted paycheck facts and comparable confirmed checks. Corrections/rollover do not inflate
unique-period audits; a second comparable period is a separate milestone. StoreKit purchase outcomes
and verified trial/nonzero-price transaction observations remain distinct. Restores, renewals and
existing subscriptions are not new subscribers, revenue receipts or paid-conversion proof. Do not
infer trial/paid status from a catalog offer, an access boolean or a local free-audit counter.

The worker previews an immutable JSON copy containing only event labels/counts, usage days and
recording status before opening Files. It is not anonymous or a financial backup. No destination,
save/upload completion or cross-device arrival is claimed merely because a file was prepared.
The diagnostic file can leave the device only through the worker's explicit export or OS backups
under their device settings. This does not add a central LinePaycheck data service.

The roadmap's cohort/CAC and >95% coverage targets remain evaluation targets. Hook tests and local
counts do not establish production conversion, acquisition cost or global event completeness.

## Browser companion, October 19, 2026

The web client follows the same local-only boundary in its own `linepaycheck-web-activity` IndexedDB
database. It is separate from `com.streamentry.linepay.web.state` v8 and the encrypted financial
backup payload. Browser events use a closed vocabulary; UUID-shaped internal identities are
deduplicated locally and excluded from the previewed JSON export. Activity failures do not roll back
financial writes. A stored opt-out, reset generation and fail-closed future-version handling prevent
other tabs or unknown schemas from silently restoring or replacing observations. Browser/OS profile
backup behavior is platform-managed and remains unverified. The feature adds no collector, account,
tracking SDK or remote event path.

Seven dedicated Node tests and the existing 45-check Chromium/WebKit workflows cover the browser
ledger and manual export against the same runtime SHA recorded in `docs/plan/v2-execution.md`.
These checks do not imply installed-PWA, physical-device, or production-funnel evidence.
