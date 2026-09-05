# ADR 0002: Deterministic pure pay-rule engine

- Status: Accepted
- Date: 2026-09-05

## Context

LinePay's core trust claim depends on producing reproducible pay calculations from work facts and explicit rules. UI state, persistence objects, OCR guesses, device locale, subscription state, or network responses must not be able to silently alter a result.

## Decision

The pay engine is a pure domain module.

Inputs are explicit values such as:

- work events / shifts;
- pay-period context;
- currency and base rates;
- an immutable version/snapshot of the applicable rule set;
- explicit calendar/timezone context where rules depend on it.

Outputs contain:

- itemized pay components;
- totals;
- applied rule identifiers;
- explanations/evidence references;
- warnings when the inputs are insufficient or ambiguous.

The engine has no dependency on SwiftUI, SwiftData, Vision, StoreKit, networking, analytics, wall-clock globals, or mutable singletons.

## Correctness requirements

- Currency math uses decimal/fixed-point values, never binary floating point.
- Historical calculations retain the exact rule-set version/snapshot used.
- Rounding rules are explicit and testable.
- Time semantics are explicit and covered at boundaries such as midnight, DST, holidays, rest windows, and pay periods.
- Every production money/time bug gets a regression test.

## Consequences

The UI and persistence layers may contain more mapping code, but the most economically consequential logic becomes fast to test, portable in behavior, and auditable.
