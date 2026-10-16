import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { paycycleWindow } from "../src/paycycle.mjs";
const corpus = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/paycycles/calendar-v1.json",
      import.meta.url,
    ),
  ),
);
assert.equal(
  corpus.format,
  "com.streamentry.linepay.calendar-paycycle-fixtures",
);
assert.equal(corpus.version, 1);
assert.equal(corpus.cases.length, 14);
assert.equal(corpus.refusals.length, 7);
for (const c of corpus.cases)
  test("paycycle: " + c.id, () => {
    const actual = paycycleWindow(c.input);
    for (const [key, value] of Object.entries(c.expected))
      assert.equal(actual[key], value);
  });
for (const c of corpus.refusals)
  test("paycycle refusal: " + c.id, () =>
    assert.throws(() => paycycleWindow(c.input)),
  );
