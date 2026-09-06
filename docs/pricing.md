# LinePaycheck Pricing

> **Canonical pricing strategy.** If another document conflicts with this file, this file wins.

## Decision

For launch, keep pricing deliberately simple:

| Plan | Price | Purpose |
|---|---:|---|
| LinePay Free | $0 | Build trust and establish the work log |
| LinePay Pro Monthly | **$9.99/month** | Flexible paid option |
| LinePay Pro Annual | **$79.99/year** | Recommended / best-value option |

**No weekly plan. No lifetime plan. No multiple paid tiers. No credit system. No introductory pricing maze.**

**September 5, 2026 decision:** eligible new subscribers in configured storefronts (initially U.S.) can start a **seven-day free trial on Annual**, then renew at the localized yearly price. Monthly is an immediate paid alternative with no introductory trial. This deliberately supersedes the earlier no-calendar-trial policy and aligns with `docs/marketing.md`.

Free sampling remains available separately:

> **The first complete paycheck audit is free.**

After that, recurring paycheck audits require an active verified LinePaycheck Pro trial or paid subscription. An App Store trial does not consume an unused Free audit; see [onboarding.md](onboarding.md) for the state contract.

This pricing is a commercial hypothesis. StoreKit/product code must not hard-code prices or assume they never change.

---

## 1. Pareto objective

Pricing should optimize the small number of variables that matter most:

1. a worker sees a credible expected-pay result before the optional trial offer;
2. the price is trivial compared with a plausible payroll mistake;
3. the product is positioned as a specialized audit tool, not a cheap calculator;
4. annual billing improves first-receipt economics while actual usage, refunds, and renewal prove retention;
5. the choice is understandable in seconds.

Keep the offer simple: one annual introductory trial, one monthly alternative, one Pro entitlement. Measure activation and paid outcomes before adding coupons, segmentation, or more packages.

The launch question is simply:

> Will a worker who understands their expected pay start an annual trial, experience recurring audit value, and choose to remain subscribed?

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

The annual plan should be selected initially, labeled **Recommended**, and shown first. Monthly remains obvious and equally easy to select. Show the full annual charge prominently; a monthly equivalent and savings are secondary. Never imply that $6.67 is charged monthly.

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
- on-device paystub OCR for recurring future audits (also sampled in the first free audit);
- expected-versus-paid reconciliation;
- possible discrepancy detection;
- ongoing audit creation for later pay periods;
- future premium features only when actually shipped and accurately described.

Existing work, pay-period history, confirmed audits and exports remain accessible without Pro.
Named verified agreement packs are not a launch entitlement; do not advertise them until their rights,
coverage and implementation have been reviewed and shipped.

The clean mental model is:

> **Free helps me know what my work should pay.**
>
> **Pro checks every paycheck against it.**

Do not scatter random conveniences behind the paywall simply to manufacture a feature list.

---

## 6. Seven-day annual trial and first-audit sampling

LinePay's natural cadence is payday, not app-install day.

A seven-day trial can expire before the worker receives the paycheck needed to experience LinePay's core value.

The trial funnel now begins with an immediate expected-pay proof:

```text
Install
  ↓
No signup
  ↓
Set pay rules
  ↓
Log actual work
  ↓
See and understand expected pay
  ↓
Optional Annual offer: 7 days free, then $79.99/year
  ├── Start verified annual trial → activate recurring Pro value
  ├── Buy monthly at $9.99 → Pro
  └── Continue free → first complete paycheck audit remains free
```

Seven days is a launch hypothesis, not a universal optimum. It can end before payday, so let users check an existing paycheck when matching work facts exist, and preserve a useful Free path. Do not pretend a partial work record explains a complete paycheck.

The offer belongs to existing product `linepay.pro.yearly`, in the existing `LinePaycheck Pro` subscription group. Do not create a trial product or a new group. Eligibility and actual offer metadata come from StoreKit, not a device-local timer. A used introduction cannot be repeated by changing durations in the same group.

No LinePaycheck account/backend is added to police the Free audit. The detailed eligibility, Free-audit interaction, reminder, and failure contract lives in [onboarding.md](onboarding.md).

---

## 7. The paywall

The entire paywall should answer five questions:

1. What does Pro do?
2. What does it cost?
3. Which option is best value?
4. When does the trial become a paid subscription, and how do I cancel?
5. Does LinePaycheck upload my pay data?

Suggested hierarchy:

```text
Audit every paycheck

Compare your recorded work and confirmed rules
with what your paycheck actually paid.

ANNUAL — RECOMMENDED
7 days free, then $79.99 / year
Billed yearly
Save $39.89 vs monthly

$9.99 / month — billed today, no free trial

[ Start my 7-day free trial ]
Then $79.99/year, automatically renewing.
Cancel at least 24 hours before trial end to avoid renewal.
Continue free

Private by default. Calculations and paystub processing happen on your device. You choose whether to export or back up your records.
Restore Purchases · Manage Subscription · Terms · Privacy
```

For monthly, use `Subscribe monthly`. For ineligible annual customers or absent offers, use `Subscribe yearly` with the immediate price. Never display a free-trial CTA solely because annual is selected.

Do not use fake urgency, countdowns, hidden close buttons, misleading weekly equivalents, giant discount typography, or fear copy such as `Your employer may be stealing from you`.

The product should sell through evidence, not anxiety.

---

## 8. The economic story

LinePay's strongest pricing argument is not a feature comparison.

It is:

> **One caught pay mistake can pay for LinePay many times over.**

For example, if an audit flags a plausible `$184` missing callout payment, that amount exceeds eighteen monthly LinePay payments.

The product should never promise that it will find a discrepancy or claim that an estimated discrepancy is legally owed. But when a real audit identifies a credible difference, the value proposition becomes self-evident.

A real completed audit is strong contextual evidence for a later offer. The first optional offer now follows a real expected-pay result; the seven-day trial should then help the worker reach and repeat the audit outcome.

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

`LinePaycheck Pro`

with two durations at the same entitlement level:

- `linepay.pro.monthly`
- `linepay.pro.yearly`

These products already exist in App Store Connect. Treat their identifiers as immutable.

Annual is recommended because its recurring-use proposition and first-receipt economics fit this launch hypothesis. Measure usage and actual renewal; annual billing does not itself establish lower churn.

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

First complete the activation and offer-presentation experiments in [onboarding.md](onboarding.md). The price-only experiments below come afterward; they do not override the funnel experiment order.

Within price experiments, the order is:

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

Use the exact denominators and maturity windows in [onboarding.md](onboarding.md). The critical metrics are:

1. **First real expected-pay result and first audit completion**
2. **Download → annual trial → first paid conversion**
3. **Annual share of new first-paid subscribers**
4. **Paid retention / renewal**
5. **Refund rate**
6. **D30 net proceeds per first-time download**
7. **First-audit → Pro conversion**, where a linked cohort is actually measurable

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
> **LinePaycheck Pro Annual: seven days free for eligible customers, then $79.99/year, recommended**

And the governing Pareto principle is:

> **One paid tier. Two billing options. A seven-day annual trial. Prove value early, then earn paid renewal.**

---

## Research notes

Pricing context checked September 2026:

- RevenueCat, *State of Subscription Apps 2026*: `$10` is the most common monthly subscription price; North America clusters at `$9.99/month`; annual pricing varies much more widely than monthly pricing.
- Apple recommends keeping subscription offerings easy to understand and notes that most apps should use a single subscription group when users expect one active subscription.
- App Store Connect supports monthly and annual durations, storefront-specific pricing, introductory/promotional offers, and price preservation for existing subscribers when raising price.

These external benchmarks inform the starting hypothesis. LinePay-specific conversion, retention, and recovered-value evidence should override generic app-market benchmarks once available.
