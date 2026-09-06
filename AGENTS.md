# AGENTS.md — LinePaycheck Agent Contract

This file is the repository-wide operating contract for coding agents and contributors. Keep it short, stable, and executable. Detailed guidance is routed to focused docs and skills instead of being repeated here.

## Mission

Build the smallest trustworthy product that helps a worker answer:

> Given the work I actually performed and the pay rules I explicitly confirmed, what pay should I expect, and where might my paycheck differ?

LinePaycheck is a calculation and reconciliation tool. It is not payroll software, legal advice, a union authority, or an autonomous contract interpreter.

## Brand and technical identity

These are deliberately different:

- Public product name: **LinePaycheck**
- Repository: `streamentry/linepay`
- iOS bundle ID: **`com.streamentry.linepay`**
- Xcode project / scheme / target: `LinePay`
- Swift package: `LinePayDomain`
- Existing StoreKit product IDs may keep the `linepay.*` namespace

Do not rename technical identifiers merely to match the public brand. Never change the bundle ID unless the user explicitly asks for that exact migration.

## Start every task here

1. Run `bash scripts/agent-context.sh` if you have a local checkout.
2. Read only the instruction files relevant to the files you will touch.
3. Inspect existing code/tests before designing a new abstraction.
4. Make the smallest coherent change that fully satisfies the task.
5. Run verification proportional to risk before reporting completion.

For local environment problems, run:

```bash
bash scripts/agent-doctor.sh
```

## Instruction routing

Do not load every document for every task.

| Work | Read / use |
|---|---|
| Product behavior / business rules | [Product handbook](docs/product/README.md), [business rules](docs/product/business-rules.md) |
| Payroll applicability / legal scope | [Legal baseline](docs/product/payroll/us-legal-baseline.md), [coverage](docs/product/payroll/coverage-and-gaps.md), [sources](docs/product/payroll/sources.md) |
| Documentation changes | [Documentation map](docs/README.md), [docs agent contract](docs/AGENTS.md) |
| Any iOS engineering | `apps/ios/AGENTS.md`, `docs/engineering/ios-best-practices.md` |
| User-facing iOS UI | also `DESIGN.md` |
| Current iOS product scope | `docs/plan/ios-1.0.md` |
| Pay rules / calculations / reconciliation | `.agents/skills/payroll-domain/SKILL.md` |
| New iOS feature | `.agents/skills/ios-feature/SKILL.md` |
| Simulator / visual / Maestro QA | `.agents/skills/mobile-ui-qa/SKILL.md`, `docs/testing/maestro.md` |
| TestFlight / release work | `.agents/skills/release-readiness/SKILL.md`, `docs/release/checklists/ios-before-first-testflight.md` |
| Agent harness itself | `docs/engineering/agentic-development.md` |

Nearest `AGENTS.md` instructions apply in addition to this root contract.

## Product invariants

These outrank implementation convenience.

1. **Never invent a pay rule.** Rules come from explicit user input or a source-backed, versioned preset.
2. **Never silently rewrite history.** A historical result must remain reproducible from its work facts and exact rule snapshot/version.
3. **Money is exact.** Never use binary floating point for pay math. Use `Decimal` or an explicit fixed-point representation with currency metadata.
4. **Time is explicit.** Preserve instants plus the payroll-relevant timezone/context. Never reinterpret old work using the device's current timezone.
5. **OCR is evidence, not truth.** Materially uncertain fields require confirmation and provenance.
6. **The rule engine stays pure and deterministic.** No SwiftUI, SwiftData, StoreKit, Vision, network, analytics, clock, locale, or device dependency inside pay calculation logic.
7. **Privacy by architecture.** Wage, shift, agreement, and paystub data stay device-local by default. No central LinePaycheck account/pay-data backend, ad SDK, or tracking SDK without a deliberate architecture decision.
8. **Explain discrepancies.** Results must trace to work facts, applied rules, calculation steps, and source/reference metadata.
9. **Estimate, do not adjudicate.** Use language such as expected, estimated, or possible discrepancy unless a fact is directly confirmed.
10. **Native clients first.** iOS and Android may share contracts, fixtures, and behavior specs before they share runtime implementation.

## Payroll coverage and product craft

Use the product handbook before changing a pay number or verdict. A configured-rules estimate is not automatically a complete US legal-pay audit. Federal weekly overtime, regular-rate treatment, jurisdiction and agreement applicability are independent obligations; unconfigured is not waived. Preserve explicit unsupported coverage and never fabricate professional or union verification.

Make LinePaycheck exceptionally clear, fast, reliable, and recoverable. Apply Pareto efficiency to complexity, not to correctness, privacy, evidence, migration safety, or accessibility. Spend disproportionate craft on the few interactions that earn worker trust.

## Architecture boundary

```text
SwiftUI features
      ↓
small application orchestration
      ↓
LinePayDomain
      ↑
adapters: SwiftData / Vision / StoreKit / Files
```

Rules:

- Views render state and send intent. They do not contain payroll algorithms.
- `LinePayDomain` remains platform-independent and pure.
- Persistence models are adapters, not domain models.
- Introduce protocols/abstractions when they create a real ownership or test seam, not to imitate an architecture diagram.
- Prefer Apple frameworks and no dependency over convenience dependencies.
- Do not add backend infrastructure for hypothetical future requirements.

## iOS baseline

- Xcode 26.6, Swift 6.3 compiler, Swift 6 language mode.
- iOS 18+.
- SwiftUI + Observation.
- Strict concurrency and warnings-as-errors stay enabled.
- XcodeGen `2.46.0` owns project generation; generated `.xcodeproj` is disposable.
- Swift Testing for deterministic unit/integration tests.
- Maestro for a small number of black-box critical journeys.
- `PrivacyInfo.xcprivacy` is release-critical.

Do not silence concurrency diagnostics with `@unchecked Sendable` unless the invariant is proven and documented.

## Mobile feedback loop

When available, prefer **XcodeBuildMCP** for interactive agent work because it can build/run the simulator, capture logs/screenshots, inspect the accessibility hierarchy, and interact with the app. Repository defaults live in `.xcodebuildmcp/config.yaml`.

Use **Maestro** as the checked-in, tool-agnostic E2E regression layer. Accessibility identifiers are stable automation API; visible copy is not.

MCP tools are optional developer ergonomics. CI and repository correctness must remain reproducible with checked-in scripts and standard command-line tools.

## Verification by risk

Use the narrowest verification that actually proves the change. Do not repeatedly run expensive suites after they already passed unless later edits invalidate the result.

```bash
# environment + harness checks
bash scripts/agent-doctor.sh

# formatting + pure domain tests
bash scripts/agent-verify.sh quick

# full native iOS quality gate
bash scripts/agent-verify.sh ios

# native gate + simulator Maestro smoke suite
bash scripts/agent-verify.sh ui
```

Minimum expectations:

| Change | Verification |
|---|---|
| Docs / comments only | review diff; no Xcode build unless docs alter commands/config |
| Domain/pay math | `agent-verify.sh quick` + focused regression tests |
| App state / StoreKit / persistence adapter | `agent-verify.sh ios` |
| User-facing SwiftUI flow | `agent-verify.sh ios` + visual/simulator inspection; run `ui` for critical journeys |
| Maestro flow/selectors | `agent-verify.sh ui` |
| Schema migration | migration fixtures + `agent-verify.sh ios` |
| Release/config/privacy | full native gate + release checklist |

Every bug involving money, time, rule interpretation, migration, or data loss gets a meaningful regression test.

## UI and product quality

For user-facing work, `DESIGN.md` is authoritative.

- Preserve **Precision Industrial Minimalism**.
- Prefer system behavior, strong hierarchy, rows/dividers/ledger structure, Dynamic Type, and semantic design tokens.
- Important numeric values use appropriate monospaced digits.
- Never communicate status with color alone.
- Keep frequent actions comfortably tappable for tired, one-handed use.
- No generic AI/fintech visual language, fake AI personality, sparkle motifs, gratuitous glass/gradients, or decorative dashboards.
- Empty, loading, error, uncertain-OCR, and discrepancy states must look intentional.

For a UI change, do not stop at compilation when simulator inspection is available. Look at the actual screen and interaction.

## Agent execution protocol

Agents should bias toward completing authorized, reversible work rather than stopping after a plan.

Before editing:

- inspect `git status` / current diff and do not overwrite unrelated user work;
- locate the nearest existing implementation/test pattern;
- identify which invariant is most at risk;
- decide the cheapest meaningful verification.

While editing:

- keep the diff narrow;
- avoid unrelated refactors and broad formatting churn;
- preserve public behavior unless the task requests a change;
- add comments only when they explain a non-obvious invariant or trade-off;
- never put secrets or real wage/paystub data in code, fixtures, logs, screenshots, or tests.

Before handoff:

- inspect the final diff;
- run the appropriate verification tier;
- remove accidental complexity and dead code;
- state what changed, what was verified, and any real remaining limitation;
- never claim a test/build passed unless it actually ran and passed.

## Change discipline

Create or update an ADR when a change materially affects:

- module/dependency boundaries;
- persistence format or migration policy;
- privacy/data-flow architecture;
- pay-rule representation;
- bundle/application identity;
- cross-platform strategy;
- a new runtime dependency that becomes architectural.

Do not create process artifacts for trivial reversible choices.

## Complexity budget

Every abstraction, dependency, service, state, screen, database model, network request, and background process spends complexity.

Prefer the simplest reversible option that preserves correctness, trust, privacy, and data safety. Invest extra complexity when it creates a compounding asset such as canonical payroll fixtures, migration safety, source provenance, accessibility foundations, or verified agreement data.

Anti-goals until real evidence requires them:

- central user accounts/backend for core pay data;
- employer dashboards;
- generic AI chat;
- cross-platform UI framework;
- microservices;
- elaborate DI/service-locator frameworks;
- generic plugin/event-bus architecture;
- remote feature-flag or analytics platforms.

LinePaycheck should remain a small, trustworthy precision tool for expensive hours.
