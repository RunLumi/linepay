---
applyTo: "apps/ios/**/*.swift,apps/ios/**/*.yml,apps/ios/**/*.xcconfig"
---

# iOS-specific instructions

Before editing iOS code, read `apps/ios/AGENTS.md` and `docs/engineering/ios-best-practices.md`. For user-facing changes also read `DESIGN.md`.

- Use SwiftUI + Observation and preserve Swift 6 strict-concurrency correctness.
- Keep mutable app/UI state on the appropriate actor, normally `@MainActor`.
- Prefer value types, explicit dependencies, Apple frameworks, and small seams over framework-heavy architecture.
- Views render state and send intent; payroll algorithms stay in `LinePayDomain`.
- Keep generated Xcode project output disposable. Change `apps/ios/project.yml` or xcconfig source files instead of hand-editing `.pbxproj`.
- Preserve bundle ID `com.streamentry.linepay`; public display name is `LinePaycheck`.
- Use String Catalog/localizable SwiftUI strings for user-facing copy.
- Use semantic design tokens, Dynamic Type, and stable accessibility identifiers for critical automated journeys.
- User-facing changes are not complete at compile time when simulator inspection is available.
- Run `bash scripts/agent-verify.sh ios`; use `ui` for critical navigation/interaction changes.
