---
name: ios-feature
description: Implement or materially change a LinePaycheck native iOS feature. Use for SwiftUI screens, app state, navigation, adapters, StoreKit, persistence, OCR, export, or other iOS product work.
---

# LinePaycheck iOS feature workflow

Use this workflow for a real product slice, not for a trivial typo.

## 1. Load focused context

Read:

- `AGENTS.md`
- `apps/ios/AGENTS.md`
- `docs/best-practices.md`
- `docs/plan/ios-1.0.md` when scope/sequence matters
- `DESIGN.md` when the change is user-facing

Do not preload unrelated research/docs.

## 2. Inspect before designing

Find the nearest existing feature pattern and its tests. Identify:

- source of truth for state;
- domain behavior already available;
- adapter boundary if platform APIs are involved;
- existing accessibility/test selector pattern;
- the product invariant most likely to be violated.

Prefer extending a clear existing seam over introducing a new layer.

## 3. Define the smallest coherent behavior

Write a short internal acceptance statement such as:

> Given X state, when the worker performs Y, LinePaycheck produces Z visible/auditable result.

Implement that vertical slice completely. Avoid scattering placeholders across future features.

## 4. Preserve architecture

- SwiftUI renders observable state and sends intent.
- `AppModel` may coordinate small app behavior while it remains cohesive.
- Payroll calculations belong in `LinePayDomain`.
- Platform adapters own SwiftData/Vision/StoreKit/Files details.
- Do not add a protocol, repository, manager, coordinator, or dependency merely for symmetry.
- Keep public brand `LinePaycheck`; keep technical bundle/scheme/module identifiers unchanged.

## 5. Test at the cheapest useful layer

- Domain semantics: pure Swift Testing tests.
- App orchestration: app test target.
- Persistence migrations / OCR / StoreKit adapters: focused integration tests.
- Critical journey: Maestro only when black-box UI behavior is what needs proof.

Do not make E2E tests carry arithmetic correctness.

## 6. Inspect user-facing work

When simulator tooling is available:

1. build and launch the real app;
2. navigate through changed states;
3. inspect light/dark mode when relevant;
4. inspect Dynamic Type/long content risk;
5. inspect accessibility hierarchy/identifiers;
6. capture a screenshot when visual review materially helps;
7. fix obvious hierarchy, spacing, clipping, keyboard, sheet, or state-transition problems before handoff.

Prefer XcodeBuildMCP for iterative agent interaction if available. Use checked-in Maestro flows for durable regression coverage.

## 7. Verify once at the right breadth

During iteration, run focused tests. Before handoff:

```bash
bash scripts/agent-verify.sh ios
```

For a critical UI journey or Maestro change:

```bash
bash scripts/agent-verify.sh ui
```

Do not repeat the full gate after it passes unless subsequent edits could invalidate it.

## 8. Handoff

Report:

- user-visible behavior changed;
- important design/architecture choice;
- tests/builds actually run;
- simulator/visual verification performed;
- any real unresolved limitation.
