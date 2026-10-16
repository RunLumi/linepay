import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  decodeState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { adoptRuleTemplate } from "../src/rule-template.mjs";
import { calculate } from "../src/payroll.mjs";
const prior = (version) =>
  JSON.parse(
    readFileSync(
      new URL(`./fixtures/web-state-v${version}.json`, import.meta.url),
    ),
  );
const packet = () =>
  JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/templates/rule-drafts-v1.json",
        import.meta.url,
      ),
    ),
  ).cases[0].packet;
const profileID = "60000000-0000-0000-0000-000000000001";
function adoptedState() {
  const state = decodeState(prior(2)),
    source = packet(),
    profile = adoptRuleTemplate(source, {
      profileID,
      hourlyRate: "75",
      perDiemDecision: "confirmedAmount",
      perDiemAmount: "120",
      applicabilityConfirmed: true,
      valuesConfirmed: true,
    });
  state.profiles.push(profile);
  state.templateOrigins.push({
    profileID,
    packet: source,
    perDiemDecision: "confirmedAmount",
    recipientHourlyRate: "75",
    recipientPerDiemAmount: "120",
    applicabilityConfirmed: true,
    valuesConfirmed: true,
  });
  return state;
}
test("v1/v2 recovery adds only empty origin metadata and preserves original wage/fund history", () => {
  for (const version of [1, 2]) {
    const original = prior(version),
      before = structuredClone(original),
      state = decodeState(original);
    assert.equal(state.version, 3);
    assert.equal(state.revision, original.revision);
    assert.deepEqual(state.templateOrigins, []);
    assert.deepEqual(state.profiles, original.profiles);
    assert.deepEqual(state.periods, original.periods);
    assert.deepEqual(state.benefitChecks, original.benefitChecks ?? []);
    assert.deepEqual(original, before);
    const unknown = prior(version);
    unknown.templateOrigins = [{ privateUnknownRecords: "must not drop" }];
    assert.throws(() => decodeState(unknown));
  }
});
test("confirmed adoption retains source/recipient choices without changing old snapshots", () => {
  const original = prior(2),
    state = adoptedState();
  validateState(state);
  assert.deepEqual(state.periods, original.periods);
  assert.deepEqual(state.benefitChecks, original.benefitChecks);
  assert.equal(state.templateOrigins[0].packet.rules.hourlyRate, null);
  const profile = state.profiles.at(-1),
    result = calculate(original.periods[0].work, profile);
  assert.equal(result.wages, "600.00");
  assert.equal(result.allowances, "120.00");
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  const modified = structuredClone(state);
  modified.profiles.at(-1).hourlyRate = "76";
  // A rate change requires a new profile/choice, not rewriting the confirmed origin.
  assert.throws(() => validateState(modified));
  assert.deepEqual(modified.periods, original.periods);
  const changedRules = structuredClone(state);
  changedRules.profiles.at(-1).dailyOvertimeTiers = [];
  assert.throws(() => validateState(changedRules));
  const unconfirmed = structuredClone(state);
  unconfirmed.templateOrigins[0].applicabilityConfirmed = false;
  assert.throws(() => validateState(unconfirmed));
});
test("one external template identity/revision cannot acquire conflicting contents", () => {
  const state = adoptedState(),
    second = structuredClone(state.templateOrigins[0]);
  second.profileID = "60000000-0000-0000-0000-000000000002";
  second.packet.title = "SYNTHETIC changed without new revision";
  state.profiles.push({
    ...structuredClone(state.profiles.at(-1)),
    id: second.profileID,
  });
  state.templateOrigins.push(second);
  assert.throws(() => validateState(state), /conflicting contents/);
});
