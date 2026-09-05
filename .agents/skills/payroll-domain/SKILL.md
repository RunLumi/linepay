---
name: payroll-domain
description: Change or review LinePaycheck pay calculation, time semantics, agreement rules, reconciliation, money types, or canonical payroll fixtures. Use whenever a task can change an expected-pay number or its explanation.
---

# Payroll-domain workflow

This is the highest-correctness part of the product.

## 1. State the semantic change first

Before code, write the rule in plain language with explicit boundaries.

Example shape:

```text
For confirmed rule R, when work event E satisfies condition C,
component P is paid using rate/multiplier M and rounding rule Q.
```

If the source rule is ambiguous, do not invent a resolution. Preserve ambiguity for user confirmation/source review.

## 2. Identify time and money boundaries

Check whether the change depends on:

- midnight / local date;
- payroll timezone;
- DST transition;
- pay-period boundary;
- weekday/holiday classification;
- overlapping work events;
- minimum guarantees;
- tier precedence;
- rate/multiplier composition;
- currency/rounding boundary.

Treat these as explicit semantics, not incidental implementation details.

## 3. Keep the engine pure

`LinePayDomain` must not depend on:

- SwiftUI/UIKit;
- SwiftData;
- StoreKit;
- Vision/OCR;
- network;
- analytics;
- current device locale/timezone;
- implicit current clock.

Inputs contain all facts needed for deterministic output.

## 4. Write the failing/contract test

For a bug, reproduce it before fixing when practical.

For new behavior, add the smallest test table that proves:

- just before the boundary;
- exactly at the boundary;
- just after the boundary;
- relevant negative/non-applicable case.

Use Swift Testing parameterization when several rows express the same rule.

Use synthetic values only. Never copy a real worker's paystub into fixtures.

## 5. Preserve explainability

A correct total without an auditable explanation is incomplete.

Ensure the result can expose:

- work fact/event;
- rule/version applied;
- rate/multiplier/minimum;
- pay component;
- source/reference metadata when available.

Do not collapse raw facts into only a final total if doing so prevents later audit/recalculation.

## 6. Preserve history

If a change modifies agreement/rule meaning, create a new version/snapshot representation rather than silently mutating historical results.

Persistence migrations must preserve enough original facts and version IDs to reproduce prior calculations.

## 7. Verify

At minimum:

```bash
bash scripts/agent-verify.sh quick
```

If app orchestration/persistence/UI also changed:

```bash
bash scripts/agent-verify.sh ios
```

Before handoff, inspect the changed test cases and calculation diff. State the exact semantic rule that changed.
