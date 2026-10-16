import { dec, zero } from "./decimal.mjs";
export function assess(calculation, facts, rounding) {
  if (
    !facts ||
    !["unconfirmed", "wagesOnly", "wagesAndPerDiem"].includes(
      facts.grossBasis,
    ) ||
    ![
      "completeWork",
      "unreviewedFields",
      "unsupportedRules",
      "weeklyReviewPending",
    ].every((k) => typeof facts[k] === "boolean")
  )
    throw Error("Confirm the comparison scope.");
  if (
    dec(facts.paidGross).compare(zero) < 0 ||
    (facts.paidPerDiem !== null && dec(facts.paidPerDiem).compare(zero) < 0)
  )
    throw Error("Paid amounts cannot be negative.");
  if (!calculation)
    return {
      engine: "linepay.web.configured-gross/1",
      verdict: "notComparable",
      gross: null,
      difference: null,
      paidGross: facts.paidGross,
      comparisons: [],
      reasons: ["No safe expected calculation is available."],
    };
  const reasons = [],
    comparisons = [];
  let gross = null;
  if (!facts.completeWork)
    reasons.push("All work for this period has not been confirmed.");
  else if (facts.grossBasis === "unconfirmed")
    reasons.push("Confirm whether gross includes per diem.");
  else
    gross =
      facts.grossBasis === "wagesOnly" ? calculation.wages : calculation.total;
  const compare = (field, expected, paid, parts) => ({
    field,
    expected,
    paid,
    difference: dec(expected)
      .sub(dec(paid))
      .fixed(rounding.scale, rounding.mode),
    componentIDs: parts.map((x) => x.id),
  });
  if (gross !== null)
    comparisons.push(
      compare(
        "grossPay",
        gross,
        facts.paidGross,
        calculation.components.filter(
          (p) =>
            facts.grossBasis === "wagesAndPerDiem" || p.category !== "perDiem",
        ),
      ),
    );
  if (facts.paidPerDiem !== null)
    comparisons.push(
      compare(
        "perDiemPay",
        calculation.allowances,
        facts.paidPerDiem,
        calculation.components.filter((p) => p.category === "perDiem"),
      ),
    );
  if (facts.unreviewedFields)
    reasons.push("Some source fields are still unreviewed.");
  if (facts.unsupportedRules)
    reasons.push("Some applicable rules are not represented.");
  if (facts.weeklyReviewPending)
    reasons.push("A separate complete-workweek review is pending.");
  if (rounding.scope === "legacySegments")
    reasons.push("Legacy segment rounding requires review.");
  const difference =
    comparisons.find((c) => c.field === "grossPay")?.difference ?? null;
  let verdict = "notComparable";
  if (gross !== null) {
    if (reasons.length) verdict = "needsReview";
    else if (
      dec(difference).compare(zero) === 0 &&
      comparisons.some((c) => dec(c.difference).compare(zero) !== 0)
    ) {
      verdict = "needsReview";
      reasons.push("Gross matches, but a confirmed component differs.");
    } else
      verdict =
        dec(difference).compare(zero) > 0
          ? "possibleShortfall"
          : dec(difference).compare(zero) < 0
            ? "possibleOverpayment"
            : "matches";
  }
  return {
    engine: "linepay.web.configured-gross/1",
    verdict,
    gross,
    difference,
    paidGross: facts.paidGross,
    comparisons,
    reasons,
  };
}
