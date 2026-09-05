# ADR 0004: Versioned local document store for iOS 1.0

Status: **Accepted for iOS 1.0**

## Context

LinePay must preserve sensitive wage, work, rule, paystub, calculation, and reconciliation state without requiring an account or central backend. Historical pay periods must remain reproducible after rule edits and app upgrades.

The first iOS plan named SwiftData as the likely persistence adapter, but `AGENTS.md` requires the smallest trustworthy architecture rather than a framework by default.

For 1.0, LinePay has:

- one local user;
- one active pay period at a time;
- a bounded list of historical pay-period snapshots;
- no cross-record server queries;
- no multi-user merge semantics;
- no requirement for cloud sync;
- unusually strong need for inspectable, portable, immutable audit snapshots.

## Decision

Persist application state as one explicitly versioned Codable document in Application Support:

```text
Application Support/
  LinePay/
    state-v1.json
    Paystubs/
      <opaque local evidence files>
```

The state document contains:

- current pay profile and exact `AgreementSnapshot`;
- active `PayPeriodWindow` and work facts;
- confirmed paystub facts and evidence metadata;
- reconciliation state;
- immutable completed pay-period snapshots;
- first-free-audit entitlement state.

Original paystub images/PDFs are stored as separate protected local files. The JSON document stores only their metadata and local opaque filename.

Writes are atomic. Both state and paystub evidence use iOS file protection. A schema-version mismatch is treated as a recovery condition rather than silently decoded or overwritten.

## Why this is Pareto-superior for 1.0

Compared with introducing a relational persistence graph now, the document store provides:

- fewer persistence concepts and migration surfaces;
- atomic whole-state commits;
- straightforward deterministic tests;
- easy worker-controlled backup/export;
- direct preservation of immutable historical snapshots;
- no leakage of persistence objects into `LinePayDomain`;
- no extra abstraction merely to query a small local dataset.

It also avoids the failure mode where many independently persisted objects partially commit and historical audit meaning becomes difficult to reconstruct.

## Hard constraints

This decision does **not** permit casual persistence.

1. `schemaVersion` is explicit and checked before use.
2. State changes are validated before persistence and become visible only after a successful atomic save.
3. Historical snapshots preserve the exact agreement version, work facts, calculation result, confirmed paystub facts, and reconciliation seen at archive time.
4. Unsupported schemas are never silently overwritten.
5. Raw paystub data is not logged or placed in analytics.
6. Original evidence can be deleted independently from confirmed structured facts.
7. Export is user-initiated.

## Why not SwiftData now

SwiftData remains a valid future adapter, but 1.0 does not yet benefit enough from object queries/relationships to justify:

- a larger schema surface;
- object-graph migration behavior;
- model-container lifecycle complexity;
- more persistence-specific types and mapping code.

Choosing the document store is not a rejection of SwiftData. It is a deliberate delay until query scale or feature requirements make the trade worthwhile.

## Migration trigger

Reconsider SwiftData or another indexed store when one or more of these become real:

- history scale makes whole-document decoding measurably slow;
- advanced search/filtering across thousands of shifts/pay components is validated user value;
- multiple profiles/agreements are actively used at once;
- private iCloud synchronization requires finer-grained merge behavior;
- a future platform integration needs indexed incremental updates.

If migration occurs, the versioned document format should remain an import/migration fixture so existing workers do not lose history.

## Consequences

### Positive

- simpler 1.0 architecture;
- strong atomicity;
- easy backups and recovery artifacts;
- historical meaning is explicit;
- no backend or account pressure.

### Negative

- whole state is decoded/written for each mutation;
- no indexed query layer;
- future migration may be required if histories become very large.

These are acceptable within the expected 1.0 dataset. Performance must be measured before replacing the design with a more complex store.
