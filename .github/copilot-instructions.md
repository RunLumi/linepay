# LinePaycheck repository instructions

Public product name is **LinePaycheck**. Technical identifiers intentionally remain `LinePay`: bundle ID `com.streamentry.linepay`, Xcode scheme/target `LinePay`, Swift package `LinePayDomain`, repository `streamentry/linepay`. Do not rename those unless explicitly requested.

Read `AGENTS.md` before implementation. It is the canonical repository-wide agent contract. For iOS work also read `apps/ios/AGENTS.md` and `docs/engineering/ios-best-practices.md`; for user-facing UI also read `DESIGN.md`.

## Core constraints

- Never invent a pay rule or silently change historical calculation meaning.
- Use exact decimal/fixed-point money, never binary floating point for pay math.
- Preserve payroll-relevant timezone semantics.
- Keep `LinePayDomain` pure and deterministic with no SwiftUI/SwiftData/StoreKit/Vision/network dependencies.
- Wage, shift, agreement, and paystub data stay local by default.
- Keep the iOS app native SwiftUI and avoid speculative abstractions/dependencies.
- Preserve Swift 6 strict concurrency and warnings-as-errors.
- Generated `LinePay.xcodeproj` is disposable; edit `apps/ios/project.yml` instead.
- Do not overwrite unrelated working-tree changes or mix broad refactors into a feature.

## Verification

Use checked-in commands rather than inventing build flags:

```bash
bash scripts/agent-context.sh
bash scripts/agent-doctor.sh
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

Choose verification proportional to risk. Domain/pay changes need meaningful deterministic tests. App-layer changes need the native iOS gate. Critical user-facing flows should also be inspected in the simulator and covered by Maestro where appropriate.

When a build/test is available, do not claim it passes without running it. Report the exact verification performed.

## Product craft

LinePaycheck is a calm precision field instrument, not a generic fintech or AI app. Follow `DESIGN.md`: strong hierarchy, ledger structure, semantic design tokens, Dynamic Type, accessible controls, restrained motion, no generic AI visual language.
