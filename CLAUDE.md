# LinePaycheck Claude instructions

`AGENTS.md` is the canonical repository contract. Read it before making changes and follow the nearest scoped instructions/docs it routes to.

Public brand is **LinePaycheck**. Preserve technical identity unless explicitly asked otherwise:

- bundle ID `com.streamentry.linepay`
- Xcode scheme/target `LinePay`
- Swift package `LinePayDomain`
- repository `streamentry/linepay`

Useful entry points:

```bash
bash scripts/agent-context.sh
bash scripts/agent-doctor.sh
bash scripts/agent-verify.sh quick
bash scripts/agent-verify.sh ios
bash scripts/agent-verify.sh ui
```

Project-scoped optional mobile MCP servers are declared in `.mcp.json`. Do not duplicate repository policy here; update `AGENTS.md` or the focused skill/doc instead.
