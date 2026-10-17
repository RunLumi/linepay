import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  calculateWeekly,
  weeklySource,
  workFromWeeklySource,
  validateWeeklyReview,
  relatedWeeklyReviews,
} from "../src/weekly.mjs";
import {
  decodeState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { assessWithWeeklyContext } from "../src/assessment-period.mjs";
import { createPaycheckReport } from "../src/report.mjs";
import { encryptBackup, decryptBackup } from "../src/backup.mjs";
const corpus = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/weekly/reference-v2.json",
      import.meta.url,
    ),
  ),
);
assert.equal(
  corpus.format,
  "com.streamentry.linepay.weekly-reference-fixtures",
);
assert.equal(corpus.version, 2);
assert.equal(corpus.cases.length, 7);
assert.equal(corpus.refusals.length, 10);
for (const c of corpus.cases)
  test("weekly parity: " + c.id, () => {
    const actual = calculateWeekly(c.input);
    for (const [key, value] of Object.entries(c.expected))
      if (key !== "allocationAmounts") assert.equal(actual[key], value, c.id);
    assert.deepEqual(
      actual.allocations.map((a) => a.amount),
      c.expected.allocationAmounts,
    );
    assert.deepEqual(calculateWeekly(c.input), actual);
  });
for (const c of corpus.refusals)
  test("weekly refusal: " + c.id, () =>
    assert.throws(() => calculateWeekly(c.input)),
  );
const legacy = (version) =>
  JSON.parse(
    readFileSync(
      new URL(`./fixtures/web-state-v${version}.json`, import.meta.url),
    ),
  );
function record(state, id = "62000000-0000-0000-0000-000000000001") {
  const p = state.periods[0],
    startUTC = p.start + "T00:00:00Z",
    source = weeklySource(state, startUTC, p.zone, p.rule.currency, [p.id]);
  const input = {
    ...structuredClone(corpus.cases[0].input),
    startUTC,
    timeZone: p.zone,
    currency: p.rule.currency,
    work: workFromWeeklySource(source),
    remuneration: [
      {
        id: "62000000-0000-0000-0000-000000000002",
        kind: "straightTime",
        premiumCredit: "notApplicable",
        amount: { amount: "400", currency: "USD" },
      },
    ],
  };
  return {
    id,
    createdAt: "2026-10-17T00:00:00Z",
    reference: "PRIVATE SYNTHETIC weekly reference",
    source,
    input,
    result: calculateWeekly(input),
  };
}
test("schemas1–6 preserve all original records and never invent weekly reviews", () => {
  for (let version = 1; version <= 6; version++) {
    const old = legacy(version),
      copy = structuredClone(old),
      current = decodeState(old);
    assert.equal(current.version, 7);
    assert.deepEqual(current.weeklyReviews, []);
    assert.deepEqual(current.periods, old.periods);
    assert.deepEqual(current.profiles, old.profiles);
    assert.deepEqual(current.paycheckScopes, old.paycheckScopes ?? []);
    assert.deepEqual(current.paycycleSchedules, old.paycycleSchedules ?? []);
    assert.deepEqual(old, copy);
    assert.throws(() =>
      decodeState({ ...old, weeklyReviews: [{ hidden: "do not drop" }] }),
    );
  }
});
test("frozen weekly clocks/rates and result survive later work edits and actual encryption", async () => {
  const state = decodeState(legacy(6)),
    r = record(state);
  state.weeklyReviews.push(r);
  validateState(state);
  const saved = structuredClone(r);
  state.periods[0].work = [];
  // Closed periods keep their original work; an open-ledger edit is represented separately here.
  assert.throws(() => validateState(state));
  const original = decodeState(legacy(6));
  original.weeklyReviews.push(saved);
  validateState(original);
  const password = JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/backup/encryption-v1.json",
        import.meta.url,
      ),
    ),
  ).uiPhraseASCII;
  const bytes = await encryptBackup(snapshot(original), password);
  const restored = inspectSnapshot(await decryptBackup(bytes, password));
  assert.deepEqual(restored.weeklyReviews, [saved]);
  assert.deepEqual(restored.periods, original.periods);
  const missing = structuredClone(original);
  missing.weeklyReviews[0].source.periods[0].work = [];
  assert.throws(() => validateState(missing));
  const changed = structuredClone(original);
  changed.weeklyReviews[0].input.remuneration[0].amount.amount = "401";
  assert.throws(() => validateState(changed));
});
test("known weekly context cannot be unchecked away or retroactively rewrite old comparisons", () => {
  const state = decodeState(legacy(6)),
    p = state.periods[0],
    a = p.audits[0],
    scope = state.paycheckScopes[0];
  const before = structuredClone(a),
    first = assessWithWeeklyContext(
      a.calculation,
      a.facts,
      p.rule.rounding,
      p,
      scope,
      [],
    );
  a.assessment = first;
  validateState(state);
  assert.equal(first.weeklyContextCount, 0);
  const r = record(state);
  state.weeklyReviews.push(r);
  validateState(state);
  assert.deepEqual(a.assessment, first);
  const report = createPaycheckReport(state, {
    periodID: p.id,
    auditID: a.id,
    createdAt: "2026-10-17T00:00:00Z",
    options: {
      includeFollowUps: false,
      includeWorkFacts: false,
      includeTemplateReference: false,
    },
  });
  assert.match(
    report.html ?? report,
    /predates later retained weekly evidence/,
  );
  assert.doesNotMatch(
    report.html ?? report,
    /PRIVATE SYNTHETIC weekly reference/,
  );

  const next = assessWithWeeklyContext(
    a.calculation,
    { ...a.facts, weeklyReviewPending: false },
    p.rule.rounding,
    p,
    scope,
    state.weeklyReviews,
  );
  assert.equal(next.verdict, "needsReview");
  assert.deepEqual(next.weeklyReviewReferences, [r.id]);
  assert.equal(next.gross, before.assessment.gross);
  a.assessment = next;
  validateState(state);
  const missing = structuredClone(state);
  missing.weeklyReviews = [];
  assert.throws(() => validateState(missing));
});
test("both workweek tails, breaks and DST 168-hour boundary are exact", () => {
  const state = decodeState(legacy(6)),
    p = state.periods[0];
  state.periods = [p];
  state.ruleTimelines = [];
  p.zone = "America/New_York";
  const item = (id, startUTC, endUTC, unpaidBreaks = []) => ({
    id,
    startUTC,
    endUTC,
    timeZone: p.zone,
    kind: "regular",
    calloutEventID: null,
    unpaidBreaks,
  });
  p.work = [
    item("tail1", "2026-03-02T04:00:00Z", "2026-03-02T08:00:00Z", [
      {
        id: "break1",
        startUTC: "2026-03-02T04:30:00Z",
        endUTC: "2026-03-02T05:30:00Z",
      },
    ]),
    item("tail2", "2026-03-09T04:00:00Z", "2026-03-09T06:00:00Z"),
  ];
  const source = weeklySource(state, "2026-03-02T05:00:00Z", p.zone, "USD", [
      p.id,
    ]),
    facts = workFromWeeklySource(source);
  assert.equal(
    facts.reduce((n, f) => n + f.workedSeconds, 0),
    12600,
  );
  assert.equal(source.periods[0].work[0].startUTC, "2026-03-02T04:00:00Z");
  const duplicate = structuredClone(source);
  duplicate.periods[0].work.push(duplicate.periods[0].work[0]);
  assert.throws(() => workFromWeeklySource(duplicate));
});

test("an explicitly selected unworked period keeps its employer-context relationship", () => {
  const state = decodeState(legacy(6)),
    p = state.periods[0];
  p.work = [];
  const source = weeklySource(
    state,
    p.start + "T00:00:00Z",
    p.zone,
    p.rule.currency,
    [p.id],
  );
  assert.throws(() =>
    weeklySource(state, p.start + "T00:00:00Z", p.zone, p.rule.currency),
  );
  assert.equal(source.periods.length, 1);
  assert.deepEqual(workFromWeeklySource(source), []);
  const input = {
    ...structuredClone(corpus.cases[0].input),
    startUTC: source.startUTC,
    timeZone: p.zone,
    work: [],
    remuneration: [
      {
        id: "unworked-cash",
        amount: { amount: "0", currency: "USD" },
        kind: "straightTime",
        premiumCredit: "notApplicable",
      },
    ],
  };
  const r = {
    id: "unworked-review",
    createdAt: "2026-10-17T00:00:00Z",
    reference: "",
    source,
    input,
    result: calculateWeekly(input),
  };
  validateWeeklyReview(r);
  assert.equal(relatedWeeklyReviews([r], p.id).length, 1);
  assert.equal(r.result.regularRate, null);
});
