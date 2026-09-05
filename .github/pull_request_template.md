## User outcome

<!-- What becomes better for the worker? Keep this behavior-focused. -->

## What changed

<!-- Summarize the smallest coherent implementation. Call out important architecture/product choices. -->

## Risk / invariants

<!-- Which LinePaycheck invariant was most at risk? Money, time, rule history, privacy, migration, bundle identity, accessibility, etc. -->

- [ ] No pay rule was invented or silently broadened
- [ ] Money/time semantics remain explicit and deterministic where relevant
- [ ] Historical/persisted behavior was considered where relevant
- [ ] Privacy/data flow was considered where relevant
- [ ] Bundle ID remains `com.streamentry.linepay`

## Verification performed

<!-- Check only commands or inspection that actually ran. Paste concise failure context if something remains unresolved. -->

- [ ] Focused tests
- [ ] `bash scripts/agent-verify.sh quick`
- [ ] `bash scripts/agent-verify.sh ios`
- [ ] `bash scripts/agent-verify.sh ui`
- [ ] Simulator/manual visual inspection
- [ ] Accessibility hierarchy / identifiers inspected

Details:

```text
<exact commands, simulator/device, and result>
```

## UI evidence

<!-- For user-facing changes, attach before/after or relevant Simulator screenshots when useful. Never include real wage/paystub data. -->

Not applicable / evidence:

## Persistence / migration / release notes

<!-- State “none” if none. Do not leave migration consequences implicit. -->

## Remaining limitations

<!-- Real limitations only. Do not invent future work to make the PR look comprehensive. -->
