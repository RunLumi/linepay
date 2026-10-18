import { dec, zero, seconds } from "./decimal.mjs";
export const moneyFields = [
  "regularPay",
  "overtimePay",
  "doubleTimePay",
  "calloutPay",
];
export const hourFields = ["regularHours", "overtimeHours", "doubleTimeHours"];
const moneySet = new Set(moneyFields),
  hourSet = new Set(hourFields);
const exactKeys = (value, names) =>
  value &&
  typeof value === "object" &&
  !Array.isArray(value) &&
  Object.keys(value).sort().join("|") === names.slice().sort().join("|");
export function validateLineScope(scope) {
  if (
    !exactKeys(scope, [
      "auditID",
      "periodID",
      "layout",
      "hoursBasis",
      "guaranteeLayout",
      "completeEarnings",
      "amounts",
      "hours",
    ]) ||
    typeof scope.auditID !== "string" ||
    typeof scope.periodID !== "string" ||
    !["unconfirmed", "fullRateBuckets", "basePlusPremium"].includes(
      scope.layout,
    ) ||
    !["unconfirmed", "actualWork", "paidEquivalents"].includes(
      scope.hoursBasis,
    ) ||
    !["unconfirmed", "separateLine", "includedInHourlyLines"].includes(
      scope.guaranteeLayout,
    ) ||
    typeof scope.completeEarnings !== "boolean"
  )
    throw Error("Invalid confirmed paycheck line scope.");
  for (const [values, allowed] of [
    [scope.amounts, moneySet],
    [scope.hours, hourSet],
  ]) {
    if (
      !values ||
      typeof values !== "object" ||
      Array.isArray(values) ||
      Object.keys(values).some((k) => !allowed.has(k))
    )
      throw Error("Unsupported paycheck line.");
    for (const value of Object.values(values)) {
      const number = dec(value);
      if (
        number.compare(zero) < 0 ||
        (allowed === hourSet && number.compare(dec("10000")) > 0)
      )
        throw Error(
          "Confirmed line values must be nonnegative and within the supported hours limit.",
        );
    }
  }
  return scope;
}
// exactComponents come from the frozen work/rule plan, never from rounded decimal hours.
export function compareLines(base, facts, scope, exactComponents, rounding) {
  validateLineScope(scope);
  const reasons = [...base.reasons],
    comparisons = [...base.comparisons];
  const wages = exactComponents.filter((c) => c.category !== "perDiem"),
    guarantees = wages.filter((c) => c.category === "calloutGuarantee"),
    hasLines =
      Object.keys(scope.amounts).length || Object.keys(scope.hours).length,
    knownGuarantees =
      !guarantees.length || scope.guaranteeLayout !== "unconfirmed",
    unusual = wages.some(
      (c) => !["1", "1.5", "2"].includes(c.multiplier ?? "1"),
    ),
    total = (parts) => parts.reduce((n, c) => n.add(dec(c.amount)), zero),
    basePay = (parts) => {
      const groups = new Map();
      for (const c of parts) {
        const key = c.category + "|" + (c.multiplier ?? "1");
        const numerator = dec(c.baseRate).mul(dec(c.workedSeconds));
        groups.set(key, (groups.get(key) ?? zero).add(numerator));
      }
      return [...groups.values()].reduce(
        (n, x) =>
          n.add(dec(x.div(seconds(3600)).fixed(rounding.scale, rounding.mode))),
        zero,
      );
    },
    compare = (field, expected, paid, parts, unit) => ({
      field,
      expected: expected.fixed(
        unit === "hours" ? 4 : rounding.scale,
        unit === "hours" ? "halfUp" : rounding.mode,
      ),
      paid,
      difference: expected
        .sub(dec(paid))
        .fixed(
          unit === "hours" ? 4 : rounding.scale,
          unit === "hours" ? "halfUp" : rounding.mode,
        ),
      componentIDs: parts.map((c) => c.id),
      unit,
    });
  if (hasLines && !knownGuarantees)
    reasons.push(
      "Confirm whether callout guarantees are separate or included in hourly lines.",
    );
  if (hasLines && unusual)
    reasons.push(
      "A multiplier outside 1x, 1.5x or 2x needs manual line mapping.",
    );
  if (hasLines && scope.layout === "unconfirmed")
    reasons.push("Confirm full-rate or base-plus-premium earnings layout.");
  if (
    hasLines &&
    knownGuarantees &&
    !unusual &&
    scope.layout !== "unconfirmed"
  ) {
    const included = wages.filter(
      (c) =>
        c.category === "workedHours" ||
        scope.guaranteeLayout === "includedInHourlyLines",
    );
    for (const [field, multiplier] of [
      ["regularPay", "1"],
      ["overtimePay", "1.5"],
      ["doubleTimePay", "2"],
    ]) {
      if (!Object.hasOwn(scope.amounts, field)) continue;
      const selected = included.filter(
        (c) =>
          (scope.layout === "basePlusPremium" && field === "regularPay") ||
          c.multiplier === multiplier,
      );
      const expected =
        scope.layout === "fullRateBuckets"
          ? total(selected)
          : field === "regularPay"
            ? basePay(selected)
            : total(selected).sub(basePay(selected));
      comparisons.push(
        compare(field, expected, scope.amounts[field], selected, "money"),
      );
    }
    if (Object.hasOwn(scope.amounts, "calloutPay")) {
      if (scope.guaranteeLayout === "separateLine")
        comparisons.push(
          compare(
            "calloutPay",
            total(guarantees),
            scope.amounts.calloutPay,
            guarantees,
            "money",
          ),
        );
      else
        reasons.push(
          "A separate callout amount conflicts with the selected hourly-line mapping.",
        );
    }
    if (Object.keys(scope.hours).length && scope.hoursBasis === "unconfirmed")
      reasons.push(
        "Confirm whether paystub hours are actual work or paid equivalents.",
      );
    else {
      const hourParts =
        scope.hoursBasis === "actualWork"
          ? wages.filter((c) => c.category === "workedHours")
          : included;
      for (const [field, multiplier] of [
        ["regularHours", "1"],
        ["overtimeHours", "1.5"],
        ["doubleTimeHours", "2"],
      ]) {
        if (!Object.hasOwn(scope.hours, field)) continue;
        const selected = hourParts.filter(
            (c) =>
              (scope.layout === "basePlusPremium" &&
                field === "regularHours") ||
              c.multiplier === multiplier,
          ),
          hours = selected
            .reduce((n, c) => n.add(dec(c.workedSeconds)), zero)
            .div(seconds(3600));
        comparisons.push(
          compare(field, hours, scope.hours[field], selected, "hours"),
        );
      }
    }
  }
  const knownBasis =
    facts.grossBasis !== "unconfirmed" && scope.layout !== "unconfirmed";
  const fields = ["regularPay", "overtimePay", "doubleTimePay"];
  if (scope.guaranteeLayout === "separateLine") fields.push("calloutPay");
  const entered = fields
    .filter((f) => Object.hasOwn(scope.amounts, f))
    .map((f) => dec(scope.amounts[f]));
  if (facts.grossBasis === "wagesAndPerDiem" && facts.paidPerDiem !== null)
    entered.push(dec(facts.paidPerDiem));
  if (knownBasis) {
    const subtotal = entered.reduce((n, x) => n.add(x), zero);
    if (
      entered.length &&
      (subtotal.compare(dec(facts.paidGross)) > 0 ||
        (scope.completeEarnings &&
          subtotal.compare(dec(facts.paidGross)) !== 0))
    )
      reasons.push(
        "Confirmed earnings lines conflict with gross. Resolve adjustments or overlapping lines before drawing a pay conclusion.",
      );
    if (scope.completeEarnings && !entered.length)
      reasons.push(
        "No earnings lines were confirmed for the complete breakdown.",
      );
  } else if (scope.completeEarnings)
    reasons.push(
      "Confirm gross basis and earnings layout before declaring the breakdown complete.",
    );
  if (scope.completeEarnings && !knownGuarantees)
    reasons.push("The complete breakdown needs the callout guarantee mapping.");
  const lineDifference = comparisons.some(
    (c) =>
      !["grossPay", "perDiemPay"].includes(c.field) &&
      dec(c.difference).compare(zero) !== 0,
  );
  let verdict = base.verdict;
  if (
    base.gross !== null &&
    (reasons.length ||
      (lineDifference && dec(base.difference).compare(zero) === 0))
  ) {
    verdict = "needsReview";
    if (!reasons.length)
      reasons.push(
        "Gross matches, but a confirmed earnings or hours line differs.",
      );
  }
  return { ...base, verdict, comparisons, reasons };
}
