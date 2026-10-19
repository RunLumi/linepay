import { calculateContributions } from "./benefits.mjs";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const field = (title, name, value = "", options = "") =>
  `<label>${title}<input name="${name}" value="${esc(value)}" ${options}></label>`;
const checkbox = (title, name) =>
  `<label><input type="checkbox" name="${name}" required>${title}</label>`;
const bases = {
  eligibleHour: "Eligible hours",
  eligibleDay: "Eligible days",
  percentOfEligibleEarnings: "Percent of explicitly eligible earnings",
  fixedPeriod: "Fixed full-period contribution",
};
const quantityLabels = {
  eligibleHour: "Eligible hours",
  eligibleDay: "Eligible days",
  percentOfEligibleEarnings: "Explicit eligible earnings",
  fixedPeriod: "Full periods (quantity one)",
};
const statuses = {
  notVerified: "Not verified",
  notComparable: "Unable to verify",
  comparedValuesMatch: "Match within compared scope",
  possibleDifference: "Possible difference",
};
const notes = {
  statementMissing:
    "No confirmed statement is available. Paid contributions are unknown.",
  statementUnconfirmed:
    "Statement values have not been confirmed and were not compared.",
  scopeMismatch:
    "Fund, dates, timezone or currency do not match. These values cannot be compared.",
  noComparableValues: "No comparable confirmed amount or units were provided.",
  unitsOnly:
    "Only eligible units were compared. The contribution amount is not verified.",
  amountOnlyDifferentBasis:
    "Amounts were compared. Statement units use a different basis and were not compared.",
  confirmedValuesOnly:
    "Only these confirmed values were compared; remittance and legal eligibility are not verified.",
};
export function contributionResultView(result) {
  const amount = (value) => `${esc(result.currency)} ${esc(value)}`;
  return `<p class="badge">${esc(statuses[result.status])}</p><ul class="ledger"><li><span>Expected employer contribution</span><strong class="money">${amount(result.amount)}</strong></li><li><span>Confirmed statement amount</span><span class="money">${result.paid === null ? "Not compared / unknown" : amount(result.paid)}</span></li>${result.difference === null ? "" : `<li><span>Expected minus confirmed</span><strong class="money">${amount(result.difference)}</strong></li>`}${result.eligibleQuantity === null ? "" : `<li><span>${esc(quantityLabels[result.quantityBasis])}</span><span>${result.quantityBasis === "percentOfEligibleEarnings" ? amount(result.eligibleQuantity) : esc(result.eligibleQuantity)}</span></li>`}${result.quantityDifference === null ? "" : `<li><span>${result.quantityBasis === "percentOfEligibleEarnings" ? "Eligible minus reported earnings" : "Eligible minus reported units"}</span><span>${result.quantityBasis === "percentOfEligibleEarnings" ? amount(result.quantityDifference) : esc(result.quantityDifference)}</span></li>`}</ul><p class="rule-note">${esc(notes[result.limitation])}</p><p class="note">Separate from cash wages, per diem and employee deductions. This is not a benefits entitlement, debt or recovery finding.</p>`;
}
function segmentEditor(index, segment) {
  const r = segment?.rule,
    period = segment?.period;
  return `<fieldset data-segment="${index}"><legend>Eligibility segment ${index + 1}</legend><div class="fields">${field("Eligibility start", "segment-start", period?.start, 'type="date" required')}${field("Eligibility end (exclusive)", "segment-end", period?.endExclusive, 'type="date" required')}<div><label for="segment-basis-${index}">Contribution basis</label><select id="segment-basis-${index}" name="segment-basis">${Object.entries(
    bases,
  )
    .map(
      ([value, title]) =>
        `<option value="${value}" ${r?.basis === value ? "selected" : ""}>${title}</option>`,
    )
    .join(
      "",
    )}</select></div>${field("Confirmed rate or percentage", "segment-rate", r?.rate, 'inputmode="decimal" required')}${field("Explicit eligible quantity", "segment-quantity", segment?.quantity, 'inputmode="decimal" required')}${field("Rule snapshot version", "segment-version", r?.version ?? "1", 'required maxlength="128"')}</div><p class="note">For a percentage, enter the percentage (5 means 5%) and eligible earnings as quantity. For fixed period, quantity must be 1. Do not map overtime or wages into eligibility automatically.</p><button type="button" data-full-period>Use full fund period for this segment</button>${checkbox("I confirmed this rate is effective throughout this eligibility segment.", "segment-effective")}<button type="button" data-remove-segment>Remove this segment</button></fieldset>`;
}
function editor(check) {
  const last = check?.revisions.at(-1),
    statement = last?.statement,
    mode = statement
      ? statement.confirmed
        ? "confirmed"
        : "unconfirmed"
      : "missing";
  return `<h2>${check ? "Review a new revision" : "New fund check"}</h2><p>Contribution periods and eligible quantities are independent of the wage ledger. Enter confirmed fund facts; nothing is inferred from your logged hours.</p><form id="fund-form">${check ? `<p class="context">${esc(check.name)} · ${esc(check.currency)} · ${esc(check.period.start)} → ${esc(check.period.endExclusive)} (exclusive) · ${esc(check.period.timeZone)}</p>` : `<div class="fields">${field("Fund name", "fund-name", "", 'required maxlength="120"')}<div><label for="fund-currency">Fund currency</label><select id="fund-currency" name="fund-currency"><option>USD</option><option>CAD</option></select></div>${field("Contribution start", "fund-start", "", 'type="date" required')}${field("Contribution end (exclusive)", "fund-end", "", 'type="date" required')}${field("Contribution timezone", "fund-zone", Intl.DateTimeFormat().resolvedOptions().timeZone, "required")}</div>`}<section id="fund-segments">${(last?.segments ?? [null]).map((s, i) => segmentEditor(i, s)).join("")}</section><button type="button" id="add-fund-segment">Add eligibility segment</button>${checkbox("These segments cover all eligible work or earnings for this fund period.", "fund-complete")}${field("Clause, page and source-version note (optional)", "source-reference", last?.sourceReference ?? "", 'maxlength="2000"')}<p class="note">This note is your reference, not professional or union verification. Original source files are not attached by this editor.</p><h2>Statement observations</h2><div><label for="fund-statement-mode">Statement review state</label><select id="fund-statement-mode" name="statement-mode"><option value="missing" ${mode === "missing" ? "selected" : ""}>No statement yet</option><option value="unconfirmed" ${mode === "unconfirmed" ? "selected" : ""}>Unconfirmed source values</option><option value="confirmed" ${mode === "confirmed" ? "selected" : ""}>Confirmed source values</option></select></div><details ${statement ? "open" : ""}><summary>Statement dates, currency, amount and units</summary><div class="fields">${field("Statement start", "statement-start", statement?.period.start, 'type="date"')}${field("Statement end (exclusive)", "statement-end", statement?.period.endExclusive, 'type="date"')}${field("Statement timezone", "statement-zone", statement?.period.timeZone ?? "")}<div><label for="statement-currency">Statement currency</label><select id="statement-currency" name="statement-currency"><option ${statement?.currency === "USD" ? "selected" : ""}>USD</option><option ${statement?.currency === "CAD" ? "selected" : ""}>CAD</option></select></div>${field("Statement employer contribution (optional)", "statement-amount", statement?.employerContribution, 'inputmode="decimal"')}${field("Statement eligible quantity (optional)", "statement-quantity", statement?.quantity, 'inputmode="decimal"')}<div><label for="statement-basis">Statement quantity basis</label><select id="statement-basis" name="statement-basis"><option value="">Not stated / unknown</option>${Object.entries(
    bases,
  )
    .map(
      ([value, title]) =>
        `<option value="${value}" ${statement?.quantityBasis === value ? "selected" : ""}>${title}</option>`,
    )
    .join(
      "",
    )}</select></div></div><label><input type="checkbox" name="statement-confirmed">I checked the fund identity, dates, currency and each entered value against the source.</label></details><button class="primary">Review fund check</button></form><section id="fund-preview" aria-live="polite"></section>`;
}
export function renderBenefitUI({
  container,
  state,
  selection,
  editing,
  onNew,
  onSelect,
  onEdit,
  onSave,
  run,
  uid,
  now,
}) {
  const selected = state.benefitChecks.find((c) => c.id === selection);
  let pending = null;
  container.innerHTML = `<h1>Employer contributions</h1><p>Check one explicitly confirmed fund and period. Contributions are kept separate from your paycheck’s cash wages.</p><ul class="ledger">${
    state.benefitChecks
      .toReversed()
      .map(
        (c) =>
          `<li><span>${esc(c.name)}<small>${esc(c.period.start)} → ${esc(c.period.endExclusive)} (exclusive) · ${esc(statuses[c.revisions.at(-1).result.status])}</small></span><button data-fund-check="${esc(c.id)}">Open fund check</button></li>`,
      )
      .join("") || "<li>No fund checks saved.</li>"
  }</ul><button id="new-fund-check">New fund check</button>${selected ? `<h2>${esc(selected.name)} · saved revisions</h2><p class="context">${esc(selected.period.start)} → ${esc(selected.period.endExclusive)} (exclusive) · ${esc(selected.period.timeZone)}</p>${selected.revisions.map((r, i) => `<details data-fund-revision="${i + 1}" ${i === selected.revisions.length - 1 ? "open" : ""}><summary>Revision ${i + 1} · ${esc(statuses[r.result.status])} · ${esc(r.createdAt)}</summary>${contributionResultView(r.result)}<details><summary>Recorded eligibility, rules and reference</summary><ul class="ledger">${r.segments.map((s) => `<li><span>${esc(s.period.start)} → ${esc(s.period.endExclusive)}<small>${esc(s.quantity)} · ${esc(bases[s.rule.basis])} · rate ${esc(s.rule.rate)} · rule ${esc(s.rule.id)}/${esc(s.rule.version)}</small></span></li>`).join("")}</ul><p>${r.sourceReference ? esc(r.sourceReference) : "No source-reference note was recorded."}</p><p>Engine ${esc(r.result.engine)}. Each revision retains its original confirmed inputs.</p>${r.statement ? `<p>Recorded source state: ${r.statement.confirmed ? "confirmed" : "unconfirmed"} · ${esc(r.statement.period.start)} → ${esc(r.statement.period.endExclusive)} · ${esc(r.statement.period.timeZone)} · ${esc(r.statement.currency)} · contribution ${r.statement.employerContribution === null ? "unknown" : esc(r.statement.employerContribution)} · units ${r.statement.quantity === null ? "unknown" : esc(r.statement.quantity)}</p>` : ""}</details></details>`).join("")}<button id="revise-fund-check">Add revised check</button>` : ""}${editing ? editor(selected) : ""}`;
  container.querySelector("#new-fund-check").onclick = onNew;
  container
    .querySelectorAll("[data-fund-check]")
    .forEach(
      (button) => (button.onclick = () => onSelect(button.dataset.fundCheck)),
    );
  if (selected) container.querySelector("#revise-fund-check").onclick = onEdit;
  if (!editing) return;
  const form = container.querySelector("#fund-form"),
    preview = container.querySelector("#fund-preview"),
    segments = container.querySelector("#fund-segments");
  const invalidate = (event) => {
    pending = null;
    preview.replaceChildren();
    const target = event?.target;
    if (!target || target.type === "checkbox") return;
    const field = target.closest("[data-segment]");
    if (field) {
      field.querySelector("[name=segment-effective]").checked = false;
      form.elements["fund-complete"].checked = false;
    } else if (target.name?.startsWith("fund-")) {
      segments.querySelectorAll("[name=segment-effective]").forEach((input) => {
        input.checked = false;
      });
      form.elements["fund-complete"].checked = false;
      form.elements["statement-confirmed"].checked = false;
    }
    if (target.name?.startsWith("statement-"))
      form.elements["statement-confirmed"].checked = false;
  };
  const bindSegment = (field) => {
    field.querySelector("[data-remove-segment]").onclick = () => {
      field.remove();
      form.elements["fund-complete"].checked = false;
      invalidate();
    };
    field.querySelector("[data-full-period]").onclick = () => {
      const data = new FormData(form),
        period = selected?.period ?? {
          start: data.get("fund-start"),
          endExclusive: data.get("fund-end"),
        };
      field.querySelector("[name=segment-start]").value = period.start;
      field.querySelector("[name=segment-end]").value = period.endExclusive;
      field.querySelector("[name=segment-effective]").checked = false;
      form.elements["fund-complete"].checked = false;
      invalidate();
    };
  };
  segments.querySelectorAll("[data-segment]").forEach(bindSegment);
  let nextIndex = segments.children.length;
  container.querySelector("#add-fund-segment").onclick = () =>
    run(async () => {
      if (segments.children.length >= 100)
        throw Error("This editor supports up to 100 eligibility segments.");
      segments.insertAdjacentHTML(
        "beforeend",
        segmentEditor(nextIndex++, null),
      );
      bindSegment(segments.lastElementChild);
      form.elements["fund-complete"].checked = false;
      invalidate();
    });
  form.addEventListener("input", invalidate);
  form.addEventListener("change", invalidate);
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    run(async () => {
      const data = new FormData(form),
        get = (name) => data.get(name),
        nullable = (name) => (get(name) === "" ? null : get(name)),
        period = selected?.period ?? {
          start: get("fund-start"),
          endExclusive: get("fund-end"),
          timeZone: get("fund-zone"),
        };
      const check = selected
        ? {
            id: selected.id,
            fundID: selected.fundID,
            name: selected.name,
            currency: selected.currency,
            period: structuredClone(selected.period),
          }
        : {
            id: uid(),
            fundID: uid(),
            name: get("fund-name"),
            currency: get("fund-currency"),
            period,
          };
      const eligible = [...segments.querySelectorAll("[data-segment]")].map(
        (field) => {
          const value = (name) => field.querySelector(`[name=${name}]`).value,
            scope = {
              start: value("segment-start"),
              endExclusive: value("segment-end"),
              timeZone: period.timeZone,
            };
          if (!field.querySelector("[name=segment-effective]").checked)
            throw Error(
              "Confirm the rate is effective throughout every segment.",
            );
          return {
            id: uid(),
            period: scope,
            rule: {
              id: uid(),
              fundID: check.fundID,
              version: value("segment-version"),
              basis: value("segment-basis"),
              rate: value("segment-rate"),
              currency: check.currency,
              effectivePeriod: structuredClone(scope),
            },
            quantity: value("segment-quantity"),
            eligibilityConfirmed: true,
          };
        },
      );
      const mode = get("statement-mode");
      if (
        mode === "missing" &&
        [
          "statement-amount",
          "statement-quantity",
          "statement-start",
          "statement-end",
          "statement-zone",
        ].some((name) => get(name) !== "")
      )
        throw Error(
          "Select a statement review state to retain the source values, or clear them for a missing statement.",
        );
      if (mode === "confirmed" && !data.has("statement-confirmed"))
        throw Error(
          "Confirm the statement’s fund, scope and entered values against its source.",
        );
      const statement =
        mode === "missing"
          ? null
          : {
              fundID: check.fundID,
              currency: get("statement-currency"),
              period: {
                start: get("statement-start"),
                endExclusive: get("statement-end"),
                timeZone: get("statement-zone"),
              },
              employerContribution: nullable("statement-amount"),
              quantity: nullable("statement-quantity"),
              quantityBasis: nullable("statement-basis"),
              confirmed: mode === "confirmed",
            };
      const revision = {
        id: uid(),
        createdAt: now(),
        sourceReference: get("source-reference"),
        segments: eligible,
        completeEligibilityConfirmed: data.has("fund-complete"),
        rounding: { scale: 2, mode: "halfUp", scope: "payCategory" },
        statement,
        result: null,
      };
      revision.result = calculateContributions({
        period,
        segments: eligible,
        completeEligibilityConfirmed: revision.completeEligibilityConfirmed,
        rounding: revision.rounding,
        statement,
      });
      // Validate metadata at preview too; the commit validates the complete retained state again.
      if (
        typeof check.name !== "string" ||
        !check.name.trim() ||
        check.name.length > 120
      )
        throw Error("Enter a fund name up to 120 characters.");
      pending = { check, revision };
      preview.innerHTML = `<div class="preview"><h2>Review before saving fund check</h2>${contributionResultView(revision.result)}<p>Saving appends a new immutable revision. Earlier checks remain unchanged.</p><button class="primary" id="confirm-fund-check">Save this fund check</button></div>`;
      preview.querySelector("button").onclick = () =>
        run(async () => {
          if (!pending) throw Error("Review the current fund facts again.");
          await onSave(pending.check, pending.revision);
        });
    });
  });
}
