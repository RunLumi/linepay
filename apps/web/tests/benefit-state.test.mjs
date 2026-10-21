import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { calculateContributions } from "../src/benefits.mjs";
import {
  decodeState,
  validateState,
  emptyState,
  snapshot,
  inspectSnapshot,
} from "../src/state.mjs";
import { encryptBackup, decryptBackup } from "../src/backup.mjs";
const old = () =>
  JSON.parse(
    readFileSync(new URL("./fixtures/web-state-v1.json", import.meta.url)),
  );
const sample = () =>
  JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/benefits/confirmed-fund-v1.json",
        import.meta.url,
      ),
    ),
  ).cases[0];
const checkID = "40000000-0000-0000-0000-000000000001",
  revisionID = "40000000-0000-0000-0000-000000000002";
function revision(s, id = revisionID) {
  return {
    id,
    createdAt: "2026-10-17T00:00:00Z",
    sourceReference: "SYNTHETIC rule; no actual agreement authority",
    segments: s.segments,
    completeEligibilityConfirmed: s.completeEligibilityConfirmed,
    rounding: s.rounding,
    statement: s.statement,
    result: calculateContributions(s),
  };
}
function withFund() {
  const state = decodeState(old()),
    s = sample();
  state.benefitChecks.push({
    id: checkID,
    fundID: s.segments[0].rule.fundID,
    name: "SYNTHETIC fund",
    currency: "USD",
    period: s.period,
    revisions: [revision(s)],
  });
  return state;
}
test("actual v1 source fixture migrates without writes, repricing or invented fund data", () => {
  const original = old(),
    before = structuredClone(original),
    migrated = decodeState(original);
  assert.equal(migrated.version, 9);
  assert.equal(migrated.revision, 8);
  assert.deepEqual(migrated.benefitChecks, []);
  assert.deepEqual(migrated.periods, original.periods);
  assert.deepEqual(migrated.profiles, original.profiles);
  assert.deepEqual(original, before);
  const bytes = new TextEncoder().encode(
    JSON.stringify({
      format: "com.streamentry.linepay.web.snapshot",
      version: 1,
      state: original,
    }),
  );
  assert.deepEqual(inspectSnapshot(bytes), migrated);
  const unknown = old();
  unknown.benefitChecks = [{ hiddenFinancialData: "must not drop" }];
  assert.throws(() => decodeState(unknown));
  const future = old();
  future.version = 8;
  assert.throws(() => decodeState(future));
});
test("fund revisions preserve missing observations and exact later statement differences", () => {
  const state = withFund(),
    first = structuredClone(state.benefitChecks[0].revisions[0]),
    s = sample();
  s.statement = {
    fundID: s.segments[0].rule.fundID,
    currency: "USD",
    period: structuredClone(s.period),
    employerContribution: "350.001",
    quantity: "40",
    quantityBasis: "eligibleHour",
    confirmed: true,
  };
  state.benefitChecks[0].revisions.push(
    revision(s, "40000000-0000-0000-0000-000000000003"),
  );
  validateState(state);
  assert.deepEqual(state.benefitChecks[0].revisions[0], first);
  assert.equal(first.result.status, "notVerified");
  assert.equal(first.result.paid, null);
  assert.equal(state.benefitChecks[0].revisions[1].result.difference, "-0.001");
  assert.deepEqual(inspectSnapshot(snapshot(state)), state);
  const changed = structuredClone(state);
  changed.benefitChecks[0].revisions[1].result.difference = "0";
  assert.throws(() => validateState(changed));
  const hidden = structuredClone(state);
  hidden.benefitChecks[0].revisions[0].statementOriginals = [];
  assert.throws(() => validateState(hidden));
});
test("cross-revision immutable rule IDs cannot conceal a new definition", () => {
  const state = withFund(),
    s = sample();
  s.segments[0].rule.rate = "9";
  s.segments[0].rule.id = s.segments[0].rule.id.toUpperCase();
  state.benefitChecks[0].revisions.push(
    revision(s, "40000000-0000-0000-0000-000000000004"),
  );
  assert.throws(
    () => validateState(state),
    /conflicting immutable definitions/,
  );
});
test("encrypted v1 recovery migrates safely and v2 fund history round-trips exactly", async () => {
  const password = JSON.parse(
    readFileSync(
      new URL(
        "../../../shared/contracts/backup/encryption-v1.json",
        import.meta.url,
      ),
    ),
  ).uiPhraseASCII;
  const prior = old(),
    bytes = new TextEncoder().encode(
      JSON.stringify({
        format: "com.streamentry.linepay.web.snapshot",
        version: 1,
        state: prior,
      }),
    );
  const recovered = inspectSnapshot(
    await decryptBackup(await encryptBackup(bytes, password), password),
  );
  assert.deepEqual(recovered.periods, prior.periods);
  assert.deepEqual(recovered.benefitChecks, []);
  const current = withFund(),
    sealed = await encryptBackup(snapshot(current), password);
  assert.deepEqual(
    inspectSnapshot(await decryptBackup(sealed, password)),
    current,
  );
  const empty = emptyState();
  assert.deepEqual(empty.benefitChecks, []);
  validateState(empty);
});
