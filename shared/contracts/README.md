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
