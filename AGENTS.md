# AGENTS.md — LinePay Engineering Contract

This file is authoritative for AI agents and contributors working in this repository.

## Mission

Build the smallest trustworthy product that helps a worker answer:

> Given the work I actually performed and the pay rules I explicitly selected or confirmed, what pay should I expect, and where might my paystub differ?

LinePay is a **calculation and reconciliation tool**, not payroll software, legal advice, a union authority, or an autonomous contract interpreter.

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

- Dynamic Type from day one.
- VoiceOver labels/hints for non-obvious controls.
- Do not encode meaning using color alone.
- Minimum touch target sizes consistent with Apple HIG.
- Respect locale for display, but keep calculation primitives locale-independent.
- Prefer system components and navigation before custom UI infrastructure.
- Avoid a design-system framework until repetition justifies it.

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

## Definition of done

A change is done only when:

- behavior is implemented;
- important edge cases are tested;
- money/time calculations are deterministic;
- no new warning is introduced;
- privacy implications are understood;
- persistence changes include migration consideration;
- user-visible errors are actionable;
- documentation/ADR is updated when the architecture changed.

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

LinePay should remain a small, trustworthy machine for expensive hours.
