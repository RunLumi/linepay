import { paycycleWindow } from "./paycycle.mjs";
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export function bindPeriodSetup({ form, state, run, uid, onSave }) {
  let pending = null;
  const end = form.elements.end,
    cadence = form.elements.cadence,
    preview = form.querySelector(".period-preview");
  function invalidate() {
    pending = null;
    preview.replaceChildren();
    end.readOnly = cadence.value !== "manual";
    if (end.readOnly && form.elements.start.value && form.elements.zone.value) {
      try {
        end.value = paycycleWindow({
          cadence: cadence.value,
          startDate: form.elements.start.value,
          manualEndDate: end.value,
          timeZone: form.elements.zone.value,
        }).endDate;
      } catch {
        end.value = "";
      }
    }
  }
  form.addEventListener("input", invalidate);
  form.addEventListener("change", invalidate);
  invalidate();
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    run(async () => {
      if (state.periods.some((p) => !p.closed))
        throw Error("Close the current period before starting another.");
      const data = new FormData(form),
        window = paycycleWindow({
          cadence: data.get("cadence"),
          startDate: data.get("start"),
          manualEndDate: data.get("end"),
          timeZone: data.get("zone"),
        }),
        profile = state.profiles.at(-1);
      if (!profile) throw Error("Confirm a pay profile first.");
      const period = {
        id: uid(),
        start: window.startDate,
        end: window.endDate,
        zone: window.timeZone,
        rule: structuredClone(profile),
        work: [],
        audits: [],
        closed: false,
        closedCalculation: null,
      };
      pending = { period, schedule: { periodID: period.id, window } };
      preview.innerHTML = `<div class="preview"><h3>Review pay period</h3><p>${esc(window.startDate)} through ${esc(window.endDate)} (included) · ${esc(window.timeZone)}</p><p>First instant ${esc(window.startUTC)}; exclusive end ${esc(window.endExclusiveUTC)}. Calendar cycles can have different elapsed hours across clock changes.</p><p>Confirmed profile: ${esc(profile.currency)} ${esc(profile.hourlyRate)}/hour. This paycycle does not configure a statutory workweek or waive overtime obligations.</p><button type="button" class="primary">Start period</button></div>`;
      preview.querySelector("button").onclick = () =>
        run(async () => {
          if (!pending) throw Error("Review the current period again.");
          await onSave(pending.period, pending.schedule);
        });
    });
  });
}
