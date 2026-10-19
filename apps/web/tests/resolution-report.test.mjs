import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import {
  decodeState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { calculate } from "../src/payroll.mjs";
import { assess } from "../src/assessment.mjs";
import { createResolutionEvent } from "../src/resolution.mjs";
import {
  createPaycheckReport,
  REPORT_CSS,
  REPORT_STYLE_HASH,
} from "../src/report.mjs";
const fixture = (version) =>
  JSON.parse(
    readFileSync(
      new URL(`./fixtures/web-state-v${version}.json`, import.meta.url),
    ),
  );
const fresh = () => decodeState(fixture(3));
const options = {
  includeFollowUps: false,
  includeWorkFacts: false,
  includeTemplateReference: false,
};
function followUp(
  state,
  status = "explained",
  note = "PRIVATE SYNTHETIC note <script>not executable</script>",
) {
  return createResolutionEvent(state, {
    id: "80000000-0000-0000-0000-000000000001",
    periodID: state.periods[0].id,
    auditID: state.periods[0].audits[0].id,
    status,
    note,
    createdAt: "2026-10-17T00:00:00Z",
  });
}
test("prior v1/v2/v3 schemas migrate with no invented follow-up or changed financial records", () => {
  for (const version of [1, 2, 3]) {
    const original = fixture(version),
      before = structuredClone(original),
      current = decodeState(original);
    assert.equal(current.version, 8);
    assert.deepEqual(current.resolutionEvents, []);
    assert.equal(current.revision, original.revision);
    for (const key of ["profiles", "periods"])
      assert.deepEqual(current[key], original[key]);
    assert.deepEqual(current.benefitChecks, original.benefitChecks ?? []);
    assert.deepEqual(current.templateOrigins, original.templateOrigins ?? []);
    assert.deepEqual(original, before);
    const hidden = fixture(version);
    hidden.resolutionEvents = [{ unknownPrivateData: "do not drop" }];
    assert.throws(() => decodeState(hidden));
  }
});
test("worker status is append-only metadata and never corrects comparison amounts or verdict", () => {
  const state = fresh(),
    periods = structuredClone(state.periods);
  state.resolutionEvents.push(followUp(state, "corrected"));
  validateState(state);
  assert.deepEqual(state.periods, periods);
  assert.equal(
    state.periods[0].audits[0].assessment.verdict,
    "possibleShortfall",
  );
  assert.equal(state.periods[0].audits[0].assessment.difference, "25.00");
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  const older = structuredClone(state.resolutionEvents[0]);
  state.resolutionEvents.push({
    ...followUp(state, "unresolved", "New worker-reported follow-up"),
    id: "80000000-0000-0000-0000-000000000002",
  });
  validateState(state);
  assert.deepEqual(state.resolutionEvents[0], older);
});
test("follow-up refuses unknown status, missing note, wrong revision and conflicting identity", () => {
  const state = fresh();
  assert.throws(() => followUp(state, "paidAutomatically"));
  assert.throws(() => followUp(state, "reviewing", " "));
  assert.throws(() => followUp(state, "reviewing", "x".repeat(4001)));
  assert.throws(() => followUp(state, "reviewing", "\ud800"));
  assert.throws(() => followUp(state, "reviewing", "before\u0000after"));
  assert.throws(() => followUp(state, ["corrected"]));
  const event = followUp(state);
  assert.throws(() =>
    createResolutionEvent(state, { ...event, auditID: "another-check" }),
  );
  state.resolutionEvents = [event, { ...event }];
  assert.throws(() => validateState(state));
});
test("default report renders saved facts, omits private notes/clock details and never reprices", () => {
  const state = fresh();
  state.resolutionEvents.push(followUp(state));
  const before = structuredClone(state);
  const selected = {
    periodID: state.periods[0].id,
    auditID: state.periods[0].audits[0].id,
    createdAt: "2026-10-17T01:00:00Z",
    options,
  };
  const report = createPaycheckReport(state, selected),
    html = report.html;
  assert.ok(
    html.includes("USD 400.00") &&
      html.includes("USD 375") &&
      html.includes("USD 25.00"),
  );
  assert.ok(html.includes("Possible shortfall"));
  assert.equal(html.includes("PRIVATE SYNTHETIC"), false);
  assert.equal(html.includes(state.periods[0].work[0].startUTC), false);
  assert.equal(html.includes("Explanation accepted by me"), false);
  assert.equal(html.includes("SYNTHETIC omitted-amounts"), false);
  assert.deepEqual(state, before);
  assert.deepEqual(new TextEncoder().encode(html), report.bytes);
  // A report is a receipt of the selected saved snapshot, not a second price engine.
  const alternative = structuredClone(state);
  alternative.profiles.at(-1).hourlyRate = "1";
  assert.equal(createPaycheckReport(alternative, selected).html, html);
});
test("explicit details are scoped to the selected check and escaped; output policy denies scripts/network", () => {
  const state = fresh();
  state.resolutionEvents.push(followUp(state));
  const report = createPaycheckReport(state, {
    periodID: state.periods[0].id,
    auditID: state.periods[0].audits[0].id,
    createdAt: "2026-10-17T01:00:00Z",
    options: { ...options, includeFollowUps: true, includeWorkFacts: true },
  });
  assert.ok(
    report.html.includes(
      "PRIVATE SYNTHETIC note &lt;script&gt;not executable&lt;/script&gt;",
    ),
  );
  assert.equal(report.html.includes("<script>"), false);
  assert.ok(report.html.includes(state.periods[0].work[0].startUTC));
  assert.ok(
    report.html.includes("default-src 'none'") &&
      report.html.includes("script-src 'none'"),
  );
  const hash =
    "sha256-" + createHash("sha256").update(REPORT_CSS).digest("base64");
  assert.equal(hash, REPORT_STYLE_HASH);
  const index = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  assert.ok(
    index.includes("'" + hash + "'") && index.includes("frame-src blob:"),
  );
  const invalid = structuredClone(options);
  invalid.unreviewedIdentity = true;
  assert.throws(() =>
    createPaycheckReport(state, {
      periodID: state.periods[0].id,
      auditID: state.periods[0].audits[0].id,
      createdAt: "2026-10-17T01:00:00Z",
      options: invalid,
    }),
  );
});
test("incomparable saved gross stays unknown rather than becoming zero in a report", () => {
  const state = fresh(),
    audit = state.periods[0].audits[0];
  audit.assessment = {
    ...audit.assessment,
    verdict: "notComparable",
    gross: null,
    difference: null,
    reasons: ["Complete work not confirmed"],
    comparisons: [],
  };
  audit.facts.completeWork = false;
  const html = createPaycheckReport(state, {
    periodID: state.periods[0].id,
    auditID: audit.id,
    createdAt: "2026-10-17T01:00:00Z",
    options,
  }).html;
  assert.ok(
    html.includes("Unable to verify / unknown") &&
      html.includes("Complete work not confirmed"),
  );
  assert.equal(html.includes("USD null"), false);
});

test("an oversized optional history refuses instead of silently dropping the tail", () => {
  const state = fresh();
  for (let i = 0; i < 600; i++)
    state.resolutionEvents.push({
      ...followUp(state, "reviewing", "x".repeat(4000)),
      id: "synthetic-large-" + i,
    });
  assert.throws(
    () =>
      createPaycheckReport(state, {
        periodID: state.periods[0].id,
        auditID: state.periods[0].audits[0].id,
        createdAt: "2026-10-17T01:00:00Z",
        options: { ...options, includeFollowUps: true },
      }),
    /exceeds 2 MiB/,
  );
});

test("follow-up from one saved paycheck revision cannot leak into another selected report", () => {
  const state = fresh(),
    period = state.periods[0],
    original = period.audits[0];
  state.resolutionEvents.push(followUp(state));
  const facts = { ...original.facts, paidGross: "400" },
    second = {
      ...structuredClone(original),
      id: "80000000-0000-0000-0000-000000000003",
      facts,
      assessment: assess(original.calculation, facts, period.rule.rounding),
    };
  period.audits.push(second);
  validateState(state);
  const html = createPaycheckReport(state, {
    periodID: period.id,
    auditID: second.id,
    createdAt: "2026-10-17T01:00:00Z",
    options: { ...options, includeFollowUps: true },
  }).html;
  assert.ok(
    html.includes("Match within compared scope") &&
      html.includes("No follow-up was recorded for this check."),
  );
  assert.equal(html.includes("PRIVATE SYNTHETIC"), false);
  assert.equal(original.assessment.verdict, "possibleShortfall");
});
test("crew-draft text is an explicit opt-in and recipient amounts stay the saved values", () => {
  const state = fresh(),
    rule = state.profiles.at(-1),
    prior = state.periods[0],
    work = prior.work.map((w, i) => ({
      ...structuredClone(w),
      id: "80000000-0000-0000-0000-" + (10 + i).toString().padStart(12, "0"),
    })),
    calculation = calculate(work, rule),
    facts = { ...prior.audits[0].facts, paidGross: "600" },
    audit = {
      id: "80000000-0000-0000-0000-000000000004",
      createdAt: "2026-10-17T00:00:00Z",
      work,
      facts,
      calculation,
      assessment: assess(calculation, facts, rule.rounding),
    };
  const period = {
    ...structuredClone(prior),
    id: "80000000-0000-0000-0000-000000000005",
    rule,
    work,
    audits: [audit],
    closedCalculation: calculation,
  };
  state.periods.push(period);
  validateState(state);
  const args = {
    periodID: period.id,
    auditID: audit.id,
    createdAt: "2026-10-17T01:00:00Z",
    options,
  };
  const title = state.templateOrigins[0].packet.title;
  assert.equal(createPaycheckReport(state, args).html.includes(title), false);
  const included = createPaycheckReport(state, {
    ...args,
    options: { ...options, includeTemplateReference: true },
  }).html;
  assert.ok(
    included.includes(title) &&
      included.includes("USD 75") &&
      included.includes("not source approval"),
  );
});
