# Payroll handbook

[Product home](../README.md) · [Business rules](../business-rules.md) · [Sources](sources.md)

**There is no single US lineman pay formula.** The operative rules depend on the employer, work, jurisdiction, worker classification, agreement, project, and effective dates. Federal and state requirements cannot be replaced with a generic union multiplier or a worker turning an optional switch off. See [legal baseline](us-legal-baseline.md).

## The model in one view

```text
Actual work and other confirmed events
             +
Applicable, effective-dated rules and source context
             |
             v
Exact components, with explanations and coverage limits
             |
             +---- wages
             +---- allowances / reimbursements
             +---- other separately modeled entitlements
             |
             v
Confirmed paycheck facts and explicit line/total mappings
             |
             v
Scoped comparison, possible differences, unresolved questions
```

No stage is allowed to turn an ambiguous clause, an OCR guess, or a missing payroll line into a confirmed fact.

## Documents

| Document | Owns |
|---|---|
| [US legal baseline](us-legal-baseline.md) | Federal floor, state/contract applicability, regular-rate and project complications |
| [Calculation specification](calculation-spec.md) | Time, money, segmentation, guarantees, totals, and versioned calculations |
| [Rule catalog](rule-catalog.md) | Required facts and boundaries for each lineworker compensation concept |
| [Reconciliation](reconciliation.md) | Paystub mappings, completeness, verdicts, and evidence |
| [Worked examples](worked-examples.md) | Synthetic acceptance cases with independently checkable answers |
| [Coverage and gaps](coverage-and-gaps.md) | Observed implementation limits and gates against overclaiming |
| [Sources and approval](sources.md) | Primary references, scope, review date, agreement admission requirements |

## Vocabulary that must not drift

| Term | Meaning |
|---|---|
| Base rate | The configured contractual straight-time hourly wage. Not necessarily the statutory regular rate. |
| Regular rate | A legal overtime calculation basis. Included compensation and exclusions need a separate applicable-law analysis. |
| Actual hours worked | Compensable work time under the applicable rule, not all “paid hours” printed on a check. |
| Clock span | Elapsed time between recorded start and end instants, before classified breaks. |
| Contract workday | The day boundary used by the agreement or applicable daily-overtime rule. Not automatically midnight. |
| Statutory workweek | The separately identified recurring week used for the applicable weekly-overtime test. Not the pay period. |
| Pay period | The earnings window being recorded or compared. Payday is when payment is made; these dates can differ. |
| Full-rate overtime line | Wages including both base and premium for that line's hours, such as 1.5 × base. |
| Premium-only line | Additional premium above base already paid elsewhere, such as 0.5 × base. |
| Guarantee / top-up | Additional compensation created by a minimum-payment rule; not invented clock time. |
| Per diem / subsistence | A named allowance with explicit eligibility and payment basis. The label alone determines neither tax nor overtime treatment. |
| Gross comparison | Comparison of explicitly mapped totals, not a comparison with bank deposit or take-home pay. |
| Snapshot / revision | Immutable recorded inputs, rules, calculation version and result. Later corrections create an identifiable new revision. |
| Supported | A precise rule variant is representable and verified for its declared scope, not an entire agreement or occupation. |

For statutory definitions, follow [the named sources](sources.md); this vocabulary is the product's modeling guide, not a replacement for their terms.
