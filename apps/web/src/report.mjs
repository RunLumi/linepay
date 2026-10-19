import { comparisonNames, mappingSummary } from "./assessment-lines-ui.mjs";
import { relatedWeeklyReviews } from "./weekly.mjs";
import { epoch } from "./payroll.mjs";
import { selectedAudit, resolutionStatuses } from "./resolution.mjs";
export const REPORT_CSS = `:root{color-scheme:light;font:16px/1.45 Arial,sans-serif;color:#13171A;background:#fff}*{box-sizing:border-box}body{max-width:900px;margin:auto;padding:32px}h1{font-size:27px;line-height:1.15}h2{font-size:19px;margin-top:28px}h3{font-size:16px}p,li{overflow-wrap:anywhere}.context{font-size:13px;color:#384147}.scope{border-left:3px solid #0b6d66;padding:10px 16px}table{border-collapse:collapse;width:100%;margin:16px 0}th,td{text-align:left;vertical-align:top;border-bottom:1px solid #aab2b6;padding:10px 6px;overflow-wrap:anywhere}th{font-weight:600}.amount{font-variant-numeric:tabular-nums;text-align:right}.note{white-space:pre-wrap}thead{display:table-header-group}tr{break-inside:avoid}a{color:inherit}@page{size:letter;margin:.55in}@media print{body{max-width:none;padding:0}h2,h3{break-after:avoid}p{orphans:3;widows:3}.amount{min-width:7em}}`;
// The hash is checked against both the source document and the app's frame policy by Node tests.
export const REPORT_STYLE_HASH =
  "sha256-vH1IHgZQMOfSn59p/jhnAtNgS3mzKtrxAgw41hEEcVs=";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const verdicts = {
  matches: "Match within compared scope",
  possibleShortfall: "Possible shortfall",
  possibleOverpayment: "Possible overpayment",
  needsReview: "Needs review",
  notComparable: "Unable to verify",
};
const grossBases = {
  unconfirmed: "Not confirmed",
  wagesOnly: "Cash wages only",
  wagesAndPerDiem: "Cash wages and per diem",
};
const categories = {
  workedHours: "Recorded worked time",
  calloutGuarantee: "Callout guarantee (paid equivalent, not actual work)",
  perDiem: "Separate configured per diem",
};
const roundingNames = {
  halfUp: "Half up",
  bankers: "Nearest, ties to even",
  down: "Down",
  up: "Up",
};
const money = (value, currency) =>
  value === null
    ? "Unable to verify / unknown"
    : `${esc(currency)} ${esc(value)}`;
function optionsValid(options) {
  if (
    !options ||
    Object.keys(options).sort().join("|") !==
      ["includeFollowUps", "includeWorkFacts", "includeTemplateReference"]
        .sort()
        .join("|") ||
    !Object.values(options).every((v) => typeof v === "boolean")
  )
    throw Error("Review the report privacy choices.");
}
export function createPaycheckReport(
  state,
  { periodID, auditID, createdAt, options },
) {
  optionsValid(options);
  epoch(createdAt);
  const { period, audit } = selectedAudit(state, periodID, auditID),
    saved = audit.assessment,
    calculation = audit.calculation,
    currency = period.rule.currency;
  if (
    !Object.hasOwn(verdicts, saved.verdict) ||
    !Object.hasOwn(grossBases, audit.facts.grossBasis)
  )
    throw Error("This saved check needs review before reporting.");
  const savedTimeline =
    calculation.engine === "linepay.web.configured-pay/2"
      ? state.ruleTimelines.find(
          (t) =>
            t.id === calculation.ruleTimelineID && t.periodID === period.id,
        )
      : null;
  if (calculation.engine === "linepay.web.configured-pay/2" && !savedTimeline)
    throw Error("This saved report has no retained rule plan.");
  const snapshots = calculation.ruleSnapshots ?? [period.rule];
  const sourceIDs = new Set([
    period.rule.id,
    ...(savedTimeline?.changes.map((c) => c.sourceProfileID) ?? []),
  ]);
  const draftOrigins = state.templateOrigins.filter((o) =>
    sourceIDs.has(o.profileID),
  );
  const schedule = state.paycycleSchedules.find(
    (s) => s.periodID === period.id,
  );
  const sourcePeriod = saved.reportedPeriod;
  const periodStatement = sourcePeriod
    ? sourcePeriod.startDate === null
      ? "Not stated / unconfirmed"
      : `${sourcePeriod.startDate} through ${sourcePeriod.endDate} · ${sourcePeriod.timeZone} · ${sourcePeriod.confirmed ? "confirmed from source" : "unconfirmed"}`
    : "Separate source dates were not retained by this legacy comparison.";
  const events = state.resolutionEvents.filter(
      (e) => e.periodID === periodID && e.auditID === auditID,
    ),
    origin = state.templateOrigins.find((o) => o.profileID === period.rule.id);
  const row = (label, value) =>
    `<tr><th scope="row">${esc(label)}</th><td class="amount">${value}</td></tr>`;
  const weeklyContextNote = relatedWeeklyReviews(
    state.weeklyReviews,
    period.id,
  ).some((r) => !(saved.weeklyReviewReferences ?? []).includes(r.id))
    ? "This recorded comparison predates later retained weekly evidence. Its original values are preserved; review a new check for current decisions. Weekly/paycheck mapping remains unchecked."
    : "Weekly/paycheck mapping remains separately unchecked.";
  const body = `<p class="scope">${esc(weeklyContextNote)}</p><h1>Paycheck Audit: LinePay evidence report</h1><p class="context">Work period: ${esc(period.start)} through ${esc(period.end)} (included)<br>Payroll timezone: ${esc(period.zone)}<br>Report created: ${esc(createdAt)}<br>Saved paycycle: ${schedule ? esc(schedule.window.cadence) : "not retained in this legacy record"}<br>Saved check: ${esc(auditID)} · recorded ${esc(audit.createdAt)}</p><p class="scope">Configured estimate and worker-confirmed observations. This report is not a legal-pay audit, debt finding or proof of money recovered. It contains sensitive amounts, dates and rule references; review your recipient.</p><h2>Saved comparison</h2>${mappingSummary(saved.lineMapping, esc)}<p><strong>${esc(verdicts[saved.verdict])}</strong></p><table><caption>Amounts remain exactly as saved; no calculation is rerun for this report.</caption><tbody>${row("Expected cash wages", money(calculation.wages, currency))}${row("Separate configured allowance", money(calculation.allowances, currency))}${row("Confirmed paycheck gross", money(saved.paidGross, currency))}${row("Expected on the confirmed gross basis", money(saved.gross, currency))}${row("Expected minus confirmed", money(saved.difference, currency))}${row("Reported paycheck work dates", esc(periodStatement))}${row("Period matching", saved.periodMatch === "confirmedSamePeriod" ? "Confirmed same work period" : saved.periodMatch === "differentPeriod" ? "Different work period / context" : saved.periodMatch === "unconfirmedPeriod" ? "Source period not confirmed" : "Legacy worker-confirmed basis; separate date facts not retained")}${row("Confirmed gross basis", esc(grossBases[audit.facts.grossBasis]))}${row("All work confirmed complete", audit.facts.completeWork ? "Yes, by the worker" : "No")}</tbody></table>${saved.reasons.length ? `<h3>Recorded review reasons</h3><ul>${saved.reasons.map((reason) => `<li>${esc(reason)}</li>`).join("")}</ul>` : ""}<p>Only the stated gross basis and listed confirmed values were compared. Unlisted hours/earnings, weekly/statutory entitlement and unconfigured rules remain separately unchecked. Hour expectations are displayed to four decimals; hour differences use their own half-up four-decimal policy. A matching gross can hide offsetting differences.</p><table><caption>Listed confirmed comparisons</caption><thead><tr><th>Value</th><th>Expected</th><th>Confirmed</th><th>Difference</th></tr></thead><tbody>${saved.comparisons.map((c) => `<tr><th scope="row">${esc(comparisonNames[c.field] ?? c.field)}<br><small>Ledger rows: ${c.componentIDs.map((id) => calculation.components.findIndex((part) => part.id === id) + 1).join(", ") || "none"}</small></th><td class="amount">${c.unit === "hours" ? esc(c.expected) + " h" : money(c.expected, currency)}</td><td class="amount">${c.unit === "hours" ? esc(c.paid) + " h" : money(c.paid, currency)}</td><td class="amount">${c.unit === "hours" ? esc(c.difference) + " h" : money(c.difference, currency)}</td></tr>`).join("")}</tbody></table><h2>Saved calculation and rules</h2><p class="context">Calculation engine: ${esc(calculation.engine)}<br>Comparison engine: ${esc(saved.engine)}<br>Rule snapshot: ${esc(period.rule.id)} · version ${esc(period.rule.version)}<br>Confirmed base rate: ${money(period.rule.hourlyRate, currency)}/hour${savedTimeline ? " (baseline; see dated snapshots below)" : ""}<br>Premium combination: highest applicable; multipliers do not multiply together.<br>Rounding: ${esc(roundingNames[period.rule.rounding.mode])}, ${period.rule.rounding.scale} decimal places, grouped by pay category</p>${savedTimeline ? `<h3>Saved effective-date rule plan</h3><p class="context">Retained plan ${esc(savedTimeline.id)}. Later plans did not rewrite this check.</p><ul>${snapshots.map((r) => `<li>${r.version === period.rule.version ? "Baseline" : "From " + esc(savedTimeline.changes.find((c) => c.agreement.version === r.version)?.effectiveDate)}: ${money(r.hourlyRate, currency)}/hour; rule ${esc(r.id)}/${esc(r.version)}; daily tiers ${esc(r.dailyOvertimeTiers.map((t) => t.afterHours + "h at " + t.multiplier + "×").join(", ") || "not configured")}; weekday premiums ${esc(r.weekdayPremiums.map((p) => p.weekday + " at " + p.multiplier + "×").join(", ") || "not configured")}; isolated minimum ${r.calloutMinimumHours === null ? "not configured" : esc(r.calloutMinimumHours) + " hours"}; flat per diem ${r.perDiemPerWorkDate === null ? "not configured" : money(r.perDiemPerWorkDate, currency)}</li>`).join("")}</ul>` : ""}<h3>Baseline configured parameters</h3><ul>${period.rule.dailyOvertimeTiers.map((t) => `<li>After ${esc(t.afterHours)} daily hours: ${esc(t.multiplier)}×</li>`).join("")}${period.rule.weekdayPremiums.map((p) => `<li>${esc(p.weekday)} premium: ${esc(p.multiplier)}×</li>`).join("")}<li>Isolated callout minimum: ${period.rule.calloutMinimumHours === null ? "not configured" : esc(period.rule.calloutMinimumHours) + " hours"}</li><li>Flat per diem per worked local date: ${period.rule.perDiemPerWorkDate === null ? "not configured" : money(period.rule.perDiemPerWorkDate, currency)}</li></ul><p>Unconfigured is not waived. These parameters do not establish complete agreement or statutory coverage.</p><table><caption>Saved pay components</caption><thead><tr><th>Local date / component</th><th>Recorded basis</th><th>Amount</th></tr></thead><tbody>${calculation.components.map((c, index) => `<tr><th scope="row">Row ${index + 1}<br>${esc(c.date)}<br>${esc(categories[c.category] ?? c.category)}</th><td>${c.category === "calloutGuarantee" ? `Confirmed minimum top-up at ${esc(c.multiplier)}×; actual work is unchanged` : c.workedSeconds === null ? "Worked local date" : `${esc(c.workedSeconds.replace(/\.0+$/, ""))} recorded seconds at ${esc(c.multiplier)}×`}<br>${c.baseRate ? `Applied rate: ${money(c.baseRate, currency)}/hour<br>` : ""}${esc(c.explanation)}<br>Rule ${esc(c.reference.id)} / ${esc(c.reference.version)}</td><td class="amount">${money(c.amount, currency)}</td></tr>`).join("")}</tbody></table>${options.includeWorkFacts ? `<h2>Optional recorded work facts</h2><p>Original instants are listed with their recorded payroll timezone. Unpaid breaks are worker-classified inputs.</p><ul>${audit.work.map((w) => `<li>${esc(w.kind)}: ${esc(w.startUTC)} → ${esc(w.endUTC)} · ${esc(w.timeZone)}${w.unpaidBreaks.length ? `<ul>${w.unpaidBreaks.map((b) => `<li>Unpaid break: ${esc(b.startUTC)} → ${esc(b.endUTC)}</li>`).join("")}</ul>` : ""}</li>`).join("")}</ul>` : ""}${options.includeFollowUps ? `<h2>Optional worker-recorded follow-up</h2><p>These are the worker’s reports, not independent confirmation of correction, payment or recovery. They do not change the saved comparison above.</p>${events.length ? events.map((event) => `<section><h3>${esc(resolutionStatuses[event.status])}</h3><p class="context">Recorded ${esc(event.createdAt)} · saved check ${esc(event.auditID)}</p><p class="note">${esc(event.note)}</p></section>`).join("") : "<p>No follow-up was recorded for this check.</p>"}` : ""}${options.includeTemplateReference && draftOrigins.length ? `<h2>Optional rule-draft reference</h2><ul>${draftOrigins.map((o) => `<li>${esc(o.packet.title)} · revision ${esc(o.packet.revision)} · ${esc(o.packet.templateID)}</li>`).join("")}</ul><p>This is an unverified worker-provided parameter draft, not source approval. Recipient amounts and applicability were confirmed separately.</p>` : ""}<h2>Question for review</h2><p>Could you help me understand the difference between these confirmed work records and the paycheck for this period?</p><p class="context">No original documents are attached. Follow-up notes, detailed clock entries and imported-draft text are excluded unless explicitly selected. User-directed downloads/printing can leave this browser; the app does not send this report to an employer, union or LinePaycheck server.</p>`;
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src '${REPORT_STYLE_HASH}'; script-src 'none'; base-uri 'none'; form-action 'none'; object-src 'none'"><title>Paycheck Audit: LinePay evidence report</title><style>${REPORT_CSS}</style></head><body>${body}</body></html>`;
  const bytes = new TextEncoder().encode(html);
  if (bytes.length > 2097152)
    throw Error(
      "Selected report exceeds 2 MiB. Reduce optional details; nothing was exported.",
    );
  return {
    html,
    bytes,
    periodID,
    auditID,
    createdAt,
    options: structuredClone(options),
  };
}
