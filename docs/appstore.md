# LinePaycheck App Store & ASO Playbook

> **Canonical App Store strategy for iOS 1.0.** This file owns public App Store positioning, metadata, ASO, screenshot sequencing, review strategy, and launch presentation. If implementation or another marketing document conflicts with this file, update the conflict deliberately rather than letting the store page drift.

## Decision

The consumer brand is:

> **LinePaycheck**
>
> **Check every paycheck.**

The App Store listing should use the extra title space for one high-intent descriptive phrase without changing the brand users see in the icon or inside the app.

### Recommended U.S. App Store metadata

| Field | Launch value | Limit |
|---|---|---:|
| App Store name | **LinePaycheck: Lineman Pay** | 25 / 30 chars |
| Device/app brand | **LinePaycheck** | — |
| Subtitle | **Overtime, Callout & Per Diem** | 28 / 30 chars |
| Promotional text | **Track real work, calculate expected pay from your confirmed rules, and check each paycheck for possible differences. No LinePaycheck account required.** | 150 / 170 chars |
| Primary category | **Finance** | — |
| Secondary category | **Utilities** | — |
| Price | **Free with In-App Purchases** | — |
| Age rating | Target **4+** if the final questionnaire supports it | — |

The technical identity does **not** need to match the public brand:

- bundle ID remains `com.streamentry.linepay`;
- repository may remain `streamentry/linepay`;
- existing internal StoreKit product IDs such as `linepay.pro.monthly` and `linepay.pro.yearly` may remain unchanged;
- internal identifiers should not be renamed merely for cosmetic brand consistency.

The App Store title is intentionally **not** just `Lineman Pay`. `LinePaycheck` gives us an ownable consumer name; `Lineman Pay` gives search and first-glance clarity.

---

## 1. Store-page job

The product page has roughly one job:

> **Make a lineman understand within seconds that LinePaycheck was built to check his pay against the work he actually performed.**

The page should communicate five things, in this order:

1. this is for linemen;
2. it understands real pay structures such as overtime, callouts, and per diem;
3. it calculates expected pay from the worker's confirmed rules;
4. it can compare that expectation with the paycheck and surface possible differences;
5. it does this without requiring a LinePaycheck account or central paycheck database.

Do not position LinePaycheck primarily as:

- a generic time tracker;
- a salary calculator;
- a budgeting app;
- a tax estimator;
- an employer timesheet system;
- an AI payroll assistant;
- a legal wage-claim tool.

The differentiating sentence is:

> **LinePaycheck doesn't just total overtime. It checks the paycheck against the work and pay rules you recorded.**

---

## 2. ASO strategy

### 2.1 What Apple indexes

For App Store search, prioritize:

1. app name;
2. subtitle;
3. keyword field;
4. primary and secondary categories;
5. behavioral signals such as downloads, ratings, and reviews.

Apple states that search relevance considers the app title, subtitle, keywords, primary category, and user behavior. Current ASO research also consistently finds the title to be the strongest on-metadata keyword field.

Do not assume that promotional text improves App Store keyword ranking. Apple explicitly says it does not.

The description is valuable for conversion and for web search engines, but it should not be treated as the main App Store keyword field.

### 2.2 Launch keyword thesis

The first market is U.S. linemen, so optimize for the language they naturally use:

#### Tier 1: highest intent

- lineman pay
- lineman paycheck
- lineman overtime
- overtime tracker
- paycheck audit
- paystub audit
- callout pay
- per diem tracker

#### Tier 2: trade context

- journeyman pay
- apprentice pay
- union pay
- storm pay
- work hours
- pay rate
- shift tracker
- earnings tracker

#### Tier 3: later expansion

- electrician pay
- electrical trade pay
- utility worker pay
- payroll checker
- wage tracker

Do **not** dilute the launch metadata by targeting every construction trade at once. Win the lineman query space first.

### 2.3 App name

Recommended:

> **LinePaycheck: Lineman Pay**

Why:

- `LinePaycheck` preserves the brand;
- `Lineman Pay` is the clearest category phrase;
- the title uses 25 of 30 characters without becoming keyword spam;
- the name still reads naturally in a search result.

Do not use:

- `Best Lineman Paycheck Calculator`;
- `Lineman Pay OT Per Diem Tracker`;
- competitor names;
- trademark bait;
- generic superlatives such as `#1` or `Best`.

If App Review or real ASO data later shows the descriptor is counterproductive, fall back to `LinePaycheck` and move the category phrase to the subtitle.

### 2.4 Subtitle

Recommended:

> **Overtime, Callout & Per Diem**

Why this subtitle:

- it avoids repeating `lineman` and `pay`, which are already in the title;
- it adds three trade-relevant concepts;
- it immediately signals that this is not a generic 8-hours-times-rate calculator;
- it remains understandable when truncated or read without the description.

Alternative to test later if audit intent becomes the stronger acquisition source:

> **Overtime & Paystub Auditor**

Do not repeatedly change title/subtitle without enough data. Metadata changes can reset the learning process around new terms and make interpretation noisy.

### 2.5 Keyword field

Recommended U.S. launch keyword field:

```text
paystub,union,journeyman,apprentice,storm,shift,hours,rate,earnings,ledger,audit,tracker,wages,work
```

This is **99 bytes** and intentionally does not repeat words already used in the recommended title/subtitle.

Rules:

- commas, no spaces after commas;
- use singular terms unless research shows a meaningful plural difference;
- do not repeat the app name, subtitle words, company name, or category name;
- do not waste bytes on `app`, `best`, `free`, or other weak generic terms;
- do not use competitor names;
- do not use protected third-party names merely to capture search traffic;
- specifically avoid putting `IBEW` in the keyword field unless we have a legitimate basis to use that trademark.

The algorithm can combine individual terms into multi-word queries, so prefer reusable words over stuffing long phrases into the hidden keyword field.

### 2.6 Semantic consistency and App Store tags

Apple can generate App Store tags from App Store Connect metadata using machine learning. Keep the same semantic core throughout the listing:

- lineman;
- pay;
- paycheck;
- overtime;
- callout;
- per diem;
- paystub;
- work log;
- audit/check;
- private/on-device.

Do not make the subtitle say `pay tracker`, screenshots say `personal finance`, and description say `AI assistant`. Semantic consistency helps both people and machine classification understand what LinePaycheck actually is.

---

## 3. Final App Store description

Use plain text. Do not fill the first paragraph with a feature inventory. The opening should sell the job to be done before the customer taps **More**.

### Launch description

```text
LinePaycheck is built for linemen who want to know what their work should pay before trusting the number on a paycheck.

Set up your real pay rules, log the work you actually performed, and let LinePaycheck calculate expected gross pay with an explainable ledger. When payday comes, compare your paystub with your recorded work and review possible differences.

BUILT FOR LINEWORK PAY

• Track regular shifts, callouts, storm work, and overnight work
• Configure overtime rules and pay multipliers
• Account for callout minimums and per diem
• Keep the work timezone tied to the pay rules
• See expected pay broken down line by line

CHECK THE PAYCHECK

LinePaycheck is more than an overtime calculator. It is designed to compare what your recorded work and confirmed rules say you should expect with what your paycheck reports.

When something does not line up, LinePaycheck shows the possible difference and the math behind it so you can review the source instead of guessing.

YOUR RULES, NOT OUR ASSUMPTIONS

Pay rules vary by agreement, contractor, local, job, and situation. LinePaycheck does not silently invent rules for you. Optional rules stay off until you confirm them, and calculations remain tied to the rule context that produced them.

PRIVATE BY DEFAULT

No LinePaycheck account is required. Your work and pay data stay on your iPhone by default. LinePaycheck is designed to perform calculation and paystub processing on-device rather than uploading your paycheck to a central account.

FREE TO START

Use LinePaycheck Free to set up a pay profile, log work, calculate expected pay, review the Pay Ledger, and complete your first paycheck audit.

LinePaycheck Pro is for workers who want recurring paycheck checks, paystub scanning, reconciliation history, and advanced audit tools.

LinePaycheck helps you organize and compare your own work and pay information. Calculations and possible discrepancies are estimates for review and are not legal, tax, payroll, or employment advice.

Check every paycheck.
```

### Description rules

- Only mention features that are actually shipping in the submitted build.
- If paystub OCR is not shipping, remove `paystub processing`, `paystub scanning`, and any screenshot that implies scanning.
- If recurring reconciliation is not active, do not advertise a paid subscription as if it is.
- Do not say LinePaycheck determines what the employer **legally owes**.
- Prefer `possible difference`, `expected pay`, `confirmed rules`, and `review` over accusations.
- Do not claim workers recover an average dollar amount unless we have real, supportable data.
- Do not say `AI-powered` merely because OCR or extraction uses machine learning.

---

## 4. Promotional text

Promotional text can be changed without submitting a new app version and does **not** affect App Store search ranking.

Default:

> **Track real work, calculate expected pay from your confirmed rules, and check each paycheck for possible differences. No LinePaycheck account required.**

Good later uses:

- a newly launched agreement/rule capability;
- a major reconciliation improvement;
- a new export/report workflow;
- a limited real promotion if one actually exists.

Do not turn promotional text into a rotating keyword dump.

---

## 5. Screenshot strategy

Apple allows up to ten screenshots. Depending on orientation, up to three can appear directly in search results. Therefore **screenshots 1–3 are the product page** for many customers.

Use portrait screenshots first unless product evidence later proves another orientation converts better.

### Visual principle

The screenshot set follows `DESIGN.md`:

> **Precision Industrial Minimalism**

Use:

- actual app UI;
- porcelain + graphite surfaces;
- Oxide teal interaction color;
- restrained copper only as a tiny signature detail;
- strong tabular money typography;
- the Line Gap motif sparingly;
- real trade vocabulary;
- one message per screenshot.

Never use:

- stock linemen;
- generated worker imagery;
- lightning backgrounds;
- blue-purple gradients;
- glowing phone mockups;
- giant rounded fintech cards;
- fake five-star reviews;
- fake recovered-dollar claims;
- screenshots made mostly of marketing text with barely visible UI.

Apple recommends screenshots show the actual experience and lead with the strongest functionality rather than turning the whole asset into a generic advertisement.

### Required launch sequence

#### Screenshot 1 — core promise

**Headline**

> **Know what your work should pay.**

**UI shown**

- a real Pay Ledger or pay-period summary;
- one clear expected gross amount;
- regular/OT breakdown visible;
- no fake discrepancy needed.

**Job**

Explain the app in one glance.

#### Screenshot 2 — trade-specific credibility

**Headline**

> **Built around your pay rules.**

**Supporting microcopy, if needed**

> OT · callouts · per diem

**UI shown**

- pay profile/rules;
- hourly rate;
- enabled rules;
- optional rules visibly explicit rather than magically assumed.

**Job**

Make a lineman think: `this understands how my pay works`.

#### Screenshot 3 — differentiated outcome

**Headline**

> **Spot possible pay differences.**

**UI shown**

```text
EXPECTED
PAID
POSSIBLE DIFFERENCE
```

with the Line Gap motif and an explainable result.

**Job**

Separate LinePaycheck from basic overtime trackers.

#### Screenshot 4 — explainability

**Headline**

> **See the math behind every hour.**

**UI shown**

- ledger rows;
- multipliers;
- amount per component;
- expandable evidence/rule explanation.

#### Screenshot 5 — work logging

**Headline**

> **Log the shift. Keep the evidence.**

**UI shown**

- regular shift;
- callout;
- overnight/storm example;
- clean work-entry flow.

#### Screenshot 6 — paystub workflow

Only include once OCR/reconciliation is actually shipping.

**Headline**

> **Scan the paystub. Confirm the fields.**

**UI shown**

- paystub import;
- extracted fields;
- `Needs confirmation` states where appropriate.

Do not imply OCR is infallible.

#### Screenshot 7 — privacy

**Headline**

> **No account. No paycheck upload.**

**Supporting copy**

> Pay data stays on this iPhone by default.

**UI shown**

- actual privacy/settings screen or a real product state;
- avoid a decorative lock illustration as the entire screenshot.

Only use `No paycheck upload` while the architecture truly remains local-only.

#### Screenshot 8 — history

Only include once durable history is shipping.

**Headline**

> **Keep every pay period straight.**

**UI shown**

- history list;
- status labels such as Match / Review;
- expected and paid totals.

### Screenshot copy rules

- Headline ideally 4–7 words.
- One headline per frame.
- Keep text in safe areas and assume thumbnails.
- Money and important states must be legible without zooming.
- Use realistic but fabricated demo data, never a real worker's paystub or personal information.
- Avoid improbable `gotcha` examples designed only to shock.
- Screenshots must match the current shipping UI closely enough that users do not feel bait-and-switched.

---

## 6. App preview strategy

Apple permits up to three app previews per supported device size/language, each up to 30 seconds, and previews can autoplay on the product page and in search.

For launch, **do not add an app preview merely because the slot exists**.

Ship screenshots first. Add one preview only when the reconciliation flow is polished enough to look excellent in real captured UI.

### Recommended 22–28 second story

```text
0–4 sec
Set actual pay rules

4–8 sec
Log a shift / callout

8–12 sec
Expected pay updates

12–17 sec
Import or scan paystub

17–23 sec
Expected vs paid comparison

23–27 sec
Open the rule/evidence explanation

Final beat
Check every paycheck.
No LinePaycheck account required.
```

Rules:

- use real captured app footage;
- show the strongest product moment in the first few seconds;
- no cinematic stock footage;
- no fake text messages from employers;
- no exaggerated recovered-money claims;
- no narration required if the visual story works silently;
- subtitles/on-screen text must remain readable without sound.

---

## 7. App icon

The icon must follow `DESIGN.md` and should remain recognizable at search-result size.

Direction:

- use the **Line Gap** as the core geometry;
- graphite / porcelain / Oxide as the primary language;
- copper can appear as one restrained detail;
- strong silhouette;
- no literal bucket truck, hard hat, pole, dollar sign, lightning bolt, or paycheck document icon;
- no tiny letters such as `LP` unless testing proves they improve recognition;
- no gradient-glass fintech orb.

The icon should communicate precision and difference, not `construction clip art`.

Before release, inspect it at:

- Home Screen size;
- Spotlight size;
- App Store search-result size;
- light and dark surrounding UI;
- grayscale if possible.

---

## 8. Category

### Primary: Finance

The product's central subject is the worker's pay and paycheck reconciliation. Finance is the clearest primary category and matches the category in which adjacent pay-tracking products are already found.

### Secondary: Utilities

Utilities reflects the app's tool-like workflow: rules, work logging, calculation, and checking.

Do not choose Business simply because the user has a job. LinePaycheck is a worker-side financial utility, not software for running an employer's organization.

Categories must remain accurate; Apple can reject misleading category choices.

---

## 9. Privacy presentation

Privacy is not footer trivia for LinePaycheck. It is one of the reasons to choose the product.

### Target App Privacy label

If the shipping build continues to transmit **no user/work/pay data off-device to us or third-party SDKs**, the target App Store Connect answer is:

> **No, we do not collect data from this app.**

Apple defines information processed only on-device as not `collected` for App Privacy disclosure purposes.

This declaration is only correct if the final binary agrees with it.

Before every submission, audit:

- analytics SDKs;
- crash/reporting SDKs;
- remote configuration;
- support/feedback forms;
- OCR providers;
- advertising/attribution SDKs;
- any network request containing work/pay metadata.

If any third-party code collects data, update the label honestly. Never preserve `Data Not Collected` as a marketing claim after the architecture changes.

### Required privacy policy

Apple requires a privacy policy URL in App Store Connect and an easily accessible privacy-policy link inside the app.

Before release create a real public page at the canonical LinePaycheck domain, for example conceptually:

```text
/privacy
```

The exact domain is intentionally not invented in this document.

The policy should plainly state:

- what LinePaycheck collects, if anything;
- what stays only on-device;
- whether Apple services such as StoreKit are used;
- whether support emails submitted voluntarily leave the device;
- retention/deletion behavior;
- how users can contact support;
- what changes if iCloud or any backend is introduced later.

---

## 10. Support and marketing URLs

Before App Review, create real pages on the canonical public domain.

Required/strongly recommended routes:

```text
/                 marketing homepage
/support          support/contact page
/privacy          privacy policy
/terms            terms of use if we use custom terms
```

The support URL must lead to genuine contact information. Do not submit a blank landing page or `coming soon` page.

The marketing homepage above the fold should mirror the App Store message:

> **Check every paycheck.**
>
> LinePaycheck helps linemen track real work, calculate expected pay from confirmed rules, and review possible differences against the paycheck.

Do not let the website turn into a broader `AI payroll platform` while the App Store page says something else.

---

## 11. Subscription metadata

Follow `docs/pricing.md` and `docs/onboarding.md`.

### Subscription group

User-facing display name:

> **LinePaycheck Pro**

One subscription group only.

### Monthly

**Internal product ID**

```text
linepay.pro.monthly
```

**Display name**

> **LinePaycheck Pro Monthly**

**Description**

> **Check every paycheck with Pro tools.**

### Annual

**Internal product ID**

```text
linepay.pro.yearly
```

**Display name**

> **LinePaycheck Pro Annual**

**Description**

> **Check every paycheck with Pro tools.**

Apple permits In-App Purchase display names up to 30 characters and descriptions up to 45 characters. Keep them understandable rather than using internal marketing names.

### Pricing

Canonical launch hypothesis:

- Monthly: **$9.99/month**
- Annual: **$79.99/year**
- annual recommended;
- first complete paycheck audit free;
- seven-day introductory free trial on Annual for eligible customers; Monthly has no trial;
- no weekly plan;
- no lifetime plan.

Actual displayed price inside the app must come from StoreKit so localization and storefront pricing remain correct.

The trial decision supersedes the original no-calendar-trial policy. [Onboarding](onboarding.md) owns offer timing, eligibility-aware copy, the seven-day activation sequence, and measured conversion targets. [Setup evidence](research/onboarding-trial-2026-09-05.md) distinguishes saved App Store configuration from tested purchasing.

Use “7 days free, then [localized annual price]/year” only where eligibility and the offer are verified. The full annual charge must remain prominent. Public listing copy should say “Eligible new annual subscribers can try Pro free for 7 days” only after the purchase path and the supported storefronts are verified. The current launch description above does not promise a trial; do not publish an unverified universal claim.

---

## 12. Ratings and reviews

Ratings affect conversion and can influence search ranking, but prompting too early burns trust.

Apple may display the system review prompt a maximum of three times in a 365-day period, so treat each opportunity as scarce.

### Do not ask

- on first launch;
- during onboarding;
- immediately after a paywall;
- immediately after purchase;
- while the user is editing a shift;
- at the moment a stressful discrepancy first appears;
- after an OCR failure or validation error.

### Good LinePaycheck trigger

For a Free user:

```text
first audit completed successfully
+
user has used LinePaycheck on multiple days
+
user later returns to History/Today
+
no unresolved app error
→ consider review request
```

For Pro:

```text
2–3 completed paycheck audits
+
user has just completed a successful non-error flow
+
no review prompt shown for this app version
→ consider review request after a short pause
```

Use StoreKit's current `RequestReviewAction` / App Store review API, not a custom fake star dialog.

Also provide an optional persistent **Rate LinePaycheck** link in Settings that opens the App Store review page.

### Responding to reviews

For every substantive review:

- respond calmly;
- answer the actual issue;
- never disclose user data;
- do not argue about pay rules;
- if a bug is fixed, say which version contains the fix;
- treat repeated complaints as product evidence.

Never buy, gate, or incentivize ratings.

---

## 13. App Review notes

Because LinePaycheck has no account, make review easy.

Suggested review notes for 1.0, adapted to the actual shipping feature set:

```text
LinePaycheck is a local-first paycheck and work-pay utility for linemen. No account or login is required.

Suggested review path:
1. Launch the app.
2. Tap "Set up my pay".
3. Enter an hourly rate and save the pay profile. Optional overtime/callout/per-diem rules are off until explicitly enabled.
4. Continue free from the Pro offer if shown.
5. Add a work interval from Today.
6. Open Pay to review the expected-pay ledger and rule explanations.
7. If paycheck scanning/reconciliation is enabled in this build, use the included demo/test path described below to exercise it.

All wage/work data is processed and stored locally by default. There is no LinePaycheck user account or central user database.
```

If subscriptions are active, add exact instructions for finding the paywall and restoring purchases. If OCR needs a sample paystub, provide a non-sensitive test asset or deterministic review path rather than expecting App Review to invent payroll data.

Never leave App Review guessing how to reach the feature tied to an In-App Purchase.

---

## 14. Product page optimization

Apple's Product Page Optimization supports the original product page plus up to three treatments using alternate screenshots, previews, and app icons.

Do not start testing until the baseline page has enough traffic to produce interpretable data.

### Experiment order

#### Test 1 — screenshot 1 message

Baseline:

> **Know what your work should pay.**

Treatment A:

> **Check every paycheck.**

Treatment B:

> **Built for lineman pay rules.**

Keep the rest of the screenshot set identical. This isolates whether outcome, recurring audit, or trade identity is the strongest conversion hook.

#### Test 2 — screenshot ordering

Compare:

```text
Expected pay → Rules → Difference
```

with:

```text
Difference → Rules → Ledger
```

Do not test icon, headline, screenshot order, and pricing simultaneously.

#### Test 3 — icon

Only after screenshot messaging stabilizes should we test one restrained icon variation.

Apple's current PPO tooling evaluates conversion lift and confidence. Do not declare a winner from a handful of downloads.

---

## 15. Custom Product Pages

Apple allows multiple Custom Product Pages with distinct screenshots, promotional text, previews, and keyword targeting. Current App Store behavior can surface a keyword-linked custom page directly in organic search results.

Do **not** create dozens at launch.

After the default page has real traffic, start with at most three:

### CPP A — Overtime / storm / callout

Audience/search intent:

- lineman overtime;
- storm pay;
- callout pay;
- overtime tracker.

First screenshot:

> **Track the hours that change the check.**

Show OT/callout rule handling.

### CPP B — Paycheck / paystub audit

Audience/search intent:

- paycheck audit;
- paystub checker;
- missing pay review.

First screenshot:

> **Check the paycheck against the work.**

Show expected vs paid and evidence.

### CPP C — Per diem / travel

Only after the feature is strong enough to deserve its own acquisition path.

First screenshot:

> **Keep per diem with the work it belongs to.**

Use unique, relevant keyword groups for each page. Do not assign the same keyword intent to multiple custom pages.

---

## 16. Localization

### Launch

Primary localization:

> **English (U.S.)**

Do not create fake localizations merely to gain keyword inventory.

### Expansion rule

Localize App Store metadata only when:

- the app itself supports that language well;
- the pay-rule model is relevant to that market;
- support can reasonably serve that market;
- keyword research is done in the local vocabulary rather than translated word-for-word.

Potential later markets include English-speaking Canada and other countries with substantial linework audiences, but product-rule fit must come before ASO expansion.

---

## 17. Web SEO relationship

App Store ASO and web SEO should reinforce each other without copying every field verbatim.

The website should eventually target dedicated high-intent pages such as:

```text
/lineman-pay-calculator
/lineman-overtime-calculator
/lineman-paycheck-audit
/lineman-callout-pay
/lineman-per-diem
```

Only publish pages that contain genuinely useful information rather than doorway pages made solely for rankings.

Recommended homepage HTML title concept:

> **LinePaycheck | Lineman Pay & Paycheck Auditor**

Recommended homepage H1:

> **Check every paycheck.**

The App Store description is also used in web search-engine results after release, so its first paragraphs should remain human-readable and semantically clear.

---

## 18. Apple Ads, only after organic baseline

Do not spend meaningfully on Apple Ads before the product page converts real organic/TestFlight-quality traffic.

When ready, begin with tightly related exact/high-intent terms such as:

- lineman pay;
- lineman overtime;
- overtime tracker;
- paycheck tracker;
- paystub checker;
- callout pay;
- per diem tracker.

Use custom product pages so the ad promise and destination screenshot match the query.

Do not bid on competitor trademarks as a brand strategy.

Paid acquisition is a multiplier on the product page, not a substitute for one that explains itself poorly.

---

## 19. What's New copy

For later releases, write release notes like a product changelog for workers, not a developer commit log.

Good:

```text
LinePaycheck now handles overnight callouts more clearly and makes Pay Ledger explanations easier to review.

Also included:
• Faster work entry
• Clearer rule-confirmation states
• Fixes for pay periods that cross a timezone boundary
```

Bad:

```text
Bug fixes and performance improvements.
```

Also bad:

```text
Refactored persistence layer and fixed race condition.
```

Lead with the customer-visible improvement. Mention meaningful fixes when they increase trust.

---

## 20. Launch asset checklist

### Metadata

- [ ] App Store name set to `LinePaycheck: Lineman Pay`
- [ ] Home-screen display name remains `LinePay`; public product branding remains `LinePaycheck`
- [ ] Subtitle set to `Overtime, Callout & Per Diem`
- [ ] Keyword field verified at <=100 bytes
- [ ] Promotional text pasted exactly and proofread
- [ ] Description matches the actual shipping build
- [ ] Primary category = Finance
- [ ] Secondary category = Utilities
- [ ] Age rating questionnaire completed honestly
- [ ] Copyright/legal entity correct

### Privacy and URLs

- [ ] Canonical public domain selected
- [ ] Marketing URL live
- [ ] Support URL live and contains real contact information
- [ ] Privacy Policy URL live
- [ ] Privacy policy link exists inside the app
- [ ] App Privacy answers audited against the final binary
- [ ] No analytics/crash SDK silently invalidates the privacy claim

### Screenshots

- [ ] Screenshots 1–3 communicate value without scrolling
- [ ] Screens use current real UI
- [ ] Demo data is fabricated and realistic
- [ ] No real paystub/personally identifying data appears
- [ ] Light/dark visuals are consistent with `DESIGN.md`
- [ ] Screenshot typography remains legible at thumbnail size
- [ ] No feature appears before it ships

### Subscription

- [ ] `LinePaycheck Pro` subscription group configured
- [ ] Monthly and annual display names localized
- [ ] Monthly and annual descriptions localized
- [ ] Annual introductory offer is seven days free in the intended storefronts; Monthly remains immediate paid
- [ ] Eligible, ineligible, unknown-eligibility, and unavailable-offer paywall states tested
- [ ] Trial duration, full renewal price, cancellation, Terms, and Privacy are visible
- [ ] StoreKit returns localized prices correctly
- [ ] Restore Purchases works
- [ ] Subscription-management path works
- [ ] Core recurring Pro value is actually shipping before commerce is enabled

### Review

- [ ] App Review notes include a deterministic test path
- [ ] OCR/reconciliation review asset exists if needed
- [ ] No login credentials are required because there is no account
- [ ] All permissions are explainable and requested only in context

### Conversion

- [ ] First screenshot is the strongest value promise
- [ ] First three screenshots tell a complete mini-story
- [ ] Soft paywall behavior matches `docs/onboarding.md`
- [ ] First complete paycheck audit remains free
- [ ] Review prompt is delayed until a genuine successful-use moment

---

## 21. Metrics after launch

Keep the App Store dashboard small.

Watch:

1. search impressions;
2. product page views;
3. product page conversion rate;
4. downloads by source;
5. top search terms where available through Apple acquisition tooling;
6. first expected-pay result and first audit completion;
7. download → annual trial → first paid conversion, plus annual share of first-paid subscribers;
8. ratings volume and average rating;
9. review themes;
10. D30 net proceeds per download, refunds, and actual subscription renewal.

Diagnose before changing metadata.

Examples:

- impressions low + conversion strong → discoverability/ASO problem;
- impressions strong + conversion weak → screenshot/positioning/trust problem;
- downloads strong + first-audit completion weak → product/onboarding problem;
- trial starts strong + paid conversion weak → trial activation, recurring value, or billing-confidence problem;
- Pro conversion strong + retention weak → product value does not persist after purchase.

Do not respond to every weekly fluctuation with new metadata.

---

## 22. What LinePaycheck must never become on the App Store

Never present it as:

> `THE #1 AI-POWERED LINEMAN MONEY SUPER APP ⚡💰`

No:

- keyword-stuffed title soup;
- hard-hat stock photography;
- generated worker testimonials;
- fake recovered-dollar figures;
- `your boss is stealing from you` fear copy;
- electrical hazard theater;
- purple gradient AI visuals;
- `FREE` spam in screenshots;
- giant annual-discount stickers;
- false legal certainty;
- unsupported union endorsements;
- competitor names in metadata;
- privacy claims that the shipping binary no longer deserves.

The store page should feel like the app itself:

> **precise, useful, calm, trade-aware, and trustworthy.**

---

## 23. Final launch page

If every secondary decision is stripped away, this is the page we are building:

```text
ICON
The Line Gap. Precision, not trade cosplay.

NAME
LinePaycheck: Lineman Pay

SUBTITLE
Overtime, Callout & Per Diem

SCREENSHOT 1
Know what your work should pay.

SCREENSHOT 2
Built around your pay rules.
OT · callouts · per diem

SCREENSHOT 3
Spot possible pay differences.

SCREENSHOT 4
See the math behind every hour.

SCREENSHOT 5
Log the shift. Keep the evidence.

SCREENSHOT 6
Scan the paystub. Confirm the fields.

SCREENSHOT 7
No account. No paycheck upload.

SCREENSHOT 8
Keep every pay period straight.

PROMOTIONAL TEXT
Track real work, calculate expected pay from your confirmed rules, and check each paycheck for possible differences. No LinePaycheck account required.

PRIMARY CATEGORY
Finance

SECONDARY CATEGORY
Utilities

PRICE
Free · In-App Purchases
```

And the governing rule is:

> **The App Store page should make the right worker think “this was made for my paycheck” before he has to read the full description.**

---

## Research basis

Checked September 2026.

Primary Apple references:

- Creating your product page: https://developer.apple.com/app-store/product-page/
- App Store search: https://developer.apple.com/app-store/search/
- App information limits: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- Platform version metadata: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Screenshots and previews: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- Asset best practices: https://developer.apple.com/app-store/asset-best-practices/
- App previews: https://developer.apple.com/app-store/app-previews/
- Product Page Optimization: https://developer.apple.com/app-store/product-page-optimization/
- Custom Product Pages: https://developer.apple.com/app-store/custom-product-pages/
- Categories: https://developer.apple.com/app-store/categories/
- Ratings and reviews: https://developer.apple.com/app-store/ratings-and-reviews/
- Requesting App Store reviews: https://developer.apple.com/documentation/storekit/requesting-app-store-reviews
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Managing app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/

Current ASO context:

- AppTweak, App Store ranking factors (2026): https://www.apptweak.com/en/aso-blog/app-store-ranking-factors
- AppTweak, App Store keyword research (2026): https://www.apptweak.com/en/aso-blog/app-store-keyword-research-aso

Competitive reference:

- LineVault App Store listing: https://apps.apple.com/us/app/linevault/id6764867679

External ASO guidance informs the launch hypothesis; LinePaycheck's own search impressions, conversion, completed audits, retention, and worker interviews should override generic benchmarks once real data exists.
