import { assess } from "./assessment.mjs";
import { calendarDate } from "./paycycle.mjs";
import { relatedWeeklyReviews, weeklyMappingReason } from "./weekly.mjs";
export function validatePaycheckScope(scope) {
  const expected = [
    "auditID",
    "periodID",
    "startDate",
    "endDate",
    "timeZone",
    "confirmed",
  ];
  if (
    !scope ||
    typeof scope !== "object" ||
    Array.isArray(scope) ||
    Object.keys(scope).sort().join("|") !== expected.sort().join("|") ||
    typeof scope.auditID !== "string" ||
    typeof scope.periodID !== "string" ||
    typeof scope.confirmed !== "boolean" ||
    typeof scope.timeZone !== "string"
  )
    throw Error("Invalid reported paycheck period.");
  new Intl.DateTimeFormat("en", { timeZone: scope.timeZone });
  if (scope.startDate === null && scope.endDate === null) {
    if (scope.confirmed)
      throw Error("Unknown paycheck dates cannot be marked confirmed.");
    return scope;
  }
  calendarDate(scope.startDate);
  calendarDate(scope.endDate);
  if (scope.endDate < scope.startDate)
    throw Error("Reported paycheck dates are reversed.");
  return scope;
}
export function assessForPeriod(calculation, facts, rounding, period, scope) {
  validatePaycheckScope(scope);
  // Validate facts through the unchanged v1 contract without drawing a mismatched-period direction.
  assess(null, facts, rounding);
  const confirmed = scope.confirmed && scope.startDate !== null;
  const matches =
    confirmed &&
    scope.periodID === period.id &&
    scope.startDate === period.start &&
    scope.endDate === period.end &&
    scope.timeZone === period.zone;
  const status = matches
    ? "confirmedSamePeriod"
    : confirmed
      ? "differentPeriod"
      : "unconfirmedPeriod";
  const source = {
    startDate: scope.startDate,
    endDate: scope.endDate,
    timeZone: scope.timeZone,
    confirmed: scope.confirmed,
  };
  if (!matches)
    return {
      engine: "linepay.web.configured-gross/2",
      verdict: "notComparable",
      gross: null,
      difference: null,
      paidGross: facts.paidGross,
      comparisons: [],
      reasons: [
        confirmed
          ? "Reported paycheck work dates or timezone do not match the selected work period. No directional pay comparison was made."
          : "The paycheck work period has not been confirmed from source dates. No directional pay comparison was made.",
      ],
      periodMatch: status,
      reportedPeriod: source,
    };
  return {
    ...assess(calculation, facts, rounding),
    engine: "linepay.web.configured-gross/2",
    periodMatch: status,
    reportedPeriod: source,
  };
}
export function reproduceAssessment(state, period, audit, calculation) {
  if (audit.assessment.engine === "linepay.web.configured-gross/1")
    return assess(calculation, audit.facts, period.rule.rounding);
  if (
    [
      "linepay.web.configured-gross/2",
      "linepay.web.configured-gross/3",
    ].includes(audit.assessment.engine)
  ) {
    const scope = state.paycheckScopes.find(
      (s) => s.periodID === period.id && s.auditID === audit.id,
    );
    if (!scope)
      throw Error(
        "Saved check has no retained reported-period facts. Nothing was replaced.",
      );
    if (audit.assessment.engine === "linepay.web.configured-gross/3") {
      const count = audit.assessment.weeklyContextCount;
      if (
        !Number.isSafeInteger(count) ||
        count < 0 ||
        count > state.weeklyReviews.length
      )
        throw Error("Invalid retained weekly context.");
      return assessWithWeeklyContext(
        calculation,
        audit.facts,
        period.rule.rounding,
        period,
        scope,
        state.weeklyReviews.slice(0, count),
      );
    }
    return assessForPeriod(
      calculation,
      audit.facts,
      period.rule.rounding,
      period,
      scope,
    );
  }
  throw Error("Unsupported saved comparison version. Nothing was replaced.");
}
export function assessWithWeeklyContext(
  calculation,
  facts,
  rounding,
  period,
  scope,
  reviews,
) {
  const result = assessForPeriod(calculation, facts, rounding, period, scope);
  const references = relatedWeeklyReviews(reviews, period.id).map((r) => r.id);
  return {
    ...result,
    engine: "linepay.web.configured-gross/3",
    weeklyContextCount: reviews.length,
    weeklyReviewReferences: references,
    verdict:
      references.length && result.gross !== null
        ? "needsReview"
        : result.verdict,
    reasons: references.length
      ? [...result.reasons, weeklyMappingReason]
      : result.reasons,
  };
}
