# ADR 0005: effective-dated rule snapshots and scoped audit verdicts

Status: accepted implementation contract. Native and device validation are separate release evidence.

## Decision

Keep the pure Swift calculator and existing local document store. Add a small, ordered timeline of complete worker-confirmed agreement snapshots. Do not freeze the current profile's newest rate into earlier work or introduce a backend.

A change begins at midnight on a confirmed **payroll-local date**. The original baseline is retained, and each actual work segment selects the applicable snapshot for its local date. Daily overtime accumulates across entries on that date; overnight work splits at local midnight, preserving elapsed time through DST. Per-diem and schedule rules use the same dated snapshot. Each calculated component records its rule identity/version/rate, while the result retains the distinct complete snapshots used.

A prospective edit must begin after the last local date touched by existing work. Backdated work entered later still resolves through the same date timeline. An explicit correction is a different intent: preview current expected pay, confirm recalculation of all open-period work, and invalidate that period's audit. The correction removes scheduled changes inside the current period but retains changes starting in later periods. Archived work, calculations, rule snapshots, and confirmed facts are never rewritten by either operation. The open period's timezone cannot be changed through rule editing.

The default UI is a prospective change at the next period boundary. Users can choose another eligible date. Editing the profile alone does not close or split a work period. There is no invented overtime policy or implicit replacement of a signed agreement.

## Deliberately unsupported ambiguity

If a callout spans a rule-change boundary and a minimum-hours top-up might apply, the contract may determine which rate prices that guarantee. The engine returns an explicit review requirement rather than guessing. The app preserves the original work facts, presents an unavailable calculation rather than $0, and blocks audit/archival of an unpriced result. A callout that already satisfies both minimums is split and paid as actual work. Adding a configurable cross-boundary guarantee policy requires a separate confirmed rule and fixtures.

## Persistence and backup

State schema 2 adds optional baseline/timeline fields and component provenance. The physical state filename remains `state-v1.json` so existing installations are found; its embedded schema is authoritative. Schema-1 records upgrade in memory without replacing stored historical calculation results or modifying bytes during a read. The next normal successful save writes schema 2 atomically.

The backup envelope remains format 1. It includes the embedded state schema; imports accept schema 1/2, validate schedules and referenced rule snapshots, then restore as schema 2. Older app builds reject state schema 2 rather than silently dropping schedules. Back up before downgrading; do not expect an older build to open newer data. Original evidence bytes and historical identities remain part of the existing staged restore contract.

## One audit assessment

`AuditAssessment` owns amount aggregation, confirmed worked-hour comparisons, the summary verdict, and its scope explanation. AppModel, live views, history, and PDF exports use that assessment. A stored gross reconciliation remains a gross observation, not the display verdict for an entire paycheck.

- **Gross total matches:** only gross was compared; components and hours are unverified.
- **Confirmed items match:** the supplied details match; blank items, deductions, and unsupported rules remain unverified.
- **Needs review:** conflicting confirmed components/hours, a currency conflict, stale calculation, or unavailable evidence. Equal gross cannot hide offsetting differences.
- **Possible shortfall / overpayment:** comparable gross differs without contradictory confirmed detail. The difference remains visible even when the broader verdict needs review.

Hours compare actual worked-hour buckets, not synthetic callout-guarantee hours. Differences are reasons to review payroll categorization/rounding, not legal conclusions. Missing optional values are not zero. Auditing with no work is blocked without consuming the free audit.

This change does not solve every existing product gap, especially paycheck layouts that report allowances separately from gross, late first audits of closed periods, arbitrary agreement support, durable drafts, or source-crop OCR review.

## Verification contract

`AgreementTimelineTests`, `RuleScopeRegressionTests`, `AuditScopeRegressionTests`, and `TimelinePersistenceTests` replace the two expected-known-issue cases with ordinary assertions. They cover prospective increases/decreases, overnight tails, pending changes, explicit correction, failed saves, historical preservation, schema-1 migration, backup round trips, gross-only scope, offsetting components, confirmed hours, and PDF verdict consistency.

Maestro flows `rule-scope.yaml` and `audit-scope.yaml` exercise the real entry/edit/confirmation/audit routes. Native CI runs the existing journeys plus these regressions and captures compact dark/large-text variants. A configured flow is not proof it passed: retain exact-commit logs and screenshots. Hardware scanner, signed StoreKit lifecycle, and two-device iCloud transfer remain separate checks. Never report all-screen or 100% application coverage from these tests.
