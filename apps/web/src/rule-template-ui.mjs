import {
  createRuleTemplate,
  decodeRuleTemplate,
  encodeRuleTemplate,
  adoptRuleTemplate,
} from "./rule-template.mjs";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const field = (title, name, value = "", attributes = "") =>
  `<label>${title}<input name="${name}" value="${esc(value)}" ${attributes}></label>`;
const roundingNames = {
  halfUp: "Half up",
  bankers: "Nearest, ties to even",
  down: "Down",
  up: "Up",
};
function summary(packet) {
  const r = packet.rules;
  return `<p class="rule-note">Worker-provided rule draft. Not a verified agreement or legal coverage check. Confirm classification, jurisdiction, effective dates and unconfigured obligations separately.</p><h3>${esc(packet.title)}</h3><ul class="ledger"><li><span>Currency</span><span>${esc(r.currency)}</span></li><li><span>Hourly amount in file</span><span>${r.hourlyRate === null ? "Omitted — enter your own" : esc(r.hourlyRate)}</span></li>${r.dailyOvertimeTiers.map((t) => `<li><span>Daily premium after ${esc(t.afterHours)} hours</span><span>${esc(t.multiplier)}×</span></li>`).join("")}${r.weekdayPremiums.map((p) => `<li><span>${esc(p.weekday)} premium</span><span>${esc(p.multiplier)}×</span></li>`).join("")}<li><span>Isolated callout minimum</span><span>${r.calloutMinimumHours === null ? "Not configured" : esc(r.calloutMinimumHours) + " hours"}</span></li><li><span>Flat per diem per worked local date</span><span>${r.perDiem.configured ? (r.perDiem.amount === null ? "Configured; amount omitted" : esc(r.perDiem.amount)) : "Not configured; not a waiver"}</span></li><li><span>Premium combination</span><span>Highest applicable multiplier; premiums do not multiply together</span></li><li><span>Rounding</span><span>${esc(roundingNames[r.rounding.mode])}, ${r.rounding.scale} decimal places, grouped by pay category</span></li></ul><p class="context">Draft ${esc(packet.templateID)} · revision ${esc(packet.revision)}</p>`;
}
export function renderRuleTemplateUI({
  container,
  state,
  run,
  onAdopt,
  message,
  uid,
}) {
  let outgoing = null,
    packet = null;
  container.innerHTML = `<h2>Share selected pay rules</h2><p>A rule draft contains selected rule parameters, not work records, paychecks, fund checks or evidence. It is not anonymous: review the title and conditions. Wage and allowance amounts are omitted unless you explicitly include them.</p>${state.profiles.length ? `<form id="template-export-form" data-rule-template><label for="template-source">Profile to export</label><select id="template-source" name="source">${state.profiles.map((p, i) => `<option value="${esc(p.id)}" ${i === state.profiles.length - 1 ? "selected" : ""}>Profile ${i + 1} · ${esc(p.currency)} ${esc(p.hourlyRate)}/hour</option>`).join("")}</select>${field("Rule draft title", "title", "Configured pay-rule draft", 'required maxlength="240"')}<label><input type="checkbox" name="include-amounts">Include hourly wage and per-diem amounts in this file.</label><label><input type="checkbox" name="sharing-confirmed" required>I have the right to share these rule parameters.</label><button>Review rule file</button></form><section id="template-export-preview" aria-live="polite"></section>` : "<p>Save a profile before exporting rules.</p>"}<h2>Import a rule draft</h2><p>Inspect the file first. Confirm your own amounts and applicability before creating a new profile. A new profile applies when starting a new period.</p><form id="template-inspect-form" data-rule-template>${field("Selected rule draft", "file", "", 'type="file" accept=".linepayrules,application/json" required')}<button>Inspect rule draft</button></form><section id="template-import-preview" aria-live="polite"></section>`;
  const exportForm = container.querySelector("#template-export-form"),
    exportPreview = container.querySelector("#template-export-preview"),
    inspectForm = container.querySelector("#template-inspect-form"),
    importPreview = container.querySelector("#template-import-preview");
  if (exportForm) {
    const invalidate = (event) => {
      outgoing = null;
      exportPreview.replaceChildren();
      if (event.target.name !== "sharing-confirmed")
        exportForm.elements["sharing-confirmed"].checked = false;
    };
    exportForm.addEventListener("input", invalidate);
    exportForm.addEventListener("change", invalidate);
    exportForm.addEventListener("submit", (event) => {
      event.preventDefault();
      run(async () => {
        const data = new FormData(exportForm);
        if (!data.has("sharing-confirmed"))
          throw Error("Confirm you may share these parameters.");
        const source = state.profiles.find((p) => p.id === data.get("source"));
        if (!source) throw Error("Select a saved profile.");
        const draft = createRuleTemplate(source, {
          templateID: uid(),
          revision: "1",
          title: data.get("title"),
          includeAmounts: data.has("include-amounts"),
        });
        const bytes = encodeRuleTemplate(draft);
        outgoing = { draft, bytes };
        exportPreview.innerHTML = `<div class="preview"><h3>Exact file preview</h3>${summary(draft)}<details><summary>Full JSON that will be downloaded</summary><pre>${esc(new TextDecoder().decode(bytes))}</pre></details><p>This is an unencrypted rule file. It has no publisher authentication or source-approval claim.</p><button id="download-rule-draft" class="primary">Download reviewed rule draft</button></div>`;
        exportPreview.querySelector("button").onclick = () =>
          run(async () => {
            if (!outgoing) throw Error("Review the current export again.");
            const url = URL.createObjectURL(
                new Blob([outgoing.bytes], { type: "application/json" }),
              ),
              link = document.createElement("a");
            link.href = url;
            link.download = "LinePaycheck-rules.linepayrules";
            link.click();
            setTimeout(() => URL.revokeObjectURL(url), 60000);
            message(
              "Reviewed rule-file download requested. Choose its recipient yourself.",
            );
          });
      });
    });
  }
  inspectForm.addEventListener("input", () => {
    packet = null;
    importPreview.replaceChildren();
  });
  inspectForm.addEventListener("submit", (event) => {
    event.preventDefault();
    run(async () => {
      packet = null;
      importPreview.replaceChildren();
      const file = new FormData(inspectForm).get("file");
      if (!file || file.size > 65536)
        throw Error("Select a rule draft up to 64 KiB.");
      for (const input of inspectForm.elements) input.disabled = true;
      try {
        packet = decodeRuleTemplate(new Uint8Array(await file.arrayBuffer()));
      } finally {
        for (const input of inspectForm.elements) input.disabled = false;
      }
      const r = packet.rules;
      importPreview.innerHTML = `<div class="preview"><h3>Inspected; no profile created</h3>${summary(packet)}<form id="template-adopt-form" data-rule-template>${field("Your confirmed hourly rate", "hourly-rate", r.hourlyRate ?? "", 'inputmode="decimal" required')}${r.perDiem.configured ? `<label for="recipient-allowance">Does this per-diem rule apply to your new profile?</label><select id="recipient-allowance" name="allowance-choice"><option value="unreviewed">Needs review</option><option value="confirmedAmount">Applies — confirm my amount</option><option value="notApplicable">Not applicable to my new profile</option></select>${field("Your confirmed per-diem amount", "allowance-amount", r.perDiem.amount ?? "", 'inputmode="decimal"')}<p class="note">The amount field is used only when you choose that the rule applies.</p>` : "<p>Per diem is not configured by this file. This does not waive an unassessed allowance obligation.</p>"}<label><input type="checkbox" name="applicability-confirmed" required>I checked every listed rule and its applicability to my work, dates and classification.</label><label><input type="checkbox" name="values-confirmed" required>I confirmed the rate, currency, allowance choice and rounding policy.</label><button class="primary">Save confirmed new profile</button></form></div>`;
      const adoptForm = importPreview.querySelector("form");
      const invalidate = (event) => {
        if (event.target.type !== "checkbox") {
          adoptForm.elements["applicability-confirmed"].checked = false;
          adoptForm.elements["values-confirmed"].checked = false;
        }
      };
      adoptForm.addEventListener("input", invalidate);
      adoptForm.addEventListener("change", invalidate);
      adoptForm.addEventListener("submit", (event) => {
        event.preventDefault();
        run(async () => {
          if (!packet) throw Error("Inspect the rule draft again.");
          const data = new FormData(adoptForm),
            choice = packet.rules.perDiem.configured
              ? data.get("allowance-choice")
              : "notConfigured";
          const choices = {
            profileID: uid(),
            hourlyRate: data.get("hourly-rate"),
            perDiemDecision: choice,
            perDiemAmount:
              choice === "confirmedAmount"
                ? data.get("allowance-amount")
                : null,
            applicabilityConfirmed: data.has("applicability-confirmed"),
            valuesConfirmed: data.has("values-confirmed"),
          };
          const profile = adoptRuleTemplate(packet, choices);
          await onAdopt(profile, {
            profileID: profile.id,
            packet: structuredClone(packet),
            perDiemDecision: choice,
            recipientHourlyRate: choices.hourlyRate,
            recipientPerDiemAmount: choices.perDiemAmount,
            applicabilityConfirmed: choices.applicabilityConfirmed,
            valuesConfirmed: choices.valuesConfirmed,
          });
        });
      });
    });
  });
}
