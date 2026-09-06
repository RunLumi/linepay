# LinePay iOS Engineering Best Practices

Status: **authoritative engineering guidance for iOS 1.x**  
Last researched: **2026-09-05**  
Baseline: **Xcode 26.6, Swift 6.3 compiler, Swift 6 language mode, iOS 18+**

This document converts current Apple and Swift guidance into rules for LinePay. It is intentionally opinionated toward a small, privacy-first, correctness-sensitive utility. It is not a generic architecture cookbook.

## 1. Product-shaped engineering goals

LinePay should be:

- **correct before clever**: pay math and historical reproducibility outrank architectural fashion;
- **native and boring**: SwiftUI plus Apple frameworks first, minimal dependencies;
- **local-first**: wage, work, agreement, and paystub data stay on-device by default;
- **testable at every boundary**: pure domain tests, app-orchestration tests, then a very small UI smoke suite;
- **migration-safe**: persisted data is explicitly versioned from the first public release;
- **accessible and localizable by construction**: not retrofitted after launch;
- **easy to delete and refactor**: abstractions must earn their existence.

The original product constraint remains a strength: no LinePay account and no central wage/paystub backend are required for the core experience.

## 2. Current repo assessment

### Already strong

The repository already follows several modern practices:

- Swift 6 language mode with complete concurrency checking and warnings-as-errors.
- SwiftUI with Observation (`@Observable`) rather than legacy `ObservableObject` boilerplate.
- UI/application state isolated to `@MainActor`.
- Pure `LinePayDomain` package with no SwiftUI, persistence, OCR, StoreKit, or networking dependencies.
- Exact money representation instead of binary floating-point.
- Explicit payroll timezone semantics.
- XcodeGen project generation and xcconfig-based build settings.
- Swift Testing for domain tests.
- `PrivacyInfo.xcprivacy` present from the start.
- No runtime third-party SDKs or central backend.
- A small StoreKit 2 subscription scaffold now exists, but `commerceEnabled` remains false until Pro value is ready to ship.

### Highest-value gaps found by this audit

1. `AppModel` owned important orchestration but originally had no app-layer tests.
2. CI originally tested only `LinePayDomain` and compiled the app; it did not execute an iOS app test target.
3. CI originally built Debug only; Release configuration needs a gate too.
4. The privacy manifest existed but was not explicitly validated or checked in the built app bundle.
5. Localization infrastructure had not been established before user-facing strings multiplied.
6. There was no standard privacy-safe unified-logging seam.
7. StoreKit is scaffolded but must not be considered production-ready until a checked-in StoreKit test configuration and entitlement-path tests exist.
8. SwiftData persistence, OCR ingestion, migration tests, and UI automation should be added only when those product slices begin.

## 3. Toolchain and project configuration

- Pin a currently supported stable Xcode toolchain in CI.
- Keep Swift 6 language mode and complete concurrency checking.
- Never downgrade language mode to silence a data-race diagnostic.
- Treat warnings from our code as errors.
- Keep build settings reviewable in `project.yml` and `.xcconfig`; the generated `.xcodeproj` is disposable output.
- Commit application dependency lockfiles when remote dependencies are introduced.
- Prefer the platform SDK over a convenience dependency.

Swift 6.3 is the current compiler baseline in Xcode 26.6. Swift 6.2+ also introduced more approachable concurrency, but LinePay should prefer **explicit isolation at subsystem boundaries** rather than globally making every type main-actor isolated.

### Concurrency rules

- UI and mutable application state: `@MainActor`.
- Pure immutable domain values: `Sendable`, nonisolated.
- CPU-heavy OCR/parser work: move off the main actor deliberately when measurements justify it.
- Persistence adapters: obey SwiftData/`ModelContext` actor ownership.
- Prefer structured concurrency over detached tasks and ad-hoc dispatch queues.
- Never use `@unchecked Sendable` as a compiler-silencing tool.

Sources:

- Swift 6 data-race safety: https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/
- Swift 6.2 approachable concurrency: https://www.swift.org/blog/swift-6.2-released/
- Swift 6.3: https://www.swift.org/blog/swift-6.3-released/
- Apple Swift concurrency: https://developer.apple.com/documentation/swift/concurrency

## 4. Architecture: boundaries, not ceremony

Use this dependency direction:

```text
SwiftUI views
    ↓
application orchestration
    ↓
LinePayDomain
    ↑
adapters: SwiftData / Vision / StoreKit / Files
```

Rules:

- Views render state and send intent. They do not contain payroll algorithms.
- `AppModel` may coordinate small synchronous use cases while the product is small.
- Split a type only when a real seam appears, such as persistence, OCR, or commerce.
- Do not create `Manager`, `Coordinator`, `Repository`, `UseCase`, or protocol layers simply to imitate an architecture diagram.
- Introduce a protocol when it creates a useful ownership/test boundary.
- Keep platform SDK types out of the pure domain package.
- Keep persistence models out of domain calculations.

There is no requirement to adopt MVVM, Clean Architecture, TCA, or a DI framework. For LinePay, unnecessary indirection is technical debt too.

## 5. SwiftUI state and Observation

For iOS 18+, Observation is the default model-state approach.

- Own long-lived observable app state with `@State` at the appropriate root.
- Pass observable models explicitly; use Environment only when breadth truly justifies it.
- Use `@Bindable` only when a child needs bindings into an observable model.
- Keep ephemeral presentation state in the view with `@State`.
- Do not mirror one source of truth in multiple wrappers.
- Avoid heavyweight work in `body`.
- Do not accidentally recreate a long-lived reference model during view recomputation.

Apple notes that Observation lets SwiftUI track the observable properties a view actually reads, reducing unnecessary invalidation.

Sources:

- https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro

## 6. Money and payroll correctness

LinePay needs stricter correctness than an ordinary CRUD app.

- Never represent money using `Double` or `Float`.
- Currency is part of every monetary value.
- Rounding policy is domain data, not a formatting side effect.
- Historical calculations preserve the exact agreement/rule snapshot used at the time.
- Store raw work facts and confirmed paystub facts, not only derived totals.
- Agreement presets require provenance and immutable version identity.
- Every production bug involving money, time, rule interpretation, migration, or data loss gets a regression test.

## 7. Date, time, calendar, and timezone

Never let the phone's current timezone reinterpret historical work.

- Persist instants plus the payroll-relevant timezone identifier.
- Use `Calendar` configured with an explicit timezone for calendar-day rules.
- Test DST forward/backward transitions, midnight crossings, Sundays/holidays, callouts, rest windows, and pay-period boundaries.
- Never calculate duration from formatted clock strings.
- Treat changes to day-boundary semantics as domain changes requiring fixture updates.

## 8. Persistence with SwiftData

When persistence is introduced, begin with an explicit versioned schema even if V1 has only a few models.

- Persistence models are adapters, not domain objects.
- Define `VersionedSchema` from the first public store format.
- Add `SchemaMigrationPlan` when automatic migration is insufficient.
- Keep stable domain IDs independent from SwiftData object identity.
- Store enough source facts to recalculate and audit results.
- Never silently delete/reset a production store after migration failure.
- Migration tests open representative old stores and verify semantic data, not merely that migration does not throw.
- Use in-memory `ModelConfiguration` for ordinary persistence tests.

Sources:

- `ModelContainer`: https://developer.apple.com/documentation/swiftdata/modelcontainer
- `SchemaMigrationPlan`: https://developer.apple.com/documentation/swiftdata/schemamigrationplan

## 9. Testing strategy

Apple recommends a test pyramid: many fast unit tests, fewer integration tests, and a small UI layer. LinePay should follow that shape.

### Domain tests: many and fast

Use Swift Testing for:

- pay-rule boundaries;
- cross-midnight/DST behavior;
- overtime-tier interactions;
- callout minimums;
- schedule premiums;
- rounding;
- reconciliation;
- canonical cross-platform fixtures.

Prefer parameterized tests for rule tables.

### App/application tests: required

Test orchestration that the domain package cannot know about:

- first-run defaults do not invent optional pay rules;
- profile edits create new agreement versions;
- add/edit/delete work recalculates consistently;
- invalid/overlapping input is rejected atomically;
- later: persistence, OCR confirmation, and entitlement orchestration.

### UI tests: deliberately small

Before TestFlight, keep smoke coverage for critical journeys only:

1. fresh launch → onboarding → configure pay rules;
2. add/edit/delete work;
3. inspect expected pay and ledger;
4. later: scan/confirm paystub → reconcile;
5. later: relaunch → persisted data remains intact;
6. later: purchase/restore Pro.

Use accessibility identifiers for automation. Do not test payroll arithmetic through UI tests.

### Diagnostics

Maintain test-plan configurations as useful for normal CI, diagnostics/sanitizers, and release-candidate smoke. Periodically run Address Sanitizer, Thread Sanitizer where supported, Undefined Behavior Sanitizer, Main Thread Checker, and Thread Performance Checker. They need not run on every commit.

Sources:

- Swift Testing: https://developer.apple.com/documentation/testing
- Xcode testing strategy: https://developer.apple.com/documentation/xcode/testing
- Test plans: https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback
- Runtime diagnostics: https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early

## 10. Privacy and security

LinePay's strongest security property is data minimization.

- No LinePay user account in 1.0.
- No central wage/paystub database.
- No ads or remote analytics SDK by default.
- OCR and reconciliation stay on-device by default.
- Never log wage amounts, paystub OCR text, employer identifiers, document contents, or notes.
- Any dynamic user-derived unified-log value must be private/redacted.
- Test fixtures contain synthetic data only.
- Validate `PrivacyInfo.xcprivacy` in CI and confirm it is present in the built app.
- Re-audit the privacy manifest whenever a dependency or required-reason API is added.
- Add permission usage descriptions only when the feature genuinely needs the permission.

Apple states that privacy manifests describe collected data and required-reason API usage, and App Store Connect can reject invalid manifests.

Sources:

- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest

## 11. Logging and diagnostics

Use `os.Logger`, not `print`, for durable diagnostics.

- Keep a tiny category set such as `app`, `calculation`, `persistence`, `ocr`, and `storekit`.
- Log state transitions and failures, not sensitive payloads.
- Treat user-derived interpolation as private.
- Do not add a remote crash/analytics SDK until its value clearly exceeds the privacy/dependency cost.
- Add signposts only for measured performance questions.

Source: https://developer.apple.com/documentation/os/logging/

## 12. Localization and formatting

Establish localization before copy proliferates.

- Use String Catalogs (`.xcstrings`).
- Keep SwiftUI user-facing literals in localizable APIs.
- Let Xcode extract strings during builds.
- Use generated localizable symbols where they genuinely improve safety; do not replace clear text with opaque keys everywhere.
- Format money, dates, durations, and numbers using locale-aware `FormatStyle` APIs for display.
- Keep parsing and interchange locale-independent.
- Do not make orchestration tests depend needlessly on English copy.

Sources:

- String Catalogs: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Preparing text: https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation
- Generated symbols: https://developer.apple.com/documentation/xcode/using-generated-localizable-symbols-in-your-code

## 13. Accessibility

Accessibility is part of correctness for a field utility.

- Support Dynamic Type without clipping primary flows.
- Maintain appropriate contrast in light, dark, and increased-contrast appearances.
- Give icon-only/non-obvious controls useful VoiceOver labels.
- Never communicate discrepancy state with color alone.
- Respect Reduce Motion.
- Keep frequent controls comfortably tappable; LinePay may deliberately exceed Apple's minimum for field use.
- Use automation identifiers separately from user-facing accessibility labels.
- Before release, manually exercise the main flow with VoiceOver and accessibility text sizes.

Source: https://developer.apple.com/design/human-interface-guidelines/accessibility

## 14. Performance

Do not optimize imaginary bottlenecks, but keep the main actor clean.

- Keep launch work minimal.
- Lazy-load expensive OCR/commerce work where practical.
- Avoid dynamic third-party frameworks without clear value; extra frameworks can increase launch cost.
- Profile with Instruments/Organizer before making performance-driven architecture changes.
- Move CPU-heavy OCR/parsing off the main actor when measurements justify it.
- Prefer deterministic recomputation over caching derived payroll state while datasets are small.

Sources:

- https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time
- https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early

## 15. StoreKit 2

The repo now contains a StoreKit 2 scaffold and preview paywall. **Commerce stays disabled until the following gate is met.**

- Use StoreKit 2 async APIs and verified transactions.
- Treat current App Store entitlements as the Apple-platform source of truth.
- Keep listening for transaction updates so purchases outside the immediate session are reflected.
- Finish verified transactions after processing them.
- Keep product entitlement separate from payroll-calculation correctness.
- Check in a StoreKit configuration file before enabling commerce.
- Add deterministic tests for product loading/entitlement presentation where practical and StoreKit Test coverage for purchase, restore, renewal, expiration, revocation/refund, grace/billing-retry, pending/Ask-to-Buy, cancellation, and failed verification paths.
- Test restore behavior on a real sandbox/TestFlight path before release.
- Never require network availability to read an already-saved historical calculation.

Sources:

- StoreKit 2: https://developer.apple.com/storekit/
- StoreKit Test: https://developer.apple.com/documentation/storekittest
- Testing purchases in Xcode: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode

## 16. CI and release gates

Every iOS pull request should, at minimum:

1. run `swift format lint --strict`;
2. run all pure domain tests;
3. validate the privacy manifest;
4. generate the Xcode project from source;
5. run app-layer tests on an iOS Simulator;
6. confirm the built app bundles the privacy manifest;
7. build Release for a generic iOS Simulator/device-compatible destination without signing;
8. fail on compiler warnings from our code.

Before TestFlight/App Store:

- archive Release;
- verify dSYM generation and retain symbols;
- inspect the generated privacy report;
- test migration from the previous production store version;
- run the UI smoke suite on current and minimum-supported OS/device classes where practical;
- run accessibility checks;
- test StoreKit in Xcode and sandbox/TestFlight;
- exercise launch, background/foreground, low-storage/import failure, corrupted/unsupported-document, and interrupted-purchase paths.

Source: https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information

## 17. Dependencies

Default answer: **do not add one**.

Before adding a runtime package/SDK, answer:

1. Can Foundation, SwiftUI, Vision, or StoreKit already solve this sufficiently?
2. Does it touch sensitive user data?
3. What privacy-manifest obligations does it add?
4. Is it maintained and compatible with Swift 6 concurrency?
5. What is its launch, binary-size, license, and transitive-dependency cost?
6. Can we remove it without rewriting the product?

An architectural runtime dependency requires an ADR.

## 18. Error handling and recovery

- User-visible errors say what happened and what the user can do next.
- Internal details belong in privacy-safe logs, not raw alert text.
- Failed mutations must not leave partial state.
- Destructive actions on meaningful history require confirmation or an immediately reversible path.
- File imports must not destroy the original before replacement is validated.
- Persistence migration failure must preserve a recoverable path.

## 19. Code-review checklist

For every meaningful iOS change, ask:

- Does this change payroll meaning or only presentation?
- Could it mutate or reinterpret historical results?
- Is money exact and currency-aware?
- Is time interpreted in the payroll timezone?
- Does mutable state have an explicit isolation owner?
- Did UI code absorb business logic?
- Is new persistent data versioned and migratable?
- Is new user data logged, uploaded, or exposed to an SDK?
- What regression test proves the important behavior?
- Does the primary flow work with large Dynamic Type and VoiceOver?
- Does the feature still work without a LinePay backend unless an explicit product need says otherwise?
- Is the abstraction/dependency smaller than the problem it solves?

## 20. Implemented by this audit

This audit applies the highest-leverage practices immediately:

- adds an iOS app unit-test target using Swift Testing;
- adds regression tests around `AppModel` defaults, agreement versioning, work mutation, and atomic invalid-overlap handling;
- runs app tests on an installed iOS Simulator in CI;
- validates `PrivacyInfo.xcprivacy` and verifies it is bundled into the app;
- adds a Release build gate;
- establishes a String Catalog and compiler localization extraction;
- adds a privacy-safe unified-logging seam;
- makes this document mandatory through `apps/ios/AGENTS.md`;
- retains the existing pure domain package and simple Observation architecture instead of introducing framework ceremony.

Not implemented prematurely: SwiftData models/migrations, OCR architecture, remote analytics, a backend, or broad UI automation. StoreKit exists as a disabled scaffold; its next engineering step is test infrastructure, not enabling commerce.