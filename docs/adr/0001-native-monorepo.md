# ADR 0001: Native clients in one monorepo

- Status: Accepted
- Date: 2026-09-05

## Context

LinePay needs to ship quickly on iOS while preserving a credible Android path. Cross-platform UI code would reduce duplication later but adds abstraction and native-integration friction now, before Android demand is proven.

## Decision

Use one monorepo with separate native applications:

```text
apps/ios      SwiftUI
apps/android  Kotlin + Jetpack Compose
```

Do not share runtime UI/application code initially.

Share **contracts** instead:

- versioned rule schemas;
- canonical calculation fixtures;
- example payloads;
- behavioral expectations;
- source/reference metadata formats.

## Consequences

Positive:

- iOS can use Apple frameworks directly;
- Android does not constrain product discovery;
- each platform remains idiomatic;
- shared fixtures prevent behavioral drift without forcing implementation coupling.

Costs:

- Android will duplicate some domain implementation;
- bug fixes may need two implementations after Android launches.

That cost is accepted only after Android demand is proven.

## Revisit when

- Android demand becomes material; and
- maintaining two domain implementations becomes measurably expensive.

At that point evaluate a shared rule interpreter or Kotlin Multiplatform domain layer. Do not adopt one merely to reduce aesthetic duplication.
