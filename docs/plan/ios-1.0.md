# LinePay iOS 1.0

Status: **Active implementation plan**

Canonical bundle ID: **`com.streamentry.linepay`**

This plan is governed by `AGENTS.md`, `DESIGN.md`, `docs/product/pricing.md`, and `docs/architecture/local-first-no-account.md`.

> **1.0 objective:** build a small, trustworthy, insanely great machine for expensive hours.

LinePay is not trying to be the most feature-complete time tracker. It should be the product a lineworker trusts enough to use after a 14-hour shift and again on payday because it is faster than a notepad, clearer than a spreadsheet, and more rigorous than a generic overtime calculator.

---

## 1. Product promise

LinePay 1.0 should let a lineworker answer one repeated question with confidence:

> **Given the work I actually performed and the pay rules I confirmed, what gross pay should I expect, and where might my paystub differ?**

The core loop is:

```text
CONFIRM RULES -> RECORD REAL WORK -> KNOW EXPECTED PAY -> CHECK PAYSTUB -> EXPLAIN THE GAP
```

No account. No employer integration. No LinePay backend required for the core product. Wage, shift, agreement, and paystub data remain device-local by default.

### The emotional result

After using LinePay, a worker should feel:

- `I recorded what actually happened.`
- `I can see exactly how LinePay got this number.`
- `I did not have to fake hours to make the math work.`
- `I know what I should check on this paycheck.`
- `My pay data is mine.`

Calm certainty is the delight.

---

## 2. What “insanely great” means for LinePay

Insanely great does **not** mean more features, more animation, more AI, or more screens.

It means the critical 20% of interactions are exceptionally good:

1. first setup feels surprisingly short despite complex pay rules;
2. logging a familiar shift takes seconds;
3. actual work facts never get distorted to force a desired pay result;
4. expected pay updates immediately and remains explainable;
5. scanning a paystub feels safe and correctable;
6. uncertainty is visible instead of hidden;
7. a discrepancy can be understood in under five seconds, then audited deeply if needed;
8. historical results never mysteriously change;
9. errors are recoverable without losing evidence;
10. the app works without signal, signup, ads, tracking, or employer surveillance.

### Quality hierarchy

When scope conflicts arise, optimize in this order:

1. **correctness and trust**;
2. **daily-entry speed**;
3. **audit comprehension**;
4. **privacy and ownership**;
5. **recovery from mistakes**;
6. **craft and visual distinction**;
7. additional breadth.

Do not trade the first five for feature count.

---

## 3. Competitive research, September 2026

Research was reviewed against current App Store listings, release notes, and user reviews. We should borrow proven interaction principles, not copy visual trade dress or product structure.

### 3.1 Direct and adjacent products

| Product | What users/value signals show | What LinePay should learn | What LinePay should avoid |
|---|---|---|---|
| **LineVault** | Lineman-specific REG/OT1/OT2, per diem, meal tickets, mileage, goals, history; $9.99/month; users explicitly value multiple rates and catching short pay | trade vocabulary matters; specialized pay structures can justify professional-tool pricing | account creation and identity-linked data are unnecessary for our core loop; generic rate buckets are not enough for agreement-aware auditing |
| **ShiftWallet** | one-tap shifts, cross-midnight, break tracking, premiums, local math, line-by-line paycheck verifier, scanner, historical rate preservation | verifier is now table stakes; breaks and rate changes need historical correctness; scanning must have clear fallbacks | feature sprawl, tax calculators, AI chat, dashboards, multi-platform breadth before LinePay nails its niche |
| **TechPay Audit** | another trade-specific product already uses source facts -> pay rules -> confirmed statement fields -> explainable audit | evidence-first reconciliation is a viable product shape; preserve payment/reissue history and evidence levels | genericizing into every trade; LinePay should remain linework-specific |
| **Work Log** | 4.8 rating / thousands of ratings; Quick Shifts, custom pay periods, per-diem-by-day, easy navigation; reviews praise exact records for employer disputes | repeat/copy is high leverage; pay periods must match reality; per diem needs day-level control; simplicity wins | forcing paid guarantees into fake worked hours; one reviewer works 7h but is guaranteed 10h and the generic model cannot represent this cleanly |
| **HoursTracker** | mature product; users value easy setup, adaptive defaults, copy entries, pay-period view, records used to check employer errors | smart defaults and reuse matter more than fancy entry UI; pay-period context should always be visible | location automation, web accounts, analytics breadth, and deep customization are not needed for 1.0 |
| **Supershift** | 4.9 rating; no account, no internet, instant use; shift-worker-specific; strong widgets/watch ecosystem | offline/no-account is itself a product benefit; shift workers reward calm reliability | calendar/rota planning is not our job in 1.0 |
| **Paycheck & OT Estimator** | high-overtime worker positioning including linemen; very low price; tracks pay-period hours and forecasts taxes/refund | high-overtime positioning is validated | competing on tax forecasting or commodity-calculator pricing |
| **WageWatch** | explicit paycheck discrepancy/wage-theft positioning plus legal-help funnel | demand exists for detecting underpayment | legal-adjudication language, fear marketing, collecting identity/financial data, or turning LinePay into a law-firm lead funnel |
| **U.S. DOL Timesheet / WorkWise** | authoritative but intentionally simple 40h/1.5x calculations and known limitations | unsupported cases should be stated honestly | pretending federal generic overtime logic covers lineworker agreements |

### 3.2 Research-derived product rules

1. **Fast reuse beats repeated form filling.** Add `Repeat last shift` / recent shift presets after the first successful entry.
2. **Never mutate worked facts to represent guaranteed pay.** If a worker worked 7 hours but a callout minimum pays 10, store 7 hours of work and derive the additional entitlement separately.
3. **Pay-period context is a first-class navigation concept.** Workers think in checks, not abstract date ranges.
4. **Breaks need explicit semantics.** 1.0 supports unpaid break duration as a work fact; do not silently infer meal penalties or agreement entitlements.
5. **Rate/rule changes never rewrite history.** Existing agreement snapshots already point in the right direction.
6. **Manual entry must always exist beside scanning.** OCR is convenience, not a gate.
7. **Verification must be neutral.** Outcomes include `Matches`, `Possible shortfall`, `Possible overpayment`, and `Needs review`; never force every difference into a theft narrative.
8. **Offline and no-account are differentiators.** Make them visible at the moments where trust matters, not as decorative badges everywhere.
9. **Evidence depth is LinePay's moat.** A line can open from amount -> calculation -> rule -> source -> original paystub field.
10. **Do not chase watch/widgets before the core audit is extraordinary.** They are strong post-1.0 candidates after daily logging retention is proven.

### Research sources

- LineVault: https://apps.apple.com/us/app/linevault/id6764867679
- ShiftWallet: https://apps.apple.com/us/app/shiftwallet-hours-paycheck/id6761481192
- TechPay Audit: https://apps.apple.com/us/app/techpay-audit/id6800600726
- Work Log: https://apps.apple.com/us/app/work-log-shift-tracker/id1578126960
- HoursTracker: https://apps.apple.com/us/app/hours-tracker-time-tracking/id336456412
- Supershift: https://apps.apple.com/us/app/supershift-shift-calendar/id1104165041
- Paycheck & OT Estimator: https://apps.apple.com/us/app/paycheck-ot-estimator/id6755323596
- WageWatch: https://apps.apple.com/us/app/wagewatch-app/id6744068979
- U.S. DOL Timesheet / WorkWise: https://apps.apple.com/us/app/dol-timesheet/id433638193

---

## 4. Definition of 1.0

A worker can:

1. open LinePay and begin without an account;
2. create one active pay profile and explicitly confirm the rules that apply;
3. define a real weekly, biweekly, or custom pay period;
4. record real work intervals including overnight work, callouts, notes, and unpaid breaks;
5. repeat a recent shift with one action and edit only what changed;
6. see expected gross pay calculated by `LinePayDomain` immediately;
7. inspect an auditable Pay Ledger explaining every component;
8. scan/import a paystub locally **or enter paystub facts manually**;
9. confirm OCR-extracted facts before they become trusted facts;
10. compare confirmed paid values with expected values;
11. see a neutral audit verdict: match, possible shortfall, possible overpayment, or needs review;
12. drill from every discrepancy to work facts, rule logic, source reference, and paystub evidence;
13. retain immutable completed pay periods locally;
14. export a worker-controlled reconciliation summary;
15. complete the **first full paycheck audit free**;
16. optionally subscribe to LinePay Pro for future audits and premium history/export features.

1.0 is complete when this loop is trustworthy and fast enough to repeat every payday, not when every conceivable agreement has been encoded.

---

## 5. Non-goals

Do not turn 1.0 into:

- payroll software;
- legal advice or wage-law adjudication;
- a union-management system;
- employer dashboards;
- social/community features;
- budgeting;
- tax filing or take-home-tax forecasting;
- GPS/geofence employee tracking;
- shift rota/calendar planning;
- AI chat;
- autonomous authoritative CBA interpretation;
- a cloud account system;
- a remote agreement marketplace;
- multi-job/project management;
- Apple Watch / widgets / Live Activities;
- Android implementation;
- an elaborate design-system framework.

When forced to choose, improve **calculation trust, entry speed, evidence, recovery, and repeat payday usage** before adding breadth.

---

## 6. The three loops

### Loop A — set up once

```text
Welcome -> Pay basics -> Pay period -> Optional rules -> Confirm summary
```

Goal: get to the first usable rule snapshot with minimal cognitive load.

Rules are progressively disclosed. Do not present a giant payroll configuration form on first launch.

### Loop B — repeat after work

```text
Today -> Repeat last / Add work -> Confirm -> Expected pay updates
```

Target: a familiar shift should be recordable in **under 10 seconds** once setup exists.

### Loop C — payday

```text
Pay -> Scan/import/manual -> Confirm paystub facts -> Audit -> Explain gap -> Archive
```

Target: after OCR, the worker should understand the top-level result in **under 5 seconds** and be able to prove where it came from.

---

## 7. Main navigation

Use four native destinations.

### Today

The fastest operational surface, not a dashboard.

Show:

- current pay-period dates;
- expected gross to date as the one focal amount;
- hours logged;
- audit/payday state in one concise line;
- `Repeat last shift` when a recent entry exists;
- primary `Add work` action;
- today/recent work entries;
- direct edit/delete through native interactions.

Do not show charts, goals, motivational copy, or a card grid.

### Pay

LinePay's signature surface.

Before paycheck:

- expected gross;
- total worked hours;
- Pay Ledger;
- agreement snapshot/version;
- `Check paycheck` primary action.

After paycheck:

- Expected / Paid / Difference relationship;
- neutral verdict;
- discrepancy lines;
- Pay Ledger below;
- source/evidence access.

### History

Completed pay periods as a ledger of trust:

- dates;
- expected amount;
- confirmed paid amount when available;
- difference;
- status;
- immutable snapshot used;
- export/share.

No analytics dashboard in 1.0.

### Settings

Only settings that matter:

- Pay profile;
- Pay period;
- Rule sources;
- LinePay Pro / Restore Purchases;
- Privacy & local data;
- Export data;
- About / legal.

Avoid a junk drawer of cosmetic toggles.

---

## 8. Canonical state model

The UI should be driven by explicit product states instead of loosely scattered booleans.

### Setup state

- `notStarted`
- `rulesNeedConfirmation`
- `ready`
- `unsupportedRulePresent`

### Current pay-period state

- `empty`
- `workLogged`
- `readyForPaystub`
- `paystubNeedsConfirmation`
- `audited`
- `archived`

### Audit verdict

- `matches`
- `possibleShortfall`
- `possibleOverpayment`
- `needsReview`
- `notComparable`

### Subscription state

- `freeAuditAvailable`
- `freeAuditConsumed`
- `proActive`
- `billingGrace`
- `expired`
- `storeUnavailable`

The same state should render consistently across Today, Pay, History, and Settings.

---

## 9. Feature plan

### F1. First-run trust — P0

First launch contains one strong promise and one action.

```text
Know what your work should pay.

LinePay uses the work and pay rules you confirm to estimate your check.
Your pay data stays on this iPhone.

[ Set up my pay ]
[ Try a sample pay period ]   P1 / validation-only if kept
```

Requirements:

- no account;
- no permission prompts;
- no subscription paywall;
- no carousel;
- no generated worker illustration;
- no legal-entitlement claim;
- visible but restrained local-first privacy statement.

**Production rule, revised September 5, 2026:** follow `docs/product/onboarding.md`: show an optional seven-day annual trial offer after the first real expected-pay result has been read, with Monthly and Continue free available. No paywall on welcome or before meaningful proof. This deliberately supersedes the earlier prohibition on all onboarding offers; implementing the new flow remains a release task.

### F2. Pay-profile setup — P0

Onboarding is progressive, not one giant editor.

#### Step 1 — Pay basics

- profile display name, default `My current pay`;
- base hourly rate;
- currency, USD fixed in UI for U.S. 1.0 while domain remains currency-aware;
- work/payroll timezone, default current timezone but explicit and editable.

#### Step 2 — Pay period

- weekly;
- biweekly;
- custom current start/end;
- anchor date / next boundary where needed.

Show an example current period before confirmation.

#### Step 3 — Optional agreement rules

Off by default:

- daily overtime tiers;
- outside-schedule premium;
- weekday/Sunday premiums;
- date/holiday premium;
- callout minimum;
- flat per diem;
- effective dates;
- optional source title/URL/section.

Group common rules first and tuck advanced details behind disclosure.

#### Step 4 — Confirm summary

Show exactly what LinePay will calculate, in plain English:

```text
Base rate                    $58.00/hr
After 8 worked hours         1.5x
Sunday                       2.0x
Callout minimum              4 paid hours
Per diem                     $125 / worked day
Timezone                     America/Chicago
```

CTA: `Use these rules`.

Important:

- optional rules start disabled;
- `I don't see my rule` is visible and leads to an unsupported-rule explanation, not a guess;
- saving a material change creates a new `AgreementSnapshot`;
- historical periods retain the prior snapshot;
- setup language is confirmation language, not CBA interpretation.

### F3. Pay-period model — P0

Support:

- weekly;
- biweekly;
- manually selected start/end dates.

Requirements:

- current period is visible on Today and Pay;
- next/previous period navigation is obvious on History/details, not on Today;
- changing cadence affects future periods only;
- current period can be manually corrected without rewriting archived history;
- period closing is explicit when an audit is archived.

### F4. Work logging — P0

A work record captures:

- stable ID;
- start instant;
- end instant;
- relevant timezone;
- kind: regular / callout / other;
- **unpaid break duration**, default 0;
- optional note;
- optional source context text such as `Storm - Tulsa` if useful, not used for calculation in 1.0.

#### Interaction requirements

- default start/end should reflect the user's recent pattern where safe;
- `Repeat last shift` copies the prior work facts into an editable draft;
- recent presets are derived locally from user history, not cloud templates;
- overnight work is represented by real dates/times;
- overlapping intervals are blocked and explained before save;
- editing never silently moves another field to preserve duration;
- deleting supports immediate Undo where practical;
- no GPS requirement;
- primary touch targets 48–56 pt where practical.

#### Work facts vs entitlements

Never make the worker enter fictional hours to represent a guarantee.

Example:

```text
Actual callout work          2.0 h
Callout minimum rule         4.0 paid h
Derived guarantee            +2.0 paid h equivalent
```

The Pay Ledger explains the entitlement. The work log remains factual.

### F5. Expected-pay calculation — P0

Use pure `LinePayDomain.PayCalculator`.

Required 1.0 coverage:

- regular scheduled hours;
- unpaid break deduction from actual worked duration;
- outside-schedule premium;
- weekday premiums;
- date premiums;
- daily OT tiers;
- callout minimum guarantees;
- flat per diem;
- explicit rounding;
- timezone/day boundaries;
- agreement effective dates.

Every result is reproducible from source work facts plus exact agreement snapshot/version.

Unsupported combinations fail visibly rather than approximate silently.

### F6. Pay Ledger — P0

This is LinePay's signature UI and should receive disproportionate craft.

Header:

- pay period;
- expected gross;
- total worked hours;
- pay profile/rule version.

Ledger groups by real work date.

Each row shows:

- category;
- worked/paid hours where meaningful;
- rate/multiplier where meaningful;
- amount;
- concise reason.

Example:

```text
Mon, Sep 7
Regular              8.0 h x $58.00        $464.00
Overtime              4.0 h x $58 x 1.5     $348.00
Callout minimum       +2.0 paid-hour equiv   $116.00
  Rule 7.4 - 4h minimum
Per diem                                      $125.00
```

Interaction:

- rows remain scannable when collapsed;
- tap a derived line for `Why this amount?`;
- detail shows Work Facts -> Applied Rule -> Calculation -> Source;
- raw worked hours remain distinct from paid-equivalent guarantees;
- monospaced digits for aligned money/hours;
- no donut charts, gauges, score rings, or arbitrary category colors.

### F7. Rule detail / evidence — P0

Every derived amount has an evidence path.

`Why this amount?` shows:

1. facts used;
2. rule applied;
3. arithmetic;
4. agreement snapshot/version;
5. source title/section/URL if present;
6. confirmation status.

If a rule was manually entered without a source, say:

`Rule confirmed by you - no source attached.`

Never fabricate authority.

### F8. Paystub acquisition — P0

Entry points:

- `Scan paystub` using VisionKit;
- `Choose photo`;
- `Choose PDF/file`;
- **`Enter manually`**.

Manual entry is always available on the first chooser. Do not bury it as an error fallback.

Requirements:

- on-device OCR by default;
- original source remains evidence until explicitly deleted;
- no upload to LinePay server;
- source can be removed without deleting the worker's confirmed facts only after an explicit explanation;
- scanner cancellation returns safely to Pay.

### F9. OCR review — P0

OCR produces suggestions, never truth.

Initial extracted facts:

- pay-period start/end;
- gross pay;
- regular hours/pay when identifiable;
- overtime/premium hours/pay when identifiable;
- double-time lines when identifiable;
- per diem/allowance when identifiable.

Review screen:

- `Ready` fields need ordinary confirmation;
- `Check` fields are visually emphasized with reason/confidence;
- tapping a field shows the corresponding source crop/page;
- editing is faster than rescanning;
- a worker can continue with only the minimum confirmed fields needed for a top-level comparison.

Do not block a whole audit because one nonessential line is unreadable. Degrade the verdict to `Needs review` where appropriate.

### F10. Reconciliation — P0

Top-level relationship:

```text
EXPECTED        PAID
$7,421.80    $6,968.20

POSSIBLE DIFFERENCE
-$453.60
```

Then render a neutral verdict.

#### Verdict: Matches

`Confirmed paystub facts match LinePay's expected total within the configured comparison tolerance.`

No confetti.

#### Verdict: Possible shortfall

Show the total possible shortfall plus the 1–3 strongest explainable reasons.

#### Verdict: Possible overpayment

Show it neutrally. Do not color it celebratory green by arithmetic sign alone.

#### Verdict: Needs review

Used when material source fields are missing, uncertain, or cannot be mapped confidently.

#### Component reconciliation

For each difference show:

1. expected component;
2. confirmed paystub component;
3. difference;
4. work facts;
5. rule/calculation;
6. paystub source field;
7. evidence/confirmation level;
8. plain next action: `Check this line on your paystub or with payroll.`

Never convert a difference into `employer owes you` language.

### F11. The Line Gap audit visualization — P0

Use the signature motif functionally at the top of an audited period:

```text
EXPECTED  ----------------|   |-----------  PAID
                           gap
```

Rules:

- only appears when two real values are being compared;
- gap magnitude need not be geometrically proportional if doing so harms legibility, but numeric difference is always explicit;
- no animated alarm effect;
- `Matches` collapses the gap rather than celebrating.

### F12. Local persistence — P0 before external beta

Use SwiftData as an adapter only after the model is explicit.

Requirements:

- explicit versioned schema from first external beta;
- stable IDs independent of persistence identity;
- migration fixtures/tests;
- appropriate file protection;
- no wage/paystub content in logs;
- recoverable writes for current pay period;
- source documents stored separately from structured facts where practical.

Persist:

- pay profile / agreement snapshots;
- pay-period definitions and lifecycle;
- work facts including breaks;
- calculation snapshots;
- paystub source metadata;
- OCR suggestions if needed for recovery;
- confirmed paystub facts;
- reconciliation snapshots;
- first-free-audit entitlement state;
- preferences.

Historical meaning must survive rule edits, app restarts, migrations, and rate changes.

### F13. History — P0

History is a compact list, not analytics.

Row:

```text
Aug 24 - Sep 6          Possible shortfall
Expected $7,421.80              -$453.60
Paid     $6,968.20
```

Statuses:

- Not audited;
- Matches;
- Possible shortfall;
- Possible overpayment;
- Needs review.

Opening a period shows the frozen historical audit and source/rule version used at the time.

### F14. Archive / close pay period — P0

After an audit, CTA: `Finish this pay period`.

Before closing:

- show final expected/paid/difference;
- confirm source facts are reviewed;
- allow `Keep open`;
- archive creates/finalizes the immutable snapshot.

Do not auto-close merely because calendar dates passed.

### F15. StoreKit / LinePay Pro — P0 before App Store release

Canonical pricing lives in `docs/product/pricing.md`.

Launch structure:

**Free**

- one active pay profile;
- work logging;
- expected-pay calculation;
- Pay Ledger;
- **first complete paycheck audit free**.

**Pro**

- future/unlimited paycheck audits;
- on-device OCR/reconciliation;
- extended audit history;
- export/reporting;
- advanced verified rule packs when available.

Launch pricing hypothesis:

- `$9.99/month`;
- `$79.99/year`, recommended.
- eligible annual subscribers receive a seven-day introductory free trial; monthly starts paid immediately.

#### Paywall timing

Use the proof-first trial flow in `docs/product/onboarding.md`.

Preferred triggers:

1. after the first real expected-pay result, as an optional seven-day annual trial offer;
2. after the first free audit result, as an optional contextual continuation offer; or
3. when the user starts a second new audit after the Free audit is consumed.

Dismissal preserves work and completed results. Suppress unsolicited repeats for the session. An active verified Pro trial grants recurring access without consuming an unused Free audit; expiry follows the access rules in `docs/product/onboarding.md`.

Paywall must preserve:

- Restore Purchases;
- StoreKit renewal/expiration/grace handling;
- privacy statement;
- no fake urgency;
- no backend/account requirement.

### F16. Export/share — P1 but desirable for 1.0

Generate a concise PDF and/or CSV selected by the worker.

Audit PDF includes:

- pay period;
- expected and confirmed paid totals;
- difference/verdict;
- ledger components;
- discrepancy explanations;
- rule/source references;
- creation timestamp;
- estimation/reconciliation disclaimer.

Do not include original paystub pages unless the worker explicitly selects that option.

### F17. Privacy & data controls — P0

Settings must explain concretely:

> Your paycheck stays on your iPhone. No LinePay account. No employer connection. No paystub upload to a LinePay server.

Controls:

- delete source paystub;
- delete a pay period;
- export worker-owned data;
- delete all LinePay data;
- explain future iCloud/network use if ever introduced.

No trust badges or `military-grade` copy.

### F18. Accessibility / field usability — P0

From first screen:

- Dynamic Type;
- VoiceOver semantics;
- Bold Text;
- Increase Contrast;
- Reduce Motion / Reduce Transparency;
- >=44 pt targets, 48–56 preferred for frequent actions;
- no color-only status;
- daylight contrast;
- important numeric values read coherently by VoiceOver;
- rows may grow/stack instead of clipping;
- haptics only for meaningful save/confirm/audit completion.

### F19. Failure and recovery — P0

Explicitly handle:

- invalid time range;
- overlapping work intervals;
- unpaid break >= interval duration;
- work outside rule effective dates;
- unsupported rule combination;
- invalid/missing timezone;
- OCR unable to identify fields;
- partial/low-confidence scan;
- imported file unavailable;
- corrupted/migration-failed local record;
- StoreKit unavailable;
- document access cancelled;
- interrupted scan/review;
- app killed while current pay period is being edited.

Never destroy original evidence because parsing failed.

Where safe, preserve draft input so recovery means `continue`, not `start over`.

### F20. Sample/demo data — P1 validation tool

A synthetic `Try a sample pay period` flow can be retained for screenshots, demos, and usability testing if it remains clearly marked `Sample` and can be reset instantly.

Never mix synthetic sample records into real History.

---

## 10. Screen inventory

`docs/plan/mockups.md` is the canonical ASCII interaction reference for these screens and states.

### Onboarding/setup

1. Welcome
2. Pay basics
3. Pay period setup
4. Optional rules
5. Confirm pay rules
6. Unsupported rule explanation

### Today/work capture

7. Today - empty
8. Today - active period
9. Add work
10. Repeat last shift / quick draft
11. Edit work
12. Work validation error
13. Delete + Undo state

### Pay / expected calculation

14. Pay - no work
15. Pay - expected ledger
16. Ledger component detail / Why this amount?
17. Rule source detail

### Paystub acquisition/review

18. Check paycheck source chooser
19. System document scanner handoff reference
20. OCR review
21. OCR field/source detail
22. Manual paystub entry
23. Incomplete evidence / needs confirmation

### Audit

24. Audit - Matches
25. Audit - Possible shortfall
26. Audit - Possible overpayment
27. Audit - Needs review
28. Discrepancy detail
29. Paystub evidence viewer
30. Finish pay period

### History

31. History - empty
32. History - list
33. Historical period detail

### Monetization

34. Post-first-audit Pro offer
35. Second-audit paywall
36. Store unavailable / restore result state

### Settings/data

37. Settings
38. Pay profile summary
39. Edit pay rules
40. Pay period settings
41. Rule sources
42. Privacy & local data
43. Export data
44. Delete all data confirmation
45. About / legal

### Recovery

46. Local data recovery screen

Native iOS system sheets such as photo picker, file picker, document scanner camera UI, StoreKit purchase sheet, and share sheet should remain system-owned. Mockups show our handoff/context, not custom replicas.

---

## 11. Architecture for 1.0

```text
SwiftUI Features
      |
      v
@MainActor application state / use cases
      |
      v
LinePayDomain
  pure work facts + calculation + reconciliation
      ^
      |
Adapters
  SwiftData | Vision/VisionKit | StoreKit | files/export
```

### Rules

- `LinePayDomain` remains UI/persistence/network-free;
- feature views do not construct payroll algorithms;
- domain types are not annotated with `@Model`;
- UI uses semantic design tokens;
- external frameworks enter through narrow adapters;
- no generic service locator/event bus/DI framework;
- work facts and pay entitlements are distinct concepts;
- OCR suggestions and confirmed paystub facts are distinct concepts;
- archived calculations reference immutable agreement snapshots.

---

## 12. Implementation sequence

### Slice A — calculation UI foundation **IMPLEMENTED, needs product hardening**

Already present in the repository:

- [x] deterministic domain calculator foundation;
- [x] domain tests for money/rules/reconciliation foundation;
- [x] semantic iOS design tokens foundation;
- [x] application state layer foundation;
- [x] pay-profile setup foundation;
- [x] add/edit/delete work interval;
- [x] Today screen foundation;
- [x] live expected-pay calculation;
- [x] Pay Ledger foundation;
- [x] Settings/navigation foundation;
- [x] strict formatter/test/build CI.

Hardening required before calling Slice A done:

- [ ] replace giant setup form feeling with progressive setup + confirmation summary;
- [ ] add pay-period model to visible UI;
- [ ] add unpaid-break fact support;
- [ ] add `Repeat last shift`;
- [ ] preserve drafts on recoverable failures;
- [ ] separate actual work from minimum/guaranteed paid entitlements visibly;
- [ ] add the proof-first optional annual trial offer after the first real expected-pay result;
- [ ] complete accessibility pass for current screens;
- [ ] update screens to match `mockups.md` hierarchy.

Exit condition: a tester can set rules, log a familiar shift in seconds, and explain the expected total without help.

### Slice B — persistence + pay-period lifecycle

- [ ] explicit SwiftData v1 schema;
- [ ] migration fixtures/tests;
- [ ] pay-period cadence and current-period lifecycle;
- [ ] restart-safe profile/work/drafts;
- [ ] immutable agreement snapshot references;
- [ ] History foundation;
- [ ] archive/close period flow;
- [ ] data protection / recovery path.

Exit condition: real beta data survives relaunches, rule edits, and app upgrades without changing historical meaning.

### Slice C — paystub evidence

- [ ] source chooser;
- [ ] VisionKit scan;
- [ ] photo/PDF import;
- [ ] manual entry fallback;
- [ ] local OCR adapter;
- [ ] OCR suggestion vs confirmed fact model;
- [ ] uncertainty review UI;
- [ ] source crop/page viewer;
- [ ] source delete behavior.

Exit condition: worker can safely produce confirmed structured paystub facts without a backend and without trusting unreadable OCR.

### Slice D — reconciliation, the wow slice

- [ ] audit verdict state machine;
- [ ] expected/paid/difference hero;
- [ ] Line Gap comparison;
- [ ] component mapping;
- [ ] match / shortfall / overpayment / review states;
- [ ] discrepancy detail;
- [ ] rule + paystub evidence drill-down;
- [ ] historical reconciliation snapshot;
- [ ] finish/archive flow.

Exit condition: a tester understands the result in <5 seconds and can explain every material difference from evidence.

### Slice E — monetization + export

- [ ] first-free-audit entitlement;
- [ ] implement proof-first annual trial placement, eligibility-aware terms, and Continue free;
- [ ] StoreKit 2 entitlement adapter;
- [ ] local StoreKit config/tests;
- [ ] yearly/monthly offer according to `docs/product/pricing.md`;
- [ ] restore/renewal/grace/expiration states;
- [ ] PDF/CSV audit report;
- [ ] native share sheet.

Exit condition: payment never blocks the first value moment, and losing StoreKit never corrupts pay data.

### Slice F — release hardening

- [ ] privacy manifest review;
- [ ] Accessibility Inspector + VoiceOver/Dynamic Type audit;
- [ ] daylight/low-light real-device visual review;
- [ ] localization-ready strings;
- [ ] migration/data-loss tests;
- [ ] interrupted-OCR/recovery tests;
- [ ] TestFlight checklist;
- [ ] App Store screenshots/privacy copy;
- [ ] performance/memory review for long histories/scans;
- [ ] remove debug-only onboarding/paywall/sample behavior from production paths;
- [ ] lineman usability test with real pay periods/paystubs where users consent and data stays private.

---

## 13. Performance targets

These are product budgets, not premature micro-benchmarks.

- cold launch to usable local screen: feels immediate on supported devices;
- Today scrolling/editing: no visible jank;
- save work -> updated expected amount: perceived immediate, target <100 ms for ordinary period size;
- open Pay Ledger: perceived immediate for a normal pay period;
- local OCR: progressive feedback, never freezes UI;
- audit calculation after facts confirmed: perceived immediate;
- no network dependency on launch or core calculation;
- ordinary pay period calculations should not require loading historical source documents into memory.

Measure before optimizing beyond these goals.

---

## 14. Insanely-great interaction budgets

### First setup

- no more than one conceptual decision per section;
- worker can skip every optional rule they do not use;
- final rule summary fits on one normal scroll;
- no subscription decision.

### Familiar shift

- Today -> Repeat last -> Save can be 2–3 taps if nothing changed;
- manual Add Work has sensible defaults;
- editing one field never unexpectedly mutates another.

### Payday

- `Check paycheck` is obvious;
- manual entry is one tap away from scan/import;
- worker never has to wonder whether OCR is trusted;
- top-level verdict visible without scrolling on common iPhone sizes where practical;
- strongest discrepancy reason appears immediately below result.

### Explanation

No material number is a dead end. Tapping it either explains it or clearly says it is a confirmed source fact.

---

## 15. Release gates

Do not ship 1.0 until:

### Correctness

- all money/rule regressions have deterministic tests;
- no known calculation silently approximates an unsupported rule;
- breaks/callout guarantees preserve actual-work truth;
- historical calculations remain immutable in meaning;
- timezone/DST/cross-midnight boundaries are tested;
- OCR uncertain material fields require review.

### Product quality

- familiar shift logging is genuinely fast;
- workers do not have to invent fake hours to get correct guarantees;
- the Pay Ledger is understandable without tutorial copy;
- first-time users understand why a number exists;
- the audit verdict is clear in under five seconds in usability testing;
- every discrepancy has an evidence path;
- no production paywall appears before the first real expected-pay proof; trial offer is optional with clear renewal terms;
- the first free audit can be completed end-to-end without account creation.

### Privacy/reliability

- no wage/paystub content leaves the device without explicit user action and disclosure;
- persistence migrations have fixtures;
- interrupted edits/scans recover safely;
- StoreKit failure never blocks access to worker-owned historical data;
- deleting source evidence is explicit and scoped;
- `Delete all data` works and is clearly destructive.

### Accessibility/craft

- VoiceOver, Dynamic Type, Bold Text, Increase Contrast, Reduce Motion are reviewed;
- sunlight/night contrast reviewed on a real device;
- tap targets meet the field-use standard;
- no critical state depends only on color;
- no screen smells like a generic AI/finance dashboard;
- the product visually follows `DESIGN.md`.

### Real-user evidence

Before 1.0 public release, at minimum:

- a small set of actual linemen can complete setup without hand-holding;
- they can log several realistic shifts including callout/OT scenarios;
- they can audit a real or faithfully anonymized paystub;
- they can explain a flagged difference back to us in their own words;
- at least some users voluntarily return for another pay period.

---

## 16. Post-1.0 candidates, only after evidence

Potentially valuable, but intentionally outside the 1.0 critical path:

- iCloud private sync;
- encrypted backup/import;
- Home/Lock Screen widgets;
- Live Activity for active shift;
- Apple Watch quick logging;
- Siri/App Intents shortcuts;
- verified agreement packs downloaded as signed data;
- multiple active pay profiles/jobs;
- richer travel/mileage/meal-ticket facts;
- photo/note attachments to work entries;
- Android native client;
- cross-platform sync requiring a backend only if real demand proves it.

Do not promote these merely because competitors have them.

---

## 17. Product principle for every scope decision

Ask three questions:

> **Does this make it faster or safer for a worker to turn real work facts into a trusted pay expectation?**
>
> **Does this make the paycheck audit easier to understand or prove?**
>
> **Is there a materially simpler way to get almost all of the value?**

If the first two are no, it probably does not belong in 1.0.

If the third is yes, choose the simpler path and spend the saved complexity making the critical interaction insanely great.

## Payroll correctness completion contract

Use [ADR 0005](../adr/0005-effective-dated-rules-and-audit-scope.md) for prospective-versus-correction behavior, effective-dated snapshots, schema-1 migration, explicit guarantee ambiguity, and the single scoped audit verdict. The two original known-issue tests are replaced by ordinary regression tests. The default new rate starts at the next period boundary; editing requires an expected-pay preview and confirmation.

Acceptance requires native CI and the real `rule-scope` / `audit-scope` Maestro journeys, with archived/PDF/backup consistency tested below the UI. This addition does not mark unrelated feature, device, commerce, or 46-screen release checks complete.
