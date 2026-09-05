# LinePay iOS 1.0

Status: **Active implementation plan**

Canonical bundle ID: **`com.streamentry.linepay`**

This plan is governed by `AGENTS.md` and `DESIGN.md`.

## Product promise

LinePay 1.0 should let a lineworker answer one repeated question with confidence:

> **Given the work I actually performed and the pay rules I confirmed, what gross pay should I expect, and where might my paystub differ?**

No account. No employer integration. No LinePay backend required for the core product. Wage and paystub data remain device-local by default.

---

## 1. Definition of 1.0

A worker can:

1. create a pay profile and explicitly confirm the rules that apply to them;
2. record work intervals, including overnight work and callouts;
3. see expected gross pay calculated by `LinePayDomain`;
4. inspect an auditable Pay Ledger explaining every component;
5. scan or import a paystub locally;
6. confirm OCR-extracted facts before they are trusted;
7. compare confirmed paid values with expected values;
8. inspect possible discrepancies and the rule/work evidence behind them;
9. retain completed pay periods locally;
10. export a worker-controlled reconciliation summary;
11. optionally subscribe to LinePay Pro for premium audit/history features.

1.0 is complete when this loop is trustworthy and fast enough to repeat every payday, not when every conceivable union rule has been encoded.

---

## 2. Non-goals

Do not turn 1.0 into:

- payroll software;
- legal advice;
- a union-management system;
- employer dashboards;
- a social network;
- generic budgeting;
- tax filing or detailed net-pay prediction;
- GPS employee tracking;
- AI chat;
- autonomous authoritative CBA interpretation;
- a cloud account system;
- a large remote agreement marketplace;
- Android implementation;
- an elaborate design-system framework.

When forced to choose, improve **calculation trust, evidence, speed, and repeat usage** before adding breadth.

---

## 3. Main navigation

Use four native destinations.

### Today

The fastest operational surface.

- current pay period;
- expected gross to date;
- hours logged;
- today/recent work intervals;
- primary `Add work` action;
- status of the current audit: rules ready / stub pending / audit complete.

No generic dashboard card grid.

### Pay

LinePay's core surface.

- expected gross pay;
- total hours;
- Pay Ledger grouped by date/component;
- multiplier and category detail;
- explanation for each line;
- profile/agreement snapshot used;
- scan/import paystub action;
- expected vs paid reconciliation.

### History

- completed pay periods;
- expected total;
- confirmed paid total when available;
- discrepancy status;
- immutable historical calculation details;
- export/share.

### Settings

- pay profile and current rules;
- pay-period cadence;
- timezone;
- rule sources/effective dates;
- subscription and restore purchases;
- local data export/delete;
- privacy/about/legal.

---

## 4. Feature plan

### F1. First-run trust + setup — P0

First launch should establish value without a marketing carousel.

1. `Know what your work should pay.`
2. explain that calculations come from rules the worker confirms;
3. explain local-first privacy;
4. create the first pay profile.

Rules:

- no account;
- no permission prompts until the relevant action;
- no generated worker illustration;
- no claims of legal entitlement;
- onboarding remains available from Settings.

### F2. Pay profile / rule setup — P0

A user-facing pay profile produces a versioned `AgreementSnapshot`.

1.0 rule editor supports:

- profile name;
- currency, US launch initially USD while domain remains currency-aware;
- base hourly rate;
- payroll/work timezone;
- regular schedule windows;
- outside-schedule multiplier;
- weekday premium rules;
- date/holiday premium rules;
- daily overtime tiers;
- callout minimum hours;
- flat per-diem amount;
- effective dates;
- optional source title/URL/section.

Important:

- optional rules start disabled rather than silently assuming a worker's agreement;
- saving a material rule change creates a new rule snapshot for future calculations;
- historical results keep their original version;
- unsupported rules are surfaced as unsupported rather than approximated.

### F3. Pay-period model — P0

Support:

- weekly;
- biweekly;
- manually selected start/end dates.

Changing future cadence must never reinterpret historical pay periods.

### F4. Work logging — P0

A work record captures:

- start instant;
- end instant;
- relevant timezone;
- kind: regular / callout / other;
- optional note;
- stable ID.

UX:

- defaults may reduce typing but never invent payroll meaning;
- overnight work is explicit;
- overlapping intervals are blocked/explained;
- edit/delete is easy;
- frequent controls target 48–56 pt where practical;
- no GPS requirement.

### F5. Expected-pay calculation — P0

Use the pure `LinePayDomain.PayCalculator`.

Current domain coverage includes:

- regular scheduled hours;
- outside-schedule premium;
- weekday premiums;
- date premiums;
- daily OT tiers;
- callout minimum guarantees;
- flat per diem;
- explicit rounding;
- timezone/day boundaries;
- agreement effective dates.

Every result must remain reproducible from source work facts plus exact agreement snapshot/version.

### F6. Pay Ledger — P0

This is LinePay's signature UI.

Header:

- pay period;
- expected gross;
- total hours;
- pay profile.

Ledger row:

- local date;
- category;
- hours when applicable;
- multiplier when applicable;
- amount;
- concise explanation.

Interaction:

- tap for calculation/rule detail;
- monospaced digits for aligned money/hours;
- rows and dividers rather than floating cards;
- empty state points directly to `Add work`.

Follow `DESIGN.md` Precision Industrial Minimalism and Line Gap rules.

### F7. Paystub scan/import — P0 before 1.0 release

Inputs:

- VisionKit document scanner;
- photo/library import;
- Files/PDF import.

Behavior:

- on-device OCR by default;
- original image/PDF remains evidence until deleted;
- raw OCR and confirmed structured facts are distinct;
- material uncertain fields show `Needs confirmation`;
- worker confirms values before reconciliation;
- OCR/AI output never becomes an authoritative pay rule.

Initial facts:

- pay-period dates;
- gross pay;
- regular hours/pay when identifiable;
- overtime/premium hours/pay when identifiable;
- double-time lines when identifiable;
- per diem/allowance lines when identifiable.

### F8. Reconciliation — P0

Primary relationship:

`EXPECTED  →  PAID  →  POSSIBLE DIFFERENCE`

For each discrepancy show:

1. expected value;
2. confirmed paystub value;
3. difference;
4. work facts involved;
5. applied rule/explanation;
6. what the worker should manually verify.

Use `possible discrepancy`, `expected`, and `estimated` language. Never silently turn an estimate into `you are legally owed`.

### F9. Local persistence — P0 before external beta data matters

Likely adapter: SwiftData, introduced only after app/domain boundaries are stable.

Requirements:

- explicit versioned schema from first external beta;
- persistence types remain adapters, not domain models;
- stable IDs independent of database identity;
- migration tests with representative fixtures;
- preserve source facts and immutable historical calculation snapshots;
- appropriate local file protection;
- no pay data in logs.

Likely persisted concepts:

- pay profile/rule snapshots;
- pay periods;
- work intervals;
- calculation snapshots;
- source document metadata;
- confirmed paystub facts;
- reconciliation snapshots;
- preferences.

### F10. History — P0

A completed pay period stores enough information to reproduce what the worker saw at the time.

Historical rows show:

- dates;
- expected amount;
- paid amount if confirmed;
- status: not audited / matches / possible discrepancy / review required.

### F11. StoreKit / LinePay Pro — P0 before App Store release

Keep entitlement logic behind a small protocol.

Candidate packaging for validation:

**Free**

- one pay profile;
- work logging;
- current-period expected-pay calculation;
- enough value to establish trust.

**Pro**

- paystub OCR/reconciliation;
- extended history;
- export/reporting;
- advanced verified rule presets/packs as they become available.

Commercial hypothesis: `$9.99/month` plus annual option. Pricing is not an architectural constant.

Must support restore, renewal, expiration, grace/billing retry, and local StoreKit configuration tests.

### F12. Export/share — P1

Generate a concise report selected by the worker:

- pay period;
- expected and confirmed paid totals;
- possible differences;
- ledger components;
- applicable rule/source references;
- disclaimer that LinePay is an estimation/reconciliation tool.

Do not include the original paystub unless the worker explicitly chooses it.

### F13. Privacy/data controls — P0

Settings must expose:

- what is stored locally;
- delete source paystub;
- delete a pay period;
- delete all local LinePay data;
- export worker-owned data;
- clear explanation of any future network use.

A backend or tracking SDK requires an ADR and privacy review.

### F14. Accessibility/field usability — P0

From first screen:

- Dynamic Type;
- VoiceOver semantics;
- >=44 pt touch targets, 48–56 pt preferred for frequent field actions;
- no status by color alone;
- strong daylight contrast;
- Reduce Motion / Reduce Transparency respected;
- no tiny gray secondary text as essential information;
- haptics only for meaningful confirmation/warning.

### F15. Failure/recovery — P0

Explicitly handle:

- invalid time range;
- overlapping work intervals;
- work outside rule effective dates;
- malformed/unsupported rule combination;
- OCR unable to identify values;
- partial/low-confidence scan;
- corrupted/migration-failed local record;
- StoreKit unavailable;
- user cancels document access.

Never destroy original evidence because parsing failed.

---

## 5. Architecture for 1.0

```text
SwiftUI Features
      ↓
@MainActor application model / use cases
      ↓
LinePayDomain
  pure calculation + reconciliation
      ↑
Adapters
  persistence | Vision | StoreKit | export
```

### Rules

- `LinePayDomain` stays UI/persistence/network-free;
- feature views do not construct complex payroll algorithms;
- domain types are not annotated with `@Model`;
- UI uses semantic design tokens, not random color literals;
- external frameworks enter through narrow adapters;
- no generic service locator/event bus/DI framework.

---

## 6. Implementation sequence

### Slice A — core value loop **IN PROGRESS**

Goal: usable end-to-end calculation without persistence.

- [x] deterministic domain calculator foundation;
- [x] domain tests for money/rules/reconciliation foundation;
- [ ] semantic iOS design tokens;
- [ ] application state/use-case layer;
- [ ] first pay-profile setup;
- [ ] add/edit/delete work interval;
- [ ] Today screen;
- [ ] live expected-pay calculation;
- [ ] Pay Ledger;
- [ ] Settings rule summary/editor entry point;
- [ ] formatter/build CI green.

Exit condition: a tester can launch, create rules, add work and understand the expected total without reading source code.

### Slice B — persistence

- [ ] versioned SwiftData adapter schema;
- [ ] migrations/fixtures;
- [ ] current pay period lifecycle;
- [ ] restart-safe profile/work records;
- [ ] History foundation.

Exit condition: beta data survives app upgrades and rule edits without changing historical meaning.

### Slice C — paystub evidence

- [ ] document/photo/PDF acquisition;
- [ ] local OCR adapter;
- [ ] parsed vs confirmed facts;
- [ ] uncertainty review UI;
- [ ] source evidence viewer/delete.

Exit condition: worker can safely produce confirmed structured paystub facts without a backend.

### Slice D — reconciliation

- [ ] expected vs paid summary;
- [ ] component mapping;
- [ ] possible discrepancy states;
- [ ] evidence/rule drill-down;
- [ ] historical reconciliation snapshots.

Exit condition: tester can explain every flagged difference and its evidence.

### Slice E — monetization + export

- [ ] StoreKit 2 entitlement adapter;
- [ ] StoreKit configuration/tests;
- [ ] paywall placed after demonstrated value;
- [ ] restore/renewal edge cases;
- [ ] PDF/shareable reconciliation report.

### Slice F — release hardening

- [ ] privacy manifest review;
- [ ] accessibility audit;
- [ ] localization-ready strings;
- [ ] migration/data-loss tests;
- [ ] TestFlight checklist;
- [ ] App Store screenshots/privacy copy;
- [ ] performance/memory review for large histories/scans;
- [ ] remove debug/sample data paths.

---

## 7. 1.0 release gates

Do not ship 1.0 until:

- all money/rule regressions have deterministic tests;
- no known calculation silently approximates an unsupported rule;
- historical calculations are immutable in meaning;
- OCR requires confirmation for uncertain material fields;
- no wage/paystub content leaves the device without explicit user action and disclosure;
- persistence migrations have fixture tests;
- StoreKit restore and entitlement transitions are tested;
- VoiceOver/Dynamic Type/daylight contrast are reviewed;
- crashes/data-loss bugs around current pay periods are resolved;
- user-facing discrepancy language remains estimation/reconciliation language;
- at least a small set of real linemen can complete the full flow without hand-holding.

---

## 8. Product principle for every scope decision

Ask:

> **Does this make it faster or safer for a worker to turn real work facts into a trusted, explainable pay expectation?**

If not, it probably does not belong in 1.0.
