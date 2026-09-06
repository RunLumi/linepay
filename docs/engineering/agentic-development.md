# LinePaycheck Agentic Mobile Development Harness

Status: **authoritative harness guidance**  
Last researched: **2026-09-05**

This document defines how LinePaycheck is shaped so coding agents can understand the repository quickly, make bounded changes, verify them at the cheapest correct layer, and inspect the real mobile product without turning the repository into a pile of duplicated prompt files.

## 1. Design goal

The correct path should also be the easiest path:

```text
understand task
    ↓
load only relevant context
    ↓
inspect existing implementation/tests
    ↓
make a small coherent change
    ↓
run deterministic verification
    ↓
inspect the real mobile UI when relevant
    ↓
report evidence, not confidence theater
```

The harness must remain useful when a particular model, IDE, agent vendor, or MCP server changes.

## 2. 2026 conclusions applied here

### Keep always-on context small

Repository instructions should contain durable rules that apply broadly. Detailed procedures belong in path-specific instructions, skills, or focused docs.

LinePaycheck therefore uses:

- `AGENTS.md` for mission, invariants, routing, and verification;
- nearest `AGENTS.md` files for strong local boundaries;
- `.github/instructions/` for GitHub/Copilot path-specific rules;
- `.agents/skills/` for task workflows loaded only when relevant;
- specialist agents for isolated review/implementation contexts;
- detailed architecture/design docs only when the task needs them.

`AGENTS.md` has a CI-enforced size budget so it cannot quietly grow back into an all-purpose prompt.

### Skills and specialist agents solve different problems

Skills are reusable procedures. Specialist agents are isolated workers with a focused role and their own context.

Use a skill when the same workflow repeats, for example payroll-domain review or mobile UI QA. Use a specialist agent when an isolated lens is useful, for example a payroll correctness reviewer after an implementation change.

### Give agents executable feedback

An agent should not need to reconstruct Xcode flags every session. Stable checked-in commands are the contract:

```bash
bash scripts/agent-context.sh
bash scripts/agent-doctor.sh
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

### Mobile work needs a rendered-product loop

SwiftUI compilation is not visual verification. For user-facing work the ideal loop is:

```text
build + launch
    ↓
inspect screenshot
    ↓
inspect accessibility hierarchy
    ↓
interact with real controls
    ↓
inspect logs/state
    ↓
fix
    ↓
run durable E2E journey when appropriate
```

XcodeBuildMCP is the optional interactive layer. Maestro YAML is the durable black-box regression layer.

### Accessibility identifiers are an automation API

Critical controls should expose semantic identifiers such as:

```text
onboarding.set-up-pay
pay-profile.hourly-rate
today.add-work
```

Do not use implementation-shaped identifiers such as `button3`, `blueCTA`, or `vstack2`.

## 3. Harness map

```text
AGENTS.md                              canonical repository contract
CLAUDE.md / GEMINI.md                  thin compatibility entry points
apps/ios/AGENTS.md                     iOS boundary
apps/ios/Packages/LinePayDomain/AGENTS.md
shared/contracts/AGENTS.md             cross-platform behavior boundary
.maestro/AGENTS.md                     E2E boundary
apps/android/AGENTS.md                 explicit deferred-scope guard

.agents/skills/                        canonical task workflows
  ios-feature/
  payroll-domain/
  mobile-ui-qa/
  release-readiness/

.github/instructions/                  path-specific Copilot rules
.github/agents/                        Copilot specialist agents
.claude/agents/                        Claude project specialist agents

.mcp.json                              shared Claude-compatible project MCP
.codex/config.toml                     Codex project MCP
.gemini/settings.json                  Gemini workspace MCP
.xcodebuildmcp/config.yaml             iOS agent session defaults

scripts/
  agent-context.sh                     cheap repository snapshot
  agent-doctor.sh                      environment + harness diagnosis
  agent-verify.sh                      verification router
  check-agent-harness.sh               harness self-test
  check-ios.sh                         full native iOS gate
  test-ios-maestro.sh                  build/install/E2E smoke gate
  install-xcodegen.sh                  checksum-pinned XcodeGen installer
```

## 4. Context routing

Do not preload the whole documentation corpus.

| Work | Focused context |
|---|---|
| Any task | `AGENTS.md` |
| iOS implementation | `apps/ios/AGENTS.md`, `docs/engineering/ios-best-practices.md` |
| User-facing UI | also `DESIGN.md` |
| Current iOS scope | `docs/plan/ios-1.0.md` |
| Payroll/domain | `.agents/skills/payroll-domain/SKILL.md` |
| New iOS feature | `.agents/skills/ios-feature/SKILL.md` |
| Simulator / Maestro | `.agents/skills/mobile-ui-qa/SKILL.md`, `docs/testing/maestro.md` |
| Release | `.agents/skills/release-readiness/SKILL.md`, TestFlight checklist |
| Harness | this file + `scripts/check-agent-harness.sh` |

Nearest `AGENTS.md` files add local constraints automatically on hosts that support hierarchical agent instructions.

## 5. Normal agent loop

### 1. Establish context

```bash
bash scripts/agent-context.sh
```

This reports immutable product identity, branch/HEAD, **tracked and untracked** working-tree state, tool availability, and verification entry points.

Never assume an untracked file is disposable user work.

### 2. Inspect before editing

Find the nearest implementation, its tests, and relevant plan/ADR. Do not invent a new architecture because repository search was inconvenient.

### 3. Define a bounded observable outcome

Prefer:

> Given X state, when the worker performs Y, LinePaycheck produces Z visible/auditable result.

Then implement that vertical slice completely.

### 4. Verify proportional to risk

```bash
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

Do not rerun the slowest tier after it already passed unless later edits invalidate that evidence.

### 5. Inspect the rendered result

For user-facing work, use XcodeBuildMCP when available for iterative build/run/screenshot/accessibility/log work. Use Maestro for a checked-in critical journey where regression protection is worth its cost.

### 6. Hand off evidence

State:

- what changed;
- the important product/architecture decision;
- exact verification that ran and passed;
- visual observations/screenshots when relevant;
- any genuine limitation.

Never use “should pass” as a substitute for a test that was available to run.

## 6. Verification tiers

### `quick`

For pure domain work and fast iteration:

- strict Swift formatting;
- `LinePayDomain` tests.

### `ios`

For app-layer changes:

- exact XcodeGen toolchain check;
- strict format lint;
- privacy manifest validation;
- domain tests;
- XcodeGen generation;
- app tests on Simulator;
- built-app privacy-manifest check;
- Release configuration build.

### `ui`

For critical user-facing journeys:

- complete native gate;
- build/install on Simulator;
- checked-in Maestro smoke flows.

### Harness integrity

`agent-doctor.sh` runs `check-agent-harness.sh` first. Harness CI also runs the same self-test cheaply on Linux.

## 7. Mobile tool layers

### XcodeBuildMCP

`.xcodebuildmcp/config.yaml` provides project/scheme/simulator/bundle defaults.

Use XcodeBuildMCP for interactive agent work when available:

- combined simulator build/run;
- structured build/test output;
- screenshots;
- accessibility hierarchy;
- UI interaction;
- logs;
- focused debugging/LLDB.

The MCP server is ergonomics, not source of truth. `apps/ios/project.yml`, checked-in tests, and repository verification scripts win if tooling disagrees.

### Maestro

`.maestro/` contains durable black-box journeys. Maestro should answer questions such as “can a fresh user complete onboarding?” rather than prove overtime arithmetic.

Use semantic identifiers and independent fresh-state flows. Keep payroll correctness in deterministic Swift tests.

### MCP portability

The same optional mobile servers are declared for common hosts without copying project policy:

- `.mcp.json` for Claude-compatible project MCP;
- `.codex/config.toml` for Codex;
- `.gemini/settings.json` for Gemini CLI.

They reference local `xcodebuildmcp` and `maestro` commands and contain no secrets.

## 8. Skills and specialists

Canonical workflows live only under `.agents/skills/`:

- `ios-feature`
- `payroll-domain`
- `mobile-ui-qa`
- `release-readiness`

GitHub/Copilot specialists live under `.github/agents/`.

Claude project specialists live under `.claude/agents/` and point back to the same canonical skill files rather than duplicating policy:

- `linepay-ios-engineer`
- `linepay-payroll-reviewer`
- `linepay-mobile-qa`
- `linepay-release-reviewer`

Gemini can discover `.agents/skills/` directly, so no duplicate Gemini skill tree is needed.

Do not create vendor-specific copies of core architecture or payroll rules.

## 9. Instruction-budget rules

Prompt quality degrades when broad instruction files become sprawling or contradictory. The harness self-test currently enforces:

- root `AGENTS.md` <= 12 KB;
- `CLAUDE.md` <= 200 lines;
- canonical skill entrypoints <= 500 lines each.

If a limit is reached, move focused content into a skill/supporting resource or durable doc. Do not simply raise the limit to silence CI.

## 10. Reproducible developer tooling

XcodeGen is part of the build contract, so CI must not silently follow Homebrew latest.

LinePaycheck pins XcodeGen 2.46.0 and provides:

```bash
XCODEGEN_PREFIX="$HOME/.local" bash scripts/install-xcodegen.sh
export PATH="$HOME/.local/bin:$PATH"
```

The installer downloads the official release archive and validates its published SHA-256 before installing it. CI uses this path, and `check-ios.sh` separately verifies the reported version.

Generated `LinePay.xcodeproj` remains disposable.

## 11. Agent security and supply chain

Treat instructions, skills, MCP servers, and CI actions as executable development dependencies.

Rules:

- inspect third-party skills/MCP tooling before adding it;
- never commit secrets to prompts/configs/fixtures;
- never use real wage/paystub data in examples, tests, logs, screenshots, or agent context;
- keep external-system write access off unless the task genuinely needs it;
- do not add permission-bypass defaults for convenience;
- do not auto-run untrusted repository scripts through hooks;
- keep GitHub Actions `GITHUB_TOKEN` permissions minimal;
- pin third-party GitHub Actions to reviewed full commit SHAs;
- disable persisted checkout credentials in read-only CI jobs.

The two checked-in workflows currently use read-only contents permission and an immutable reviewed `actions/checkout` SHA.

## 12. Why there are no automatic agent hooks

Claude/GitHub hooks can enforce workflows, but repository-controlled hooks are executable code that may run automatically after checkout or tool calls. LinePaycheck deliberately uses explicit scripts + CI instead.

Do not add auto-executing hooks merely to make the repo feel more agentic. Add one only when a concrete repeated failure cannot be prevented by the existing explicit gates and the security trade-off is justified.

## 13. Task and PR quality

Agent-ready tasks describe user outcomes and observable acceptance behavior, not premature architecture. Use `.github/ISSUE_TEMPLATE/agent-task.md`.

PRs use `.github/pull_request_template.md` to record:

- user outcome;
- relevant invariants;
- exact verification performed;
- UI evidence when appropriate;
- persistence/migration consequences;
- remaining real limitations.

Check only verification that actually ran.

## 14. What the harness intentionally avoids

Do not add by default:

- a custom agent orchestration framework;
- a bespoke task/memory database;
- giant generated context dumps;
- duplicate vendor constitutions;
- always-on MCP dependencies in CI;
- autonomous App Store deployment without review;
- broad permission-bypass settings;
- automatic repo hooks without a demonstrated need;
- visual snapshot infrastructure before screens are stable enough to justify it;
- Android implementation before demand proves it should exist.

The harness should remain smaller and easier to understand than the product it helps build.

## 15. Research sources

Primary/current sources used for the September 2026 harness:

- OpenAI, Codex development guidance and environment/MCP guidance: https://developers.openai.com/
- GitHub Copilot repository custom instructions, path-specific instructions, Agent Skills, and custom agents: https://docs.github.com/en/copilot
- GitHub Actions secure-use guidance: https://docs.github.com/en/actions/reference/security/secure-use
- Claude Code project subagents, project MCP, and skills: https://code.claude.com/docs/
- Gemini CLI workspace settings and MCP configuration: https://github.com/google-gemini/gemini-cli/tree/main/docs
- XcodeBuildMCP: https://github.com/getsentry/XcodeBuildMCP
- Maestro MCP/CLI documentation: https://docs.maestro.dev/
- XcodeGen 2.46.0 release and archive layout: https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0

Research recommendations are adapted to LinePaycheck's actual constraints: a native SwiftUI app, correctness-sensitive pay calculations, local-first privacy, no central pay-data backend, and a deliberately small runtime dependency surface.
