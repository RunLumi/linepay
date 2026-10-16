import { calculateTimeline } from "./payroll-v2.mjs";
import { currentCalculation, currentTimeline } from "./calculation-context.mjs";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const roundingNames = {
  halfUp: "Half up",
  bankers: "Nearest, ties to even",
  down: "Down",
  up: "Up",
};
function description(r) {
  return `${r.currency} ${r.hourlyRate}/hour; daily tiers ${r.dailyOvertimeTiers.map((t) => `${t.afterHours}h → ${t.multiplier}×`).join(", ") || "not configured"}; weekday premiums ${r.weekdayPremiums.map((p) => `${p.weekday} ${p.multiplier}×`).join(", ") || "not configured"}; isolated minimum ${r.calloutMinimumHours === null ? "not configured" : r.calloutMinimumHours + " hours"}; flat per diem ${r.perDiemPerWorkDate === null ? "not configured" : r.currency + " " + r.perDiemPerWorkDate + " per worked local date"}; ${roundingNames[r.rounding.mode]}, ${r.rounding.scale} decimals, pay category`;
}
export function renderRuleTimelineUI({
  container,
  state,
  period,
  run,
  onSave,
  uid,
  now,
}) {
  const records = state.ruleTimelines.filter((t) => t.periodID === period.id),
    latest = currentTimeline(state, period.id);
  const history = records
    .map(
      (t, i) =>
        `<details><summary>Retained rule plan ${i + 1} · ${esc(t.createdAt)}</summary><ul>${t.changes.map((c) => `<li>From ${esc(c.effectiveDate)}: ${esc(description(c.agreement))}<br><small>Rule version ${esc(c.agreement.version)}</small></li>`).join("") || "<li>Baseline rules only.</li>"}</ul></details>`,
    )
    .join("");
  container.innerHTML = `<details ${latest ? "open" : ""}><summary>Effective-date rule plan</summary><p>Baseline: ${esc(description(period.rule))}.</p><p>Each confirmed change starts at midnight on its payroll-local date in ${esc(period.zone)}. Earlier saved checks retain their original work and rule plan. A revised plan requires another explicit review; it does not rewrite old results.</p>${history}${period.closed ? "<p>This closed period retains its final rule plan. Its work/rules cannot be edited.</p>" : `<form data-timeline-owned><h3>Review a new rule-plan revision</h3><section class="timeline-changes"></section><button type="button" data-add-change>Add effective change</button><p>Removing every change and reviewing creates a new baseline-only plan. Older plans/checks remain retained. Review source profile, rates, premiums, allowances and dates together.</p><label><input type="checkbox" name="dates-confirmed" required>I confirmed these complete rules and effective dates apply to this period.</label><button>Review proposed rule plan</button></form><section class="timeline-preview" aria-live="polite"></section>`}</details>`;
  if (period.closed) return;
  const form = container.querySelector("form"),
    rows = form.querySelector(".timeline-changes"),
    preview = container.querySelector(".timeline-preview");
  let prepared = null,
    next = 0;
  const invalidate = (event) => {
    prepared = null;
    preview.replaceChildren();
    if (!event || event.target.type !== "checkbox")
      form.elements["dates-confirmed"].checked = false;
  };
  function add(change = null) {
    if (rows.children.length >= 20)
      throw Error(
        "This editor supports up to 20 effective changes per revision.",
      );
    const index = next++,
      element = document.createElement("fieldset");
    element.dataset.effectiveChange = String(index);
    element.innerHTML = `<legend>Effective change ${index + 1}</legend><div class="fields"><label>Effective payroll-local date<input type="date" name="effective-date" value="${esc(change?.effectiveDate ?? "")}" required></label><div><label for="effective-profile-${index}">Confirmed source profile</label><select id="effective-profile-${index}" name="source-profile" required><option value="">Choose a confirmed profile</option>${state.profiles.map((p, i) => `<option value="${esc(p.id)}" ${p.id === change?.sourceProfileID ? "selected" : ""}>Profile ${i + 1} · ${esc(p.currency)} ${esc(p.hourlyRate)}/hour</option>`).join("")}</select></div></div><button type="button">Remove effective change</button>`;
    element.querySelector("button").onclick = () => {
      element.remove();
      invalidate();
    };
    rows.append(element);
  }
  for (const c of latest?.changes ?? []) add(c);
  form.querySelector("[data-add-change]").onclick = () =>
    run(async () => {
      add();
      invalidate();
    });
  form.addEventListener("input", invalidate);
  form.addEventListener("change", invalidate);
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    run(async () => {
      if (!new FormData(form).has("dates-confirmed"))
        throw Error(
          "Confirm the applicable dates and complete rules before review.",
        );
      const record = {
        id: uid(),
        periodID: period.id,
        createdAt: now(),
        confirmed: true,
        changes: [...rows.querySelectorAll("[data-effective-change]")]
          .map((row) => {
            const effectiveDate = row.querySelector(
                "[name=effective-date]",
              ).value,
              sourceProfileID = row.querySelector(
                "[name=source-profile]",
              ).value,
              source = state.profiles.find((p) => p.id === sourceProfileID);
            if (!source) throw Error("Choose a confirmed source profile.");
            if (effectiveDate < period.start || effectiveDate > period.end)
              throw Error("An effective date lies outside this period.");
            return {
              effectiveDate,
              sourceProfileID,
              agreement: {
                ...structuredClone(source),
                id: period.rule.id,
                version: uid(),
              },
            };
          })
          .sort((a, b) =>
            a.effectiveDate < b.effectiveDate
              ? -1
              : a.effectiveDate > b.effectiveDate
                ? 1
                : 0,
          ),
      };
      const proposed = calculateTimeline(period.work, period.rule, record),
        current = currentCalculation(state, period);
      prepared = record;
      preview.innerHTML = `<div class="preview"><h3>Proposed effective-date plan</h3><ul>${record.changes.map((c) => `<li>From ${esc(c.effectiveDate)}: ${esc(description(c.agreement))}</li>`).join("") || "<li>Baseline rules only.</li>"}</ul><ul class="ledger"><li><span>Current expected cash wages</span><span class="money">${esc(current.currency)} ${esc(current.wages)}</span></li><li><span>Proposed expected cash wages</span><strong class="money">${esc(proposed.currency)} ${esc(proposed.wages)}</strong></li><li><span>Proposed separate per diem</span><span class="money">${esc(proposed.currency)} ${esc(proposed.allowances)}</span></li></ul><p>Only the open ledger adopts this plan. Saved comparisons/reports retain their original versioned inputs.</p><button class="primary">Save confirmed rule plan</button></div>`;
      preview.querySelector("button").onclick = () =>
        run(async () => {
          if (!prepared) throw Error("Review the current proposed plan again.");
          await onSave(prepared);
        });
    });
  });
}
