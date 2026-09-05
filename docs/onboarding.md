# LinePay Onboarding & Soft Paywall

> **Canonical onboarding strategy.** If implementation or another product document conflicts with this file, this file wins unless the product decision is deliberately revised.

## Decision

LinePay 1.0 uses a **short, interactive onboarding flow with a soft paywall**.

The first-session sequence is:

```text
Open app
  ↓
1. Value + trust
  ↓
2. Set real pay rules
  ↓
3. Soft Pro offer
  ├── Subscribe, if Pro is actually available
  └── Continue free
  ↓
Today / start logging work
```

The second monetization moment is **not another arbitrary timer**. It is triggered by real intent:

```text
First complete paycheck audit
  ↓
Show actual audit result
  ↓
User attempts another audit
  ↓
Contextual Pro paywall
```

LinePay does **not** use a hard launch paywall, mandatory account creation, a 3-day countdown trial, fake urgency, or a paywall before the user understands what the product does.

The guiding rule is:

> **Earn trust first. Ask early enough to monetize Day 0 intent. Ask again only when the user reaches the paid boundary.**

---

## 1. Why this structure

### What current subscription evidence says

RevenueCat's *State of Subscription Apps 2026* reports:

- hard-paywall apps have much higher median D35 download-to-paid conversion than freemium apps (10.7% vs. 2.1%);
- most subscription decisions are heavily front-loaded in the first session;
- roughly one-third of conversions happen on Day 0;
- 60%+ of conversions happen within the first week;
- Business apps start almost 90% of their trials on Day 0;
- longer trials outperform very short trials on trial-to-paid conversion;
- two-plan paywalls are the dominant simple structure across many categories;
- countdown timers and progress bars are rare, not normal best practice.

Source: https://www.revenuecat.com/state-of-subscription-apps

Adapty's 2026 research similarly emphasizes that most trial starts happen on Day 0 and that onboarding/paywall **structure, placement, trial design, and plan duration** tend to matter more than cosmetic copy/color changes.

Sources:

- https://adapty.io/blog/how-to-personalize-onboarding-and-paywalls-in-your-mobile-app/
- https://adapty.io/blog/what-is-adapty-flow-builder/

### What Apple's platform guidance says

Apple's HIG recommends that onboarding be:

- fast;
- optional where practical;
- interactive rather than lecture-like;
- focused on the app's actual experience;
- light on nonessential setup;
- delayed only when setup is not required;
- respectful of the user's ability to experience the app before ratings or purchase prompts.

Apple also explicitly recommends explaining subscription benefits during onboarding and considering limited free access before requiring a purchase.

Sources:

- https://developer.apple.com/design/human-interface-guidelines/onboarding
- https://developer.apple.com/design/human-interface-guidelines/in-app-purchase
- https://developer.apple.com/app-store/review/guidelines/

### LinePay-specific conclusion

A generic hard paywall would likely increase immediate purchase attempts, but it would undermine LinePay's strongest product advantages:

- trust;
- privacy;
- immediate local utility;
- no account;
- proof through actual pay calculations;
- first real paycheck audit as the decisive value moment.

Therefore the correct optimization target is **qualified conversion + retention**, not maximum first-screen purchase rate.

---

## 2. The onboarding job

Onboarding has only four jobs:

1. communicate the outcome;
2. establish privacy/trust;
3. collect the minimum facts required to calculate expected pay;
4. expose the Pro offer without blocking Free.

It is **not** a product tour.

Do not teach:

- every tab;
- every future feature;
- OCR mechanics;
- agreement internals;
- export/reporting;
- settings;
- terminology the worker has not needed yet.

Contextual tips can teach later features when the user reaches them.

---

## 3. Screen 1: value + trust

### Goal

Make the worker understand LinePay within 5 seconds.

### Recommended copy

**Headline**

> Know what your work should pay.

**Supporting copy**

> Track the hours and pay rules that matter. LinePay calculates expected pay and helps you check the paycheck against your work.

**Trust proof**

> No account. Your pay data stays on this iPhone.

**Primary CTA**

> Set up my pay

### Visual rules

Use the Line Gap motif once. No illustration carousel. No generated lineworker photo. No three-card feature grid.

The screen should feel like opening a precision instrument, not watching an ad.

---

## 4. Screen 2: interactive pay setup

This is the core onboarding interaction.

Ask only for information needed to make LinePay useful immediately:

### Required

- profile/agreement label;
- hourly rate;
- work timezone.

### Optional, off by default

- daily overtime tier;
- Sunday premium;
- callout minimum;
- per diem.

Never pre-enable a rule merely because it is common among linemen.

The user should feel:

> **I am teaching LinePay how I get paid.**

not:

> I am filling in a registration form.

### Completion CTA

> Save my pay rules

After successful validation, move directly to the soft paywall. Preserve the completed profile regardless of whether the user buys.

---

## 5. Screen 3: onboarding soft paywall

### Purpose

Expose the subscription while Day 0 intent is strongest, but do not prevent the worker from using Free.

### Headline

> Audit every paycheck.

Avoid generic copy such as:

- Unlock premium;
- Go Pro;
- Supercharge your pay;
- AI-powered payroll insights.

### Personalized proof

Reflect the rules the worker just configured.

Examples:

> Your LinePay profile is ready for **daily OT + callout minimums**.

or:

> Your LinePay profile is ready at **$58.40/hr**.

Do not invent a rule or imply the rules are legally authoritative.

### Benefits

Keep to three concrete benefits maximum:

1. **Check every paycheck** against recorded work and confirmed rules.
2. **See possible differences** with an explainable Pay Ledger.
3. **Keep pay data private** on the device by default.

Only advertise features that are actually available in the shipping build.

### Plans

Follow `docs/pricing.md`:

- **Yearly**: recommended / Best value;
- **Monthly**: clearly visible alternative;
- no weekly plan;
- no lifetime plan;
- no fake third plan used as a decoy.

Prices must come from StoreKit `Product` data, not hard-coded UI strings.

### Primary action

When Yearly is selected:

> Continue with Yearly

When Monthly is selected:

> Continue with Monthly

### Soft escape

A visible secondary action is mandatory:

> Continue free

Do not:

- hide it behind an X in the corner;
- delay its appearance;
- use 30% opacity;
- label it ambiguously (`Maybe later` is less clear);
- make users decline twice.

A soft paywall should be genuinely soft.

### Trust footer

Show:

> No LinePay account. Pay data stays on this device by default.

Also provide:

- Restore Purchases;
- clear auto-renewal language when purchase is available;
- subscription management/help path before App Store release.

---

## 6. Do not use a calendar trial at launch

The pricing strategy already establishes:

> **First complete paycheck audit is free.**

That is a better LinePay trial than `3 days free` or `7 days free` because the product's natural value cadence is payday.

A short timer can expire before the user receives a paycheck.

RevenueCat's 2026 data also shows that longer trials tend to convert materially better than ≤4-day trials, reinforcing that ultra-short timers are not automatically superior.

Do not add a calendar trial until real data demonstrates that event-based sampling is inferior.

---

## 7. The second paywall: contextual intent

The onboarding paywall is an offer.

The **paid-boundary paywall** is where LinePay should eventually convert best because the worker has expressed explicit intent.

Preferred trigger:

```text
First complete audit consumed
       +
User starts another paycheck audit
       ↓
Feature-specific paywall
```

Copy should reflect the attempted action:

> Check every paycheck

> Your first paycheck check was free. LinePay Pro keeps auditing future paychecks against your recorded work and confirmed rules.

This is superior to showing the exact same generic paywall every three launches.

Do not paywall:

- opening the app;
- viewing one's own recorded work;
- editing existing work;
- reading the first audit result;
- correcting a mistaken pay rule.

---

## 8. Purchase implementation rules

Use StoreKit 2 directly unless a demonstrated growth requirement justifies another dependency.

### Product IDs

Canonical entitlement: `LinePay Pro`

Current product identifier proposal from `docs/pricing.md`:

- `linepay.pro.monthly`
- `linepay.pro.yearly`

Before App Store Connect creation, identifiers may be finalized once. After creation, treat them as immutable external identifiers.

### Store behavior

The app must:

- load product metadata asynchronously;
- display `Product.displayPrice` / localized store data;
- handle verified transactions only;
- listen for transaction updates;
- restore purchases;
- unlock Pro from current verified entitlements;
- remain usable as Free if StoreKit is unavailable;
- never make pay calculation depend on StoreKit availability.

### Pre-launch safety

Until Pro's paid audit value is actually implemented, the onboarding paywall may render as a **preview**, but purchase buttons must not sell unavailable functionality.

Do not ship a purchasable subscription whose core promised paid feature does not yet exist.

---

## 9. Paywall design rules

Follow `DESIGN.md`.

### Structure

One continuous vertical hierarchy, not a pile of cards:

```text
Line Gap

Audit every paycheck.
Short outcome copy

Profile-ready personalization

✓ Check every paycheck
✓ Explain possible differences
✓ Private by default

[ Yearly — Best value ]
[ Monthly ]

[ Continue with Yearly ]
Continue free

Restore Purchases
Renewal / privacy note
```

### Avoid AI subscription slop

No:

- giant `SAVE 67%` bursts;
- countdowns;
- pulsing CTA buttons;
- fake testimonials;
- fake review stars;
- fake scarcity;
- blurred workers in the background;
- gradient-purple Pro cards;
- weekly-equivalent price tricks;
- preselected consent checkboxes;
- confetti before purchase;
- fear copy about wage theft;
- dark-pattern close buttons.

The value proposition itself must carry the sale.

---

## 10. Personalization rules

Personalization is valuable only when it reflects facts the user supplied.

Good:

> Ready for daily OT, Sunday premium, and callout minimums.

Good:

> Your profile is set to $58.40/hr.

Bad:

> We found you could be losing $427 every paycheck.

Bad:

> Most linemen like you recover $2,300/year.

Unless LinePay has real evidence for those claims, they are fabricated persuasion.

---

## 11. Onboarding state

Onboarding is product state, not authentication state.

Minimum conceptual state:

```text
welcome
paySetup
softPaywall
complete
```

Once persistence exists:

- persist completion locally;
- never show first-run onboarding again merely because StoreKit failed;
- preserve pay setup if the app terminates at the paywall;
- let users revisit pay rules from Settings;
- let users revisit Pro from Settings / a contextual feature boundary.

No user account or backend is required.

---

## 12. Failure behavior

### Pay-rule validation fails

Stay on setup and explain the exact field that needs correction.

### Store products fail to load

Never trap the user.

Show:

> Pro isn't available right now.

and keep:

> Continue free

available.

### Purchase is cancelled

Return to the paywall without alarm copy.

### Purchase fails

Display an actionable, non-technical error and preserve the selected plan.

### Purchase succeeds

Confirm quietly and enter the main app.

No casino animation.

---

## 13. Accessibility

- Dynamic Type throughout onboarding and paywall.
- VoiceOver order follows visual hierarchy.
- Plan selection communicates selected state without color alone.
- Buttons meet LinePay field-ready target sizes.
- The close/free path remains accessible.
- Do not place critical renewal text at unreadably small sizes.
- Respect Reduce Motion.

---

## 14. Conversion metrics

Do not add a third-party analytics SDK solely for this funnel.

At launch, the minimum evidence set is:

1. install / App Store product-page data;
2. purchase and subscription data from App Store Connect;
3. TestFlight observation/interviews;
4. local debug-only funnel instrumentation during development;
5. direct user interviews around where onboarding felt confusing or untrustworthy.

If LinePay later needs remote funnel analytics, add the minimum privacy-preserving events under an explicit ADR. Never send wage, hours, rule details, employer names, or paystub content as analytics.

### Target diagnostic questions

Do not worship a generic industry conversion benchmark. Instead diagnose:

- Are users reaching pay setup?
- Are they completing pay setup?
- Are they seeing the onboarding paywall?
- Are they continuing into the app rather than abandoning?
- Are they logging work?
- Are they completing the first paycheck audit?
- Do first-audit completers convert to Pro?
- Do subscribers retain because audits remain useful?

The most important LinePay conversion metric is eventually:

> **first completed real audit → paid Pro**

not install → paywall tap.

---

## 15. Experiment order

Do not begin with button-color experiments.

### Experiment 0: product truth

Validate that real workers finish setup, log real work, and want recurring audits.

### Experiment 1: paywall placement

Compare:

- after pay setup (default);
- only after first audit.

Do not test until there is enough traffic to learn something.

### Experiment 2: package emphasis

Keep $9.99 monthly fixed and compare annual emphasis / annual price only if purchase volume supports it.

### Experiment 3: personalized benefit ordering

Examples:

- callout-first for workers who enabled callout rules;
- OT-first for workers who enabled overtime;
- privacy-first for workers who did not enable advanced rules.

### Experiment 4: trial mechanics

Only after first-audit-free has meaningful data should LinePay test a calendar trial.

Structural experiments outrank cosmetic experiments.

---

## 16. Implementation acceptance criteria

The onboarding implementation is correct when:

- first launch shows the value/trust screen;
- onboarding contains no account creation;
- the worker can set a valid pay profile interactively;
- all optional pay rules default off;
- successful setup preserves the profile before the paywall;
- the onboarding Pro offer is dismissible via `Continue free`;
- StoreKit product prices are not hard-coded in the purchase surface;
- StoreKit failure cannot block Free usage;
- purchasing is disabled if promised Pro value is not shipping/configured;
- Restore Purchases exists when StoreKit products are active;
- accessibility labels and Dynamic Type work;
- design follows `DESIGN.md`;
- no pay-rule or wage information leaves the device.

---

## 17. Final rule

The onboarding system should feel like this:

> **LinePay understands why I'm here, lets me configure the real rules quickly, tells me exactly what Pro buys, and doesn't hold my own work hostage.**

The monetization principle is:

> **Value before coercion. Day-0 offer without Day-0 captivity. Contextual paywall when intent is strongest.**
