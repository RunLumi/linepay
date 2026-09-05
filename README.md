# LinePay

**Private, agreement-aware paycheck auditing for linemen.**

LinePay records work facts, applies explicit pay rules, calculates expected pay, and helps reconcile a paystub without sending wage or paystub data to a LinePay backend.

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
scripts/        Reproducible developer checks
```

We intentionally do **not** share UI or platform runtime code between iOS and Android. What may be shared is the specification: rule schemas, canonical test vectors, fixtures, and behavioral contracts.

## Current sequencing

1. Validate willingness to pay with real linemen.
2. Ship a small, excellent iOS app.
3. Prove retention and discrepancy-detection value.
4. Build Android when user demand justifies the second native client.

See `AGENTS.md` before making changes.
