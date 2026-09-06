---
name: mobile-ui-qa
description: Visually and behaviorally verify LinePaycheck iOS UI in Simulator and maintain Maestro flows. Use for SwiftUI layout, navigation, onboarding, sheets, forms, accessibility selectors, visual polish, or E2E regression work.
---

# LinePaycheck mobile UI QA workflow

Compilation is necessary but insufficient for user-facing work.

## 1. Read the UI contract

Read:

- `DESIGN.md`
- `apps/ios/AGENTS.md`
- `docs/testing/maestro.md` when authoring/regressing a critical journey

Know the intended screen/state before judging pixels.

## 2. Build and launch the real app

If XcodeBuildMCP is available, use its simulator workflow and the repository defaults in `.xcodebuildmcp/config.yaml`.

Otherwise use the checked-in local build/Simulator workflow.

Do not validate a UI only from SwiftUI source code or a static mental model.

## 3. Inspect semantic UI first

Check:

- correct visible state and navigation;
- stable accessibility identifiers for critical controls;
- useful VoiceOver labels/hints where a control is not self-explanatory;
- no reliance on color alone;
- controls remain reachable with the keyboard presented;
- sheet dismissal and back navigation are sane;
- long/localized content has room to grow;
- frequent actions have comfortable hit targets.

## 4. Inspect visual craft

Against `DESIGN.md`, check:

- hierarchy is obvious before reading every label;
- money/hours are scannable;
- ledger structure reads as evidence, not decoration;
- spacing rhythm is calm and consistent;
- surfaces do not devolve into generic card grids;
- no accidental gradients/glow/sparkle/AI-fintech styling;
- brand color is restrained and semantic status colors are not confused with branding;
- light and dark appearances remain legible when the changed screen supports both.

Use screenshots to review actual rendered output, not as a substitute for semantic assertions.

## 5. Test important state variants

For the changed surface, exercise the meaningful states that exist now, such as:

- empty;
- populated;
- error/invalid input;
- long values;
- uncertain OCR;
- possible discrepancy;
- subscription unavailable;
- edit/cancel/save.

Do not manufacture speculative states that the product does not support yet.

## 6. Maintain Maestro only for durable journeys

A Maestro flow should prove a user journey whose breakage would be expensive or embarrassing.

Prefer:

```yaml
- tapOn:
    id: today.add-work
```

rather than text or coordinates.

Flows must:

- establish their own starting state;
- be order-independent;
- avoid fixed sleeps when semantic waiting works;
- stay focused and short;
- store artifacts under `.build/`;
- use synthetic data.

## 7. Verification

For critical UI flows:

```bash
bash scripts/agent-verify.sh ui
```

If Maestro is unavailable but the native gate and manual simulator inspection succeeded, report that limitation explicitly rather than claiming E2E passed.

## 8. Handoff evidence

Report the actual device/simulator and state inspected, the flow run, and any visual/accessibility issue fixed. Do not report “looks good” without saying what was inspected.
