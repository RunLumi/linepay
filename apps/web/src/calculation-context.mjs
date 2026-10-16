import { calculate } from "./payroll.mjs";
import { calculateTimeline } from "./payroll-v2.mjs";
export function currentTimeline(state, periodID) {
  return (
    state.ruleTimelines.filter((t) => t.periodID === periodID).at(-1) ?? null
  );
}
export function currentCalculation(state, period, work = period.work) {
  const timeline = currentTimeline(state, period.id);
  return timeline
    ? calculateTimeline(work, period.rule, timeline)
    : calculate(work, period.rule);
}
export function reproduceSavedCalculation(state, period, work, saved) {
  if (saved.engine === "linepay.web.configured-pay/1")
    return calculate(work, period.rule);
  if (saved.engine === "linepay.web.configured-pay/2") {
    const timeline = state.ruleTimelines.find(
      (t) => t.id === saved.ruleTimelineID && t.periodID === period.id,
    );
    if (!timeline)
      throw Error(
        "Saved calculation has no retained rule timeline. Nothing was replaced.",
      );
    return calculateTimeline(work, period.rule, timeline);
  }
  throw Error("Unsupported saved calculation version. Nothing was replaced.");
}
export function auditUsesEarlierContext(state, period, audit) {
  return (
    JSON.stringify(audit.work) !== JSON.stringify(period.work) ||
    (audit.calculation.ruleTimelineID ?? null) !==
      (currentTimeline(state, period.id)?.id ?? null)
  );
}
