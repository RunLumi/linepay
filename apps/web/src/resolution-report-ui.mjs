import { createResolutionEvent, resolutionStatuses } from "./resolution.mjs";
import { createPaycheckReport } from "./report.mjs";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export function renderAuditTools({
  container,
  state,
  period,
  audit,
  run,
  onSave,
  message,
  uid,
  now,
}) {
  let prepared = null,
    url = null,
    ready = false,
    disposed = false;
  const events = state.resolutionEvents.filter(
    (e) => e.periodID === period.id && e.auditID === audit.id,
  );
  const savedTimeline = state.ruleTimelines.find(
    (t) =>
      t.id === audit.calculation.ruleTimelineID && t.periodID === period.id,
  );
  const sourceIDs = new Set([
    period.rule.id,
    ...(savedTimeline?.changes.map((c) => c.sourceProfileID) ?? []),
  ]);
  const origin = state.templateOrigins.find((o) => sourceIDs.has(o.profileID)),
    suffix = audit.id;
  container.innerHTML = `<h3>Worker-recorded follow-up</h3><p>Record what you reviewed, shared or heard back. These are your reports; they do not change the saved comparison or establish money owed or recovered. Nothing is sent to your employer or union.</p><form data-audit-owned id="followup-${esc(suffix)}"><label for="resolution-status-${esc(suffix)}">Follow-up status</label><select id="resolution-status-${esc(suffix)}" name="status">${Object.entries(
    resolutionStatuses,
  )
    .map(([key, title]) => `<option value="${key}">${esc(title)}</option>`)
    .join(
      "",
    )}</select><label>What happened?<textarea name="note" rows="4" maxlength="4000" required></textarea></label><p class="note">Keep notes on this check. Avoid other people’s personal information. Saved notes remain in history; a later correction is another entry.</p><button>Save follow-up</button></form><ol class="resolution-history">${events.map((e) => `<li><strong>${esc(resolutionStatuses[e.status])}</strong><p class="context">${esc(e.createdAt)}</p><p class="note">${esc(e.note)}</p></li>`).join("") || "<li>No follow-up recorded for this check.</li>"}</ol><h3>Prepare an evidence report</h3><p>The default copy contains sensitive period, amount and rule-reference information. Optional notes and detailed clocks stay out unless you choose them. Inspect the exact copy before downloading or printing.</p><form data-audit-owned id="report-options-${esc(suffix)}"><label><input type="checkbox" name="followups">Include follow-up status and notes for this check.</label><label><input type="checkbox" name="workfacts">Include detailed recorded clock/break facts.</label>${origin ? '<label><input type="checkbox" name="template">Include the worker-provided rule-draft title and reference.</label>' : ""}<button>Review evidence report</button></form><section class="report-preview" id="report-preview-${esc(suffix)}" aria-live="polite"></section>`;
  const noteForm = container.querySelector("[id^=followup-]"),
    optionsForm = container.querySelector("[id^=report-options-]"),
    preview = container.querySelector(".report-preview");
  function invalidate() {
    prepared = null;
    ready = false;
    preview.replaceChildren();
    if (url) {
      URL.revokeObjectURL(url);
      url = null;
    }
  }
  optionsForm.addEventListener("input", invalidate);
  optionsForm.addEventListener("change", invalidate);
  noteForm.addEventListener("submit", (event) => {
    event.preventDefault();
    run(async () => {
      const data = new FormData(noteForm),
        record = createResolutionEvent(state, {
          id: uid(),
          periodID: period.id,
          auditID: audit.id,
          status: data.get("status"),
          note: data.get("note"),
          createdAt: now(),
        });
      await onSave(record);
    });
  });
  optionsForm.addEventListener("submit", (event) => {
    event.preventDefault();
    run(async () => {
      invalidate();
      const data = new FormData(optionsForm),
        options = {
          includeFollowUps: data.has("followups"),
          includeWorkFacts: data.has("workfacts"),
          includeTemplateReference: data.has("template"),
        };
      prepared = createPaycheckReport(state, {
        periodID: period.id,
        auditID: audit.id,
        createdAt: now(),
        options,
      });
      url = URL.createObjectURL(
        new Blob([prepared.bytes], { type: "text/html;charset=utf-8" }),
      );
      preview.innerHTML =
        '<div class="preview"><h3>Reviewed report copy</h3><p>This unencrypted report can leave the browser when downloaded or printed. It is not anonymous. Changing a privacy choice requires another review.</p><iframe class="report-frame" title="Reviewed paycheck report" sandbox="allow-same-origin allow-modals"></iframe><div class="actions"><button data-report-download disabled>Download reviewed report (HTML)</button><button data-report-print disabled>Print / save PDF</button></div></div>';
      const frame = preview.querySelector("iframe"),
        buttons = preview.querySelectorAll("button");
      const expectedURL = url;
      const loaded = () => {
        if (
          disposed ||
          !prepared ||
          url !== expectedURL ||
          frame.contentWindow.location.href !== expectedURL
        )
          return;
        ready = true;
        buttons.forEach((button) => {
          button.disabled = false;
        });
        frame.removeEventListener("load", loaded);
      };
      frame.addEventListener("load", loaded);
      frame.src = url;
      preview.querySelector("[data-report-download]").onclick = () =>
        run(async () => {
          if (!prepared || !ready)
            throw Error("Review the current report again.");
          const copy = URL.createObjectURL(
              new Blob([prepared.bytes], { type: "text/html;charset=utf-8" }),
            ),
            link = document.createElement("a");
          link.href = copy;
          link.download = "LinePaycheck-paycheck-report.html";
          link.click();
          setTimeout(() => URL.revokeObjectURL(copy), 60000);
          message(
            "Reviewed report download requested. Choose its recipient yourself; no follow-up status was changed.",
          );
        });
      preview.querySelector("[data-report-print]").onclick = () =>
        run(async () => {
          if (!prepared || !ready)
            throw Error("Review the current report again.");
          frame.contentWindow.focus();
          frame.contentWindow.print();
        });
    });
  });
  return () => {
    disposed = true;
    invalidate();
  };
}
