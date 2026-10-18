import { Decimal, dec, zero, one } from "./decimal.mjs";
const requireFact = (condition, message) => {
  if (!condition) throw Error(message);
};
function exact(value) {
  const significant = value
    .text()
    .replace(/^-/, "")
    .replace(".", "")
    .replace(/^0+/, "")
    .replace(/0+$/, "");
  requireFact(
    significant.length <= 38,
    "Contribution arithmetic exceeds the supported exact decimal capacity. Review is required.",
  );
  return value;
}
const bases = new Set([
  "eligibleHour",
  "eligibleDay",
  "percentOfEligibleEarnings",
  "fixedPeriod",
]);
const identifier = (value) => {
  requireFact(
    typeof value === "string" &&
      /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value),
    "A fund, segment or rule needs a valid immutable identity.",
  );
  return value.toLowerCase();
};
export function validateContributionPeriod(period) {
  requireFact(
    period && typeof period === "object",
    "Enter a complete contribution period.",
  );
  for (const key of ["start", "endExclusive"]) {
    const value = period[key];
    requireFact(
      typeof value === "string" &&
        /^20\d\d-\d\d-\d\d$/.test(value) &&
        new Date(value + "T00:00:00Z").toISOString().slice(0, 10) === value,
      "Contribution dates must be valid dates from 2000 through 2099.",
    );
  }
  requireFact(
    period.endExclusive > period.start && typeof period.timeZone === "string",
    "The contribution end date is exclusive and must follow its start.",
  );
  new Intl.DateTimeFormat("en", { timeZone: period.timeZone });
}
const samePeriod = (a, b) =>
  a.start === b.start &&
  a.endExclusive === b.endExclusive &&
  a.timeZone === b.timeZone;
const contains = (a, b) =>
  a.start <= b.start &&
  a.endExclusive >= b.endExclusive &&
  a.timeZone === b.timeZone;
const currency = (value) => {
  requireFact(
    typeof value === "string" && /^[A-Z]{3}$/.test(value),
    "Confirm an explicit contribution currency.",
  );
  return value;
};
export function contributionRuleDefinition(rule) {
  identifier(rule.id);
  identifier(rule.fundID);
  currency(rule.currency);
  validateContributionPeriod(rule.effectivePeriod);
  requireFact(
    typeof rule.version === "string" &&
      rule.version.trim().length > 0 &&
      rule.version.length <= 128 &&
      bases.has(rule.basis),
    "Confirm the contribution basis and version.",
  );
  requireFact(
    exact(dec(rule.rate)).compare(zero) >= 0,
    "Contribution rate cannot be negative.",
  );
  return JSON.stringify([
    identifier(rule.fundID),
    rule.version,
    rule.basis,
    dec(rule.rate).text(),
    rule.currency,
    rule.effectivePeriod.start,
    rule.effectivePeriod.endExclusive,
    rule.effectivePeriod.timeZone,
  ]);
}
export function calculateContributions({
  period,
  segments,
  completeEligibilityConfirmed,
  statement,
  rounding,
}) {
  validateContributionPeriod(period);
  requireFact(
    completeEligibilityConfirmed === true &&
      Array.isArray(segments) &&
      segments.length > 0 &&
      segments.length <= 1000,
    "Confirm complete eligibility for this fund period.",
  );
  requireFact(
    rounding && rounding.scope === "payCategory",
    "A contribution total requires an explicit fund-total rounding policy.",
  );
  zero.fixed(rounding.scale, rounding.mode);
  const ordered = segments
    .slice()
    .sort((a, b) =>
      a.period.start < b.period.start
        ? -1
        : a.period.start > b.period.start
          ? 1
          : 0,
    );
  const fundID = identifier(ordered[0].rule.fundID),
    code = currency(ordered[0].rule.currency);
  const definitions = new Map(),
    identities = new Set(),
    components = [],
    seenBases = new Set();
  let raw = zero,
    units = zero,
    previousEnd = period.start;
  for (const segment of ordered) {
    const segmentID = identifier(segment.id),
      rule = segment.rule,
      definition = contributionRuleDefinition(rule),
      ruleID = identifier(rule.id);
    requireFact(
      !identities.has(segmentID),
      "Duplicate contribution segment identity.",
    );
    identities.add(segmentID);
    requireFact(
      !definitions.has(ruleID) || definitions.get(ruleID) === definition,
      "One contribution rule identity has conflicting definitions.",
    );
    definitions.set(ruleID, definition);
    validateContributionPeriod(segment.period);
    requireFact(
      segment.eligibilityConfirmed === true,
      "Confirm each segment’s eligibility.",
    );
    const quantity = exact(dec(segment.quantity));
    requireFact(
      quantity.compare(zero) >= 0,
      "Eligible quantity cannot be negative.",
    );
    requireFact(
      identifier(rule.fundID) === fundID && rule.currency === code,
      "One contribution check cannot combine funds or currencies.",
    );
    requireFact(
      contains(period, segment.period) &&
        contains(rule.effectivePeriod, segment.period),
      "An eligibility segment lies outside the contribution period or effective rule dates.",
    );
    requireFact(
      segment.period.start >= previousEnd,
      "Contribution eligibility segments overlap.",
    );
    previousEnd = segment.period.endExclusive;
    if (rule.basis === "fixedPeriod")
      requireFact(
        quantity.compare(one) === 0 &&
          ordered.length === 1 &&
          samePeriod(segment.period, period) &&
          samePeriod(rule.effectivePeriod, period),
        "A fixed-period contribution requires quantity one and the complete exact period; no proration is inferred.",
      );
    let amount = exact(dec(rule.rate).mul(quantity));
    if (rule.basis === "percentOfEligibleEarnings")
      amount = exact(amount.div(dec("100")));
    raw = exact(raw.add(amount));
    units = exact(units.add(quantity));
    seenBases.add(rule.basis);
    components.push({
      segmentID: segment.id,
      ruleID: rule.id,
      ruleVersion: rule.version,
      unroundedAmount: amount.text(),
    });
  }
  const expectedValue = exact(
    new Decimal(
      raw.units(rounding.scale, rounding.mode),
      10n ** BigInt(rounding.scale),
    ),
  );
  const expected = expectedValue.fixed(rounding.scale, rounding.mode),
    basis = seenBases.size === 1 ? ordered[0].rule.basis : null;
  const result = {
    engine: "linepay.web.confirmed-benefit/1",
    fundID,
    period: structuredClone(period),
    currency: code,
    amount: expected,
    components,
    eligibleQuantity: basis === null ? null : units.text(),
    quantityBasis: basis,
    paid: null,
    difference: null,
    quantityDifference: null,
    status: "notVerified",
    limitation: "statementMissing",
  };
  if (statement === null) return result;
  requireFact(
    statement && typeof statement.confirmed === "boolean",
    "Confirm the statement review state.",
  );
  identifier(statement.fundID);
  currency(statement.currency);
  validateContributionPeriod(statement.period);
  requireFact(
    statement.employerContribution === null ||
      dec(statement.employerContribution).compare(zero) >= 0,
    "Statement contribution cannot be negative.",
  );
  requireFact(
    (statement.quantity === null) === (statement.quantityBasis === null) &&
      (statement.quantity === null ||
        (bases.has(statement.quantityBasis) &&
          dec(statement.quantity).compare(zero) >= 0)),
    "Confirm both statement quantity and its basis, or leave both unknown.",
  );
  if (!statement.confirmed)
    return { ...result, limitation: "statementUnconfirmed" };
  if (
    identifier(statement.fundID) !== fundID ||
    statement.currency !== code ||
    !samePeriod(statement.period, period)
  )
    return { ...result, status: "notComparable", limitation: "scopeMismatch" };
  const differenceValue =
    statement.employerContribution === null
      ? null
      : exact(expectedValue.sub(exact(dec(statement.employerContribution))));
  const quantityDifferenceValue =
    statement.quantity !== null &&
    basis !== null &&
    statement.quantityBasis === basis
      ? exact(units.sub(exact(dec(statement.quantity))))
      : null;
  const difference = differenceValue?.text() ?? null,
    quantityDifference = quantityDifferenceValue?.text() ?? null;
  if (difference === null && quantityDifference === null)
    return { ...result, limitation: "noComparableValues" };
  const differs = [differenceValue, quantityDifferenceValue].some(
    (value) => value !== null && value.compare(zero) !== 0,
  );
  return {
    ...result,
    paid: statement.employerContribution,
    difference,
    quantityDifference,
    status: differs ? "possibleDifference" : "comparedValuesMatch",
    limitation:
      difference === null
        ? "unitsOnly"
        : statement.quantity !== null && quantityDifference === null
          ? "amountOnlyDifferentBasis"
          : "confirmedValuesOnly",
  };
}
