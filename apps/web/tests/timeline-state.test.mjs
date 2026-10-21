import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  emptyState,
  decodeState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { calculate } from "../src/payroll.mjs";
import {
  currentCalculation,
  reproduceSavedCalculation,
  auditUsesEarlierContext,
} from "../src/calculation-context.mjs";
import { assess } from "../src/assessment.mjs";
import { createPaycheckReport } from "../src/report.mjs";
function scenario() {
  const c = JSON.parse(
      readFileSync(
        new URL(
          "../../../shared/contracts/payroll/effective-date-v1.json",
          import.meta.url,
        ),
      ),
    ).cases[0],
    state = emptyState(),
    baseline = { ...c.baseline, id: "synthetic-base-profile" },
    source = {
      ...c.changes[0].agreement,
      id: "synthetic-new-profile",
      version: "1",
    },
    work = c.work.map((w) => ({ ...w, timeZone: c.timeZone })),
    calculation = calculate(work, baseline),
    facts = {
      completeWork: true,
      grossBasis: "wagesOnly",
      unreviewedFields: false,
      unsupportedRules: false,
      weeklyReviewPending: false,
      paidGross: "950",
      paidPerDiem: null,
    };
  const audit = {
      id: "synthetic-old-check",
      createdAt: "2026-10-17T00:00:00Z",
      work: structuredClone(work),
      facts,
      calculation,
      assessment: assess(calculation, facts, baseline.rounding),
    },
    period = {
      id: "synthetic-period",
      start: "2026-10-05",
      end: "2026-10-18",
      zone: c.timeZone,
      rule: baseline,
      work,
      audits: [audit],
      closed: false,
      closedCalculation: null,
    };
  state.profiles = [baseline, source];
  state.periods = [period];
  const timeline = {
    id: "synthetic-plan-1",
    periodID: period.id,
    createdAt: "2026-10-17T00:00:00Z",
    confirmed: true,
    changes: [
      {
        effectiveDate: "2026-10-06",
        sourceProfileID: source.id,
        agreement: {
          ...structuredClone(source),
          id: baseline.id,
          version: "version-2",
        },
      },
    ],
  };
  return { state, period, audit, timeline };
}
test("confirmed effective plan changes open estimate but never rewrites old engine-v1 audit", () => {
  const { state, period, audit, timeline } = scenario(),
    original = structuredClone(audit);
  state.ruleTimelines.push(timeline);
  validateState(state);
  assert.equal(currentCalculation(state, period).wages, "1005.00");
  assert.equal(currentCalculation(state, period).allowances, "170.00");
  assert.deepEqual(audit, original);
  assert.equal(
    reproduceSavedCalculation(state, period, audit.work, audit.calculation)
      .wages,
    "950.00",
  );
  assert.equal(auditUsesEarlierContext(state, period, audit), true);
});
test("revised plans and close retain each engine-v2 audit on its exact original plan", () => {
  const { state, period, timeline } = scenario();
  state.ruleTimelines.push(timeline);
  const calculation = currentCalculation(state, period),
    facts = { ...period.audits[0].facts, paidGross: "1005" },
    second = {
      ...structuredClone(period.audits[0]),
      id: "synthetic-new-check",
      calculation,
      facts,
      assessment: assess(calculation, facts, period.rule.rounding),
    };
  period.audits.push(second);
  validateState(state);
  state.ruleTimelines.push({
    id: "synthetic-plan-2",
    periodID: period.id,
    createdAt: "2026-10-17T00:01:00Z",
    confirmed: true,
    changes: [],
  });
  assert.equal(currentCalculation(state, period).wages, "950.00");
  assert.equal(
    reproduceSavedCalculation(state, period, second.work, second.calculation)
      .wages,
    "1005.00",
  );
  assert.equal(auditUsesEarlierContext(state, period, second), true);
  period.closed = true;
  period.closedCalculation = currentCalculation(state, period);
  validateState(state);
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  const missing = structuredClone(state);
  missing.ruleTimelines.shift();
  assert.throws(() => validateState(missing));
  const bad = structuredClone(state);
  bad.ruleTimelines.push({
    ...structuredClone(timeline),
    id: "synthetic-plan-3",
  });
  assert.throws(() => validateState(bad));
  const report = createPaycheckReport(state, {
    periodID: period.id,
    auditID: second.id,
    createdAt: "2026-10-17T00:02:00Z",
    options: {
      includeFollowUps: false,
      includeWorkFacts: false,
      includeTemplateReference: false,
    },
  }).html;
  assert.ok(
    report.includes("USD 1005.00") &&
      report.includes("USD 55/hour") &&
      report.includes("2026-10-06"),
  );
  assert.equal(report.includes("synthetic-plan-2"), false);
});
test("missing/changed source snapshots and incompatible rounding cannot be admitted", () => {
  const { state, timeline } = scenario();
  state.ruleTimelines.push(timeline);
  const unconfirmed = structuredClone(state);
  unconfirmed.ruleTimelines[0].confirmed = false;
  assert.throws(() => validateState(unconfirmed));
  const mutated = structuredClone(state);
  mutated.ruleTimelines[0].changes[0].agreement.hourlyRate = "99";
  assert.throws(() => validateState(mutated));
  const absent = structuredClone(state);
  absent.ruleTimelines[0].changes[0].sourceProfileID = "unknown-profile";
  assert.throws(() => validateState(absent));
  const wrong = structuredClone(state);
  wrong.profiles[1].rounding.mode = "bankers";
  wrong.ruleTimelines[0].changes[0].agreement.rounding.mode = "bankers";
  assert.throws(() => validateState(wrong));
});
test("actual v1/v2/v3/v4 fixtures gain empty rule-plan metadata without repricing or invented versions", () => {
  for (const version of [1, 2, 3, 4]) {
    const original = JSON.parse(
        readFileSync(
          new URL(`./fixtures/web-state-v${version}.json`, import.meta.url),
        ),
      ),
      copy = structuredClone(original),
      migrated = decodeState(original);
    assert.equal(migrated.version, 9);
    assert.deepEqual(migrated.ruleTimelines, []);
    for (const key of ["profiles", "periods"])
      assert.deepEqual(migrated[key], original[key]);
    for (const key of ["benefitChecks", "templateOrigins", "resolutionEvents"])
      assert.deepEqual(migrated[key], original[key] ?? []);
    assert.deepEqual(original, copy);
    const hidden = structuredClone(original);
    hidden.ruleTimelines = [{ unknown: "must not drop" }];
    assert.throws(() => decodeState(hidden));
  }
});
