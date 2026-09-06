# Product handbook

[Documentation home](../README.md) · [Agent contract](../../AGENTS.md) · [iOS release scope](../plan/ios-1.0.md)

**Purpose:** give every contributor one connected specification for how LinePaycheck works, what its pay calculations mean, and what they do not establish.

LinePaycheck is a private work record and agreement-aware paycheck comparison tool for lineworkers. It is not an employer payroll system, a tax return, a labor-law decision service, or an automatically certified interpretation of a collective bargaining agreement (CBA).

## Read by task

| Task | Start here | Then read |
|---|---|---|
| Understand the product | [How the app works](app-workflows.md) | [Business rules](business-rules.md) |
| Map requirements to code, tests, and issues | [Implementation map](implementation-map.md) | [Issue tracker #49](https://github.com/streamentry/linepay/issues/49), current source/PR status |
| Change an expected-pay amount | [Payroll handbook](payroll/README.md) | [Calculation specification](payroll/calculation-spec.md), [coverage and gaps](payroll/coverage-and-gaps.md) |
| Add a rule or agreement | [Rule catalog](payroll/rule-catalog.md) | [Sources and approval](payroll/sources.md), [worked examples](payroll/worked-examples.md) |
| Change audit results or paystub entry | [Reconciliation](payroll/reconciliation.md) | [Business rules](business-rules.md), [app workflows](app-workflows.md) |
| Change trial, paywall, or access | [Pricing](pricing.md) | [Onboarding](onboarding.md) |
| Change history, backup, or deletion | [Business rules](business-rules.md) | [Local-first architecture](../architecture/local-first-no-account.md), [backup/restore](../architecture/icloud-drive-backup-restore.md) |
| Determine whether a feature works today | [Implementation map](implementation-map.md) | [Remediation status](../plan/ios-1.0-remediation.md), source and tests at the candidate commit |

## Authority and evidence

These documents deliberately distinguish **requirements** from **proof of implementation**.

- **LAW:** a bounded summary of a named primary legal source, with jurisdiction and applicability conditions. A source publication date is not a guarantee that no later amendment exists.
- **AGREEMENT:** a provision of one identified agreement, wage letter, or employer policy. It does not apply to every lineman, every union member, or every storm assignment.
- **PRODUCT:** the behavior LinePaycheck is required to provide. It does not create a wage entitlement.
- **IMPLEMENTATION:** behavior found in identified code at a pinned revision. This alone does not establish a passing build, correct legal coverage, or successful user testing.
- **EXAMPLE:** synthetic inputs and expected arithmetic or UI outcomes. Examples are not market wage quotes or proof that tests passed.
- **UNKNOWN / UNSUPPORTED:** a missing fact, interpretation, source, or engine capability. Preserve the distinction between an unknown value and zero.

The product documents own business semantics; `DESIGN.md` owns presentation; architecture decisions own technical boundaries; the release plan owns delivery scope; pricing owns commercial choices. Sources establish external rules within their scope. Code establishes what is implemented, not what the law requires. A conflict is a defect to resolve explicitly, not permission to select whichever document is convenient.

**The most important limit:** a configured-rules calculation can be internally exact while omitting a legally required payment. Read [coverage and gaps](payroll/coverage-and-gaps.md) before using language such as “all pay,” “compliant,” or “correct paycheck.”
