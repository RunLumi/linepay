# ADR 0003: Local-first paycheck data

- Status: Accepted
- Date: 2026-09-05

## Context

LinePay handles wages, schedules, agreements, and paystubs. Centralizing those records would create privacy, security, compliance, infrastructure, and trust costs before a backend is needed for the product's core value.

## Decision

The default product architecture stores and processes sensitive work/pay data on the user's device.

For v1:

- no LinePay account is required;
- no LinePay application backend is required;
- OCR is performed on device where platform capability permits;
- calculation and reconciliation are local;
- raw paystub content is not sent to analytics or logging systems;
- `PrivacyInfo.xcprivacy` is maintained from the beginning.

A future sync/backup capability must be a separate product/architecture decision. Apple-provided private sync may be evaluated before introducing a LinePay-owned sensitive-data service.

## Consequences

Positive:

- smaller attack surface;
- lower infrastructure/support burden;
- strong and comprehensible privacy positioning;
- offline usefulness in field/storm conditions.

Costs:

- multi-device recovery/sync is deferred;
- device loss is initially a data-loss risk unless export/backup is provided;
- centralized product analytics are intentionally limited.

## Revisit when

A validated user need cannot be solved reasonably with device-local storage/export or platform-private sync.
