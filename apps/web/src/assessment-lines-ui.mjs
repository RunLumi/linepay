import {
  moneyFields,
  hourFields,
  validateLineScope,
} from "./assessment-lines.mjs";
export const comparisonNames = {
  grossPay: "Gross pay",
  perDiemPay: "Per diem",
  regularPay: "Regular/base pay",
  overtimePay: "Overtime pay",
  doubleTimePay: "Double-time pay",
  calloutPay: "Separate callout pay",
  regularHours: "Regular/base hours",
  overtimeHours: "Overtime hours",
  doubleTimeHours: "Double-time hours",
};
export function lineFields() {
  const input = (f) =>
    `<label>${comparisonNames[f]}<input name="${f}" inputmode="decimal" aria-describedby="line-facts-note"></label>`;
  return `<details id="paycheck-line-fields"><summary>Hours and earnings lines (optional)</summary>
 <p id="line-facts-note">Enter only current-period values you identified on the source. Typed values count as your confirmation. Blank is unknown, not zero. Money and hours are separate quantities. Expected hours are shown to four decimals; hour differences use half-up rounding to four decimals, independently of wage rounding.</p>
 <label for="paycheck-line-layout">Earnings layout</label><select id="paycheck-line-layout" name="line-layout"><option value="unconfirmed">Unconfirmed</option><option value="fullRateBuckets">Full rates</option><option value="basePlusPremium">Base + extra</option></select>
 <p>Full rates include the base within each overtime line. Premium-only lines show the extra above base; the base line covers all applicable hours.</p>
 <label for="paycheck-hours-basis">Hours mean</label><select id="paycheck-hours-basis" name="hours-basis"><option value="unconfirmed">Unconfirmed</option><option value="actualWork">Worked hours</option><option value="paidEquivalents">Paid equivalents</option></select>
 <p>Paid-equivalent hours include a callout guarantee only when you map it into the hourly lines. Actual worked hours always exclude that top-up.</p><label for="paycheck-guarantee-layout">Callout guarantee</label><select id="paycheck-guarantee-layout" name="guarantee-layout"><option value="unconfirmed">Unconfirmed</option><option value="separateLine">Separate line</option><option value="includedInHourlyLines">Hourly lines</option></select>
 <div class="fields">${moneyFields.map(input).join("")}</div><div class="fields">${hourFields.map(input).join("")}</div>
 <label><input type="checkbox" name="complete-earnings">These confirmed earnings lines are the complete breakdown of the stated gross, including any confirmed per diem.</label>
 <p class="note">Unknown mapping, unusual multipliers and unresolved weekly coverage can require review even when gross matches.</p></details>`;
}
export function readLineScope(form, auditID, periodID) {
  const data = new FormData(form),
    values = (fields) =>
      Object.fromEntries(
        fields.flatMap((f) => {
          const value = String(data.get(f) ?? "").trim();
          return value ? [[f, value]] : [];
        }),
      );
  return validateLineScope({
    auditID,
    periodID,
    layout: String(data.get("line-layout")),
    hoursBasis: String(data.get("hours-basis")),
    guaranteeLayout: String(data.get("guarantee-layout")),
    completeEarnings: data.has("complete-earnings"),
    amounts: values(moneyFields),
    hours: values(hourFields),
  });
}
export function mappingSummary(mapping, esc) {
  if (!mapping) return "";
  const layouts = {
      unconfirmed: "Not confirmed",
      fullRateBuckets: "Full hourly rates",
      basePlusPremium: "Base plus extra premium",
    },
    hours = {
      unconfirmed: "Not confirmed",
      actualWork: "Actual worked hours",
      paidEquivalents: "Paid equivalents",
    },
    guarantees = {
      unconfirmed: "Not confirmed",
      separateLine: "Separate line",
      includedInHourlyLines: "Included in hourly lines",
    };
  return `<p class="context">Earnings layout: ${esc(layouts[mapping.layout])}<br>Hours mean: ${esc(hours[mapping.hoursBasis])}<br>Callout guarantee: ${esc(guarantees[mapping.guaranteeLayout])}<br>Complete earnings breakdown: ${mapping.completeEarnings ? "confirmed by the worker" : "not confirmed"}</p>`;
}

export function comparisonEvidence(comparison, calculation, rule, esc) {
  const selected = (calculation?.components ?? []).filter((c) =>
    comparison.componentIDs.includes(c.id),
  );
  if (!selected.length)
    return '<p class="note">No applicable ledger component for this confirmed line.</p>';
  const categories = {
    workedHours: "Worked time",
    calloutGuarantee: "Callout paid equivalent",
    perDiem: "Separate per diem",
  };
  return `<details class="comparison-evidence" data-comparison-evidence="${esc(comparison.field)}"><summary>Work and rules behind ${esc(comparisonNames[comparison.field] ?? comparison.field)}</summary><ul>${selected.map((c) => `<li>${esc(c.date)} · ${esc(categories[c.category] ?? c.category)} · ${esc(c.currency)} ${esc(c.amount)}<br>${c.workedSeconds === null ? "Worked local date" : esc(c.workedSeconds) + " paid seconds at " + esc(c.multiplier) + "×"}${c.category === "perDiem" ? "" : "; applied base " + esc(c.baseRate ?? rule.hourlyRate) + "/hour"}<br>Rule ${esc(c.reference.id)} / ${esc(c.reference.version)}</li>`).join("")}</ul><p class="note">These are the saved ledger components behind the comparison. Premium-only base and extra split the same rounded bucket. Guarantee top-ups are paid equivalents, not additional actual work.</p></details>`;
}
