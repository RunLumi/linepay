import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dec, zero } from "../src/decimal.mjs";
import { calculateTimeline } from "../src/payroll-v2.mjs";
const corpus = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/payroll/effective-date-v1.json",
      import.meta.url,
    ),
  ),
);
assert.equal(corpus.format, "com.streamentry.linepay.effective-pay-fixtures");
assert.equal(corpus.version, 1);
assert.equal(corpus.cases.length, 8);
assert.equal(corpus.refusals.length, 5);
for (const c of corpus.cases)
  test("timeline: " + c.id, () => {
    const actual = calculateTimeline(
      c.work.map((w) => ({ ...w, timeZone: c.timeZone })),
      c.baseline,
      { id: "synthetic-" + c.id, changes: c.changes },
    );
    for (const key of ["wages", "allowances", "total"])
      assert.equal(dec(actual[key]).compare(dec(c.expected[key])), 0);
    assert.equal(
      actual.components
        .filter((p) => p.category === "workedHours")
        .reduce((n, p) => n.add(dec(p.workedSeconds)), zero)
        .compare(dec(c.expected.workedSeconds)),
      0,
    );
    assert.deepEqual(
      [...new Set(actual.components.map((p) => p.reference.version))].sort(),
      c.expected.appliedVersions.slice().sort(),
    );
    assert.equal(actual.engine, "linepay.web.configured-pay/2");
    assert.equal(actual.ruleSnapshots.length, c.changes.length + 1);
    assert.ok(
      actual.components.every(
        (p) => p.reference.id === c.baseline.id && p.explanation,
      ),
    );
  });
for (const c of corpus.refusals)
  test("timeline refusal: " + c.id, () =>
    assert.throws(() =>
      calculateTimeline(
        c.work.map((w) => ({ ...w, timeZone: c.timeZone })),
        c.baseline,
        { id: "synthetic-" + c.id, changes: c.changes },
      ),
    ),
  );
