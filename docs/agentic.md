# LinePaycheck Agentic Mobile Development Harness

Status: **authoritative harness guidance**  
Last researched: **2026-09-05**

This document describes how LinePaycheck is structured so coding agents can understand the repository quickly, make bounded changes, run the right verification, and visually inspect mobile work without turning the repo into a pile of duplicated prompt files.

## 1. Design goal

The repository should make the correct path the easy path for both humans and agents:

```text
understand task
    ↓
load only relevant context
    ↓
inspect existing pattern
    ↓
make a small coherent change
    ↓
run deterministic verification
    ↓
inspect the real mobile UI when relevant
    ↓
report evidence, not confidence theater
```

The harness must remain useful even when a specific agent vendor, model, IDE, or MCP server changes.

## 2. 2026 research conclusions

### Keep always-on instructions short

OpenAI recommends `AGENTS.md` as persistent repository context and emphasizes improving the development environment so agents can build and verify their own work. GitHub's 2026 guidance similarly recommends short repository-wide instructions and path-specific instructions for specialized concerns.

Large instruction stacks have a real downside: newer coding models are increasingly sensitive to instructions in skills and repository files, so conflicting or overly broad guidance can cause unnecessary pauses or wrong behavior.

LinePaycheck therefore uses:

- a concise root `AGENTS.md` for mission, hard invariants, routing, and verification;
- nearest/path-specific instructions for iOS/domain/test concerns;
- on-demand skills for repeatable specialized workflows;
- detailed durable docs for architecture/design that are read only when relevant.

### Put repeatable workflows in skills

GitHub Agent Skills are folders with `SKILL.md` plus optional scripts/resources. GitHub recommends skills for detailed instructions that should load only when a task is relevant, while repository instructions should contain rules that apply to almost every task.

The Agent Skills format is designed to be portable across agent hosts. LinePaycheck stores project skills under `.agents/skills/` so the workflow knowledge is not coupled to one IDE.

### Give agents executable verification

OpenAI's internal Codex guidance highlights that agents perform better when they can build, test, and validate in their own environment. GitHub says the same for cloud agents: reliable setup/build/test instructions increase the chance of producing mergeable changes.

LinePaycheck therefore exposes one obvious verification surface:

```bash
bash scripts/agent-doctor.sh
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

The scripts are the stable contract. Agents do not need to rediscover Xcode flags every session.

### Mobile agents need a visual feedback loop

Compilation is insufficient for SwiftUI work. A good mobile agent loop needs to:

- build and launch the app;
- inspect simulator/device state;
- capture screenshots;
- inspect accessibility hierarchy;
- interact with controls;
- capture logs;
- run durable E2E flows.

XcodeBuildMCP is an optional local agent tool for fast interactive build/run/debug/UI iteration. Maestro remains the checked-in black-box E2E regression layer because YAML flows are reviewable and independent of a particular coding agent.

### Stable accessibility identifiers are agent APIs

Automation should target semantic accessibility identifiers instead of English copy or screen coordinates whenever possible. This improves Maestro stability and also gives interactive agents a clearer accessibility tree.

Identifiers describe product meaning:

```text
onboarding.set-up-pay
pay-profile.hourly-rate
today.add-work
```

Avoid implementation-shaped IDs such as `button3`, `blueCTA`, or `vstack2`.

## 3. Harness map

```text
AGENTS.md                         always-on agent contract
apps/ios/AGENTS.md                nearest iOS instructions

.github/
  copilot-instructions.md         compact GitHub/Xcode Copilot context
  instructions/                   path-specific Copilot rules
  agents/                         specialized Copilot agent profiles
  pull_request_template.md        reviewable handoff contract

.agents/
  skills/                         portable on-demand Agent Skills

.xcodebuildmcp/
  config.yaml                     local iOS agent session defaults

scripts/
  agent-context.sh                cheap context snapshot
  agent-doctor.sh                 environment/harness validation
  agent-verify.sh                 verification router
  check-ios.sh                    full native iOS gate
  test-ios-maestro.sh             build/install/E2E smoke gate

docs/
  agentic.md                      this guide
  best-practices.md               iOS engineering rules
  maestro.md                      local Maestro workflow
  plan/ios-1.0.md                 current product implementation plan
```

## 4. Context routing

Agents should not read the whole repository documentation corpus before every change.

### Universal context

Read `AGENTS.md` first.

### iOS implementation

Also read:

- `apps/ios/AGENTS.md`
- `docs/best-practices.md`

### User-facing UI

Also read:

- `DESIGN.md`
- `.agents/skills/mobile-ui-qa/SKILL.md` when verification is involved

### Pay calculation / rule engine

Use:

- `.agents/skills/payroll-domain/SKILL.md`
- existing `LinePayDomain` tests and fixtures

### Release work

Use:

- `.agents/skills/release-readiness/SKILL.md`
- `docs/checklists/ios-before-first-testflight.md`

This progressive-disclosure structure reduces token/context waste and reduces the chance of irrelevant guidance influencing a task.

## 5. Normal agent loop

### Step 1: establish context

```bash
bash scripts/agent-context.sh
```

This prints the product/technical identity, branch/status/diff summary, toolchain availability, and the canonical verification commands.

### Step 2: inspect before editing

Find:

- the nearest similar implementation;
- relevant tests;
- the smallest domain/UI boundary affected;
- any existing ADR or product-plan decision.

Do not create a new architecture because search was inconvenient.

### Step 3: implement a vertical slice

Prefer a coherent behavior that can be verified end-to-end over many partially wired files.

For example:

```text
work fact
  ↓
application intent
  ↓
domain calculation
  ↓
observable state
  ↓
real SwiftUI result
```

### Step 4: verify proportional to risk

Use the narrowest tier that proves the task:

```bash
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

Do not run the slowest tier repeatedly after it has passed unless later edits invalidate the result.

### Step 5: inspect the result

For user-facing work, compilation is not completion.

If XcodeBuildMCP is available, prefer it for iterative build/run/screenshot/accessibility inspection. Otherwise use the normal Simulator and Maestro workflow.

For a critical journey, run the checked-in Maestro flow rather than relying only on a one-off manual tap path.

### Step 6: hand off evidence

A useful completion report states:

- what changed;
- important architectural/product choice made;
- exact verification that ran and passed;
- screenshots/visual observations when relevant;
- any real limitation or deferred work.

Never write “should pass” as a substitute for running a test that is available.

## 6. Verification tiers

### `quick`

Use for pure domain changes and early iteration.

Expected work:

- strict Swift formatting;
- `LinePayDomain` tests.

### `ios`

Use for app-layer changes.

Delegates to the repository's native iOS gate, including:

- toolchain/version check;
- format lint;
- privacy manifest validation;
- domain tests;
- XcodeGen generation;
- app tests on Simulator;
- privacy-manifest bundle check;
- Release build.

### `ui`

Use for critical user-facing flows and Maestro changes.

Runs the native gate and then the local Maestro build/install/smoke workflow.

## 7. XcodeBuildMCP

LinePaycheck includes `.xcodebuildmcp/config.yaml` as optional local-agent configuration.

Why it is useful:

- avoids repeatedly rediscovering the project/scheme/bundle ID;
- offers combined build-and-run simulator workflows;
- captures structured build/test outputs;
- can capture simulator screenshots and logs;
- can inspect accessibility hierarchy and interact with the UI when the UI-automation workflow is enabled;
- can attach LLDB/debugging tools when explicitly needed.

The repository pins project defaults, not the XcodeBuildMCP binary version. Developer/agent environments may install a current compatible release.

Install examples are documented by XcodeBuildMCP itself. The harness does not auto-install or auto-execute third-party MCP software.

### Source-of-truth rule

XcodeBuildMCP is an ergonomic interface over local Apple tooling. It does not replace:

- `apps/ios/project.yml` as project source of truth;
- `scripts/check-ios.sh` as the native quality gate;
- checked-in tests;
- Maestro YAML as E2E regression source of truth.

If MCP behavior disagrees with repository scripts, debug the discrepancy rather than weakening the scripts.

## 8. Maestro and Maestro MCP

LinePaycheck's committed Maestro flows live in `.maestro/`.

The CLI workflow is documented in `docs/maestro.md` and is always sufficient to run the suite.

Maestro also provides an MCP server for coding agents. It can be useful when an agent is authoring or debugging a flow interactively, but the resulting test must still be represented by checked-in YAML when it is intended as regression coverage.

Use the right layer:

```text
XcodeBuildMCP       interactive iOS build/run/debug/inspect loop
Maestro CLI/YAML    durable black-box regression contract
Maestro MCP         optional interactive flow authoring/debugging
Swift Testing       deterministic domain/app correctness
```

Do not turn screenshots into the primary assertion mechanism for payroll correctness.

## 9. Skills

Project skills live in `.agents/skills/`.

### `ios-feature`

Use when implementing or materially changing a native iOS feature.

It focuses the agent on:

- product-plan fit;
- existing patterns;
- state ownership;
- minimal architecture;
- appropriate tests;
- visual inspection.

### `payroll-domain`

Use for money/time/rule/reconciliation changes.

It requires:

- explicit semantics;
- deterministic fixtures;
- exact money;
- timezone-boundary thinking;
- regression tests;
- no platform dependencies in the engine.

### `mobile-ui-qa`

Use for SwiftUI UX and end-to-end verification.

It separates:

- visual/manual agent inspection;
- accessibility-tree quality;
- checked-in Maestro regression coverage.

### `release-readiness`

Use for TestFlight/App Store/release configuration work.

It forces validation of bundle identity, privacy manifest, Release build, versioning, signing assumptions, StoreKit state, and final critical flows.

## 10. Custom agent profiles

`.github/agents/` provides optional specialized profiles for GitHub Copilot cloud/CLI/app environments.

These profiles do not contain a second copy of project architecture. They point the specialist toward the same canonical contract and skills.

Specialization should reduce irrelevant reasoning, not fork project truth.

## 11. Cross-agent compatibility

The repo supports common 2026 discovery conventions without duplicating policy:

- `AGENTS.md` is canonical;
- `.github/copilot-instructions.md` gives Copilot/Xcode a compact entry point;
- `.github/instructions/*.instructions.md` supplies path-specific Copilot context;
- `CLAUDE.md` and `GEMINI.md` are tiny compatibility pointers, not alternate constitutions;
- `.agents/skills/` contains portable task workflows.

If a host supports only one of these surfaces, it should still find enough information to discover the canonical files and commands.

## 12. Prompt/task quality

Agent tasks should look like good engineering issues.

Include when known:

- desired user outcome;
- relevant screen/module/path;
- observed current behavior;
- acceptance behavior;
- constraints or invariants;
- screenshot/mockup when visual precision matters.

Avoid prescribing an architecture unless that architecture itself is the requirement.

Good:

> On `TodayView`, let a worker duplicate yesterday's regular shift with one action. Preserve the payroll timezone and create a new stable work-event ID. Follow `DESIGN.md`. Add an app-model test and visually verify the resulting row.

Weak:

> Add a reusable ShiftDuplicationManager protocol and coordinator.

## 13. Agent security and supply-chain rules

Agentic repositories introduce a new dependency class: instructions and skills.

Treat third-party skills/MCP servers like executable development dependencies:

- inspect before installing;
- prefer pinned/reviewed versions for automation;
- do not auto-run arbitrary skill scripts from untrusted repositories;
- keep network access minimal where the task does not require it;
- never put secrets in prompts, fixtures, screenshots, logs, skill files, or MCP configuration;
- keep user wage/paystub data out of agent examples and tests;
- do not grant an agent write access to external systems merely for convenience.

GitHub explicitly warns that third-party Agent Skills may contain malicious instructions or scripts. Review skill contents before installation.

## 14. What the harness intentionally avoids

We do not add tooling merely because agents can use it.

Avoid by default:

- a custom agent framework inside the product repo;
- a bespoke task database;
- generated context dumps committed to git;
- giant all-purpose prompt files;
- duplicate architecture rules across vendor-specific instruction files;
- always-on MCP dependencies in CI;
- an autonomous deploy/release path without review;
- visual-regression infrastructure before the product has stable screens worth snapshotting.

The best harness is one that makes good engineering behavior easy while staying smaller than the product it helps build.

## 15. Research sources

Primary/current sources used for this 2026 harness:

- OpenAI, **How OpenAI uses Codex**: https://openai.com/business/guides-and-resources/how-openai-uses-codex/
- OpenAI, **Codex upgrades / environment and MCP**: https://openai.com/index/introducing-upgrades-to-codex/
- OpenAI developer model guidance on instruction stacks, autonomy, and verification: https://developers.openai.com/api/docs/guides/latest-model
- GitHub, **Best practices for using Copilot to work on tasks**: https://docs.github.com/en/copilot/tutorials/cloud-agent/get-the-best-results
- GitHub, **Repository custom instructions**: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions
- GitHub, **Agent Skills**: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
- GitHub, **Custom agents**: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/create-custom-agents
- XcodeBuildMCP: https://github.com/getsentry/XcodeBuildMCP
- Maestro MCP: https://github.com/mobile-dev-inc/maestro-docs/blob/main/introduction/get-started/maestro-mcp.md

Research-derived recommendations are adapted to LinePaycheck's specific constraints: a native SwiftUI app, correctness-sensitive pay calculations, local-first privacy, and a deliberately small runtime dependency surface.
