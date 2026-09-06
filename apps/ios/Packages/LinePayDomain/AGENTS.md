# LinePayDomain agent instructions

The repository-root `AGENTS.md` remains authoritative. For any change in this package, also read and follow `.agents/skills/payroll-domain/SKILL.md`.

This package is a pure deterministic correctness boundary:

- never use `Double`/`Float` for money;
- keep currency, rounding, instants, and payroll timezone semantics explicit;
- never invent or infer agreement rules that are not represented by inputs;
- preserve reproducibility of historical rule snapshots;
- do not import SwiftUI, SwiftData, StoreKit, Vision, networking, analytics, device state, locale, or wall-clock dependencies;
- prefer value types and `Sendable` domain values;
- add focused boundary/regression tests for any money, time, rule-precedence, or reconciliation behavior change.

Run `bash scripts/agent-verify.sh quick` at minimum after package changes. Broaden to the iOS gate when app-facing contracts change.

## Product rule references

Read the [payroll contract](../../../../docs/product/payroll/README.md), [coverage limits](../../../../docs/product/payroll/coverage-and-gaps.md), and [source approval](../../../../docs/product/payroll/sources.md) before changing wage or audit behavior. A configured daily premium is not a complete federal weekly-overtime implementation. Link relevant business-rule/example IDs in regressions; preserve scoped conclusions.
