# ADR 0012: separately confirmed employer benefit contributions

Status: accepted for v2 implementation, October 16, 2026. Native storage/UI is in progress;
this decision is not evidence of a released benefits audit.

## Meaning and scope

The owner authorized the complete v2 roadmap. Add a worker-owned local benefits audit without
changing wage gross, per diem, employee deductions or the existing wage verdict. Pension, annuity,
health/welfare and other fund names describe the worker's own configured record, not official packs.
There is no inferred fund membership, legal entitlement, project/fringe compliance or fund API.

A fund has stable identity across immutable rate snapshots. Each snapshot states version,
currency, hourly/daily/percentage/fixed-period basis, effective interval, timezone and source
references. Each eligibility segment retains that exact snapshot, scoped work dates and explicitly
confirmed eligible units. Actual shift hours, overtime paid equivalents and eligible benefit units
are distinct. Percentage rules use separately reviewed eligible earnings; allowances or wage gross
are not silently substituted. Fixed-period amounts are explicitly scoped to that exact assessment period; they cannot be multiplied by splitting it or treated as a weekly proration of a monthly amount. A rule ID cannot identify conflicting snapshots.

A calculation covers one explicitly complete fund/statement period. Segments cannot overlap or
extend beyond their source snapshot's dates. Gaps can represent dates with no eligible work only
under the worker's whole-period eligibility confirmation. Independent expected quantities and money
are exact Decimal values. Sum unrounded segment contributions, then apply the recorded rounding
mode/scale once per fund; reject arithmetic precision loss or overflow. The difference subtracts the unmodified confirmed observation from that rounded expectation without a second rounding step. Statement precision must not disappear into a false match. Cash pay remains unchanged.

## Evidence and comparison

Missing or unconfirmed statement facts are not verified, never zero. Confirmed observations identify
the fund, currency, statement work period/timezone, employer contribution amount and optional eligible
unit count/basis. Mismatched fund, date interval, timezone or currency is not comparable. Differing
unit bases do not become a false unit match. An amount-only or unit-only comparison states that scope.

Retain the expectation's period, rule/fact segments, statement observation, engine version, rounding
policy, result and limitations together. Corrections append a revision in the native adapter; a new
rate or later statement does not rewrite a historical comparison. Backups and manual exports must
preserve these relationships; no backend or automatic collection is introduced.

## Native storage and review

Schema 7 adds optional benefits drafts and records; versions 1–6 migrate additively, without
repricing wages or inventing benefit records. Each correction binds to the latest revision and
appends immutable input/result snapshots. Another period reuses fund identity only. A stale
preview, unrelated unfinished draft or failed state write cannot overwrite newer input.

Drafts preserve their numeric-entry separator and explicitly stored rounding scale. Material rule
or eligibility edits clear expectation confirmations; statement edits clear statement confirmation.
The editor separates input, comparison preview and explicit save. Historical input retains its
original numeric context and exact source snapshots.

Statement PDFs use the existing protected evidence store and preserve a SHA-256. Import is bound
to the intended draft and does not automatically read or confirm numbers. Backups remap physical
filenames while preserving logical identity and hashes. Original removal affects shared references,
not recorded statement facts or results. Benefits source references protect cited agreement imports.

The separate benefits PDF reuses the existing immutable-preview sharing session and paginated
text writer. Source names/quotations/fingerprints and the private note require separate opt-ins.
No original PDF pages are embedded. Report preparation, native transfer, provider persistence,
source rights and legal review remain distinct evidence states.

## Acceptance

Pure fixtures independently check hourly, daily, percentage and fixed amounts; 40 hours at 8.75
is 350, while a confirmed 35.5-hour / 310.63 statement gives 4.5 hours and 39.37 possible differences.
Check rounding across rate versions, exact effective boundaries, missing statements, incompatible
fund/currency/units, invalid decoded input and overflow. Native acceptance additionally requires
explicit confirmation, immutable revision/history, save failure/migration/backup evidence, source
navigation and separate report/UI statements. Pure-domain tests alone do not complete that acceptance.
