import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { assessForPeriod } from "../src/assessment-period.mjs";
import {
  decodeState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { paycycleWindow } from "../src/paycycle.mjs";
const prior = (v) =>
  JSON.parse(
    readFileSync(new URL(`./fixtures/web-state-v${v}.json`, import.meta.url)),
  );
function fixture() {
  const state = decodeState(prior(5)),
    period = state.periods[0],
    audit = period.audits[0],
    scope = {
      auditID: audit.id,
      periodID: period.id,
      startDate: period.start,
      endDate: period.end,
      timeZone: period.zone,
      confirmed: true,
    };
  return { state, period, audit, scope };
}
test("matching source dates allow only the existing scoped comparison; wrong dates block every directional amount", () => {
  const { period, audit, scope } = fixture();
  const original = structuredClone(audit);
  const matching = assessForPeriod(
    audit.calculation,
    audit.facts,
    period.rule.rounding,
    period,
    scope,
  );
  assert.equal(matching.periodMatch, "confirmedSamePeriod");
  assert.equal(matching.verdict, "possibleShortfall");
  assert.equal(matching.difference, "25.00");
  for (const wrong of [
    { ...scope, startDate: "2026-01-01" },
    { ...scope, endDate: "2026-12-31" },
    { ...scope, timeZone: "America/New_York" },
  ]) {
    const result = assessForPeriod(
      audit.calculation,
      audit.facts,
      period.rule.rounding,
      period,
      wrong,
    );
    assert.equal(result.verdict, "notComparable");
    assert.equal(result.periodMatch, "differentPeriod");
    assert.equal(result.gross, null);
    assert.equal(result.difference, null);
    assert.deepEqual(result.comparisons, []);
    assert.equal(result.paidGross, audit.facts.paidGross);
  }
  assert.deepEqual(audit, original);
});
test("unknown/unconfirmed dates never become the selected window or a zero expected amount", () => {
  const { period, audit, scope } = fixture();
  for (const unknown of [
    { ...scope, startDate: null, endDate: null, confirmed: false },
    { ...scope, confirmed: false },
  ]) {
    const r = assessForPeriod(
      audit.calculation,
      audit.facts,
      period.rule.rounding,
      period,
      unknown,
    );
    assert.equal(r.periodMatch, "unconfirmedPeriod");
    assert.equal(r.verdict, "notComparable");
    assert.equal(r.gross, null);
    assert.equal(r.difference, null);
  }
  assert.throws(() =>
    assessForPeriod(
      audit.calculation,
      audit.facts,
      period.rule.rounding,
      period,
      { ...scope, startDate: null },
    ),
  );
  assert.throws(() =>
    assessForPeriod(
      audit.calculation,
      audit.facts,
      period.rule.rounding,
      period,
      { ...scope, startDate: null, endDate: null, confirmed: true },
    ),
  );
});
test("explicit source scope and new comparison commit/restore together; missing/orphaned scope refuses", () => {
  const { state, period, audit, scope } = fixture();
  const original = structuredClone(state.periods);
  const second = {
    ...structuredClone(audit),
    id: "synthetic-date-scoped-audit",
  };
  const retained = { ...scope, auditID: second.id };
  second.assessment = assessForPeriod(
    second.calculation,
    second.facts,
    period.rule.rounding,
    period,
    retained,
  );
  period.audits.push(second);
  state.paycheckScopes.push(retained);
  validateState(state);
  assert.deepEqual(period.audits[0], original[0].audits[0]);
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  const missing = structuredClone(state);
  missing.paycheckScopes = [];
  assert.throws(() => validateState(missing));
  const orphan = structuredClone(state);
  orphan.paycheckScopes[0].auditID = "unknown";
  assert.throws(() => validateState(orphan));
  const changed = structuredClone(state);
  changed.paycheckScopes[0].startDate = "2026-01-01";
  assert.throws(() => validateState(changed));
});
test("saved standard cadence is confirmed metadata and cannot conceal a different period end", () => {
  const { state, period } = fixture();
  const window = paycycleWindow({
    cadence: "manual",
    startDate: period.start,
    manualEndDate: period.end,
    timeZone: period.zone,
  });
  state.paycycleSchedules.push({ periodID: period.id, window });
  validateState(state);
  const incorrect = structuredClone(state);
  incorrect.paycycleSchedules[0].window.cadence = "weekly";
  assert.throws(() => validateState(incorrect));
});
test("actual historical schema1–5 fixtures retain every prior record and gain no invented source dates or cadence", () => {
  for (const version of [1, 2, 3, 4, 5]) {
    const original = prior(version),
      copy = structuredClone(original),
      current = decodeState(original);
    assert.equal(current.version, 9);
    assert.deepEqual(current.paycheckScopes, []);
    assert.deepEqual(current.paycycleSchedules, []);
    for (const key of ["profiles", "periods"])
      assert.deepEqual(current[key], original[key]);
    for (const key of [
      "benefitChecks",
      "templateOrigins",
      "resolutionEvents",
      "ruleTimelines",
    ])
      assert.deepEqual(current[key], original[key] ?? []);
    assert.deepEqual(original, copy);
    const hidden = prior(version);
    hidden.paycheckScopes = [{ privateUnknownData: "do not drop" }];
    assert.throws(() => decodeState(hidden));
  }
});
