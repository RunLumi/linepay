# Paycheck reconciliation and evidence

[Payroll home](README.md) · [Business rules](../business-rules.md) · [Examples](worked-examples.md)

**PRODUCT contract.** The current model has explicit gross, line, hour, and guarantee mappings in [PaycheckAssessment.swift](../../../apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PaycheckAssessment.swift). Their presence does not certify statutory completeness. The missing legal-calculation layers are recorded in [coverage and gaps](coverage-and-gaps.md).

## 1. Define what is comparable

An assessment identifies employer/period, currency, complete or partial work coverage, configured rules and omissions, paycheck source/current-period fields, confirmation state, and explicit mappings. Never compare expected gross with a bank deposit, YTD total, net pay, or unrelated reimbursement aggregate.

| Mapping | Supported conceptual choices | Why it matters |
|---|---|---|
| Gross basis | Unconfirmed; wages only; wages including configured per diem | A separately reimbursed allowance is not missing wage gross |
| Hourly line layout | Unconfirmed; full-rate buckets; base plus premium | $150 total overtime wages and $50 extra premium can describe the same two hours at $50 base |
| Hours basis | Unconfirmed; actual work; paid equivalents | A guarantee can change paid equivalents without changing actual work |
| Guarantee layout | Unconfirmed; separate top-up line; included in hourly lines | Do not count the same guarantee twice or invent a separate missing line |
| Work completeness | Confirmed complete; not complete/unconfirmed | A fragment of a work period cannot audit the entire check |
| Coverage | Supported configured rules and explicit exclusions | No verified statutory layer means no full legal conclusion |

Descriptions printed by payroll are evidence to inspect, not automatic classification. A field outside supported mappings stays unclassified; ask for review or narrow the comparison.

## 2. Construct expected facts

For full-rate buckets, group only relevant components by their applicable multiplier. For base-plus-premium layout, base compensation is included once across the covered worked hours; premium fields contain only incremental pay above that base. Use each component's historical rate, not the latest profile rate.

Derive expected wages without allowance components for wage-only gross. Add allowance components only when the user confirms that the compared total actually includes them. A separate allowance line can be compared independently; display that its result is outside wage gross.

For guarantees, identify whether the printed hours include non-work equivalents and whether the pay appears separately. Do not assume a particular payroll provider's layout. Unexpected multipliers, mixed adjustments, missing mapping, or negative correction lines require an explicit supported representation or a review state.

## 3. Direction, scope, and completeness

For a compatible comparison:

```text
difference = expectedComparableAmount - confirmedPaidAmount
positive = possible shortfall
negative = possible overpayment
zero = equality of this comparison only
```

Money and hour comparisons use their own units, precision, and explained rounding. An amount difference is not an hour difference. No unexplained tolerance is allowed to erase a material discrepancy.

**Scope** is what was compared, such as gross only or selected confirmed lines. **Completeness** is whether enough evidence exists for the requested conclusion. A gross-only match is valid limited evidence, not a complete line-level audit. Missing lines are not confirmed zero lines; unexplained gross-to-components inconsistencies need review.

| Condition | Required presentation |
|---|---|
| Period, currency, total basis, or complete-work precondition prevents meaningful comparison | Not comparable, with the missing precondition and repair action |
| Unsupported material rule, uncertain field, contradictory mapping, stale result, or conflicting component evidence | Needs review, preserving any individually valid limited comparisons |
| Comparable gross agrees but regular/OT components differ | Gross total matches; component differences need review. Never an unconditional clean match |
| Verified comparable amount is less than expected under the declared rules | Possible shortfall, amount and implicated evidence |
| Verified comparable amount is greater than expected | Possible overpayment, with missing/adjustment context to review |
| All actually compared supported evidence agrees without unresolved material conflict | Matches within stated scope; explicitly list unchecked categories |

“Confirmed lines” does not mean all lines, all agreement clauses, or all legally required pay. A state marked matches cannot conceal a known unmodeled federal weekly rule. Work completeness and rule completeness are distinct.

## 4. Evidence is part of the result

A comparison record preserves the exact confirmed value, its field identity and original source reference, confirmation/edit history, the implicated expected components, and rule/engine version. OCR observations retain page, region, recognized text and confidence where available. Confidence is a reading signal, not proof the payroll value is correct.

The user can open the relevant original and correct the structured fact. Correcting a value does not alter the original document. If the source is deliberately deleted or becomes unreadable, retain allowed structured facts and identify the missing original; do not claim that the source remains viewable.

The focused explanation is:

```text
Recorded work → relevant effective rule → exact arithmetic
                               ↕
         confirmed paycheck field → original source region
```

Reports include the same scope and unresolved questions. A screenshot/PDF that omits the qualification and leaves only a large “missing pay” amount is misleading.

## 5. Revisions and access

An audit binds to a period and an immutable set of facts/rules. Editing work or an effective rule invalidates the current assessment until explicitly recalculated. Historical re-audits append a revision rather than replacing the record of what was previously seen.

Access checks occur before a new restricted audit, not by deleting data afterward. Failed validation does not spend Free sampling. Rechecking an already authorized period, and retaining results after subscription expiry, follow [business rules](../business-rules.md) and [onboarding](../onboarding.md).

## 6. Adversarial acceptance cases

Test equal-gross offsetting errors; current versus YTD amounts; wage gross plus separately paid subsistence; full-rate versus premium-only OT; actual versus guaranteed hours; unknown guarantee placement; a source reused during manual correction; changed work after an audit; a late paycheck for a closed period; and an unsupported rule with otherwise matching totals. Do not test only the happy path where every number has the same layout.
