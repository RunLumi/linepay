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
| BR-033a | A pay profile has one currency, chosen at setup (USD, CAD or VND, suggested from the region) and fixed once saved. Typed numbers follow the region's decimal separator. | `58,40` and `1.234,56` are read in comma-decimal regions; a lone `58.40` stays unambiguous there. Zero-decimal currencies (VND) round to whole units and accept paycheck-sized amounts. The OCR parser keeps the U.S. paystub grammar. |
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

## Employer benefit contribution checks (v2)

These requirements do not establish end-to-end implementation or legal/project coverage.

| ID | Rule | Acceptance condition |
|---|---|---|
| BR-060 | Employer contributions, cash wages, allowances and employee deductions remain distinct. | A benefits difference never changes wage gross, take-home pay or the wage verdict. |
| BR-061 | Fund identity, eligible units, basis, currency, effective dates and source snapshots are explicit. | No fund membership, OT unit multiplier, qualifying earnings or legal obligation is inferred. |
| BR-062 | Statement comparison is scoped to the same fund and work period. | Missing statement is unverified; incompatible fund, period, timezone or currency is not comparable. A unit-only result cannot imply an amount match. |
| BR-063 | Benefits history remains reproducible. | Corrections append revisions; exact eligibility facts, rule snapshots, original observations, engine version and rounding survive backup/restore. |
| BR-064 | Comparison language preserves unknown coverage. | A match concerns only the confirmed contribution values; caps, eligibility exceptions, contribution timing, project/fringe compliance and employee deductions remain separately identified when unsupported. |

## Change protocol

A behavioral change cites the affected BR ID and [example](payroll/worked-examples.md), updates scope/evidence when needed, and receives the narrowest meaningful regression test. A new legal rule additionally passes [source approval](payroll/sources.md). Changes to money, history, migration, or subscription boundaries require tests on the candidate code; documentation is not a substitute.


## Manual worker-provided rule drafts (v2)

[Portable contract](../../shared/contracts/templates/README.md) owns the v1 wire shape and limits.
These are worker-provided selected parameters, not verified agreement packs or complete pay coverage.

| ID | Rule | Observable consequence |
|---|---|---|
| BR-070 | Export sharing is explicit and minimizes personal pay data. | Work/paycheck/fund/evidence records and private ledger IDs are never copied; wage/allowance amounts are omitted unless explicitly included and reviewed. Titles/conditions may still identify a group. |
| BR-071 | Inspection is not adoption or source verification. | Unknown/incompatible/ambiguous files refuse; inspected drafts create no profiles and confer no official/union/professional approval. |
| BR-072 | Recipient monetary values and applicability require confirmation. | Omitted values never become zero. Configured allowance needs an own-amount/not-applicable decision. Unconfigured remains unconfigured, not waived. |
| BR-073 | Sharing never rewrites historical rules. | Confirmed import creates a fresh profile for future periods; old work/rules/calculations/checks remain unchanged. |
| BR-074 | Retain reproducible import provenance. | Original admitted packet, identity/revision and recipient choices/confirmation survive backup/recovery; changed profile values require a new profile/choice. |


## Worker follow-up and reviewed report copies

| ID | Rule | Observable consequence |
|---|---|---|
| BR-075 | A resolution status is the worker's report, separate from payroll arithmetic. | Corrected/explained/shared does not rewrite an audit verdict, prove payment/recovery or send a message. Corrections append events. |
| BR-076 | Follow-up belongs to a specific saved comparison. | Unknown/orphaned references refuse; another paycheck revision's notes never appear in a selected report. |
| BR-077 | A report uses the selected saved snapshot and explicit privacy choices. | New profiles do not reprice it. Notes, detailed clocks and draft text are omitted by default; unknown gross is never zero. |
| BR-078 | Export follows exact-copy review. | Changing privacy options invalidates preview/actions. Downloaded HTML uses the reviewed bytes; oversized reports refuse without truncating a tail. |
| BR-079 | Printing/exporting is not delivery or external verification. | Local Blob review, browser PDF rendering, OS/provider save, recipient transfer and release remain separate evidence claims. |


## Effective-date plan ownership

| ID | Rule | Observable consequence |
|---|---|---|
| BR-080 | Changes use explicit payroll-local dates and immutable compatible snapshots. | No device-timezone/rate inference, duplicate date/version choice, currency conversion or incompatible rounding policy. |
| BR-081 | A revised open-period plan does not rewrite a saved comparison. | Earlier audit retains its engine/work/baseline or exact plan ID; a missing reference refuses rather than reprice. |
| BR-082 | Price aggregation does not round independently at a rate-version boundary. | Compatible category/multiplier numerators sum first; one second each at 18 and 54/hour totals 0.02, not 0.03. |
| BR-083 | Binding guarantee uncertainty stops price selection. | A physical callout spanning an effective change requires review when a minimum could bind; no guessed split/top-up. |
| BR-084 | Saving must not discard the next work entry. | Existing controls are visibly unavailable while a mutation commits, after values are captured; errors retain entered values and old state. |


## Calendar windows and reported paycheck periods

| ID | Rule | Observable consequence |
|---|---|---|
| BR-085 | Paycycle means explicit local calendar boundaries, not fixed elapsed hours. | Seven/fourteen dates, true half-months and custom inclusive bounds retain their timezone and UTC boundaries through DST/leap/year changes. No statutory workweek is inferred. |
| BR-086 | Source work-period dates are distinct from selected ledger dates and payday. | New comparison fields start blank; prefilled timezone is a review context, not an extracted fact. |
| BR-087 | Unknown/unconfirmed/mismatched source scope stops directional comparison. | Paid facts remain; expected comparison/difference are null, never zero or an inferred shortfall. |
| BR-088 | Retain the evidence basis of each comparison version. | New source facts commit with the review; source edits clear confirmation. Legacy dates/cadence remain explicitly unretained rather than backfilled. |
| BR-089 | New calendar corrections do not rewrite history. | The native calendar helper affects new windows only; existing window instants and saved comparisons remain unchanged. |
