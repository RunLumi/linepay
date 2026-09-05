---
applyTo: "apps/ios/Packages/LinePayDomain/**/*.swift,shared/contracts/**/*"
---

# Payroll-domain instructions

Treat this code as correctness-sensitive financial/time logic.

- Never use `Double` or `Float` for money.
- Keep currency metadata explicit.
- Keep time instants and payroll-relevant timezone semantics explicit.
- Do not read device locale, current clock, UI state, persistence, network, StoreKit, Vision, or analytics from the domain engine.
- Rule semantics must be explicit and deterministic. Do not infer or invent agreement terms.
- Historical behavior must remain reproducible from versioned inputs/rule snapshots.
- Every bug or semantic change involving money, time, rule precedence, reconciliation, or boundaries needs a meaningful regression test.
- Prefer parameterized Swift Testing cases and canonical fixtures for boundary tables.
- When Android exists, cross-platform parity is established through `shared/contracts` fixtures, not by forcing shared runtime implementation.
- Run `bash scripts/agent-verify.sh quick` at minimum after domain changes.

For a focused workflow, use `.agents/skills/payroll-domain/SKILL.md`.
