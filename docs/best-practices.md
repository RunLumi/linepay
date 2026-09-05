# LinePay iOS Engineering Best Practices

Status: **authoritative engineering guidance for iOS 1.x**  
Last researched: **2026-09-05**  
Baseline: **Xcode 26.6, Swift 6.3 compiler, Swift 6 language mode, iOS 18+**

This document converts current Apple/Swift guidance into rules for LinePay. It is intentionally opinionated toward a small, privacy-first, correctness-sensitive utility. It is not a generic architecture cookbook.

## 1. Goals

LinePay should be:

- **correct before clever** — pay math and historical reproducibility outrank architectural fashion;
- **native and boring** — SwiftUI plus Apple frameworks first, minimal dependencies;
- **local-first** — wage, work, agreement, and paystub data stay on-device by default;
- **testable at every boundary** — pure domain tests, app orchestration tests, a small UI smoke suite;
- **migration-safe** — persisted data is versioned from the first public release;
- **accessible and localizable by construction** — not retrofitted after launch;
- **easy to delete and refactor** — abstractions must earn their existence.

## 2. Current repo assessment

### Already good

The repository already follows several modern practices:

- Swift 6 language mode with complete concurrency checking and warnings-as-errors.
- SwiftUI with the Observation framework (`@Observable`) instead of legacy `ObservableObject` boilerplate.
- UI state isolated to `@MainActor`.
- Pure `LinePayDomain` package with no SwiftUI, persistence, OCR, StoreKit, or networking dependencies.
- Exact money representation instead of binary floating-point.
- Explicit work timezone semantics.
- XcodeGen project generation and xcconfig-based build settings.
- Swift Testing for domain tests.
- `PrivacyInfo.xcprivacy` already present.
- No runtime third-party SDKs or central backend.

### Highest-value gaps found in this audit

1. **No app-layer tests.** `AppModel` owns important orchestration and validation, but CI only tests `LinePayDomain` and builds the app.
2. **CI does not execute an iOS simulator test target.** A compile-only pass cannot catch orchestration regressions.
3. **CI only builds Debug.** Release/optimization configuration deserves a build gate before App Store work begins.
4. **Privacy manifest validity is not explicitly checked by the repo script.** App Store Connect rejects invalid manifests.
5. **Localization infrastructure is not established yet.** SwiftUI literals are localizable, but the project should opt into modern String Catalog extraction before strings proliferate.
6. **No structured logging seam.** Debugging should use unified logging and must never accidentally expose wages/paystub contents.
7. Persistence, StoreKit, OCR, and UI automation are intentionally not implemented yet. Their rules are defined below before code makes them expensive to change.

## 3. Toolchain and project configuration

### Required

- Keep the app on a currently supported stable Xcode toolchain, pinned in CI.
- Use Swift 6 language mode. Swift 6 enables full data-race safety checking; do not downgrade language mode to silence concurrency errors.
- Keep warnings-as-errors for our code.
- Keep build settings reviewable in `project.yml` and `.xcconfig`, not hand-tuned only inside a generated `.xcodeproj`.
- Generated Xcode project files are disposable output.
- Commit dependency lockfiles when remote application dependencies are introduced.

### Swift 6 concurrency

Swift 6.2+ introduced more approachable concurrency, including optional main-actor default isolation for UI-heavy executable targets. For LinePay, prefer **explicit isolation at subsystem boundaries** over globally turning everything into main-actor code:

- UI/application state: `@MainActor`.
- Pure immutable domain values: `Sendable`, nonisolated.
- CPU-heavy parsing/OCR post-processing: move off the main actor deliberately when it becomes measurable work.
- Persistence adapters: respect SwiftData/ModelContext actor constraints.
- Never use `@unchecked Sendable` as a compiler-silencing tool.
- Prefer structured concurrency (`async let`, task groups, actor isolation) over detached tasks and ad-hoc queues.

Sources:

- Swift 6 data-race safety: https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/
- Swift 6.2 approachable concurrency: https://www.swift.org/blog/swift-6.2-released/
- Swift 6.3 release: https://www.swift.org/blog/swift-6.3-released/
- Apple Swift concurrency reference: https://developer.apple.com/documentation/swift/concurrency

## 4. Architecture: prefer boundaries, not layers for their own sake

Use this dependency direction:

```text
SwiftUI views
    ↓
App/application orchestration
    ↓
LinePayDomain
    ↑
adapters: SwiftData / Vision / StoreKit / Files
```

Rules:

- Views render state and send user intent. They do not contain payroll algorithms.
- `AppModel` may coordinate small synchronous use cases while the product is small. Split it only when a real seam appears, such as persistence, OCR, or StoreKit.
- Do not create `Manager`, `Coordinator`, `Repository`, `UseCase`, or protocol layers simply to match an architecture diagram.
- Introduce a protocol when it creates a useful test/ownership boundary, not automatically around every concrete type.
- Keep domain models persistence-agnostic.
- Keep platform SDK types out of the pure domain package.

There is no Apple requirement to use MVVM, Clean Architecture, TCA, or a DI framework. For LinePay, unnecessary indirection is technical debt too.

## 5. SwiftUI state and Observation

For iOS 18+, Observation is the default state model.

- Own long-lived observable app state with `@State` at the appropriate root.
- Share observable state explicitly through parameters or environment when breadth justifies it.
- Use `@Bindable` only when a child needs bindings into an observable model.
- Keep ephemeral presentation state (`isPresented`, selected row, draft text) in the view using `@State`.
- Do not mirror the same source of truth in multiple property wrappers.
- Avoid heavyweight work in `body`; derive cheap values synchronously and perform actual work in model/application methods.
- Be careful with reference identity: a view should not create a fresh long-lived model on every render.

Apple recommends the Observation macro on supported OS versions and notes that SwiftUI can track only properties a view actually reads, reducing unnecessary invalidation.

Sources:

- Managing model data: https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- Migrating to Observation: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro

## 6. Money and payroll correctness

LinePay's correctness rules are stricter than normal CRUD-app rules.

- Never represent money using `Double` or `Float`.
- Currency is part of a monetary value.
- Rounding policy is domain data, not a formatting side effect.
- Historical calculations must keep the exact agreement/rule snapshot used at the time.
- Persist raw work facts and confirmed paystub facts, not only totals.
- Every production bug involving money, time, agreement interpretation, migration, or data loss gets a regression test.
- Any agreement preset must have source/provenance metadata and immutable version identity.

## 7. Date, time, calendar, and timezone

Never let the phone's current timezone reinterpret historical work.

- Persist instants plus the payroll-relevant timezone identifier.
- Use `Calendar` with an explicit timezone for calendar-day rules.
- Test DST forward/backward transitions, midnight crossings, Sundays/holidays, long callouts, and pay-period boundaries.
- Do not calculate duration from formatted text.
- Treat changes to day-boundary semantics as domain changes requiring fixture updates.

## 8. Persistence with SwiftData

When persistence is introduced, start with an explicit versioned schema even if V1 has only a few models.

- Persistence models are adapters, not domain objects.
- Define a `VersionedSchema` from the first public store format.
- Provide `SchemaMigrationPlan` when changes exceed automatic migration capabilities.
- Keep stable domain IDs independent from SwiftData object identity.
- Store enough source facts to rebuild calculations.
- Never silently destroy a store after migration failure in production.
- Migration tests must open representative old stores and verify semantic data, not merely that migration does not throw.
- Provide an in-memory `ModelConfiguration` for persistence tests.
- Avoid doing disk work synchronously on the main actor if profiling shows meaningful blocking.

Apple explicitly supports versioned schemas, migration plans, and in-memory/custom model configurations.

Sources:

- `ModelContainer`: https://developer.apple.com/documentation/swiftdata/modelcontainer
- `SchemaMigrationPlan`: https://developer.apple.com/documentation/swiftdata/schemamigrationplan

## 9. Testing strategy

### Domain tests: many and fast

Use Swift Testing for:

- pay-rule boundaries;
- cross-midnight/DST behavior;
- overtime tier interactions;
- callout minimums;
- schedule premiums;
- rounding;
- reconciliation;
- canonical cross-platform fixtures.

Prefer parameterized tests for rule tables.

### App/application tests: required

Test orchestration that the domain package cannot know about:

- first-run defaults do not invent optional pay rules;
- profile edits version agreement snapshots;
- add/edit/delete work recalculates consistently;
- invalid/overlapping input is rejected without mutating existing state;
- formatting/parsing boundaries remain deterministic.

### UI tests: very small

Before TestFlight, maintain smoke coverage for only critical journeys:

1. launch fresh → configure pay rules;
2. add/edit/delete a work interval;
3. inspect expected pay and ledger;
4. later: scan/confirm paystub → reconcile;
5. later: relaunch → data remains intact;
6. later: purchase/restore Pro.

Use stable accessibility identifiers for automation. Do not test business arithmetic through UI tests.

### Test plans and sanitizers

As the app matures, maintain Xcode test-plan configurations for:

- normal CI;
- sanitizers / diagnostics;
- release candidate smoke.

Use Address Sanitizer, Thread Sanitizer on Simulator where applicable, Undefined Behavior Sanitizer, Main Thread Checker, and Thread Performance Checker periodically. Running every sanitizer on every commit is unnecessary.

Sources:

- Swift Testing: https://developer.apple.com/documentation/testing
- Xcode test plans: https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback
- Runtime diagnostics/sanitizers: https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early

## 10. Privacy and security

LinePay's strongest security property is data minimization.

- No LinePay user account in 1.0.
- No central wage/paystub database.
- No analytics or ad SDK by default.
- OCR and reconciliation stay on-device by default.
- Never log wage amounts, paystub OCR, employer identifiers, document text, or user-entered notes.
- Unified log interpolation containing potentially user-derived values must be private/redacted.
- Test fixtures contain synthetic data only.
- Validate `PrivacyInfo.xcprivacy` in CI and review it before every release.
- Re-evaluate the privacy manifest whenever an SDK or required-reason API is added.
- Add permission usage descriptions only when a feature actually needs the permission.

Apple requires valid privacy manifests and can reject submissions containing malformed manifests or missing required declarations.

Sources:

- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Adding a privacy manifest: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- Required-reason API guidance: https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest

## 11. Logging and diagnostics

Use `os.Logger`, not `print`, for durable diagnostics.

- Define a tiny number of categories such as `app`, `calculation`, `persistence`, `ocr`, `storekit`.
- Log lifecycle/state-transition facts, not sensitive payloads.
- Default dynamic user values to `.private`.
- Do not introduce a remote crash/analytics SDK until its incremental value exceeds the privacy and dependency cost.
- Use `OSSignposter` only for measured performance questions, not preemptively.

Apple unified logging supports privacy-aware interpolation and signposts.

Source: https://developer.apple.com/documentation/os/logging/

## 12. Localization and formatting

Set up localization infrastructure before copy spreads across dozens of screens.

- Use String Catalogs (`.xcstrings`).
- Keep SwiftUI user-facing literals in localizable APIs.
- Use generated/localizable symbols where they improve key safety; do not replace clear UI literals with opaque keys everywhere without reason.
- Format money, dates, durations, and numbers using locale-aware `FormatStyle` APIs for display.
- Keep parsing and domain interchange locale-independent.
- UI copy tests should not depend unnecessarily on English wording.

Sources:

- String Catalogs: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Preparing text for translation: https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation
- Generated localizable symbols: https://developer.apple.com/documentation/xcode/using-generated-localizable-symbols-in-your-code

## 13. Accessibility

Accessibility is part of product correctness for a field utility.

- Support Dynamic Type; do not hard-code layouts that clip at accessibility sizes.
- Maintain at least Apple's recommended contrast ratios in light/dark/high-contrast appearances.
- Give icon-only/non-obvious controls VoiceOver labels and useful hints where needed.
- Do not communicate a discrepancy through color alone.
- Respect Reduce Motion.
- Keep frequent controls comfortably tappable; LinePay's design target may exceed Apple's minimum where field use benefits.
- Use accessibility identifiers for automation, distinct from user-facing accessibility labels.
- Test primary flows with VoiceOver and at an accessibility text size before release.

Source: https://developer.apple.com/design/human-interface-guidelines/accessibility

## 14. Performance

Do not optimize imaginary bottlenecks, but keep the main actor clean.

- Keep launch work minimal and lazy-load features such as OCR/StoreKit when possible.
- Avoid adding dynamic third-party frameworks without clear value; Apple notes additional frameworks can increase launch cost.
- Profile before making performance architecture decisions.
- Use Instruments / Organizer launch and hang diagnostics for observed problems.
- For large OCR/import work, measure and move CPU-heavy processing off the main actor when necessary.
- Do not cache derived payroll state unless profiling or UX requires it; deterministic recomputation is safer while datasets are small.

Sources:

- Reducing launch time: https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time
- Diagnosing performance issues early: https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early

## 15. StoreKit 2

When Pro ships:

- Use StoreKit 2 and modern Swift concurrency APIs.
- Treat StoreKit transaction state as the source of truth for Apple-platform entitlement.
- Listen for transaction updates and handle purchases made outside the current app session/device.
- Keep entitlement checks behind a narrow seam so product code is testable without the App Store.
- Include a checked-in StoreKit configuration for local development.
- Automate StoreKit tests for purchase, restore, expiration, renewal, revocation/refund, grace period, billing retry, Ask to Buy/deferred state where relevant.
- Never gate correctness of an already-created historical calculation behind transient network availability.

Sources:

- StoreKit 2: https://developer.apple.com/storekit/
- StoreKit Test: https://developer.apple.com/documentation/storekittest
- Testing IAP in Xcode: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode

## 16. CI and release gates

Every pull request touching iOS should, at minimum:

1. run `swift format lint --strict`;
2. run all pure domain tests;
3. validate the privacy manifest;
4. generate the Xcode project from source;
5. run app-layer tests on an iOS Simulator;
6. build Debug;
7. build Release for a generic iOS Simulator/device-compatible destination without signing;
8. fail on compiler warnings from our code.

Before TestFlight/App Store:

- archive the Release configuration;
- verify dSYM generation and retain archive symbols;
- inspect the generated privacy report;
- test upgrade/migration from the previous production version;
- run the UI smoke suite on at least one current and one minimum-supported OS/device class where practical;
- run accessibility checks;
- test StoreKit in Xcode and sandbox;
- exercise app launch, background/foreground, low-storage/import failure, and corrupted/unsupported-document paths.

Apple recommends dSYM generation for distributed builds so production crashes remain symbolicated.

Source: https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information

## 17. Dependencies

Default answer: **do not add one**.

Before adding a runtime package/SDK, answer:

1. Can Foundation/SwiftUI/Vision/StoreKit already solve this sufficiently?
2. Does the dependency touch sensitive user data?
3. What privacy-manifest obligations does it add?
4. Is it maintained and compatible with Swift 6 concurrency?
5. What is its launch/binary/transitive dependency cost?
6. Can we remove/replace it without rewriting the product?

An ADR is required for an architectural dependency.

## 18. Error handling and recovery

- User-visible errors state what happened and what the user can do next.
- Internal error details belong in privacy-safe logs, not raw alert text.
- Failed mutation must not leave partial state.
- Destructive actions affecting meaningful history require confirmation or an immediately reversible path.
- File imports never destroy the original before the replacement is validated.
- Persistence migration failure must preserve recoverability.

## 19. Code review checklist

For every meaningful iOS change, ask:

- Does this change payroll meaning or only presentation?
- Could it mutate or reinterpret historical results?
- Is money exact and currency-aware?
- Is time interpreted in the correct payroll timezone?
- Does mutable state have an explicit isolation owner?
- Did UI code accidentally absorb business logic?
- Is new persistent data versioned/migratable?
- Is new user data logged, uploaded, or exposed to an SDK?
- What regression test proves the important behavior?
- Does the primary flow still work with large Dynamic Type and VoiceOver?
- Does the feature work without a LinePay backend unless a documented requirement says otherwise?
- Is the abstraction/dependency smaller than the problem it solves?

## 20. Implementation adopted in this audit

The following changes are part of this best-practices pass:

- add an iOS app unit-test target using Swift Testing;
- add regression tests around `AppModel` defaults, agreement versioning, work mutation, and invalid overlap handling;
- run app tests on a real simulator in CI;
- validate `PrivacyInfo.xcprivacy` in the repo quality gate;
- add a Release build gate;
- establish a String Catalog and compiler-based localization extraction;
- add a privacy-safe unified logging seam;
- keep the existing pure domain package and current simple Observation architecture rather than adding architectural ceremony.

These are intentionally the highest-leverage changes. SwiftData, StoreKit, OCR, and UI automation should be added when their corresponding 1.0 slices begin, following the rules above.