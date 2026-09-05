# California Outside Line 2022–2027: source-backed rule notes

Primary source: California Outside Line Construction Agreement between Western Line Constructors Chapter of NECA and IBEW Locals 47 and 1245, effective June 1, 2022 through May 31, 2027.

Source PDF:
https://ibew1245.com/wp-content/uploads/2022/06/California-Outside-Line-Construction-Agreement-2022-2027-signed.pdf

These notes exist to support tests and later agreement ingestion. They are **not** a legal interpretation and should not be exposed to users as authoritative entitlement language without a separate verification workflow.

## Rules currently safe enough for deterministic fixtures

### Section 4.6 — Minimum Call Out

The agreement states that an employee called from home for unscheduled overtime receives a four-hour minimum at the applicable rate. It also contains overlap language for callouts that run into the employee's regular shift.

Current domain coverage:

- supports a four-hour minimum;
- pays a short callout up to the minimum using the highest applicable multiplier on that callout;
- tests isolated callouts outside regular scheduled hours.

Not yet implemented:

- the specific overlap treatment when the four-hour guarantee extends into the regular shift.

Reason: that interaction should be modeled explicitly rather than inferred from a generic minimum-hours rule.

### Section 4.10 — Holidays and Overtime

The agreement states that work outside regular scheduled working hours, on Saturdays, Sundays, and on listed holidays is paid at double the regular straight-time rate.

Current domain coverage:

- configurable regular schedule windows;
- configurable outside-schedule multiplier;
- weekday premiums;
- explicit date premiums;
- a `highestApplicable` premium-combination policy so overlapping 2x reasons do not multiply into 4x.

The test fixture uses a user-confirmed Monday–Friday 07:00–15:00 schedule only to exercise the rule engine. That particular schedule is **test input**, not a claim that every worker under this agreement has those exact hours.

### Exhibit A — 2026 Journeyman Lineman wage

The wage exhibit lists the Journeyman Lineman wage effective June 1, 2026 as **$74.43/hour**.

Current domain coverage:

- source-backed test fixture uses $74.43/hour;
- agreement version is represented separately from the agreement identity;
- work outside the snapshot effective dates is rejected.

## Important rules deliberately not encoded yet

### Section 4.13 — Eight-Hour Rest Period

The agreement states that when workers are required to work six or more hours of overtime outside normal shifts, they are to receive eight or more continuous hours of rest or remain at the applicable overtime rate until released for that rest period.

This is **not yet encoded**.

Why: there are load-bearing semantics that should be verified with experienced workers or union interpretation before code is treated as correct, including:

- what exactly starts and ends the qualifying six hours;
- whether separate overtime intervals aggregate;
- how a shifted regular start interacts with the rule;
- how callouts inside the required rest window should be treated;
- how the rule interacts with local job-specific schedule changes.

The engine should gain a rest-period rule only after these semantics are represented by real anonymized examples.

### Section 4.7 — Meal Periods

The agreement includes employer-provided meal requirements and a payment when required meals are not provided.

This is not yet inferred automatically because LinePay would need reliable facts about:

- whether the employer provided the meal;
- the previous owed meal period;
- whether work completed before the relevant meal time;
- notification timing for certain early-start cases.

A future implementation should likely accept an explicit worker-confirmed meal event before calculating a missed-meal component.

## Engineering rule derived from this research

Agreement text is not converted directly into executable rules by an LLM.

The safe pipeline is:

1. source document;
2. extracted candidate provision;
3. human/domain verification;
4. explicit deterministic rule representation;
5. canonical examples;
6. automated tests;
7. immutable versioned agreement snapshot.

If the provision cannot be represented without hidden assumptions, the app should ask the worker to confirm the missing fact or mark the rule unsupported rather than inventing an answer.
