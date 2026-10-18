import {
  calculateWeekly,
  weeklySource,
  workFromWeeklySource,
} from "./weekly.mjs";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const field = (title, name, attributes = "") =>
  `<label>${title}<input name="${name}" ${attributes}></label>`;
const confirm = (title, name) =>
  `<label><input type="checkbox" name="${name}">${title}</label>`;
function resultView(result) {
  return `<p class="context">${esc(result.startUTC)} → ${esc(result.endExclusiveUTC)} (excluded) · ${esc(result.timeZone)} · 168 elapsed hours</p><ul class="ledger"><li><span>Recorded qualifying seconds</span><strong>${esc(result.qualifyingSeconds)}</strong></li><li><span>Worked hours (display rounded to 8 places)</span><span>${esc(result.qualifyingHoursDisplay)}</span></li><li><span>Weekly overtime seconds</span><span>${esc(result.overtimeSeconds)}</span></li><li><span>Reviewed includable remuneration</span><span>${esc(result.currency)} ${esc(result.includableRemuneration)}</span></li><li><span>Regular rate (rounded display)</span><span>${result.regularRate === null ? "Unavailable" : esc(result.currency) + " " + esc(result.regularRate) + "/hour"}</span></li><li><span>Additional premium before credits</span><span>${esc(result.currency)} ${esc(result.statutoryAdditionalPremium)}</span></li><li><span>Eligible extra-premium credit</span><span>${esc(result.currency)} ${esc(result.eligibleExtraPremiumCredit)}</span></li><li><span>Remaining additional premium</span><strong>${esc(result.currency)} ${esc(result.remainingAdditionalPremium)}</strong></li><li><span>Cash in reviewed scope</span><strong>${esc(result.currency)} ${esc(result.expectedCash)}</strong></li></ul><p class="note">This reference uses your declared facts/classifications. It is not added to Pay, does not map a paycheck, and does not establish legal entitlement or a debt. Zero is an explicit computed value, not proof all obligations were checked.</p>`;
}
function paymentRow(id) {
  return `<fieldset data-weekly-payment="${esc(id)}"><legend>Other cash payment</legend>${field("Amount", "payment-amount", 'inputmode="decimal" required')}<label>Payment treatment<select name="payment-kind"><option value="">Not classified</option><option value="straightTime">Additional wages</option><option value="includableBonus">Includable bonus</option><option value="excludedCash">Excluded cash</option><option value="extraPremium">Work premium</option></select></label><label>Extra-premium treatment<select name="payment-credit"><option value="">Not reviewed</option><option value="unknown">Needs review</option><option value="eligibleExtraPremium">Eligible credit</option><option value="ineligible">Includable</option></select></label><p class="note">Only an extra premium uses the second classification. Enter its premium portion above base, not the full-rate overtime line. An exclusion or credit needs an applicable source; the app does not decide it.</p><button type="button" data-remove-weekly-payment>Remove payment</button></fieldset>`;
}
export function renderWeeklyUI({ container, state, run, uid, now, onSave }) {
  let pending = null;
  container.innerHTML = `<h1>Complete workweek review</h1><p>Review one declared ordinary covered, nonexempt hourly workweek. This is separate from the configured daily ledger and paycheck comparison. No state/CBA, alternative-method or nationwide coverage is implied.</p><h2>Retained weekly reviews</h2>${
    state.weeklyReviews
      .toReversed()
      .map(
        (r, i) =>
          `<details data-weekly-record="${esc(r.id)}" ${i === 0 ? "open" : ""}><summary>${esc(r.input.startUTC)} · ${esc(r.createdAt)}</summary><div class="weekly-saved-result">${resultView(r.result)}</div><details><summary>Retained source facts</summary><p>${r.input.work.length} exact work slices from ${r.source.periods.length} saved periods. Rules, clock entries, breaks and remuneration are frozen with this review; later ledger edits do not reprice it.</p><p>${r.reference ? esc(r.reference) : "No reference note was entered."}</p><ul>${r.input.remuneration.map((p) => `<li>${esc(p.kind)} · ${esc(p.amount.currency)} ${esc(p.amount.amount)} · ${esc(p.premiumCredit)}</li>`).join("")}</ul></details></details>`,
      )
      .join("") || "<p>No weekly reviews saved.</p>"
  }<h2>New weekly review</h2><form data-weekly-owned id="weekly-form"><div class="fields">${field("Exact workweek start (ISO timestamp with seconds and UTC offset)", "weekly-start", 'required placeholder="2026-09-07T00:00:00Z"')}${field("Payroll timezone", "weekly-zone", `required value="${esc(Intl.DateTimeFormat().resolvedOptions().timeZone)}"`)}<label>Currency<select name="weekly-currency"><option>USD</option><option>CAD</option></select></label><label>Applicability<select name="weekly-applicability"><option value="unknown">Not confirmed</option><option value="coveredNonexemptHourly">Confirmed hourly</option></select></label></div><fieldset><legend>Source periods for this employer</legend>${state.periods.map((p) => `<label><input type="checkbox" name="weekly-period" value="${esc(p.id)}">${esc(p.start)} through ${esc(p.end)} · ${esc(p.zone)} · ${esc(p.rule.currency)} ${esc(p.rule.hourlyRate)}/hour</label>`).join("") || "<p>No source periods recorded.</p>"}</fieldset><p class="note">Select every relevant period for the one employer being reviewed. Other employers must be reviewed separately. No employer identity is inferred from a profile.</p><p class="note">A configured weekday or paycheck period is not a verified recurring anchor. Confirm the employer's exact start instant. The exclusive end is 168 elapsed hours later, including through DST. Relevant work from the selected periods is inspected; unknown/mixed scope requires review.</p>${field("Reviewed straight-time wages for the whole week", "weekly-base", 'required inputmode="decimal"')}<p class="note">Clock records do not confirm the remuneration numerator. Enter reviewed straight-time wages for all hours. Add every other cash payment separately; do not duplicate base wages or enter net pay, YTD or employer fund contributions.</p><section id="weekly-payments"></section><button type="button" id="weekly-add-payment">Add other payment</button><div class="fields"><label>Money decimal places<select name="weekly-scale"><option>2</option><option>0</option><option>3</option><option>4</option></select></label><label>Rounding<select name="weekly-mode"><option value="halfUp">Half up</option><option value="bankers">Ties to even</option><option value="down">Down</option><option value="up">Up</option></select></label></div><p class="note" id="weekly-rounding-explanation">Round to nearest; exact ties round away from zero.</p><label>Private source/reference note (optional)<textarea name="weekly-reference" maxlength="2000"></textarea></label>${confirm("I confirmed the employer's exact recurring 168-hour boundary", "weekly-boundary")}${confirm("I confirmed selected periods are for one employer and this declared workweek", "weekly-employer")}${confirm("Every shift and unpaid break for this workweek is recorded", "weekly-complete")}${confirm("I reviewed every amount, inclusion/exclusion and credit classification", "weekly-payments-confirmed")}<p class="note">Preview writes nothing. Saving appends a new frozen record, included in protected manual backups. It never changes an earlier review or auto-clears a paycheck warning. Leaving this unsaved form can discard its input.</p><button>Review complete workweek</button><section id="weekly-preview" aria-live="polite"></section></form>`;
  const form = container.querySelector("#weekly-form"),
    preview = container.querySelector("#weekly-preview"),
    payments = container.querySelector("#weekly-payments");
  function invalidate(event) {
    pending = null;
    preview.replaceChildren();
    if (
      event &&
      event.target.type === "checkbox" &&
      event.target.name !== "weekly-period"
    )
      return;
    for (const name of [
      "weekly-boundary",
      "weekly-employer",
      "weekly-complete",
      "weekly-payments-confirmed",
    ])
      form.elements[name].checked = false;
  }
  const roundingDescriptions = {
    halfUp: "Round to nearest; exact ties round away from zero.",
    bankers: "Round to nearest; exact ties round to even.",
    down: "Round toward negative infinity.",
    up: "Round toward positive infinity.",
  };
  form.elements["weekly-mode"].addEventListener("change", () => {
    container.querySelector("#weekly-rounding-explanation").textContent =
      roundingDescriptions[form.elements["weekly-mode"].value];
  });
  form.addEventListener("input", invalidate);
  form.addEventListener("change", invalidate);
  container.querySelector("#weekly-add-payment").onclick = () => {
    payments.insertAdjacentHTML("beforeend", paymentRow(uid()));
    invalidate();
    const row = payments.lastElementChild;
    row.querySelector("[data-remove-weekly-payment]").onclick = () => {
      row.remove();
      invalidate();
    };
    row.querySelector('[name="payment-kind"]').onchange = () => {
      row.querySelector('[name="payment-credit"]').value = "";
    };
  };
  form.onsubmit = (event) => {
    event.preventDefault();
    run(async () => {
      const data = new FormData(form),
        currency = data.get("weekly-currency"),
        source = weeklySource(
          state,
          data.get("weekly-start"),
          data.get("weekly-zone"),
          currency,
          data.getAll("weekly-period"),
        ),
        remuneration = [
          {
            id: uid(),
            amount: { amount: data.get("weekly-base"), currency },
            kind: "straightTime",
            premiumCredit: "notApplicable",
          },
          ...[...payments.querySelectorAll("[data-weekly-payment]")].map(
            (row) => {
              const kind = row.querySelector('[name="payment-kind"]').value;
              return {
                id: row.dataset.weeklyPayment,
                amount: {
                  amount: row.querySelector('[name="payment-amount"]').value,
                  currency,
                },
                kind,
                premiumCredit:
                  kind === "extraPremium"
                    ? row.querySelector('[name="payment-credit"]').value
                    : "notApplicable",
              };
            },
          ),
        ],
        input = {
          startUTC: source.startUTC,
          timeZone: source.timeZone,
          currency,
          boundaryConfirmed: data.has("weekly-boundary"),
          singleEmployerConfirmed: data.has("weekly-employer"),
          paymentsConfirmed: data.has("weekly-payments-confirmed"),
          completeWorkweek: data.has("weekly-complete"),
          applicability: data.get("weekly-applicability"),
          work: workFromWeeklySource(source),
          remuneration,
          rounding: {
            scale: Number(data.get("weekly-scale")),
            mode: data.get("weekly-mode"),
            scope: "payCategory",
          },
        };
      if (!data.has("weekly-payments-confirmed"))
        throw Error(
          "Confirm every payment and classification before reviewing.",
        );
      pending = {
        id: uid(),
        createdAt: now(),
        reference: data.get("weekly-reference"),
        source,
        input,
        result: calculateWeekly(input),
      };
      preview.innerHTML = `<div class="preview"><h3>Review before saving this workweek</h3>${resultView(pending.result)}<button type="button" id="weekly-save">Save reviewed workweek</button></div>`;
      preview.querySelector("button").onclick = () =>
        run(async () => {
          if (!pending) throw Error("Review current weekly facts again.");
          await onSave(pending);
        });
    });
  };
}
