# Maestro agent instructions

The repository-root `AGENTS.md` remains authoritative. Before changing flows, read `docs/maestro.md` and `.agents/skills/mobile-ui-qa/SKILL.md`.

- Test critical black-box user journeys, not payroll arithmetic.
- Prefer semantic accessibility identifiers over visible copy or coordinates.
- Keep each flow independent and explicit about fresh state.
- Prefer semantic waits/assertions over fixed sleeps.
- Use synthetic data only; never commit real wage/paystub content in flows or artifacts.
- Keep smoke coverage small, reviewable, and fast.

After changing Maestro flows or their SwiftUI selectors, run `bash scripts/agent-verify.sh ui` when a local Simulator is available. If it is unavailable, state that limitation explicitly.
