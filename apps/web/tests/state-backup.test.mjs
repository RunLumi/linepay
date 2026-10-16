import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dec } from "../src/decimal.mjs";
import { calculate } from "../src/payroll.mjs";
import { assess } from "../src/assessment.mjs";
import {
  emptyState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { encryptBackup, decryptBackup } from "../src/backup.mjs";
const payroll = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/payroll/configured-pay-v1.json",
      import.meta.url,
    ),
  ),
);
const gross = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/reconciliation/configured-gross-v1.json",
      import.meta.url,
    ),
  ),
);
for (const sample of gross.cases)
  test("gross: " + sample.id, () => {
    const r = {
      ...payroll.cases[0].agreement,
      hourlyRate: gross.hourlyRate,
      perDiemPerWorkDate: sample.perDiemPerWorkDate,
    };
    // Legacy calculation production is unsupported on web. This exercises the separate saved-result
    // review flag using independently priced configured wages, not admission of legacy snapshots.
    const calculation = sample.hasCalculation
      ? calculate(
          [
            {
              ...gross.work,
              kind: "regular",
              unpaidBreaks: [],
              calloutEventID: null,
              endUTC: sample.workEndUTC,
            },
          ],
          r,
        )
      : null;
    const result = assess(calculation, sample.facts, {
      ...r.rounding,
      scope: sample.roundingScope,
    });
    assert.equal(result.verdict, sample.expected.verdict);
    if (result.gross === null) assert.equal(sample.expected.gross, null);
    else assert.equal(dec(result.gross).compare(dec(sample.expected.gross)), 0);
    if (result.difference !== null)
      assert.equal(
        dec(result.difference).compare(dec(sample.expected.difference)),
        0,
      );
    else assert.equal(sample.expected.difference, null);
    assert.equal(result.comparisons.length, sample.expected.comparisons.length);
    for (const [i, actual] of result.comparisons.entries()) {
      const expected = sample.expected.comparisons[i];
      assert.equal(actual.field, expected.field);
      for (const key of ["expected", "paid", "difference"])
        assert.equal(dec(actual[key]).compare(dec(expected[key])), 0);
      const selected = calculation.components.filter((c) =>
        actual.field === "perDiemPay"
          ? c.category === "perDiem"
          : sample.facts.grossBasis === "wagesAndPerDiem" ||
            c.category !== "perDiem",
      );
      assert.deepEqual(
        actual.componentIDs,
        selected.map((c) => c.id),
      );
    }
  });
function populated() {
  const state = emptyState(),
    sample = structuredClone(payroll.cases[0]),
    rule = { ...sample.agreement, id: "synthetic-rule" };
  const work = sample.work.map((w) => ({ ...w, timeZone: sample.timeZone }));
  const period = {
    id: "synthetic-period",
    start: "2026-10-05",
    end: "2026-10-11",
    zone: sample.timeZone,
    rule,
    work,
    audits: [],
    closed: false,
    closedCalculation: null,
  };
  // Period follows the actual fixture dates rather than assuming the test-run date.
  const first = work[0].startUTC.slice(0, 10);
  period.start = first;
  period.end = first;
  state.profiles.push(rule);
  state.periods.push(period);
  return state;
}
test("state and closed/history receipts round-trip without mutable rewriting", () => {
  const state = populated(),
    p = state.periods[0],
    calculation = calculate(p.work, p.rule),
    facts = {
      completeWork: true,
      grossBasis: "wagesOnly",
      unreviewedFields: false,
      unsupportedRules: false,
      weeklyReviewPending: false,
      paidGross: "400",
      paidPerDiem: null,
    };
  p.audits.push({
    id: "synthetic-audit",
    createdAt: "2026-10-17T00:00:00Z",
    work: structuredClone(p.work),
    facts,
    calculation,
    assessment: assess(calculation, facts, p.rule.rounding),
  });
  p.closed = true;
  p.closedCalculation = calculation;
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  const altered = structuredClone(state);
  altered.periods[0].audits[0].assessment.verdict = "possibleShortfall";
  assert.throws(() => validateState(altered));
  assert.equal(state.periods[0].audits[0].assessment.verdict, "matches");
  const future = structuredClone(state);
  future.version = 5;
  assert.throws(() => validateState(future));
  const unknown = structuredClone(state);
  unknown.periods[0].unrecognizedPayRecords = [];
  assert.throws(() => validateState(unknown));
});
test("invalid periods, missing work scope and native payloads are rejected", () => {
  const state = populated();
  state.periods[0].end = "2026-02-30";
  assert.throws(() => validateState(state));
  assert.throws(() =>
    inspectSnapshot(
      new TextEncoder().encode(
        '{"format":"com.streamentry.linepay.snapshot","version":1,"state":{},"files":[]}',
      ),
    ),
  );
  assert.throws(() => inspectSnapshot(new Uint8Array([255])));
});
test("shared Unicode vector authenticates but native financial state is not silently imported", async () => {
  const fixture = JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/backup/encryption-v1.json",
        import.meta.url,
      ),
    ),
  );
  const encoded = new Uint8Array(Buffer.from(fixture.encodedHex, "hex"));
  const plaintext = await decryptBackup(encoded, fixture.password);
  assert.equal(new TextDecoder().decode(plaintext), fixture.plaintextUTF8);
  assert.throws(() => inspectSnapshot(plaintext));
  await assert.rejects(decryptBackup(encoded, "wrong password"));
  for (const offset of [12, 28, 44, encoded.length - 1]) {
    const bad = encoded.slice();
    bad[offset] ^= 1;
    await assert.rejects(decryptBackup(bad, fixture.password));
  }
  const factor = encoded.slice();
  new DataView(factor.buffer).setUint32(8, 999999999);
  await assert.rejects(decryptBackup(factor, fixture.password));
});
test("fresh protected snapshots restore exactly with no password retained in state", async () => {
  const fixture = JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/backup/encryption-v1.json",
        import.meta.url,
      ),
    ),
  );
  const state = populated(),
    plain = snapshot(state),
    first = await encryptBackup(plain, fixture.uiPhraseASCII),
    second = await encryptBackup(plain, fixture.uiPhraseASCII);
  assert.notDeepEqual(first, second);
  assert.deepEqual(
    inspectSnapshot(await decryptBackup(first, fixture.uiPhraseASCII)),
    state,
  );
  assert.equal(
    new TextDecoder().decode(plain).includes(fixture.uiPhraseASCII),
    false,
  );
  await assert.rejects(encryptBackup(plain, "short"));
});

test("one immutable rule identity cannot acquire conflicting definitions", () => {
  const state = JSON.parse(JSON.stringify(populated()));
  state.periods[0].rule.hourlyRate = "999";
  assert.throws(() => validateState(state), /conflicting definitions/);
});
