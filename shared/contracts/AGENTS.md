# Shared contracts agent instructions

The repository-root `AGENTS.md` remains authoritative. `shared/contracts` is the behavioral treaty between native clients, not a shared runtime implementation.

- Keep schemas and fixtures platform-neutral and deterministic.
- Make money/currency, timestamps/timezones, rule-set versions, rounding, and provenance explicit.
- Canonical fixtures describe inputs, expected pay components/totals, and expected explanations/references.
- Do not add Swift-, Kotlin-, SwiftData-, Room-, UIKit-, or Compose-specific representation details.
- A contract change must preserve compatibility deliberately or version the contract explicitly.
- Never invent pay semantics merely to make both platforms agree.

When a contract affects payroll behavior, use `.agents/skills/payroll-domain/SKILL.md` and update deterministic tests/fixtures together.
