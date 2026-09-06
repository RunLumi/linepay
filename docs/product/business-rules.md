# Business rules

[Product home](README.md) · [App workflows](app-workflows.md) · [Payroll](payroll/README.md) · [Pricing](pricing.md)

**Status: normative product contract, not an implementation-complete declaration.** Stable IDs below are suitable for issues and regression-test names. External wage obligations are governed by [the legal baseline](payroll/us-legal-baseline.md) and the actual applicable agreement, not this product specification.

## Identity, scope, and trust

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-001 | Public name is LinePaycheck; technical identity remains LinePay / `com.streamentry.linepay`. | Documentation or visual work does not rename bundle, scheme, storage identifiers, or subscription products. |
| BR-002 | Core use needs no LinePay account, password, employer connection, or LinePay pay-data server. | Setup, work entry, calculation, document processing, and access to saved records work locally. Store commerce has separate platform requirements. |
| BR-003 | One local worker and one primary pay profile are the launch default. | Switching employer, jurisdiction, or agreement does not silently reinterpret earlier work. Multi-employer statutory aggregation is not implied. |
| BR-004 | Every estimate states its covered work, rule version, currency, time context, and material exclusions. | Missing coverage never becomes “all legally owed pay checked.” |
| BR-005 | User confirmation establishes what the user entered, not legal correctness. | A confirmed rate or disabled rule is not labeled legally verified. Mandatory rules cannot be waived by a switch. |
| BR-006 | Unsupported or disputed rules remain visible. | The worker can record the missing rule; totals and audit conclusions are qualified accordingly. |

## Profile, rule sources, and time

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-010 | First setup progressively gathers pay basics, period dates, optional supported rules, and explicit confirmation. | No hidden preselected agreement, premium, or invented work. Before any limited estimate, explain unconfigured coverage. |
| BR-011 | Rates and rules are versioned with source and effective scope. | A saved result identifies the exact version used, including any effective-dated changes. |
| BR-012 | Profile edits have an explicit application scope. | Show a before/after review for changes affecting recorded work; future-only changes leave earlier earnings unchanged. Revisions preserve prior evidence. |
| BR-013 | Payroll/work timezone, contract workday, statutory workweek, pay period, and payday are separate concepts. | A phone timezone change cannot move old work between days or periods. Unsupported non-midnight workdays or weekly rules are disclosed. |
| BR-014 | Correcting period boundaries requires validation. | Existing work stays contained; periods cannot overlap inadvertently; a correction invalidates or revises affected audits explicitly. No ineffective date controls. |
| BR-015 | A source reference records which rule it supports. | A wage sheet does not verify rest pay, per diem, or every clause in the agreement. A URL and “verified” timestamp alone are insufficient for legal approval. |

## Work and period lifecycle

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-020 | Work records are facts, not amounts reverse-engineered to make a paycheck fit. | Actual time stays distinct from guaranteed paid equivalents and allowances. |
| BR-021 | Add, edit, repeat, delete, and Undo have consistent validation. | Start precedes end; explicit breaks are valid and nonoverlapping; duplicate IDs/overlaps cannot inflate pay. Errors identify the conflicting facts where possible. |
| BR-022 | Repeat creates a reviewable new draft. | Copy useful times/breaks/type, not original identity or proof that work happened. Show the proposed date, preserve the relevant timezone, and handle DST ambiguity explicitly. Reuse remains available after period rollover. |
| BR-023 | Unsaved work, setup, and paystub review survive ordinary interruptions. | Draft recovery returns to the original period/source and never silently overwrites another draft. Explicit discard is different from closing a sheet. |
| BR-024 | Undo belongs to its originating period and state. | Stale Undo after closing A cannot restore A's entry into B. A failed save cannot show success. |
| BR-025 | Closing work and receiving a paycheck are independent events. | Work period B remains usable while A awaits payment; A can receive a late audit without changing B. |
| BR-026 | Historical corrections append identifiable audit revisions. | The original work, rule versions, prior confirmed facts, engine version, result, and evidence references remain traceable unless explicitly deleted. |
| BR-027 | Finishing a period requires a clear summary and confirmation. | Show period and audit state. An unaudited closed period says “Awaiting paycheck,” not “Verified” or “Paid.” |
| BR-028 | Invalid calculations cannot be finalized as successful audits. | “Calculation unavailable” is not $0.00. Do not silently finalize/export a stale result as current. |

## Paycheck acquisition and comparison

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-030 | Scan, image, PDF, and manual entry lead to the same confirmation contract. | Camera permission/support failure leaves manual or file entry available. |
| BR-031 | OCR creates suggestions only. | Material fields carry source/provenance and confirmation state; current-period and YTD columns cannot be guessed. |
| BR-032 | Import operations are bound to one period, document, and operation identity. | Cancellation, replacement, or a second import cannot attach a late OCR result to the wrong record. |
| BR-033 | Whole-string numeric and date validation is mandatory. | Trailing text, ambiguous separators, invalid dates, unsupported negatives, excessive precision, or currency mismatches cause an explicit error rather than partial parsing. |
| BR-034 | Full-paycheck comparison requires confirmed work completeness and compatible dates/currency. | A partial log cannot prove a full check wrong. A prefilled date is not represented as an OCR extraction. |
| BR-035 | Total/line mappings are explicit. | Wage-only gross, gross including allowances, full-rate vs premium-only wages, actual vs paid-equivalent hours, and guarantee placement are distinguished. |
| BR-036 | Verdicts are scoped and evidence-aware. | Equal gross with offsetting component errors needs review. “Gross matches” is different from “Compared lines match”; neither certifies all legal pay. |
| BR-037 | Every difference has an evidence path. | Relevant work → applied rules → arithmetic → confirmed paycheck field → original source, or an explicit notice that the original is unavailable. |
| BR-038 | Neither direction implies wrongdoing. | Use “possible shortfall,” “possible overpayment,” “needs review,” or “not comparable”; never declare theft, legal debt, or recommend automatic deduction/repayment. |

## Free, Pro, and commerce

[Pricing](pricing.md) owns price, durations, and offer strategy. [Onboarding](onboarding.md) owns detailed eligibility and presentation state. The following invariants prevent commercial logic from damaging trust.

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-040 | One Pro entitlement covers configured monthly/yearly products. | No separate scan credits, trial identity, or new subscription group added implicitly. Display localized StoreKit metadata, not hard-coded billing promises. |
| BR-041 | First complete Free audit is separate from an eligible StoreKit introductory trial. | A successful Pro/trial audit does not consume an unused Free audit. Failed/cancelled imports do not consume it. Rechecking the already authorized period is not a second new-period purchase event. |
| BR-042 | The current launch decision includes an optional annual introductory trial after real expected-pay value. | Continue Free remains available. Eligibility and terms come from StoreKit; no local seven-day timer pretends to grant verified Pro. |
| BR-043 | Only a verified entitlement unlocks new recurring Pro audits. | Pending, cancelled, failed, expired, or revoked transactions are handled explicitly; applicable verified grace status is respected. |
| BR-044 | Product metadata availability and entitlement availability are independent. | An offline product-price fetch failure does not prevent checking locally available signed entitlements. |
| BR-045 | Worker-owned data remains accessible. | Expiry or store failure does not erase or ransom already recorded work, historical results, originals, or essential data export/backup. “Pro history/export” marketing must not be read as permission to lock existing records. |
| BR-046 | Local-only sampling is an intentional trade-off. | Do not add accounts, surveillance, or a backend just to prevent resetting the Free allowance. Restore commerce independently of imported local data. |

## Data ownership, failure, and recovery

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-050 | Wage and document data remain local unless the worker deliberately exports/backs them up. | Disclose that a selected Files/iCloud provider or an external share recipient may hold the exported copy. “No LinePay server” does not mean “cannot ever leave the device.” |
| BR-051 | Retain, replace, and delete original evidence are separate intents. | Editing manual values or failing to reread an original never implies permission to delete it. |
| BR-052 | Deletion is recoverable and truthful on failure. | Keep a retryable cleanup record until deletion succeeds; do not claim all data removed while orphaned originals or app-controlled temporary exports remain. Do not delete external user-exported copies. |
| BR-053 | Durable mutations are validated and committed atomically. | A failed write preserves prior readable state; corruption/future schema never triggers a silent reset or partial “success.” |
| BR-054 | Backups restore local records, not subscription authority. | Validate schema, identity, data relationships, evidence paths/integrity, and size limits; stage and roll back failed imports. Confirm replacement before modifying current records. |
| BR-055 | Historical meaning survives migration and backup/restore. | Frozen timezones, effective rules, calculation versions, audit revisions, and source relationships survive. Version-one and failure fixtures prove behavior. |
| BR-056 | Reports are scoped evidence receipts. | Include period, comparable basis, creation time, rule/engine references, confirmation state, and limitations; originals are included only through an explicit option. |
| BR-057 | Errors and accessibility are product behavior, not cleanup work. | Key actions work with large text/assistive technology; errors say what to do next; private paystub data is not logged or uploaded for diagnosis. |

## Change protocol

A behavioral change cites the affected BR ID and [example](payroll/worked-examples.md), updates scope/evidence when needed, and receives the narrowest meaningful regression test. A new legal rule additionally passes [source approval](payroll/sources.md). Changes to money, history, migration, or subscription boundaries require tests on the candidate code; documentation is not a substitute.
