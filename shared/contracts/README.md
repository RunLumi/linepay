# Shared contracts

This directory is for **behavioral interoperability**, not shared application code.

Future contents may include:

```text
schemas/
  pay-rule.schema.json
  agreement-snapshot.schema.json
fixtures/
  overtime-after-8h.json
  callout-minimum.json
  cross-midnight.json
  dst-transition.json
  currency-rounding.json
```

A canonical fixture should state explicit inputs and expected outputs so iOS and Android can prove they calculate the same result independently.

Do not put secrets, real paystubs, employer-private documents, or personally identifying wage records here. Fixtures must be synthetic or safely anonymized.

The schema should not be invented before the first real rule engine needs it. First learn the domain in native Swift types and real customer examples; then extract the smallest stable interchange contract.

The byte envelope is [password-protected manual backup transport v1](backup/README.md). Its synthetic vector is checked independently by native and Node/WebCrypto implementations. The typed cross-client financial payload is separately specified by [portable financial state v1](portable-state/README.md); its independent schema gate does not prove client runtime restore.

[Configured-pay fixtures v1](payroll/README.md) is the first native-consumed payroll conformance subset. It includes independent synthetic arithmetic, explicit timestamps/timezone and source snapshot references; broader cross-platform coverage remains pending.

[Confirmed fund fixtures v1](benefits/README.md) verifies separate employer-contribution arithmetic and comparison scope in both native implementations without inferring eligibility or legal coverage.

[Paycheck comparisons v1](reconciliation/README.md) verifies complete-work/gross-basis guards, configured earnings and hour lines, explicit period matching, review precedence and source-component references across the Swift, Kotlin and browser domain implementations.

[Portable rule drafts v1](templates/README.md) supports explicit parameter sharing with omitted monetary amounts by default and recipient-confirmed adoption. It is separate from full backups and verified agreement packs.

[Effective-date pay fixtures v1](payroll/effective-date-v1.md) verifies eight temporal prices and five refusals independently in Swift/Kotlin/browser, with compatible policy and explicit local-date snapshots.

[Calendar paycycles v1](paycycles/README.md) verifies fourteen local-date/instant boundaries and seven refusals independently in Swift/browser; cadence is separate from legal workweek coverage.

- [Historical weekly result](weekly/README.md): actual synthetic v1 receipt and explicit v2 correction.
