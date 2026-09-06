# Lineworker pay-rule catalog

[Payroll home](README.md) · [Calculation contract](calculation-spec.md) · [Sources](sources.md) · [Coverage](coverage-and-gaps.md)

**PRODUCT requirements for rule discovery and representation.** The rows enumerate questions to resolve, not promises that all workers receive these payments or that all variants are implemented. Use [the legal baseline](us-legal-baseline.md) for external obligations. Record missing context rather than guessing a “standard lineman” arrangement.

## Applicability envelope

Before a named preset is admitted, identify employer and agreement assent, utility versus outside-construction work, classification and apprentice step, place/project, controlling wage letter and amendments, effective dates, normal schedule, contract workday, statutory workweek, and any project wage determination. Preserve these as structured scope or an explicit unsupported condition.

| Rule ID / concept | Minimum confirmed inputs | Boundaries and traps | Release treatment |
|---|---|---|---|
| PAY-01 Base wages | Classification, employer, applicable rate, currency, effective interval | Journeyman, apprentice, foreman, operator, and groundman are not interchangeable; latest rate cannot replace old rates | Effective-dated source or explicit user entry; distinguish confirmed from externally reviewed |
| PAY-02 Daily overtime | Qualifying hours, workday start/timezone, thresholds, multipliers | Separate intervals aggregate; rate changes do not reset hours; 4×10 or non-midnight days require explicit support | Only declared variants; not a substitute for weekly law |
| PAY-03 Weekly overtime | Full recurring statutory workweek, compensable hours, regular-rate inclusions/exclusions, qualifying credits | Pay-period averaging, incomplete weeks, multiple employers/joint-employment issues, bonuses, paid-leave hours | Do not claim federal completeness until this separate layer is implemented and reviewed |
| PAY-04 Outside schedule | Approved regular windows, exceptions, multiplier, effective dates | Shift transfers, split/overnight schedules, voluntary swaps, unscheduled extensions | Unknown schedule cannot establish off-schedule premium |
| PAY-05 Weekend / dated premiums | Actual applicable weekday/holiday list, observance, work performed, multiplier | A calendar holiday can differ from contractual observance; worked premium is different from paid holiday leave | Explicit dates and combination rules; no universal weekend/storm default |
| PAY-06 Callout minimum | Trigger, reporting/call times, actual work, minimum unit and rate | Multiple calls, regular-shift overlap, canceled calls, contiguous duty, minimum crossing rate changes | Isolated minimum variant only unless interactions are represented |
| PAY-07 Rest / fatigue pay | Qualifying prior work, release and recall times, uninterrupted rest, affected shift, exact clause | Premium while working and pay for time resting are not the same; interruptions and aggregation matter | Separate verified state machine or unsupported, not a guessed “8-hour rest” toggle |
| PAY-08 Meal-related pay | Meal obligation, provision/refusal, actual break/duty status, timing, trigger and remedy | Reimbursement, cash penalty, employer-provided meal, and paid work time are different | Explicit events and eligibility; do not infer from long shift length alone |
| PAY-09 Travel | Reporting/job/home locations as needed, directed travel, driver/passenger, time and applicable source | Commute, between jobs, special assignment, overnight trip, return travel, contractual pay versus statutory hours | Review compensability and contractual entitlement independently |
| PAY-10 Standby / on-call | Required restrictions/location, response expectations, actual responses, contract allowance | Standby allowance does not automatically make every standby hour worked; nominal label does not decide law | Unsupported complex classification remains visible |
| PAY-11 Reporting / show-up | Scheduled report, actual availability/work, reason work stopped, minimum basis | Weather cancellation, sent home, minimum-hours exceptions, no actual work | Separate entitlement from actual work and regular-rate/credit treatment |
| PAY-12 Subsistence / per diem | Exact eligibility, work date/shift/trip basis, amount, partial-day and employer-provided lodging/meal exclusions | Calendar midnight, duplicate entries, termination day, receipts, tax treatment, separate reimbursement line | Simple flat work-date variant is not full subsistence coverage |
| PAY-13 Mileage / expense reimbursement | Approved distance/receipts, business use, contractual rate and unit, effective period | GSA/IRS rates do not by themselves establish the employer's promise; net/gross mapping differs | Keep separate from wages unless applicable source says otherwise |
| PAY-14 Shift, hazard, incentive, or storm supplements | Explicit agreement/pay policy, task/assignment trigger, units, applicable dates | “Storm” or “hazard” description is not a universal multiplier; regular-rate inclusion needs review | Never infer from job notes, GPS, weather, or model output |
| PAY-15 Bonus / retroactive adjustment | Type, earning period, allocation method, affected historical weeks and paid adjustments | Nondiscretionary inclusion, recalculated premiums, check date not necessarily earning date | Preserve revision history; unsupported statutory recalculation cannot be reported complete |
| PAY-16 Paid leave / holidays not worked | Leave type, approved paid units, contractual aggregation policy | Paid hours need not be statutory worked hours; leave wages differ from holiday-work premiums | Record separately; do not fabricate work intervals |
| PAY-17 Employer benefits / fringe / cash-in-lieu | Benefit plan or incorporated project rule, cash versus contribution, units, classification | Wage package is not cash gross; apprentice wage percentages do not automatically scale every fringe | Independent ledger category and scope, not inferred from base wage |
| PAY-18 Deductions / net pay | Confirmed deduction type, authorization/legal context, basis and paid amount | Dues, taxes, benefit contributions, garnishments, advances and employer costs differ | Gross reconciliation does not claim deduction legality or predict net tax |

## Agreement-specific example without universal defaults

The [California outside-line source](sources.md#c01) illustrates why scope matters. Its listed wage is classification/date-specific and distinct from pension contribution; its callout clause has overlap semantics; its overtime, rest and subsistence provisions are separate clauses. That does not authorize using those parameters for a different employer or another state's lineworker.

Existing [repository research](../../research/california-outside-line-2022-2027.md) explicitly identifies unimplemented clause interactions. Carry those exclusions into any user-facing profile, not merely into developer notes.

## Combination and precedence record

Every admitted rule should answer: Can it coexist with another payment? Does it substitute for, supplement, or create a floor beneath another component? Which amount is already base compensation? Does a minimum apply per event, period, or date? Does a payment count as work time, regular-rate remuneration, or an eligible premium credit? These are separate axes, not one “overtime” boolean.

A worker may enter a simple known rule without having every legal answer. In that case preserve the configured estimate and an explicit unreviewed legal layer. Do not claim that a disclaimer repairs a materially misleading total.

## New-rule acceptance template

```text
Rule ID / version:
Authority class: law | agreement | employer policy | worker-entered
Applicable employer / project / classification / jurisdiction:
Effective dates and relevant timezone / day / week:
Exact source and clause; amendment context:
Confirmed facts required:
Calculation, units, rounding:
Interactions and exclusions:
Unsupported variants:
Positive / boundary / negative examples:
Reviewer and evidence (not AI-invented):
Candidate code / tests / user-visible scope:
```

Follow [source approval](sources.md) before shipping a named verified pack. Prefer a small correct variant to a broad ambiguous rule, but disclose omissions that could change a paycheck conclusion.
