import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { calculateContributions } from "../src/benefits.mjs";
import { dec } from "../src/decimal.mjs";
const corpus = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/benefits/confirmed-fund-v1.json",
      import.meta.url,
    ),
  ),
);
assert.equal(
  corpus.format,
  "com.streamentry.linepay.confirmed-benefit-fixtures",
);
assert.equal(corpus.version, 1);
assert.equal(corpus.cases.length, 13);
const compare = (actual, expected) => {
  if (expected === null) assert.equal(actual, null);
  else assert.equal(dec(actual).compare(dec(expected)), 0);
};
for (const sample of corpus.cases)
  test("fund: " + sample.id, () => {
    const result = calculateContributions(sample),
      expected = sample.expected;
    for (const key of [
      "amount",
      "paid",
      "difference",
      "eligibleQuantity",
      "quantityDifference",
    ])
      compare(result[key], expected[key]);
    for (const key of ["currency", "quantityBasis", "status"])
      assert.equal(result[key], expected[key]);
    assert.equal(result.components.length, expected.components.length);
    for (const [i, component] of result.components.entries()) {
      compare(component.unroundedAmount, expected.components[i]);
      assert.equal(component.segmentID, sample.segments[i].id);
      assert.equal(component.ruleID, sample.segments[i].rule.id);
      assert.equal(component.ruleVersion, sample.segments[i].rule.version);
    }
    const retained = structuredClone(result);
    sample.period.start = "2026-01-01";
    assert.deepEqual(result, retained);
  });
const fresh = () =>
  JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/benefits/confirmed-fund-v1.json",
        import.meta.url,
      ),
    ),
  ).cases[0];
test("incomplete eligibility, overlap and changed immutable rules are rejected", () => {
  const sample = fresh();
  assert.throws(() =>
    calculateContributions({ ...sample, completeEligibilityConfirmed: false }),
  );
  const unconfirmed = structuredClone(sample);
  unconfirmed.segments[0].eligibilityConfirmed = false;
  assert.throws(() => calculateContributions(unconfirmed));
  const overlap = structuredClone(sample);
  overlap.segments.push(structuredClone(overlap.segments[0]));
  assert.throws(() => calculateContributions(overlap));
  const conflict = structuredClone(sample),
    second = structuredClone(conflict.segments[0]);
  conflict.segments[0].period.endExclusive = "2026-10-15";
  second.id = "40000000-0000-0000-0000-000000000001";
  second.period.start = "2026-10-15";
  second.rule.rate = "9";
  conflict.segments.push(second);
  assert.throws(
    () => calculateContributions(conflict),
    /conflicting definitions/,
  );
});
test("no fixed proration, invalid statement shape or hidden cross-currency sum", () => {
  const fixed = fresh();
  fixed.segments[0].rule.basis = "fixedPeriod";
  fixed.segments[0].quantity = "2";
  assert.throws(() => calculateContributions(fixed));
  const invalid = fresh();
  invalid.statement = {
    fundID: invalid.segments[0].rule.fundID,
    currency: "USD",
    period: structuredClone(invalid.period),
    employerContribution: "-1",
    quantity: null,
    quantityBasis: null,
    confirmed: true,
  };
  assert.throws(() => calculateContributions(invalid));
  const other = fresh();
  other.segments[0].rule.currency = "CAD";
  other.statement = {
    fundID: other.segments[0].rule.fundID,
    currency: "USD",
    period: structuredClone(other.period),
    employerContribution: "350",
    quantity: null,
    quantityBasis: null,
    confirmed: true,
  };
  assert.equal(calculateContributions(other).status, "notComparable");
});
test("raw decimal products keep all 26 places without binary arithmetic or display rounding", () => {
  const sample = fresh();
  sample.segments[0].rule.basis = "percentOfEligibleEarnings";
  sample.segments[0].rule.rate = "0.000000000001";
  sample.segments[0].quantity = "0.000000000001";
  assert.equal(
    calculateContributions(sample).components[0].unroundedAmount,
    "0.00000000000000000000000001",
  );
});

test("fund arithmetic refuses more than 38 significant digits rather than rounding inputs", () => {
  const sample = fresh();
  sample.segments[0].rule.rate = "99999999999999999999";
  sample.segments[0].quantity = "99999999999999999999";
  assert.throws(() => calculateContributions(sample), /exact decimal capacity/);
});
test("large exact powers compare internally without reparsing through the bounded entry parser", () => {
  const sample = fresh(),
    power = "1" + "0".repeat(29);
  sample.segments[0].rule.rate = power;
  sample.segments[0].quantity = power;
  sample.statement = {
    fundID: sample.segments[0].rule.fundID,
    currency: "USD",
    period: structuredClone(sample.period),
    employerContribution: "0",
    quantity: null,
    quantityBasis: null,
    confirmed: true,
  };
  const result = calculateContributions(sample);
  assert.equal(result.amount, "1" + "0".repeat(58) + ".00");
  assert.equal(result.difference, "1" + "0".repeat(58));
  assert.equal(result.status, "possibleDifference");
});
