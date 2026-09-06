# Calculation specification

[Payroll home](README.md) · [Legal baseline](us-legal-baseline.md) · [Worked examples](worked-examples.md) · [Coverage](coverage-and-gaps.md)

**PRODUCT computational contract.** This defines required semantics, including gates for rules not implemented in 1.0. Statutory discussion is bounded by [the legal baseline](us-legal-baseline.md); formulas are not a substitute for source/applicability review. Current implementation is separately recorded in [coverage and gaps](coverage-and-gaps.md).

## 1. Inputs and outputs

The conceptual request includes work events, the relevant period/context, immutable agreement versions/effective changes, explicit calculation policy, and an as-of revision. It does not obtain the current rate, timezone, clock, or agreement from global state inside the engine.

Required outputs are components, separately named totals, applied rule references, source references, engine/schema version, coverage limitations, and errors. A result can be a valid partial configured estimate while being unsuitable for a full-paycheck or statutory comparison.

| Object | Required meaning |
|---|---|
| Work event | Stable identity; start/end instants; original payroll context; actual work kind; explicit break facts and notes |
| Agreement snapshot | Identity/version; source scope; effective range; rate; supported rule parameters; confirmation/review metadata; omissions |
| Rule application | Rule key/version; input event IDs; condition met; units/rate/multiplier; exclusion and combination policy |
| Component | Cash amount/currency; work time versus guaranteed equivalent; date/context; arithmetic and source lineage |
| Calculation result | Exact immutable inputs/references and outputs with the engine version used; not only the final number |

Do not pretend that every conceptual field already exists in the current Swift model. A missing required field is a coverage gap, not permission to infer it.

## 2. Exact time, contextual day boundaries

Use integer instants for duration calculations and a frozen timezone/context for calendar boundaries. Represent ranges as half-open `[start, end)` so a boundary instant is not double counted. For each valid interval:

```text
elapsedSeconds = endInstant - startInstant
workedSeconds = elapsedSeconds - sum(confirmed noncompensable break spans)
workedHours = Decimal(workedSeconds) / 3600
```

The classification of a break as noncompensable needs appropriate facts and applicable rules; user input is not a legal ruling. Paid short breaks stay in worked time where required. Store the original break fact rather than shortening the recorded shift.

Validation rejects reversed/empty intervals, duplicate identities, unintended work overlap, overlapping/out-of-range breaks, and impossible date/time input. Contiguous intervals may meet at a boundary. A calculation that lacks an applicable rule version returns an actionable error, not zero.

Split at every relevant boundary: rule/rate effective time, workday, statutory week, schedule, weekday/date premium, and break. Preserve the original event identity across generated segments. Do not reset cumulative daily hours merely because an event is split or a rate changes.

Payroll date is not always midnight-to-midnight. If only calendar-midnight days are supported, a non-midnight contractual workday is unsupported. Similarly, actual overnight work and a reusable overnight schedule template are different capabilities.

DST changes elapsed time. A wall-clock repeat should propose the intended local times, disclose ambiguity/nonexistent times, and derive duration from the selected instants. Never add 24 × 3600 to implement every “next local day.” A paycheck-period split must not erase the wider daily/weekly context needed to calculate an entitlement.

## 3. Exact money and explicit rounding

Use decimal or fixed-point values with currency metadata, never binary floating point for wages. Parsing consumes the entire string. Decimal separator/grouping behavior is explicit; ambiguous input is rejected instead of accepted partially. Reject invalid currency, NaN, and values outside the supported business range. Negative adjustment workflows need their own semantics rather than a silent absolute-value conversion.

Persist rates at their allowed precision, durations as facts, and the rounding policy/version. Multiplication, subtotal aggregation, and rounding points are part of the rule contract. Prefer no intermediate rounding unless a reviewed policy requires it. If payroll rounds per component but the app rounds per period, expose the method and material difference rather than hiding it behind a tolerance.

The current engine's documented policy must be compared with the intended agreement policy before claiming a match. Do not retrofit a new rounding interpretation onto saved historical results.

## 4. Ordinary configured wages and daily tiers

For a segment with constant rate and selected multiplier:

```text
segmentPay = rate × workedHours × multiplier
```

Daily tiers consume cumulative qualifying worked hours in the relevant workday. Thresholds are ordered, unique, and boundary-defined. With 1.5× after eight hours, a span crossing hour eight becomes two segments; the whole span does not suddenly receive one multiplier.

A rule profile explicitly defines how daily, schedule, weekday, and dated premiums interact. `highestApplicable` means use the maximum approved applicable multiplier for that segment. It does not mean all legal obligations are thereby satisfied. Other contracts can require additive, sequential, or separate entitlements; those are unsupported until represented and verified. Never multiply two independent 2× labels to produce 4× by accident.

Holidays are explicit scoped dates/observance rules from a source. Do not assume a national calendar supplies the complete paid-holiday list. Paid holiday leave and premium pay for work performed on a holiday are different inputs.

## 5. Callout guarantees

For the **limited synthetic variant** of one isolated callout with one constant rate/multiplier and a confirmed minimum payable duration:

```text
workedPay = actualHours × rate × multiplier
guaranteedEquivalentHours = max(0, minimumHours - actualHours)
guaranteeTopUp = guaranteedEquivalentHours × rate × multiplier
calloutTotal = workedPay + guaranteeTopUp
```

This is not a universal CBA algorithm. Define whether the minimum attaches per call, continuous response, reporting event, or other unit, and how overlapping calls, regular-shift overlap, breaks, rate changes, and canceled calls behave. If the variant is not supported, do not claim a fully audited callout entitlement.

Guaranteed equivalent hours are never inserted into the work log or automatically added to statutory hours worked. A guarantee's treatment in a statutory regular-rate or credit calculation is a separate sourced question. See [F06](sources.md#f06) and [rule catalog](rule-catalog.md).

## 6. Allowances, reimbursements, and benefits

An allowance rule has an explicit eligibility predicate and unit: work date, shift, trip, distance, receipt, or another stated unit. Deduplicate by that actual unit, not by arbitrary work-entry count. `amountPerWorkDate` is only the supported simple variant; a split shift cannot earn two identical daily allowances unless the rule says so.

Record wage components separately from allowances and employer benefits:

```text
configuredWages = sum(worked-wage components + supported wage guarantee top-ups)
configuredAllowances = sum(supported per-diem/reimbursement components)
configuredCashTotal = configuredWages + configuredAllowances
```

These names describe app component buckets, not a tax classification or final legal regular-rate determination. Exclude employer pension/health contributions from cash gross unless a reviewed cash-in-lieu rule applies. Deductions and bank deposit are not the expected wage-gross comparison target.

## 7. Federal weekly regular-rate computation: restricted reference algorithm

**NOT a claim of current implementation.** Before using this algorithm, establish ordinary covered nonexempt hourly employment, a complete single-employer workweek, no applicable alternative statutory method, cash overtime rather than a separate lawful public-agency comp-time path, and proper inclusion/exclusion/credit classification. State/CBA obligations still require separate analysis. See [F01](sources.md#f01), [F02](sources.md#f02), and [F06](sources.md#f06).

Let:

```text
H = statutory compensable hours worked in the complete workweek
R = includable remuneration for that week, with straight time paid for all H
O = max(0, H - 40)
RR = R / H                                  # only when H > 0
statutoryAdditionalPremium = 0.5 × RR × O
remainingPremium = max(0, statutoryAdditionalPremium - eligiblePremiumCredit)
```

The half-time expression assumes base/straight-time compensation for **all** worked hours is already in R. Otherwise it is not a complete wage calculation. Never add another full 1.5× for the same already-paid base hours. Do not subtract the entire contractual overtime line as a credit: only the properly eligible extra premium portion qualifies. Preserve exclusions and credit reasons per component.

For total expected cash in this restricted model, add base/includable remuneration, already owed excluded cash components, contractual premium payments, and any remaining statutory premium **once each**. A pension contribution is not an excluded cash payment to add to the worker's check. A zero-hour week needs separate non-work-pay handling, not division by zero.

For multiple rates, use the properly applicable weighted-rate or reviewed alternative rule. For an allocated bonus or retroactive increase, retain the affected workweeks, recompute the additional premium under the applicable rule, and record a new adjustment revision. Do not dump every retroactive amount into the check-date week.

## 8. Layering law and agreement

Do not compute compliance by taking the largest of three unlabeled totals. Track obligations and satisfaction separately: source, relevant time, calculation basis, earned component, and any allowable credit. Avoid double-counting base wages and avoid using unrelated reimbursements, guarantee payments, or high straight-time rates to silently erase an overtime obligation.

An engine without the applicable statutory layer must label its result a configured-rules estimate. Disabling daily overtime is not a way to opt out of weekly federal overtime. The support matrix must make this limitation visible to implementers and user-facing copy.

## 9. Reproducibility and change handling

Stable historical meaning requires more than storing the current profile. Preserve the original events, applied agreement versions/timeline, comparison mappings, calculation engine version, and prior result. Opening History must not recompute using new defaults. Corrections create a new identifiable revision; deletes follow explicit evidence ownership rules.

Every new rule gets boundary, negative, and interaction examples. Property checks include no duplicate counting, component sums equal named totals, work remains unchanged by entitlements, timezone stability, identical inputs yield identical monetary outputs, and rejected mutations preserve prior state. Examples in [worked-examples.md](worked-examples.md) are acceptance specifications until actual tests are linked.
