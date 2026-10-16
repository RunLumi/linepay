import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { calculate, localCandidates, epoch } from "../src/payroll.mjs";
import { dec, zero } from "../src/decimal.mjs";
const corpus = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/payroll/configured-pay-v1.json",
      import.meta.url,
    ),
  ),
);
assert.equal(corpus.cases.length, 19);
for (const sample of corpus.cases)
  test(sample.id, () => {
    const result = calculate(
        sample.work.map((w) => ({ ...w, timeZone: sample.timeZone })),
        sample.agreement,
      ),
      expected = sample.expected;
    const same = (a, b) => assert.equal(dec(a).compare(dec(b)), 0, sample.id);
    same(result.wages, expected.wages);
    same(result.allowances, expected.allowances);
    same(
      result.total,
      dec(expected.wages).add(dec(expected.allowances)).fixed(8),
    );
    const parts = (category) =>
        result.components.filter((c) => c.category === category),
      sum = (items) =>
        items.reduce((n, c) => n.add(dec(c.amount)), zero).fixed(8);
    same(sum(parts("workedHours")), expected.workedAmount);
    same(sum(parts("calloutGuarantee")), expected.calloutGuarantee);
    same(
      parts("workedHours")
        .reduce((n, c) => n.add(dec(c.workedSeconds)), zero)
        .fixed(8),
      String(expected.actualWorkedSeconds),
    );
    assert.deepEqual(
      [
        ...new Set(parts("workedHours").map((c) => dec(c.multiplier).fixed(8))),
      ].sort(),
      expected.multipliers.map((x) => dec(x).fixed(8)).sort(),
    );
    assert.deepEqual(
      [...new Set(parts("workedHours").map((c) => c.date))].sort(),
      expected.workDates.slice().sort(),
    );
    assert.deepEqual(
      new Set(parts("workedHours").map((c) => c.workID)),
      new Set(sample.work.map((w) => w.id)),
    );
    assert.ok(
      result.components.every(
        (c) =>
          c.reference.id === expected.reference.id &&
          c.reference.version === expected.reference.version &&
          c.currency === expected.currency &&
          c.explanation,
      ),
    );
  });
test("strict decimals and signed half cents", () => {
  for (const input of [1.25, "1e2", "NaN", " 12", "0.1234567890123"])
    assert.throws(() => dec(input));
  assert.equal(dec("1.123456789012").text(), "1.123456789012");
  assert.equal(dec("100").text(), "100");
  assert.throws(() => zero.fixed(2, "unsupported"));
  assert.equal(dec("-0.005").fixed(2), "-0.01");
  assert.equal(dec("0.005").fixed(2, "bankers"), "0.00");
  assert.equal(dec("0.015").fixed(2, "bankers"), "0.02");
  assert.equal(dec("-0.001").fixed(2, "down"), "-0.01");
});
test("DST folds require a selection; gaps and normalized dates are refused", () => {
  assert.deepEqual(localCandidates("2026-03-08T02:30", "America/New_York"), []);
  assert.deepEqual(localCandidates("2026-11-01T01:30", "America/New_York"), [
    epoch("2026-11-01T05:30:00Z"),
    epoch("2026-11-01T06:30:00Z"),
  ]);
  assert.throws(() => epoch("2026-02-30T12:00:00Z"));
  assert.throws(() => epoch("2026-10-01T12:00:00"));
});
test("overlap and unsupported rules never produce pay", () => {
  const sample = corpus.cases[0],
    work = sample.work.map((w) => ({ ...w, timeZone: sample.timeZone }));
  assert.throws(() => calculate([...work, ...work], sample.agreement));
  assert.throws(() =>
    calculate(work, { ...sample.agreement, regularSchedule: [{}] }),
  );
  assert.throws(() =>
    calculate(work, { ...sample.agreement, outsideScheduleMultiplier: "1.5" }),
  );
  assert.throws(() =>
    calculate(work, {
      ...sample.agreement,
      dailyOvertimeTiers: [{ afterHours: "0.00001", multiplier: "1.5" }],
    }),
  );
});
