# Implementation coverage and correctness gates

[Payroll home](README.md) · [Sources](sources.md) · [Release plan](../../plan/ios-1.0.md) · [Remediation](../../plan/ios-1.0-remediation.md)

**Source inspection baseline: `105b024e283c70e07375f53cc4da11010441e5a2`, September 6, 2026.** This matrix is deliberately not a green test report. This documentation task did not execute native tests or certify legal compliance. Before changing a status, identify the rule variant, actual implementation, relevant tests, reviewed source scope, and tested candidate SHA.

## Observed scope

| Capability | Source-level assessment at baseline | What is not established |
|---|---|---|
| Exact instants, breaks, timezone context | `WorkInterval` / `WorkBreak` model these facts and validate basic relationships | Legal compensability of every entered break or travel interval |
| Configured base wages and daily tiers | `AgreementSnapshot`, `DailyOvertimeTier`, component rules exist | Federal weekly overtime or every state's daily rules |
| Weekday, specific-date, and off-schedule premiums | Model fields exist | Correct holiday/observance lists, complete CBA coverage, or universal stacking rules |
| Actual overnight work | Start/end instants can span dates | A reusable overnight regular-schedule window; `RegularScheduleWindow` rejects end <= start |
| Effective-dated rules and sources | Agreement versions, rule keys, and effective-date machinery exist | Every cross-version guarantee/weekly regular-rate interaction |
| Isolated callout minimum | `CalloutMinimumRule` and guarantee components exist | Complete regular-shift overlap, repeated-call, interrupted-rest, or mixed-rate treatment |
| Flat allowance per work date | `FlatPerDiemRule.amountPerWorkDate` exists | Every subsistence eligibility exception, tax treatment, or statutory regular-rate classification |
| Gross/line/hours comparison | `PaycheckAssessor` has explicit bases, scoped comparisons, and review/not-comparable states | A legal completeness check for unmodeled obligations |
| Restricted weekly regular-rate layer | Complete-week input model, weighted rates, includable remuneration, eligible extra-premium credits, deterministic pay-period allocation, and native review flow exist | Applicability remains restricted; no state/local, public-agency, CBA, or universal federal certification |
| Input validation and evidence review | Strict-decimal, OCR and confirmation code are present in the repository | Correct extraction of every employer's layout; OCR suggestions still need confirmation |
| History, local persistence, backup/restore, Pro | Dedicated application adapters and tests exist | Device/sandbox release sign-off on a particular candidate |

Primary inspected types are linked in [I01](sources.md#i01). Additional file names guide follow-up inspection; a file existing is not sufficient acceptance evidence.

## Material gaps and nonclaims

| Gap | Required action before claiming coverage | Safe scope in the meantime |
|---|---|---|
| GAP-01 Ordinary federal weekly overtime and complete workweek context | Restricted `WeeklyRegularRateCalculator` represents complete-week context, qualifying hours, weighted rates, explicit applicability, and pay-period allocation; EX-10–EX-14 regressions pass | Source/applicability admission, broader jurisdiction/CBA review, and any release claim remain explicitly gated by #42 |
| GAP-02 Regular-rate bonuses, differentials, multiple-rate alternatives, retroactive adjustments | Includable bonuses, multiple straight-time rates, explicit extra-premium credits, and deterministic allocation are represented in the restricted layer | Retroactive multi-week adjustments, alternative statutory methods, and universal legal coverage remain unsupported |
| GAP-03 State/local and public-agency applicability | Jurisdiction/employment matrix, actual rules and exceptions, applicable wage order, documented review | No nationwide “US compliant,” no automatic California/municipal preset |
| GAP-04 Full CBA interactions | Validate assent/amendments and every claimed clause variant, especially callout overlap, rest and meals | Isolated configured clauses, not a fully verified agreement pack |
| GAP-05 Prevailing-wage/fringe projects | Incorporated wage determination and classification/fringe/apprentice engine | Project compliance outside checked scope |
| GAP-06 Travel, standby, show-up, non-work paid time and compensability | Explicit facts and applicable rule representation | Preserve facts and disclose unsupported classification/payment |
| GAP-07 Taxes, net deductions, legal penalties, recovery claims | Separate reviewed product scope and legal/tax sources | Gross evidence comparison only; no legal debt or net-tax certification |

**GAP-01 remains a launch-positioning and product-safety boundary.** The restricted layer can calculate an explicitly confirmed complete workweek, but it is not a nationwide legal engine. A worker confirming the weekly profile does not prove every state, CBA, public-agency, or alternative-method obligation applies or is represented. #42 remains open until the admitted scope receives the required source/applicability review.

No new payroll feature is silently implemented by this documentation change. It specifies the correctness boundary for agents and product claims. A reviewed narrow profile may establish that configured payments satisfy particular obligations, but that requires explicit evidence, not the assumption that generous union premiums always exceed the statutory floor.

## Meaning of “supported”

Use separate evidence fields: `representable`, `implemented`, `regression-tested`, `app-verified`, `source/applicability-reviewed`, and `released`. Do not collapse them into one checkmark. A reviewed legal rule with no implementation is unsupported in the app; a tested implementation with no source scope is not a verified agreement.

The 1.0 plan and historical audit remain useful but may refer to earlier revisions. Use [current remediation](../../plan/ios-1.0-remediation.md) and fresh verification for release state. Preserve historical evidence rather than changing old failures into retroactive passes.

## Promotion and stop conditions

Before publishing a broad correctness claim, resolve every material omitted rule for the intended segment, prove complete inputs and correct mapping, and obtain the required source/domain review. Before calling a code change complete, execute appropriate tests and inspect the affected user flow.

Stop an unconditional full-paycheck verdict when a material rule is unsupported, work or source data is incomplete, the comparison basis is unconfirmed, or the calculator failed. A scoped calculation can still be shown with an explicit limitation. Prefer truthful useful partial coverage over false universal certainty.
