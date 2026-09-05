# LinePaycheck Gemini instructions

`AGENTS.md` is the canonical repository contract. Read it before implementation and follow the focused docs/skills it routes to.

Public brand is **LinePaycheck**. Preserve technical identity unless explicitly requested otherwise:

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

Gemini workspace MCP configuration lives in `.gemini/settings.json`. Canonical task workflows live in `.agents/skills/`, which Gemini can discover as workspace Agent Skills.

Do not duplicate repository policy here. Update `AGENTS.md` or the relevant focused skill/doc instead.
