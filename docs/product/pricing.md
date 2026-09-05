# LinePay Pricing

## Status

This is a **commercial hypothesis for validation**, not an architectural constant.

Pricing should change when real conversion, retention, and willingness-to-pay data justify it. Product and persistence architecture must not hard-code these values.

## Recommended launch pricing

### LinePay Free

**$0**

Purpose: let a worker establish trust in the calculation engine before paying.

Include:

- no account required;
- one pay profile;
- manual pay-rule setup;
- current pay-period work logging;
- expected gross-pay calculation;
- Pay Ledger with explainable calculation lines;
- edit/delete work entries;
- one complete paycheck audit as the activation experience.

The free tier must demonstrate LinePay's core promise, but should not become a complete substitute for recurring reconciliation.

### LinePay Pro

**$9.99/month**

or

**$79.99/year**

Annual equivalent: approximately $6.67/month.

Pro should unlock recurring high-value behavior:

- unlimited paycheck audits;
- paystub scan/OCR and reconciliation;
- full pay-period history;
- discrepancy tracking;
- exports/reports;
- advanced/verified agreement rule packs when available;
- future premium local-first features that materially improve audit quality or convenience.

## Why $9.99/month

LinePay should be priced against the economic consequence it prevents, not against generic calculator apps.

A single correctly identified $100 pay discrepancy pays for roughly ten months of a $9.99 subscription. For a worker with variable overtime, callouts, per diem, storm work, premiums, or agreement-specific rules, the relevant comparison is not "how much does a calculator cost?" but "how much confidence is a recurring independent paycheck audit worth?"

Current adjacent market anchors reinforce this range:

- LineVault, purpose-built for linemen/electricians, lists LineVault Pro at $9.99/month in the U.S. App Store.
- Paycheck & OT Estimator, a broader/generic overtime and tax-estimation app, lists $2.99/month and $19.99/year.

LinePay should not compete with the generic estimator on price. Its intended differentiation is agreement-aware, evidence-backed paycheck reconciliation.

## Why $79.99/year

$79.99 is a meaningful discount from $119.88 paid monthly without making the annual product feel cheap.

It gives approximately:

- 33% savings versus twelve monthly payments;
- stronger retention and upfront cash flow;
- a simple round price below $80;
- enough value separation to make annual attractive without making monthly look punitive.

Do not initially discount annual pricing more aggressively unless conversion data shows the need.

## Why not $4.99/month

$4.99 creates three problems:

1. It anchors LinePay near commodity calculators instead of a specialized wage-audit tool.
2. It leaves little room to communicate the value of verified agreement rules and reconciliation.
3. Doubling price later can create more friction than starting at the appropriate niche-professional price.

If $9.99 does not convert after users experience a real audit, first investigate product value and positioning rather than reflexively cutting price.

## Why not $14.99/month at launch

The product will initially lack the breadth, agreement coverage, and proof needed to justify a higher professional-tool price consistently.

$14.99+ can be tested later if LinePay develops strong verified agreement coverage, repeatedly finds real discrepancies, or adds high-value workflow such as claim-ready evidence/reporting.

## Activation and paywall strategy

Do not put a subscription wall in front of setup or initial expected-pay calculation.

Preferred sequence:

```text
Install
  ↓
Set confirmed pay rules
  ↓
Log real work
  ↓
See expected pay / ledger
  ↓
Scan first real paycheck
  ↓
Receive one complete audit free
  ↓
Understand the value
  ↓
Offer LinePay Pro for recurring audits
```

This is preferable to a short calendar-based free trial because a worker should reach an actual payday before evaluating the product.

A local first-audit allowance may be reset by reinstalling the app. Accept that weakness initially rather than creating a user account/backend solely to police trial abuse.

## Paywall principles

The paywall should feel like a tool purchase, not a consumer-growth funnel.

Use simple copy such as:

> **Audit every paycheck**
>
> Scan your paystub, compare it with the work and rules you recorded, and keep a history of possible differences.

Show:

- $9.99 monthly;
- $79.99 yearly with the explicit annual saving;
- Restore Purchases;
- cancel-anytime App Store language;
- local-first/privacy statement.

Do not use:

- fake countdown timers;
- hidden close buttons;
- misleading weekly-equivalent pricing as the main price;
- preselected consent tricks;
- exaggerated "you are losing money" claims;
- more than two primary subscription choices at launch.

## No lifetime purchase at launch

Do not offer lifetime pricing initially.

Reasons:

- agreement/rule maintenance creates ongoing product work;
- StoreKit/subscription value is recurring;
- lifetime pricing makes future economics and support obligations harder to reason about;
- we need retention data before pricing long-duration access.

A lifetime offer can be reconsidered only after observing real usage patterns.

## Metrics to review

Pricing decisions should eventually use:

- setup → first work log completion;
- first work log → first audit completion;
- first audit → Pro conversion;
- monthly vs annual selection;
- trial/free-audit value recovered or discrepancies found;
- 30/90/180-day paid retention;
- cancellation reasons;
- refund rate;
- conversion by trade/agreement coverage;
- qualitative answers to "what would you use if LinePay disappeared?"

## Initial pricing decision

Unless validation evidence says otherwise:

> **Free basic tracker + first full audit free**
>
> **LinePay Pro: $9.99/month or $79.99/year**

This is the launch default to implement in StoreKit when monetization work begins.
