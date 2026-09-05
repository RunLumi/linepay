# LinePaycheck

**Private, agreement-aware paycheck auditing for linemen.**

LinePaycheck records work facts, applies explicit pay rules, calculates expected pay, and helps reconcile a paystub without sending wage or paystub data to a LinePaycheck backend.

> Internal repository, module, scheme, and bundle identifiers intentionally remain `LinePay` / `com.streamentry.linepay` to preserve technical stability. The shipping product name is **LinePaycheck**.

## Product invariant

> The app may estimate and explain. It must never silently invent a pay rule or present an unverified rule as a legal entitlement.

## Monorepo

```text
apps/
  ios/          Native SwiftUI app, first shipping platform
  android/      Native Kotlin/Compose app, added after demand is proven
shared/
  contracts/    Platform-neutral schemas and fixtures, not shared runtime code
docs/
  adr/          Architectural decision records
  research/     Source-backed product/technical research
scripts/        Reproducible developer and agent checks
```

We intentionally do **not** share UI or platform runtime code between iOS and Android. What may be shared is the specification: rule schemas, canonical test vectors, fixtures, and behavioral contracts.

## Agentic development

The repository is designed for coding agents that can inspect, implement, build, test, and visually verify mobile work.

Start with:

```bash
bash scripts/agent-context.sh
bash scripts/agent-doctor.sh
```

Then choose the narrowest verification tier that proves the change:

```bash
bash scripts/agent-verify.sh quick   # Swift format + pure payroll-domain tests
bash scripts/agent-verify.sh ios     # full native iOS test/build/privacy gate
bash scripts/agent-verify.sh ui      # native gate + Simulator Maestro smoke suite
```

Agent context is progressively disclosed rather than placed in one giant prompt:

```text
AGENTS.md                     canonical repository contract
apps/ios/AGENTS.md            native iOS scope
.github/instructions/         path-specific Copilot/Xcode guidance
.agents/skills/               on-demand portable workflows
.github/agents/               specialist Copilot subagents
.xcodebuildmcp/config.yaml     interactive iOS agent defaults
.mcp.json / .codex/           optional project MCP wiring
```

Optional mobile-agent tools are **XcodeBuildMCP** for interactive build/run/screenshot/accessibility/debug loops and **Maestro** for durable black-box E2E flows. The checked-in scripts and tests remain source of truth, so MCP availability is not required for CI correctness.

See `docs/agentic.md` for the architecture and `AGENTS.md` for the operating contract.

## Local iOS development

Run the native quality gate:

```bash
bash scripts/check-ios.sh
```

Build, install, and run the local Maestro smoke suite:

```bash
bash scripts/test-ios-maestro.sh
```

See `docs/maestro.md` for prerequisites, manual Simulator commands, selector conventions, flow authoring, and debugging.

## Current sequencing

1. Validate willingness to pay with real linemen.
2. Ship a small, excellent iOS app.
3. Prove retention and discrepancy-detection value.
4. Build Android when user demand justifies the second native client.

See `AGENTS.md` before making changes.
