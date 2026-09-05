# iOS bootstrap research — September 2026

This note records the technical choices used to bootstrap LinePay and the sources behind them. Revisit when the toolchain materially changes.

## Current toolchain

- **Xcode 26.6** is the current stable Xcode line used by this repository and includes **Swift 6.3**.
  - Apple: https://developer.apple.com/documentation/xcode-release-notes/xcode-26_6-release-notes
- GitHub's `macos-26` runner image currently includes Xcode 26.6.
  - Runner image: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md

Decision: use the current stable toolchain, but keep **Swift 6 language mode** (`SWIFT_VERSION = 6.0`) because the build setting represents language mode, not the compiler's marketing/toolchain version.

## Swift concurrency

Swift 6 language mode enables full data-race safety checking. New code should start strict rather than accumulate isolation debt and migrate later.

- Swift concurrency migration guide: https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/

Decision: `SWIFT_STRICT_CONCURRENCY = complete`; do not paper over errors with `@unchecked Sendable` without a documented proof of safety.

## Testing

Apple recommends a test pyramid: many fast isolated unit tests, fewer integration tests, and a smaller UI automation layer. Swift Testing is the modern unit/integration framework and XCTest remains appropriate for UI automation.

- Apple testing overview: https://developer.apple.com/documentation/xcode/testing
- Swift Testing: https://developer.apple.com/documentation/Testing

Decision: put almost all pay-rule tests in the pure `LinePayDomain` Swift package. Use parameterized tests heavily for rule boundaries and canonical fixtures. Add UI automation only for critical end-to-end flows.

## Local Swift packages

Apple explicitly recommends local Swift packages as a way to modularize app code and keep reusable/testable boundaries inside the same repository.

- Apple: https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages

Decision: one local package, `LinePayDomain`, for pure business logic. Do **not** create a package per feature. Split only when a boundary has independent dependencies/tests/ownership/build value.

## Project generation

XcodeGen 2.46.x is actively maintained and can generate an Xcode project from a human-readable, git-friendly spec. This lets the repo avoid hand-editing and merge conflicts in `project.pbxproj` while keeping the source of truth reviewable.

- XcodeGen: https://github.com/yonaskolb/XcodeGen
- Project spec: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md

Decision: keep `apps/ios/project.yml`, xcconfigs, and source folders in git; ignore the generated `.xcodeproj`. This is deliberately lighter than adopting Tuist's broader project/build platform for a tiny app.

Reconsider XcodeGen only if it becomes friction. Do not migrate project tooling for fashion.

## Formatting

Swift 6 toolchains include `swift-format` / `swift format`, so LinePay does not need another formatter dependency.

- swift-format: https://github.com/swiftlang/swift-format

Decision: keep configuration intentionally small; use `swift format lint --strict` in checks. Avoid a second formatter unless a concrete missing capability warrants it.

## Persistence and migrations

SwiftData can automatically migrate some schema changes and supports explicit `SchemaMigrationPlan` for changes beyond automatic migration.

- `ModelContainer`: https://developer.apple.com/documentation/swiftdata/modelcontainer
- `SchemaMigrationPlan`: https://developer.apple.com/documentation/swiftdata/schemamigrationplan

Decision before persistence lands:

1. SwiftData models are adapters, not domain models.
2. Start the first public release with an explicit versioned schema.
3. Keep stable domain identifiers independent of persistence identity.
4. Preserve raw work facts and the exact agreement/rule snapshot used for a historical calculation.
5. Add migration fixtures/tests before shipping every non-trivial schema change.

Do not add SwiftData merely because it is available. Add it when the first persistence use case is implemented.

## Privacy manifest

Apple requires privacy manifests for reporting collected data and required-reason API use. Apps using required-reason APIs without approved declarations can be rejected by App Store Connect.

- Privacy manifests: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Required reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

Decision: keep `PrivacyInfo.xcprivacy` in the target from day one, initially declaring no tracking/no collection. Update it whenever code or a dependency changes the privacy facts. Avoid third-party SDKs that make the privacy story worse without clear product value.

## OCR / Vision

Apple Vision provides on-device text recognition. LinePay's privacy model should prefer local OCR for paystubs.

- `RecognizeTextRequest`: https://developer.apple.com/documentation/vision/recognizetextrequest

Decision: OCR output is an observation. It never becomes authoritative wage/hour/rule data without deterministic parsing and user confirmation where material uncertainty exists.

## StoreKit

Subscription logic must account for active, renewed, lapsed, grace/billing-retry states and transaction changes.

- Apple subscription handling: https://developer.apple.com/documentation/storekit/handling-subscriptions-billing

Decision: isolate StoreKit behind a tiny app-layer interface and keep a StoreKit test configuration. Subscription state must never influence the correctness of calculations already owned by the user.

## Money and time correctness

These are LinePay-specific engineering constraints rather than Apple framework choices:

- Never use `Double`/`Float` for currency.
- Currency code travels with the value.
- Rounding is explicit and rule-specific.
- Persist work instants and relevant timezone/context.
- Test cross-midnight, DST, Sundays/holidays, rest windows, callout minimums, pay-period boundaries, and rounding boundaries.

The expensive failure in this product is not a crash. It is a plausible-looking wrong number.

## Deployment target

Decision: **iOS 18.0** for v1 rather than iOS 26-only APIs. This preserves a materially wider device base while still providing the modern SwiftUI/Observation/SwiftData-era platform surface needed by LinePay. Revisit only if a specific newer API creates enough user value to justify excluding older supported devices.

## Dependency policy

Start with Apple/Foundation frameworks only. Before adding a third-party runtime dependency, answer:

1. What user value is blocked without it?
2. What is its maintenance/privacy/license/binary-size/transitive-dependency cost?
3. Can the platform solve the requirement adequately?
4. Can the dependency be isolated behind an adapter so it is replaceable?

Avoid analytics, DI, networking, design-system, and architecture frameworks until reality earns them.
