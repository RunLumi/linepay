import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  validateRuleTemplate,
  createRuleTemplate,
  encodeRuleTemplate,
  decodeRuleTemplate,
  adoptRuleTemplate,
} from "../src/rule-template.mjs";
const corpus = JSON.parse(
  readFileSync(
    new URL(
      "../../../shared/contracts/templates/rule-drafts-v1.json",
      import.meta.url,
    ),
  ),
);
assert.equal(corpus.format, "com.streamentry.linepay.rule-template-fixtures");
assert.equal(corpus.version, 1);
assert.equal(corpus.cases.length, 5);
for (const c of corpus.cases)
  test("shared rule draft: " + c.id, () => {
    const copy = structuredClone(c.packet);
    validateRuleTemplate(copy);
    assert.deepEqual(decodeRuleTemplate(encodeRuleTemplate(copy)), c.packet);
    const p = adoptRuleTemplate(copy, {
      ...c.recipient,
      applicabilityConfirmed: true,
      valuesConfirmed: true,
    });
    assert.equal(p.hourlyRate, c.recipient.hourlyRate);
    assert.equal(p.perDiemPerWorkDate, c.recipient.perDiemAmount);
    assert.equal(p.dailyOvertimeTiers.length, c.expected.dailyTierCount);
    assert.equal(p.weekdayPremiums.length, c.expected.weekdayPremiumCount);
    assert.equal(
      c.packet.rules.hourlyRate === null,
      c.expected.hourlyRateRequired,
    );
    assert.equal(
      c.packet.rules.perDiem.configured,
      c.expected.allowanceReviewRequired,
    );
    p.dailyOvertimeTiers.length = 0;
    assert.deepEqual(copy, c.packet);
  });
const packet = () => structuredClone(corpus.cases[0].packet);
test("default export strips amounts, personal records and ledger identity by construction", () => {
  const source = {
    id: "private-profile-id",
    version: "5",
    currency: "USD",
    hourlyRate: "58.40",
    regularSchedule: [],
    outsideScheduleMultiplier: "1",
    dailyOvertimeTiers: [{ afterHours: "8", multiplier: "1.5" }],
    weekdayPremiums: [],
    datePremiums: [],
    calloutMinimumHours: "4",
    perDiemPerWorkDate: "140",
    rounding: { scale: 2, mode: "halfUp", scope: "payCategory" },
    workerName: "PRIVATE SYNTHETIC NAME",
    work: [{ gross: "999" }],
    paystub: "PRIVATE SYNTHETIC DOCUMENT",
  };
  const options = {
    templateID: packet().templateID,
    revision: "1",
    title: "SYNTHETIC selected rules",
  };
  const draft = createRuleTemplate(source, options),
    text = new TextDecoder().decode(encodeRuleTemplate(draft));
  assert.equal(draft.rules.hourlyRate, null);
  assert.deepEqual(draft.rules.perDiem, { configured: true, amount: null });
  for (const privateValue of [
    "58.40",
    "140",
    "private-profile-id",
    "PRIVATE SYNTHETIC",
    "paystub",
    "workerName",
  ])
    assert.equal(text.includes(privateValue), false);
  const included = createRuleTemplate(source, {
    ...options,
    includeAmounts: true,
  });
  assert.equal(included.rules.hourlyRate, "58.4");
  assert.equal(included.rules.perDiem.amount, "140");
  assert.throws(() =>
    createRuleTemplate({ ...source, regularSchedule: [{}] }, options),
  );
});
test("unreviewed applicability or omitted monetary values cannot become an adopted profile", () => {
  const p = packet(),
    recipient = corpus.cases[0].recipient;
  assert.throws(() =>
    adoptRuleTemplate(p, {
      ...recipient,
      applicabilityConfirmed: false,
      valuesConfirmed: true,
    }),
  );
  assert.throws(() =>
    adoptRuleTemplate(p, {
      ...recipient,
      hourlyRate: null,
      applicabilityConfirmed: true,
      valuesConfirmed: true,
    }),
  );
  assert.throws(() =>
    adoptRuleTemplate(p, {
      ...recipient,
      perDiemDecision: "unreviewed",
      applicabilityConfirmed: true,
      valuesConfirmed: true,
    }),
  );
});
test("private/unknown fields, numeric money and incompatible rule shapes fail closed", () => {
  const unknown = packet();
  unknown.workRecords = [];
  assert.throws(() => validateRuleTemplate(unknown));
  const number = packet();
  number.rules.hourlyRate = 50;
  assert.throws(() => validateRuleTemplate(number));
  const stacked = packet();
  stacked.premiumCombination = "multiply";
  assert.throws(() => validateRuleTemplate(stacked));
  const legacy = packet();
  legacy.rules.rounding.scope = "legacySegments";
  assert.throws(() => validateRuleTemplate(legacy));
  const inconsistent = packet();
  inconsistent.rules.perDiem.configured = false;
  inconsistent.rules.perDiem.amount = "100";
  assert.throws(() => validateRuleTemplate(inconsistent));
  const fractional = packet();
  fractional.rules.dailyOvertimeTiers[0].afterHours = "0.00001";
  assert.throws(() => validateRuleTemplate(fractional));
  assert.throws(() => decodeRuleTemplate(new Uint8Array(65537)));
});

test("escaped duplicate money fields are rejected before a draft can be reviewed", () => {
  const text = JSON.stringify(packet()).replace(
    '"hourlyRate":null',
    '"hourlyRate":null,"hourly\\u0052ate":"99"',
  );
  assert.throws(
    () => decodeRuleTemplate(new TextEncoder().encode(text)),
    /Duplicate rule-draft fields/,
  );
});
