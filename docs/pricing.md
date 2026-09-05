# LinePay Pricing

> **Canonical pricing strategy.** If another document conflicts with this file, this file wins.

## Decision

For launch, keep pricing deliberately simple:

| Plan | Price | Purpose |
|---|---:|---|
| LinePay Free | $0 | Build trust and establish the work log |
| LinePay Pro Monthly | **$9.99/month** | Flexible paid option |
| LinePay Pro Annual | **$79.99/year** | Recommended / best-value option |

**No weekly plan. No lifetime plan. No multiple paid tiers. No credit system. No introductory pricing maze.**

The activation mechanic is not a calendar trial:

> **The first complete paycheck audit is free.**

After that, recurring paycheck audits require LinePay Pro.

This pricing is a commercial hypothesis. StoreKit/product code must not hard-code prices or assume they never change.

---

## 1. Pareto objective

Pricing should optimize the small number of variables that matter most:

1. a worker reaches the real value moment before paying;
2. the price is trivial compared with a plausible payroll mistake;
3. the product is positioned as a specialized audit tool, not a cheap calculator;
4. annual billing creates healthy retention and economics;
5. the choice is understandable in seconds.

Do **not** optimize early for coupon systems, segmentation, sophisticated trials, regional experimentation, lifetime value models, or many packages.

The launch question is simply:

> After LinePay has audited one real paycheck, will the worker pay about $10/month to have every future paycheck checked?

---

## 2. Why $9.99/month

`$9.99/month` is the launch anchor.

Reasons:

- It is a familiar subscription price rather than an unusual number that requires explanation.
- It leaves LinePay clearly above commodity overtime calculators.
- It is low relative to the value of detecting even one meaningful missed premium, callout minimum, per diem payment, or overtime discrepancy.
- It leaves room for LinePay to become substantially more valuable as verified agreement rules improve.
- It avoids the painful future move from an underpriced `$3–5` utility to a professional tool.

RevenueCat's 2026 subscription benchmark reports `$10` as the most common monthly subscription price and `$8` as the overall monthly median. North American subscription apps cluster around `$9.99/month`.

This benchmark is context, not the reason for the price. LinePay must ultimately earn `$9.99` through recovered value and trust.

---

## 3. Why $79.99/year

Twelve monthly payments cost:

`$9.99 × 12 = $119.88`

Annual Pro at `$79.99` saves `$39.89`, approximately **33%**.

Effective monthly cost:

`$79.99 / 12 ≈ $6.67/month`

This is the intended trade:

- Monthly preserves a low-commitment option.
- Annual rewards conviction without halving the product's value.
- A roughly one-third discount is large enough to matter while preserving strong annual revenue.

The annual plan should be visually labeled **Best value** and shown first, but the monthly option must remain obvious and equally easy to purchase.

Do not add a third duration merely to make annual look cheaper.

---

## 4. The free product

Free must be useful enough that a worker can trust LinePay before paying.

### Free includes

- no signup or LinePay account;
- one pay profile;
- manual confirmed pay rules;
- work logging;
- expected gross calculation;
- explainable Pay Ledger;
- edit/delete work records;
- **one complete paycheck audit**.

The free tier is not a crippled demo. It proves the calculation engine and establishes the habit of recording work.

What it must **not** provide is unlimited recurring reconciliation.

---

## 5. The paid boundary

### Pro includes

- unlimited paycheck audits;
- on-device paystub OCR;
- expected-versus-paid reconciliation;
- possible discrepancy detection;
- pay-period history;
- discrepancy history;
- export/shareable audit reports;
- advanced or verified agreement packs when available;
- future premium features that materially improve audit accuracy or convenience.

The clean mental model is:

> **Free helps me know what my work should pay.**
>
> **Pro checks every paycheck against it.**

Do not scatter random conveniences behind the paywall simply to manufacture a feature list.

---

## 6. Why the first audit is free instead of a 7-day trial

LinePay's natural cadence is payday, not app-install day.

A seven-day trial can expire before the worker receives the paycheck needed to experience LinePay's core value.

The preferred funnel is therefore event-based:

```text
Install
  ↓
No signup
  ↓
Set pay rules
  ↓
Log actual work
  ↓
See expected pay
  ↓
Paycheck arrives
  ↓
Scan / enter paystub
  ↓
FIRST COMPLETE AUDIT FREE
  ↓
See match or possible discrepancy
  ↓
Offer LinePay Pro for future audits
```

Do not create authentication or a central backend merely to prevent people from reinstalling the app to obtain another free audit. Some leakage is cheaper than architectural complexity at this stage.

---

## 7. The paywall

The entire paywall should answer four questions:

1. What does Pro do?
2. What does it cost?
3. Which option is best value?
4. Does LinePay upload my pay data?

Suggested hierarchy:

```text
Audit every paycheck

Compare your recorded work and confirmed rules
with what your paycheck actually paid.

BEST VALUE
$79.99 / year
Save $39.89 vs monthly

$9.99 / month

[ Continue with Yearly ]

Your pay data stays on this device.
Restore Purchases · Manage Subscription
```

If the user selects monthly, the CTA changes clearly to `Continue with Monthly`.

Do not use fake urgency, countdowns, hidden close buttons, misleading weekly equivalents, giant discount typography, or fear copy such as `Your employer may be stealing from you`.

The product should sell through evidence, not anxiety.

---

## 8. The economic story

LinePay's strongest pricing argument is not a feature comparison.

It is:

> **One caught pay mistake can pay for LinePay many times over.**

For example, if an audit flags a plausible `$184` missing callout payment, that amount exceeds eighteen monthly LinePay payments.

The product should never promise that it will find a discrepancy or claim that an estimated discrepancy is legally owed. But when a real audit identifies a credible difference, the value proposition becomes self-evident.

This is why the first complete audit should happen before the subscription decision.

---

## 9. What not to build

At launch, explicitly avoid:

- `$0.99/week`, `$4.99/week`, or any weekly plan;
- Basic / Plus / Pro / Max tier ladders;
- lifetime purchase;
- token/credit packs;
- pay-per-scan;
- separate OCR add-ons;
- separate agreement-pack subscriptions;
- family/team plans;
- employer plans inside the consumer app;
- artificial trial countdowns;
- complex promotional pricing;
- a backend just for pricing eligibility;
- a LinePay account just to police the free audit.

Every additional price or entitlement creates another branch in product, StoreKit, support, QA, copy, analytics, and customer understanding.

The 80/20 answer is **one entitlement: Pro**.

---

## 10. Annual vs monthly presentation

Use one StoreKit subscription group:

`LinePay Pro`

with two durations at the same entitlement level:

- `linepay.pro.monthly`
- `linepay.pro.yearly`

Product identifiers are implementation suggestions and may be adjusted before App Store Connect creation.

Annual should be the recommended option because it better matches recurring paycheck auditing and reduces subscription-management churn.

Monthly remains strategically important because it:

- reduces commitment anxiety;
- gives skeptical workers a low-risk paid path;
- provides a useful willingness-to-pay signal;
- allows churned users to return without another large commitment.

Do not remove monthly merely to maximize upfront cash.

---

## 11. Price localization

The initial commercial market is U.S. workers, so optimize the launch decision for the U.S. storefront.

For other storefronts initially, prefer App Store Connect's automatic comparable pricing rather than manually maintaining dozens of regional price tables.

Only introduce deliberate regional pricing when a market has enough real installs and purchase intent to justify the operational complexity.

Do not let international pricing work delay U.S. validation.

---

## 12. Pricing experiments, in order

Do not A/B test five variables simultaneously.

The experiment order is:

### Experiment 0: prove value

Before changing price, determine whether workers who complete a real audit actually want recurring audits.

If they do not, pricing is probably not the primary problem.

### Experiment 1: annual price

Default launch:

`$79.99/year`

Only after meaningful paid usage exists, test one alternative, likely:

- `$69.99/year` if annual take-rate is weak but monthly conversion is healthy; or
- `$89.99/year` if annual conversion and retention are unusually strong and users repeatedly recover meaningful value.

Do not change monthly at the same time.

### Experiment 2: monthly price

Only after the product has strong audit evidence, test `$11.99` or `$12.99/month` against `$9.99` if value is clearly exceeding the launch hypothesis.

Do not test `$4.99` merely because conversion is disappointing.

### Experiment 3: offers

Only when enough churn exists to matter, consider App Store promotional or win-back offers.

Do not build an offer engine before there is a retention problem to solve.

---

## 13. Decision rules

These are internal heuristics, not industry benchmarks.

### Do not lower price first when

- users fail to finish rule setup;
- users do not log enough work to calculate a paycheck;
- OCR is unreliable;
- agreement coverage is weak;
- users do not understand the audit result;
- users distrust the calculation;
- few users reach the first completed audit.

Those are product problems.

### Consider a lower annual price when

- workers readily buy monthly after the first audit;
- annual selection is disproportionately weak;
- interviews show commitment length, rather than total willingness to pay, is the objection.

### Consider raising price when

- audits repeatedly identify meaningful real discrepancies;
- users report LinePay has recovered or protected substantially more money than the subscription costs;
- verified agreement coverage becomes a meaningful moat;
- paid retention remains strong;
- users describe LinePay as indispensable rather than merely convenient.

---

## 14. Metrics that actually matter

Keep the pricing dashboard small.

The critical metrics are:

1. **First audit completion**
2. **First audit → Pro conversion**
3. **Annual share of new Pro subscriptions**
4. **Paid retention / renewal**
5. **Refund rate**
6. **Percentage of audits that surface a review-worthy difference**
7. **Median credible discrepancy value when one is found**

Secondary metrics can wait.

At the beginning, App Store Connect aggregate subscription data plus direct user interviews are sufficient. Do not add a third-party analytics SDK solely to optimize a paywall.

---

## 15. Revenue intuition

Ignoring taxes and App Store commission, the headline economics are deliberately easy to reason about:

| Paid users | Monthly-only equivalent at $9.99 | Annualized gross equivalent |
|---:|---:|---:|
| 100 | ~$999/month | ~$12k/year |
| 1,000 | ~$9,990/month | ~$120k/year |
| 5,000 | ~$49,950/month | ~$599k/year |
| 10,000 | ~$99,900/month | ~$1.2M/year |

Actual revenue depends on monthly/annual mix, churn, refunds, taxes, storefront pricing, and Apple's commission.

Do not optimize the product around the 10,000-user row before proving the 100-user row.

---

## 16. Final launch rule

Unless real customer evidence changes the decision:

> **LinePay Free**
> Useful work tracking + expected-pay calculation + first complete paycheck audit free.
>
> **LinePay Pro Monthly: $9.99/month**
>
> **LinePay Pro Annual: $79.99/year, recommended**

And the governing Pareto principle is:

> **One paid tier. Two billing options. One free value moment. Optimize the audit, not the paywall.**

---

## Research notes

Pricing context checked September 2026:

- RevenueCat, *State of Subscription Apps 2026*: `$10` is the most common monthly subscription price; North America clusters at `$9.99/month`; annual pricing varies much more widely than monthly pricing.
- Apple recommends keeping subscription offerings easy to understand and notes that most apps should use a single subscription group when users expect one active subscription.
- App Store Connect supports monthly and annual durations, storefront-specific pricing, introductory/promotional offers, and price preservation for existing subscribers when raising price.

These external benchmarks inform the starting hypothesis. LinePay-specific conversion, retention, and recovered-value evidence should override generic app-market benchmarks once available.
