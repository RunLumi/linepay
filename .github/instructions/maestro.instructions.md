---
applyTo: ".maestro/**/*.yaml,scripts/test-ios-maestro.sh"
---

# Maestro instructions

Read `docs/maestro.md` before editing E2E flows.

- Maestro is for critical black-box journeys, not payroll arithmetic.
- Prefer stable SwiftUI `.accessibilityIdentifier(...)` values over visible copy.
- Name identifiers by product meaning: `<feature>.<semantic-control>`.
- Keep each flow independent and explicit about fresh state.
- Prefer semantic assertions and `scrollUntilVisible` over fixed sleeps/coordinates.
- Use coordinate taps only for system-level workarounds that cannot be selected semantically.
- Never make one test depend on another test leaving simulator data behind.
- Keep smoke flows short enough to run locally during feature work.
- Store artifacts under `.build/`; never commit screenshots containing real wage/paystub data.
- After changing a flow or its selectors, run `bash scripts/agent-verify.sh ui` when a local Simulator is available.
