import test from "node:test";
import assert from "node:assert/strict";
import { calculate } from "../src/payroll.mjs";
import { calculateTimeline } from "../src/payroll-v2.mjs";
import { assessWithLines } from "../src/assessment-period.mjs";
import {
  emptyState,
  validateState,
  decodeState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { validateLineScope } from "../src/assessment-lines.mjs";
const rule = (extra = {}) => ({
  id: "synthetic-rule",
  version: "1",
  currency: "USD",
  hourlyRate: "50",
  regularSchedule: [],
  outsideScheduleMultiplier: "1",
  dailyOvertimeTiers: [{ afterHours: "8", multiplier: "1.5" }],
  weekdayPremiums: [],
  datePremiums: [],
  calloutMinimumHours: null,
  perDiemPerWorkDate: null,
  rounding: { scale: 2, mode: "halfUp", scope: "payCategory" },
  ...extra,
});
const work = (end = "2026-09-07T18:00:00Z", extra = {}) => ({
  id: "synthetic-work",
  startUTC: "2026-09-07T08:00:00Z",
  endUTC: end,
  timeZone: "UTC",
  kind: "regular",
  calloutEventID: null,
  unpaidBreaks: [],
  ...extra,
});
function setup({
  r = rule(),
  w = [work()],
  amounts = { regularPay: "400", overtimePay: "150" },
  hours = { regularHours: "8", overtimeHours: "2" },
  layout = "fullRateBuckets",
  hoursBasis = "actualWork",
  guaranteeLayout = "unconfirmed",
  completeEarnings = true,
  weekly = false,
  gross,
  sourceConfirmed = true,
  timeline = null,
} = {}) {
  const period = {
    id: "synthetic-period",
    rule: r,
    start: "2026-09-07",
    end: "2026-09-08",
    zone: "UTC",
    work: w,
    audits: [],
    closed: false,
    closedCalculation: null,
  };
  const calculation = timeline
    ? calculateTimeline(w, r, timeline)
    : calculate(w, r);
  const facts = {
    completeWork: true,
    grossBasis: "wagesOnly",
    paidGross: gross ?? calculation.wages,
    paidPerDiem: null,
    unreviewedFields: false,
    unsupportedRules: false,
    weeklyReviewPending: weekly,
  };
  const source = {
    auditID: "synthetic-audit",
    periodID: period.id,
    startDate: period.start,
    endDate: period.end,
    timeZone: "UTC",
    confirmed: sourceConfirmed,
  };
  const lines = {
    auditID: source.auditID,
    periodID: period.id,
    amounts,
    hours,
    layout,
    hoursBasis,
    guaranteeLayout,
    completeEarnings,
  };
  const assessment = assessWithLines(
    calculation,
    facts,
    period,
    source,
    [],
    lines,
    w,
    timeline,
  );
  return { period, calculation, facts, source, lines, assessment };
}
test("Full-rate lines and actual hours trace the independently priced 400 + 150 ledger", () => {
  const s = setup();
  assert.equal(s.assessment.verdict, "matches");
  assert.equal(s.assessment.engine, "linepay.web.configured-lines/4");
  assert.equal(
    s.assessment.comparisons.find((c) => c.field === "regularPay").expected,
    "400.00",
  );
  assert.equal(
    s.assessment.comparisons.find((c) => c.field === "overtimeHours").expected,
    "2.0000",
  );
  assert.equal(
    s.assessment.comparisons.find((c) => c.field === "overtimeHours").unit,
    "hours",
  );
});
test("Premium-only layout compares all base hours and only extra OT money", () => {
  const s = setup({
    layout: "basePlusPremium",
    amounts: { regularPay: "500", overtimePay: "50" },
    hours: { regularHours: "10", overtimeHours: "2" },
  });
  assert.equal(s.assessment.verdict, "matches");
  assert.equal(
    s.assessment.comparisons.find((c) => c.field === "regularPay").expected,
    "500.00",
  );
});
test("A matching gross cannot hide offsetting line differences", () => {
  const s = setup({ amounts: { regularPay: "350", overtimePay: "200" } });
  assert.equal(s.assessment.verdict, "needsReview");
  assert(s.assessment.reasons.some((r) => r.includes("Gross matches")));
});
for (const premium of [false, true])
  test("Exact one-minute half-cent base " + premium, () => {
    const s = setup({
      r: rule({
        hourlyRate: "58.50",
        dailyOvertimeTiers: premium
          ? [{ afterHours: "0", multiplier: "1.5" }]
          : [],
      }),
      w: [work("2026-09-07T08:01:00Z")],
      layout: "basePlusPremium",
      hours: {},
      amounts: premium
        ? { regularPay: "0.98", overtimePay: "0.48" }
        : { regularPay: "0.98" },
    });
    assert.equal(s.assessment.verdict, "matches");
    assert.equal(
      s.assessment.comparisons.find((c) => c.field === "regularPay").expected,
      "0.98",
    );
  });
test("Cross-rate half-cent rounds once over exact seconds, not per fragment", () => {
  const r = rule({ hourlyRate: "1", dailyOvertimeTiers: [] }),
    later = { ...r, version: "2", hourlyRate: "17" };
  const s = setup({
    r,
    w: [
      work("2026-09-07T08:00:01Z"),
      work("2026-09-08T08:00:01Z", {
        id: "synthetic-second",
        startUTC: "2026-09-08T08:00:00Z",
      }),
    ],
    timeline: {
      id: "synthetic-plan",
      changes: [{ effectiveDate: "2026-09-08", agreement: later }],
    },
    layout: "basePlusPremium",
    hours: {},
    amounts: { regularPay: "0.01" },
  });
  assert.equal(s.assessment.verdict, "matches");
  assert.equal(
    s.assessment.comparisons.find((c) => c.field === "regularPay").expected,
    "0.01",
  );
});
for (const layout of ["includedInHourlyLines", "separateLine"])
  for (const basis of ["actualWork", "paidEquivalents"])
    test("Callout mapping " + layout + " " + basis, () => {
      const separate = layout === "separateLine";
      const s = setup({
        r: rule({ calloutMinimumHours: "4" }),
        w: [
          work("2026-09-07T09:00:00Z", {
            kind: "callout",
            calloutEventID: "synthetic-call",
          }),
        ],
        guaranteeLayout: layout,
        hoursBasis: basis,
        amounts: separate
          ? { regularPay: "50", calloutPay: "150" }
          : { regularPay: "200" },
        hours: { regularHours: basis === "actualWork" || separate ? "1" : "4" },
      });
      assert.equal(s.assessment.verdict, "matches");
    });
for (const options of [
  { layout: "unconfirmed" },
  { hoursBasis: "unconfirmed" },
  { weekly: true },
  { sourceConfirmed: false },
  { amounts: { regularPay: "400", overtimePay: "151" } },
  { completeEarnings: true, amounts: {}, hours: {} },
])
  test(
    "Missing or conflicting evidence cannot produce a clean comparison " +
      JSON.stringify(options),
    () => {
      assert.notEqual(setup(options).assessment.verdict, "matches");
    },
  );
test("Unknown callout mapping and unusual multipliers refuse hourly line expectations", () => {
  for (const r of [
    rule({ calloutMinimumHours: "4" }),
    rule({ dailyOvertimeTiers: [{ afterHours: "0", multiplier: "1.25" }] }),
  ]) {
    const s = setup({
      r,
      w: [
        work("2026-09-07T09:00:00Z", {
          kind: "callout",
          calloutEventID: "synthetic-call",
        }),
      ],
    });
    assert.equal(s.assessment.verdict, "needsReview");
    assert(!s.assessment.comparisons.some((c) => c.field === "regularPay"));
  }
});
test("Strict line input rejects unknown fields, negative/excessive hours and numeric money", () => {
  const s = setup();
  for (const patch of [
    { extra: 1 },
    { amounts: { unknown: "1" } },
    { amounts: { regularPay: 400 } },
    { hours: { regularHours: "-1" } },
    { hours: { regularHours: "10000.0001" } },
  ])
    assert.throws(() => validateLineScope({ ...s.lines, ...patch }));
});
test("New line receipts reproduce from retained facts and survive snapshot round-trip; tampering refuses", () => {
  const s = setup(),
    state = emptyState();
  state.profiles.push(s.period.rule);
  state.periods.push(s.period);
  s.period.audits.push({
    id: s.source.auditID,
    createdAt: "2026-09-09T00:00:00Z",
    work: structuredClone(s.period.work),
    facts: s.facts,
    calculation: s.calculation,
    assessment: s.assessment,
  });
  state.paycheckScopes.push(s.source);
  state.paycheckLineScopes.push(s.lines);
  validateState(state);
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  for (const mutate of [
    (c) => (c.paycheckLineScopes[0].amounts.regularPay = "399"),
    (c) => (c.paycheckLineScopes = []),
    (c) => c.paycheckLineScopes.push(structuredClone(c.paycheckLineScopes[0])),
    (c) =>
      (c.periods[0].audits[0].assessment.comparisons.find(
        (x) => x.field === "regularPay",
      ).expected = "399.00"),
  ]) {
    const c = structuredClone(state);
    mutate(c);
    assert.throws(() => validateState(c));
  }
  const prior = structuredClone(state);
  prior.version = 7;
  delete prior.paycheckLineScopes;
  // Producer4 cannot be relabelled as a format that lacked its evidence.
  assert.throws(() => decodeState(prior));
});

for (const [mode, paid, expectedDifference] of [
  ["up", "0.00025", "0.0000"],
  ["down", "0.0003", "0.0000"],
  ["bankers", "0.99995", "0.0001"],
])
  test(
    "Hours use their own half-up precision, independent of wage rounding: " +
      mode,
    () => {
      const hour = mode === "bankers";
      const s = setup({
        r: rule({
          dailyOvertimeTiers: [],
          rounding: { scale: 2, mode, scope: "payCategory" },
        }),
        w: [work(hour ? "2026-09-07T09:00:00Z" : "2026-09-07T08:00:01Z")],
        amounts: {},
        hours: { regularHours: paid },
        completeEarnings: false,
      });
      assert.equal(
        s.assessment.comparisons.find((c) => c.field === "regularHours")
          .difference,
        expectedDifference,
      );
      assert.equal(s.assessment.verdict, hour ? "needsReview" : "matches");
    },
  );

test("Actual v7 weekly history migrates without repricing or inventing line confirmation", async () => {
  const { readFileSync } = await import("node:fs");
  const prior = JSON.parse(
    readFileSync(new URL("./fixtures/web-state-v7.json", import.meta.url)),
  );
  const bytes = JSON.stringify(prior),
    current = decodeState(prior);
  assert.equal(current.version, 9);
  assert.deepEqual(current.paycheckLineScopes, []);
  assert.equal(prior.weeklyReviews.length, 1);
  assert.deepEqual(current.periods, prior.periods);
  assert.deepEqual(current.weeklyReviews, prior.weeklyReviews);
  assert.equal(
    current.periods[0].audits.at(-1).assessment.engine,
    "linepay.web.configured-gross/3",
  );
  assert.equal(JSON.stringify(prior), bytes);
  assert.deepEqual(inspectSnapshot(snapshot(current)), current);
});

test("Exact line evidence reproduces all nineteen admitted configured-pay ledgers", async () => {
  const { readFileSync } = await import("node:fs");
  const corpus = JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/payroll/configured-pay-v1.json",
        import.meta.url,
      ),
    ),
  );
  for (const c of corpus.cases) {
    const w = c.work.map((x) => ({ ...x, timeZone: c.timeZone })),
      calculation = calculate(w, c.agreement);
    const period = {
      id: "synthetic-period",
      start: "2026-01-01",
      end: "2026-12-31",
      zone: c.timeZone,
      rule: c.agreement,
    };
    const scope = {
      auditID: "synthetic-audit",
      periodID: period.id,
      startDate: period.start,
      endDate: period.end,
      timeZone: period.zone,
      confirmed: true,
    };
    const lines = {
      auditID: scope.auditID,
      periodID: period.id,
      layout: "unconfirmed",
      hoursBasis: "unconfirmed",
      guaranteeLayout: "unconfirmed",
      completeEarnings: false,
      amounts: {},
      hours: {},
    };
    const facts = {
      completeWork: true,
      grossBasis: "wagesOnly",
      paidGross: calculation.wages,
      paidPerDiem: null,
      unreviewedFields: false,
      unsupportedRules: false,
      weeklyReviewPending: false,
    };
    const result = assessWithLines(
      calculation,
      facts,
      period,
      scope,
      [],
      lines,
      w,
    );
    assert.equal(result.verdict, "matches", c.id);
    assert.equal(result.gross, calculation.wages, c.id);
  }
});
