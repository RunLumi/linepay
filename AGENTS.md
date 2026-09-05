# AGENTS.md — LinePay Engineering Contract

This file is authoritative for AI agents and contributors working in this repository.

## Mission

Build the smallest trustworthy product that helps a worker answer:

> Given the work I actually performed and the pay rules I explicitly selected or confirmed, what pay should I expect, and where might my paystub differ?

LinePay is a **calculation and reconciliation tool**, not payroll software, legal advice, a union authority, or an autonomous contract interpreter.

## Insanely great product standard

**The goal is not merely to ship LinePay. The goal is to make LinePay insanely great.**

“Insanely great” does not mean more features, more animation, more abstraction, or more code. It means the few things LinePay chooses to do feel unusually clear, trustworthy, fast, useful, and well-crafted.

A worker should be able to open LinePay and quickly feel:

- **this was built for my kind of work;**
- **this understands that my hours and pay rules can get complicated;**
- **I can trust where this number came from;**
- **I can use this without reading a manual;**
- **my private pay information is being treated with respect;**
- **this feels like a serious precision tool, not generic app-store software.**

The standard is not “technically correct and shipped.” The standard is **correct, obvious, calm, fast, distinctive, and satisfying**.

### Craft where it matters

Spend disproportionate care on the moments that define the product:

1. first launch and pay-rule setup;
2. recording or correcting work after a long shift;
3. seeing expected pay update;
4. scanning and confirming a paystub;
5. understanding a possible discrepancy;
6. tracing a number back to the exact work fact and rule;
7. recovering safely from mistakes, edits, migrations, or interrupted flows.

These moments deserve polish beyond the minimum viable implementation because they determine trust and word of mouth.

### Delight without decoration

LinePay should feel great because it removes uncertainty and friction, not because it is covered in visual effects.

Prefer delight from:

- an answer appearing exactly when needed;
- excellent defaults;
- fewer decisions;
- instant feedback;
- precise typography and spacing;
- clear money and hour presentation;
- excellent empty/error states;
- subtle, meaningful haptics and motion;
- fast correction of mistakes;
- explanations that make a complicated paycheck suddenly understandable.

Avoid manufactured delight:

- gratuitous gradients or glass;
- decorative dashboards;
- fake AI personality;
- sparkle icons and “AI magic” copy;
- excessive cards, pills, badges, charts, or celebration effects;
- animation that delays the worker;
- novelty that weakens clarity or trust.

Follow `DESIGN.md` for the visual/product design constitution.

### Ruthless quality bar

Before accepting user-facing work, ask:

> If a great independent iOS team obsessed over this exact flow for another week, what obvious rough edge would they remove?

Fix the highest-value rough edge now when it is cheap and materially improves trust, comprehension, speed, or feel.

Do not use this question to justify endless polishing of low-value surfaces. Quality work must still obey the Pareto operating principle below.

### Product taste is part of engineering

Agents are expected to exercise judgment, not merely satisfy literal acceptance criteria.

If an implementation is technically compliant but feels confusing, generic, slow, fragile, visually noisy, or inconsistent with the product identity, improve it before calling it done.

When two implementations are functionally equivalent, prefer the one that:

- removes a user decision;
- makes the correct action more obvious;
- exposes less implementation detail;
- reduces latency or perceived latency;
- improves explainability;
- creates a more coherent visual hierarchy;
- makes an error easier to recover from;
- feels more specific to linework and paycheck auditing;
- leaves less code and fewer states behind.

### Distinctive, not generic

LinePay must not drift into generic fintech, time-tracker, SaaS-dashboard, or AI-app aesthetics and behavior.

Its product identity is **precision industrial minimalism**: a calm, durable field instrument for expensive hours.

If the logo and product name were blurred, a key LinePay screen should still not look interchangeable with a crypto wallet, habit tracker, generic payroll app, or AI assistant.

Distinctiveness should come from the product model, information hierarchy, Pay Ledger, evidence trail, language, and interaction quality, not decoration.

## Pareto operating principle

**Every agent decision should aim for Pareto efficiency.**

For LinePay, this means choosing solutions that deliver the most user value, correctness, trust, craft, and learning with the least unnecessary complexity, code, dependencies, operational burden, and irreversible commitment.

A decision is **Pareto-dominated** when another feasible option is at least as good on all important dimensions and meaningfully better on one or more. Do not choose a dominated option.

The goal is not to minimize engineering effort at any cost. Correctness, trust, privacy, auditability, preservation of user data, and the core product-quality bar are hard constraints. Never trade them away merely to ship faster or reduce code.

### Decision objectives, in priority order

When options compete, evaluate them against these objectives:

1. **Correctness and trust** — especially money, time, rule interpretation, history, and reconciliation.
2. **User value and product quality** — does this materially help a worker understand or protect their pay, and does the experience feel excellent?
3. **Privacy and safety** — minimize sensitive-data exposure and unnecessary data collection.
4. **Speed of learning** — prefer choices that validate important assumptions sooner with real users.
5. **Simplicity and maintainability** — fewer concepts, layers, dependencies, states, and failure modes.
6. **Implementation and operating cost** — less code, infrastructure, support, and maintenance when outcomes are otherwise comparable.
7. **Reversibility** — prefer decisions that are cheap to change until evidence justifies locking them in.
8. **Extensibility** — optimize for demonstrated next steps, not imagined futures.

Do not reverse this list by building elaborate extensibility while the core user value is still unproven.

### Pareto decision protocol

For any material product, architecture, UX, dependency, schema, pricing, or implementation decision:

1. Define the actual user outcome and the hard constraints.
2. Identify the smallest credible set of alternatives. Usually 2–4 is enough.
3. Compare the alternatives on value, correctness, product quality, privacy, learning speed, complexity, cost, and reversibility.
4. Eliminate clearly Pareto-dominated alternatives.
5. Among remaining options, prefer the simplest reversible option that preserves the hard constraints and captures most of the available value.
6. Spend additional complexity only when it buys disproportionate value, materially reduces risk, or creates a compounding asset.
7. If a real trade-off remains, state it explicitly instead of hiding it behind abstraction or vague “best practice.”
8. Revisit the decision when new evidence changes the frontier.

For trivial decisions, apply this mentally and move on. Do not create process theater. For decisions with lasting consequences, make the reasoning explicit in the issue, PR, plan, or ADR.

### The 80/20 implementation rule

Default to the smallest implementation that captures roughly 80% of the validated user value with a fraction of the complexity.

Then spend focused craft on the **critical 20% of surfaces and interactions that create most of the trust, comprehension, retention, and affection for the product**.

This does **not** mean shipping knowingly incorrect payroll math, unsafe migrations, inaccessible critical flows, weak privacy, or visibly rough core interactions. Those are hard constraints, not the expendable 20%.

Good examples:

- one excellent native workflow before multiple platforms;
- one paid tier before a pricing matrix;
- local storage before a user-account backend;
- deterministic rules before AI interpretation;
- canonical fixtures before shared runtime code;
- a focused adapter before a generic framework;
- a manual confirmation step before building uncertain automation;
- one beautifully resolved Pay Ledger before five mediocre analytics screens.

### Complexity budget

Treat every new abstraction, dependency, service, state, screen, setting, database table, network request, and background process as spending from a finite complexity budget.

Before adding one, ask:

> What concrete user value, risk reduction, learning, or product-quality improvement does this complexity purchase?

If the answer is vague, speculative, or merely “we may need it later,” do not add it yet.

Prefer deleting complexity to organizing it beautifully.

### Reversibility and option value

Early LinePay decisions should preserve option value.

Prefer:

- data and behavior contracts over shared runtime abstractions;
- adapters over framework coupling;
- versioned schemas over implicit persistence behavior;
- feature boundaries over generalized infrastructure;
- platform services over owned infrastructure when they satisfy the need;
- evidence-backed commitments over speculative future-proofing.

Irreversible or expensive-to-reverse decisions require stronger evidence than reversible ones.

### Compounding exception

Some work is worth doing even when it is not the shortest path because it compounds across the product.

Examples include:

- canonical pay-rule fixtures;
- deterministic domain tests;
- versioned agreement/rule representations;
- migration safety;
- reusable verified agreement data;
- source/provenance conventions;
- accessibility foundations;
- privacy-preserving architecture;
- durable design tokens and interaction patterns that improve every critical flow.

Agents should distinguish **compounding foundations** from **speculative infrastructure**. Invest in the former. Resist the latter.

## Product invariants

These are harder constraints than implementation convenience.

1. **Never invent a pay rule.** A rule must come from user input or a source-backed, versioned agreement preset.
2. **Never silently change historical results.** Every calculation must be reproducible from the work facts and the exact rule-set version/snapshot used at calculation time.
3. **Money must be exact.** Never use binary floating-point (`Double`/`Float`) for currency or pay math. Use decimal/fixed-point representations and explicit rounding rules.
4. **Time must be explicit.** Persist instants plus relevant timezone/context. Do not infer payroll meaning from the device's current timezone after the fact.
5. **OCR is evidence, not truth.** OCR output must preserve source/provenance and confidence where available. Low-confidence or materially consequential fields require user confirmation.
6. **The rule engine is deterministic and pure.** No UI, persistence, network, analytics, StoreKit, clock, locale, or device dependency inside core calculation logic.
7. **Privacy by architecture.** Default to device-local wage, shift, agreement, and paystub data. Do not add a LinePay backend, tracking SDK, ad SDK, or remote analytics without an explicit ADR and product need.
8. **Explain every discrepancy.** Results must be traceable to work facts, applied rule(s), calculation steps, and source/reference metadata.
9. **Estimate, don't adjudicate.** User-facing language should say “expected”, “estimated”, or “possible discrepancy” unless a fact is directly confirmed.
10. **No premature cross-platform abstraction.** iOS and Android are native clients. Share schemas, fixtures, examples, and behavioral contracts before sharing runtime code.

## Monorepo boundaries

```text
apps/ios/        SwiftUI iOS app and iOS-specific packages
apps/android/    Kotlin + Jetpack Compose Android app (later)
shared/contracts Platform-neutral schemas, canonical examples, and test vectors
docs/adr/        Architectural decisions
docs/research/   Source-backed technical/product research
scripts/         Reproducible local/CI commands
```

Do not move iOS code into a generic `shared` module merely because Android may exist later.

## iOS baseline

- Xcode 26.6 stable toolchain, Swift 6.3 compiler, Swift 6 language mode.
- XcodeGen >= 2.46.0 defines the app project; generated `.xcodeproj` output is not source of truth.
- SwiftUI for UI.
- Swift Testing for unit/integration tests; XCTest/XCUIAutomation only where UI automation requires it.
- Apple frameworks first: Foundation, SwiftData where appropriate, Vision/VisionKit for scanning/OCR, StoreKit 2 for purchases.
- Third-party runtime dependencies require a concrete reason and an ADR if they become architectural.
- Swift concurrency checking stays strict. Do not silence Sendable/isolation errors with unchecked escape hatches unless the invariant is proven and documented.
- Prefer value types and explicit dependencies.
- Avoid global mutable state and service-locator singletons.

## Architecture rule

Use dependency direction like this:

```text
SwiftUI App / Features
        ↓
Application use cases / orchestration
        ↓
LinePayDomain (pure models + rule engine + reconciliation)
        ↑
Adapters: SwiftData, Vision, StoreKit, files/export
```

The domain layer knows nothing about SwiftUI, SwiftData, StoreKit, Vision, UIKit, analytics, or networking.

### Suggested domain concepts

Keep these concepts platform-neutral even if their Swift representation is not shared:

- `Money`
- `WorkEvent`
- `Shift`
- `PayPeriod`
- `PayRule`
- `RuleSet` / `AgreementSnapshot`
- `Entitlement`
- `PayComponent`
- `CalculationResult`
- `PaystubFact`
- `ReconciliationResult`
- `EvidenceReference`

Prefer names from the problem domain over generic `Manager`, `Helper`, `Service`, or `Utils` types.

## Money rules

- Use `Decimal` or an integer minor-unit representation with currency metadata.
- Currency must never be assumed implicitly in persisted or interchange data.
- Rounding is part of the rule. Apply it at explicit boundaries, not opportunistically throughout a calculation.
- Tests must cover half-cent and boundary behavior when relevant.
- Never compare formatted currency strings.

## Time rules

Payroll is hostile to naive date/time code.

- Persist actual instants and the timezone/context relevant when the work happened.
- A shift can cross midnight, DST boundaries, holidays, or pay-period boundaries.
- Never calculate durations from formatted clock strings.
- Rules that depend on “day”, “Sunday”, “holiday”, “after 8 hours”, rest windows, or callout windows need explicit semantics and tests.
- Add regression tests for every real production edge case discovered.

## Agreement/rule versioning

A preset agreement must be source-backed and versioned.

Minimum metadata:

- stable identifier
- display name
- jurisdiction/local/employer context where applicable
- effective start/end dates
- source reference or URL metadata
- rule-set schema version
- content/version hash or immutable version identifier
- verification status/date

When a rule set changes, create a new version. Do not mutate old calculations to use new rules.

## OCR and paystub ingestion

- Original user-selected image/PDF remains the evidence source unless the user deletes it.
- Store parsed fields separately from raw OCR text.
- Preserve page/region/source references where practical.
- Parsing should be deterministic where possible. AI/LLM extraction must never silently produce authoritative pay rules.
- A materially uncertain wage/rate/hour value must be surfaced for confirmation before reconciliation.
- Avoid uploading paystubs to a server in the default architecture.

## Persistence

Persistence models are adapters, not domain models.

If SwiftData is used:

- introduce an explicit versioned schema from the first public release;
- maintain a migration plan when automatic migration is insufficient;
- test migration using representative persisted fixtures before shipping schema changes;
- do not leak `@Model` objects throughout domain logic;
- preserve stable identifiers independent of database row/object identity.

Avoid storing only derived totals. Store sufficient raw facts to recalculate and audit them.

## StoreKit

- Put subscription state behind a small protocol/interface.
- Handle purchase, restore, renewal, expiration, grace/billing-retry states, and transaction updates.
- Product access decisions must be testable without contacting the App Store.
- Keep a StoreKit configuration for local automated testing.
- Never entangle pay-calculation correctness with subscription code.

## UI quality baseline

User-facing work must follow `DESIGN.md` and the insanely great product standard above.

- Dynamic Type from day one.
- VoiceOver labels/hints for non-obvious controls.
- Do not encode meaning using color alone.
- Minimum touch target sizes consistent with Apple HIG.
- Respect locale for display, but keep calculation primitives locale-independent.
- Prefer system components and navigation before custom UI infrastructure.
- Avoid a design-system framework until repetition justifies it.
- Optimize critical flows for one-handed, tired, distracted use.
- Prefer immediate feedback and direct manipulation over modal explanation.
- Make important money values scannable at a glance.
- Keep visual hierarchy strong enough that the worker knows what matters before reading every label.
- Every empty, loading, error, uncertain-OCR, and discrepancy state must be intentionally designed.
- Never ship placeholder-feeling copy or generic “AI app” visual patterns into a core flow.

## Testing policy

Correctness of money calculations is the highest engineering priority.

### Test pyramid

1. **Many pure domain tests**: rule boundaries, overtime tiers, callout minimums, rest logic, per diem, cross-midnight, DST, rounding, reconciliation.
2. **Fewer integration tests**: persistence migrations, OCR parsing fixtures, StoreKit state, export/import.
3. **Small UI smoke suite**: onboarding, create rules, record work, run reconciliation, recover after relaunch.

Every bug involving money, time, rule interpretation, migration, or data loss gets a regression test before the fix is considered complete.

Use parameterized Swift Testing cases for rule tables and canonical fixtures.

## Canonical cross-platform fixtures

`shared/contracts/fixtures/` is the behavioral treaty between iOS and Android.

A fixture should contain:

- inputs (work facts + rule-set version)
- expected pay components
- expected totals
- expected explanations/references

Both platform implementations must pass the same fixtures once Android exists.

Do not share implementation merely to make tests pass.

## Build and dependency discipline

- Pin or explicitly constrain tools/dependencies used in reproducible builds.
- Commit application dependency lockfiles such as `Package.resolved` when generated.
- Prefer no dependency over a small convenience dependency.
- Never add an SDK only for one helper function.
- Before adding a dependency, check maintenance, privacy manifest impact, binary size, licenses, transitive dependencies, and whether Apple/Foundation already solves the problem.
- Keep Debug and Release as the primary build configurations unless a real requirement proves otherwise.
- Treat compiler warnings as errors in CI for our code.
- Keep generated artifacts out of git unless the chosen tool/workflow explicitly requires them.

## Formatting and linting

Use the Swift toolchain's `swift format` / `swift-format` capability rather than introducing a separate formatter by default. Formatting is mechanical; do not mix broad formatting rewrites into feature changes.

## Security and privacy

- No secrets in repo, fixtures, logs, screenshots, crash reports, or tests.
- Test fixtures must be synthetic/anonymized.
- Redact wage/paystub content from logs.
- Add and maintain `PrivacyInfo.xcprivacy` from the beginning.
- Review required-reason API usage and third-party SDK privacy manifests before every release.
- If analytics are later added, collect the minimum product event needed and never raw paycheck content.

## Git / change discipline

- Keep changes small and reviewable.
- Architecture changes require an ADR when they affect module boundaries, persistence format, privacy model, rule representation, or cross-platform strategy.
- Do not refactor unrelated code in the same change.
- Prefer deleting complexity to abstracting it.
- Never bypass failing tests to make CI green.

## Before implementing a feature

Answer these questions in the issue/PR or working notes:

1. What user fact or decision does this feature improve?
2. What is the smallest useful behavior?
3. Which product invariant could this accidentally violate?
4. What is the cheapest test that proves correctness?
5. Does it introduce persistence, privacy, migration, or rule-version consequences?
6. What simpler alternative captures most of the value?
7. Is the proposed solution Pareto-dominated by a cheaper, simpler, safer, more delightful, or more reversible option?
8. What complexity are we adding, and what concrete value or risk reduction buys it?
9. What is the one moment in this feature that users will judge most strongly?
10. What would make that moment feel unusually clear, fast, trustworthy, and specific to LinePay?
11. Are we adding feature surface because users need it, or because implementation makes it easy to add?

## Definition of done

A change is done only when:

- behavior is implemented;
- important edge cases are tested;
- money/time calculations are deterministic;
- no new warning is introduced;
- privacy implications are understood;
- persistence changes include migration consideration;
- user-visible errors are actionable;
- documentation/ADR is updated when the architecture changed;
- no known materially simpler Pareto-superior implementation remains unexplored;
- unnecessary complexity introduced by the change has been removed;
- critical user-facing states look intentional rather than default-generated;
- the main interaction is understandable without explanatory prose where possible;
- the flow feels fast and responsive on a real device;
- visual/copy details comply with `DESIGN.md`;
- the result clears the question: **does this make LinePay meaningfully closer to insanely great?**

## Anti-goals

Do not build these before evidence requires them:

- backend accounts
- employer dashboards
- social/community features
- generic AI chat
- cross-platform UI framework
- microservices
- elaborate DI framework
- generic design-system package
- event bus
- plugin architecture
- remote feature-flag platform
- custom analytics warehouse

LinePay should remain a small, trustworthy, insanely great machine for expensive hours.
