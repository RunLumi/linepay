import { localCandidates, localDate } from "./payroll.mjs";
import { assessForPeriod } from "./assessment-period.mjs";
import { bindPeriodSetup } from "./period-setup-ui.mjs";
import {
  currentCalculation,
  currentTimeline,
  auditUsesEarlierContext,
} from "./calculation-context.mjs";
import { renderRuleTimelineUI } from "./rule-timeline-ui.mjs";
import { renderAuditTools } from "./resolution-report-ui.mjs";
import { renderBenefitUI } from "./benefits-ui.mjs";
import { renderRuleTemplateUI } from "./rule-template-ui.mjs";
import {
  openStore,
  emptyState,
  validateState,
  snapshot,
  inspectSnapshot,
} from "./state.mjs";
import { encryptBackup, decryptBackup } from "./backup.mjs";
let openAuditID = null,
  disposeReports = () => {};
let fundSelection = null,
  fundEditing = false;
let state,
  store,
  tab = "pay",
  selection = null,
  busy = false,
  pendingAudit = null,
  pendingPaycheckScope = null,
  pendingRestore = null;
const main = document.querySelector("main"),
  status = document.querySelector("#status");
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const uid = () => crypto.randomUUID(),
  utc = (seconds) =>
    new Date(seconds * 1000).toISOString().replace(".000Z", "Z");
const now = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const workClock = (value, zone) =>
  new Intl.DateTimeFormat("en", {
    timeZone: zone,
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
const money = (amount, currency) => `${esc(currency)} ${esc(amount)}`;
const current = () =>
  state.periods.find((p) => p.id === selection) ||
  state.periods.find((p) => !p.closed) ||
  state.periods.at(-1);
const message = (text, error = false) => {
  status.textContent = text;
  status.className = error ? "error" : "";
  status.setAttribute("role", error ? "alert" : "status");
  if (error) {
    status.tabIndex = -1;
    status.focus();
  }
};
const label = (title, name, options = "") =>
  `<label>${title}<input name="${name}" ${options}></label>`;
const check = (title, name, required = false) =>
  `<label><input type="checkbox" name="${name}" ${required ? "required" : ""}>${title}</label>`;
const verdicts = {
  matches: "Compared values match",
  possibleShortfall: "Possible shortfall",
  possibleOverpayment: "Possible overpayment",
  needsReview: "Needs review",
  notComparable: "Not comparable",
};
function resultView(result, currency) {
  return `<p class="badge">${esc(verdicts[result.verdict])}</p>${result.reportedPeriod ? `<p class="context">Reported work period: ${result.reportedPeriod.startDate === null ? "not stated" : esc(result.reportedPeriod.startDate) + " through " + esc(result.reportedPeriod.endDate)} · ${esc(result.reportedPeriod.timeZone)} · ${result.reportedPeriod.confirmed ? "confirmed from source" : "not confirmed"}</p>` : '<p class="note">This legacy check did not retain separate reported-date facts. Its original result remains as recorded.</p>'}${result.gross === null ? "<p>No comparable expected gross.</p>" : `<ul class="ledger"><li><span>Expected gross in confirmed scope</span><strong class="money">${money(result.gross, currency)}</strong></li><li><span>Confirmed paycheck gross</span><span class="money">${money(result.paidGross, currency)}</span></li><li><span>Expected minus paid</span><strong class="money">${money(result.difference, currency)}</strong></li></ul>`}<ul>${result.reasons.map((r) => `<li>${esc(r)}</li>`).join("")}</ul>${result.comparisons
    .filter((c) => c.field !== "grossPay")
    .map(
      (c) =>
        `<p>Separate per diem: expected ${money(c.expected, currency)}, confirmed ${money(c.paid, currency)}, difference ${money(c.difference, currency)}.</p>`,
    )
    .join(
      "",
    )}<p class="note">Only configured rules and listed confirmed values were compared. Hours and other earnings lines were not verified. This does not establish legal entitlement or a debt.</p>`;
}
function render() {
  if (!state) return;
  disposeReports();
  disposeReports = () => {};
  pendingAudit = null;
  pendingPaycheckScope = null;
  pendingRestore = null;
  document
    .querySelectorAll("[data-tab]")
    .forEach((b) =>
      b.setAttribute("aria-current", b.dataset.tab === tab ? "page" : "false"),
    );
  if (tab === "profile") renderProfiles();
  else if (tab === "history") renderHistory();
  else if (tab === "backup") renderBackup();
  else if (tab === "benefits") renderBenefits();
  else renderPay();
  bind();
}
function renderBenefits() {
  renderBenefitUI({
    container: main,
    state,
    selection: fundSelection,
    editing: fundEditing,
    run,
    uid,
    now,
    onNew: () => {
      if (busy) return;
      fundSelection = null;
      fundEditing = true;
      render();
    },
    onSelect: (id) => {
      if (busy) return;
      fundSelection = id;
      fundEditing = false;
      render();
    },
    onEdit: () => {
      if (busy) return;
      fundEditing = true;
      render();
    },
    onSave: async (check, revision) => {
      await commit((s) => {
        const existing = s.benefitChecks.find((c) => c.id === check.id);
        if (existing) existing.revisions.push(revision);
        else s.benefitChecks.push({ ...check, revisions: [revision] });
      });
      fundSelection = check.id;
      fundEditing = false;
      render();
      message("Fund check saved separately from wages.");
    },
  });
}
function renderProfiles() {
  const latest = state.profiles.at(-1);
  main.innerHTML = `<h1>Confirmed pay rules</h1><p>Each saved profile is a new version. Existing periods keep their exact saved rules.</p>${latest ? `<p class="rule-note">Latest profile: ${money(latest.hourlyRate, latest.currency)}/hour. ${latest.dailyOvertimeTiers.length ? "Daily premium configured." : "No daily premium configured."}</p>` : ""}<form id="profile-form"><div class="fields">${label("Hourly rate", "rate", 'inputmode="decimal" required maxlength="42"')}
  <label>Currency<select name="currency"><option>USD</option><option>CAD</option></select></label></div>
  <fieldset><legend>Optional configured rules</legend><div class="fields">${label("Daily overtime after hours", "threshold", 'inputmode="decimal" placeholder="Not configured"')}${label("Overtime multiplier", "multiplier", 'inputmode="decimal" value="1.5"')}${label("Isolated callout minimum hours", "minimum", 'inputmode="decimal" placeholder="Not configured"')}${label("Per diem per worked local date", "perdiem", 'inputmode="decimal" placeholder="Not configured"')}</div></fieldset>
  <p class="note">Weekly overtime, travel, rest/meal rules, effective-date transitions, benefits and taxes need separate review. An empty optional field means unconfigured, not waived.</p>${check("I confirmed these inputs against my pay rules.", "confirmed", true)}<button class="primary">Save a new profile</button></form><section id="rule-template-tools"></section>`;
  renderRuleTemplateUI({
    container: main.querySelector("#rule-template-tools"),
    state,
    run,
    uid,
    message,
    onAdopt: async (profile, origin) => {
      await commit((s) => {
        s.profiles.push(profile);
        s.templateOrigins.push(origin);
      });
      message(
        "Confirmed rule draft saved as a new profile for future periods.",
      );
    },
  });
}
function renderPay() {
  const period = current();
  if (!period) {
    main.innerHTML = `<h1>Your work. Your expected pay.</h1><p>Start with the rules you explicitly confirmed. Record actual work, then compare a paycheck in the same period.</p>${state.profiles.length ? periodForm() : `<p>No pay profile is saved yet.</p><button class="primary" data-action="profile">Confirm pay rules</button>`}`;
    return;
  }
  const schedule = state.paycycleSchedules.find(
    (s) => s.periodID === period.id,
  );
  const templateOrigin = state.templateOrigins.find(
    (o) => o.profileID === period.rule.id,
  );
  const result = period.closed
    ? period.closedCalculation
    : currentCalculation(state, period);
  main.innerHTML = `<p class="context">${esc(period.start)} → ${esc(period.end)} · ${esc(period.zone)} · ${period.closed ? "Closed record" : "Open period"}</p><p class="context">${schedule ? `Saved paycycle: ${esc(schedule.window.cadence)} · exclusive boundary ${esc(schedule.window.endExclusiveUTC)}` : "Paycycle selection was not retained in this legacy record; its saved dates remain unchanged."}</p><h1>Expected cash wages</h1><div class="answer">${money(result.wages, result.currency)}</div><ul class="ledger"><li><span>Separate per diem</span><span class="money">${money(result.allowances, result.currency)}</span></li><li><span>Wages + configured allowance</span><strong class="money">${money(result.total, result.currency)}</strong></li></ul><p class="rule-note">${currentTimeline(state, period.id) ? "Configured estimate from the confirmed effective-date plan; component rates and rule versions are listed below." : `Configured estimate from ${esc(period.rule.currency)} ${esc(period.rule.hourlyRate)}/hour and the saved rule version.`} Weekly/legal coverage and unconfigured rules remain unchecked.</p>
  <details><summary>Calculation and saved rules</summary><ul class="ledger">${result.components.map((c) => `<li><span>${esc(c.date)} · ${esc(c.category)}<small>${esc(c.explanation)}${c.baseRate ? " · " + esc(c.currency) + " " + esc(c.baseRate) + "/hour" : ""}${c.workedSeconds !== null ? " · " + esc(c.workedSeconds.replace(/\.0+$/, "")) + " seconds at " + esc(c.multiplier) + "×" : ""}</small></span><span class="money">${money(c.amount, c.currency)}</span></li>`).join("")}</ul><p>Rule snapshot ${esc(period.rule.id)}, version ${esc(period.rule.version)}. Engine ${esc(result.engine)}.</p>${templateOrigin ? `<p>Worker-provided rule draft: ${esc(templateOrigin.packet.title)}, revision ${esc(templateOrigin.packet.revision)}, ID ${esc(templateOrigin.packet.templateID)}. This reference is not source approval.</p>` : ""}</details>
  <section id="rule-timeline-tools"></section><h2>Recorded work</h2><ul class="ledger">${period.work.map((w) => `<li><span>${esc(workClock(w.startUTC, w.timeZone))} → ${esc(workClock(w.endUTC, w.timeZone))}<small>${esc(w.kind)} · ${esc(w.timeZone)}${w.unpaidBreaks.length ? " · unpaid break recorded" : ""}</small></span>${period.closed ? "" : `<button class="danger" data-remove="${esc(w.id)}">Remove entry</button>`}</li>`).join("") || "<li>No work recorded.</li>"}</ul>
  ${period.closed ? "<p>This closed period keeps its saved work, rules and calculation.</p>" : workForm()}
  ${
    period.audits.length
      ? `<h2>Saved paycheck checks</h2>${period.audits
          .toReversed()
          .map(
            (a) =>
              `<details data-paycheck-audit="${esc(a.id)}" ${openAuditID === a.id ? "open" : ""}><summary>${esc(verdicts[a.assessment.verdict])} · ${esc(a.createdAt)}</summary>${auditUsesEarlierContext(state, period, a) ? '<p class="rule-note">This saved check retains an earlier work/rule plan. Later changes did not rewrite it; review a new check for the current estimate.</p>' : ""}${resultView(a.assessment, period.rule.currency)}<section data-audit-tools="${esc(a.id)}"></section></details>`,
          )
          .join("")}`
      : ""
  }
  ${period.work.length ? auditForm(period) : ""}${!period.closed && (period.work.length || period.audits.length) ? '<button data-action="close">Close this period</button>' : !period.closed ? '<button data-action="discard">Discard empty period</button>' : ""}${period.closed ? periodForm() : ""}`;
  renderRuleTimelineUI({
    container: main.querySelector("#rule-timeline-tools"),
    state,
    period,
    run,
    uid,
    now,
    onSave: async (record) => {
      await commit((s) => s.ruleTimelines.push(record));
      message(
        "Effective-date plan saved for the open ledger. Earlier checks retain their original plan.",
      );
    },
  });
  const cleanup = period.audits.map((a) =>
    renderAuditTools({
      container: main.querySelector(`[data-audit-tools="${a.id}"]`),
      state,
      period,
      audit: a,
      run,
      uid,
      now,
      message,
      onSave: async (event) => {
        openAuditID = a.id;
        await commit((s) => s.resolutionEvents.push(event));
        message(
          "Worker-reported follow-up saved. The original comparison remains as recorded.",
        );
      },
    }),
  );
  disposeReports = () => cleanup.forEach((dispose) => dispose());
  main.querySelectorAll("[data-paycheck-audit]").forEach((detail) =>
    detail.addEventListener("toggle", () => {
      if (detail.open) openAuditID = detail.dataset.paycheckAudit;
    }),
  );
}
function periodForm() {
  return `<h2>Start a pay period</h2><form id="period-form" data-period-owned><label for="paycycle-cadence">Paycycle</label><select id="paycycle-cadence" name="cadence"><option value="manual">Custom dates</option><option value="weekly">Weekly</option><option value="biweekly">Every two weeks</option><option value="semimonthly">Twice monthly (1–15, 16–end)</option></select><div class="fields">${label("First work date", "start", 'type="date" required')}${label("Last work date (included)", "end", 'type="date" required')}${label("Payroll timezone", "zone", `required value="${esc(Intl.DateTimeFormat().resolvedOptions().timeZone)}"`)}</div><p class="note">Confirm the payroll timezone. Device timezone changes will not reinterpret saved work. The newest profile will be copied into this period.</p><button>Review pay period</button><section class="period-preview" aria-live="polite"></section></form>`;
}
function workForm() {
  return `<h2>Add actual work</h2><form id="work-form"><div class="fields">${label("Start", "start", 'type="datetime-local" required')}${label("End", "end", 'type="datetime-local" required')}<label>When the start clock repeats<select name="startOccurrence"><option value="">Choose if needed</option><option value="0">First occurrence</option><option value="1">Second occurrence</option></select></label><label>When the end clock repeats<select name="endOccurrence"><option value="">Choose if needed</option><option value="0">First occurrence</option><option value="1">Second occurrence</option></select></label><label>Work kind<select name="kind"><option value="regular">Regular work</option><option value="callout">Separate physical callout</option><option value="other">Other recorded work</option></select></label></div><details><summary>Unpaid break (optional actual times)</summary><div class="fields">${label("Break start", "breakStart", 'type="datetime-local"')}${label("Break end", "breakEnd", 'type="datetime-local"')}</div><p class="note">Only enter an unpaid break you explicitly classified. Repeated-clock break times require a separate reviewed entry.</p></details><button class="primary">Save work</button></form>`;
}
function auditForm(period) {
  return `<h2>Check a paycheck</h2><form id="audit-form"><div class="fields">${label("Confirmed paycheck gross", "gross", 'inputmode="decimal" required')}<div><label for="gross-basis">What does gross include?</label><select id="gross-basis" name="basis"><option value="unconfirmed">Not confirmed</option><option value="wagesOnly">Cash wages only</option><option value="wagesAndPerDiem">Wages and per diem</option></select></div>${label("Separately confirmed per diem (optional)", "perdiem", 'inputmode="decimal"')}</div>${check("All work for this paycheck period is recorded.", "complete")}${check("Some paycheck fields still need review.", "unreviewed")}${check("Some applicable rules are not represented here.", "unsupported")}${check("A complete-workweek overtime review is pending.", "weekly")}<fieldset><legend>Paycheck source work-period dates</legend><p>Use the dates for work covered by this paycheck, not its payday. Blank dates remain unknown. The timezone is your review context, not an OCR extraction.</p><div class="fields">${label("Reported first work date", "reported-start", 'type="date"')}${label("Reported last work date (included)", "reported-end", 'type="date"')}${label("Paycheck date-context timezone", "reported-zone", `required value="${esc(period.zone)}"`)}</div>${check("I confirmed these work-period dates and timezone against the source.", "reported-confirmed")}</fieldset><p class="note">Enter gross earnings, not take-home pay or a bank deposit. No OCR or automatic rule interpretation is applied.</p><button>Review comparison</button></form><section id="audit-preview" aria-live="polite"></section>`;
}
function renderHistory() {
  main.innerHTML = `<h1>Pay history</h1><p>Saved checks retain their original work, rules and comparison. New profiles do not rewrite them.</p><ul class="ledger">${
    state.periods
      .toReversed()
      .map(
        (p) =>
          `<li><span>${esc(p.start)} → ${esc(p.end)}<small>${p.closed ? "Closed" : "Open"} · ${p.audits.length} saved check(s) · ${esc(p.zone)}</small></span><button data-period="${esc(p.id)}">Open record</button></li>`,
      )
      .join("") || "<li>No periods yet.</li>"
  }</ul>`;
}
function renderBackup() {
  main.innerHTML = `<h1>Keep a copy you control</h1><p>Records are stored in this browser. They can be removed by clearing site data, private browsing or storage eviction. A downloaded backup is your separate recovery copy.</p><p class="rule-note">This preview opens web snapshots only. iOS/Android state transfer is not yet supported. The protected envelope uses the shared encryption format; compatible encryption does not imply compatible financial records.</p><button data-action="persist">Request persistent browser storage</button><form id="export-form"><h2>Export protected web backup</h2>${label("New backup password", "password", 'type="password" required minlength="12" autocomplete="new-password"')}${label("Repeat password", "repeat", 'type="password" required autocomplete="new-password"')}<p class="note">Use at least 12 characters. Keep the password separately; there is no reset service. No password is saved by LinePaycheck.</p><button class="primary">Download encrypted backup</button></form><form id="restore-form"><h2>Inspect a backup</h2>${label("Protected web backup", "file", 'type="file" required accept=".linepaybackup"')}${label("Backup password", "password", 'type="password" required autocomplete="off"')}<button>Unlock and inspect</button></form><section id="restore-preview" aria-live="polite"></section><hr><h2>Remove this browser’s records</h2><p>Export a copy first. This removes profiles, periods, work and saved checks from this browser only.</p><button class="danger" data-action="clear">Review removal</button><section id="clear-preview"></section>`;
}
async function commit(change) {
  const replacement = structuredClone(state);
  change(replacement);
  validateState(replacement);
  message("Saving local records…");
  state = await store.write(replacement, state.revision);
  render();
  message("Saved in this browser.");
}
function resolveClock(text, zone, occurrence = "") {
  const choices = localCandidates(text, zone);
  if (!choices.length)
    throw Error(
      "That local clock time does not exist in this timezone. Check the clock change.",
    );
  if (choices.length > 1 && (occurrence === "" || !choices[Number(occurrence)]))
    throw Error(
      "This clock time occurs twice. Select its first or second occurrence.",
    );
  return utc(choices.length === 1 ? choices[0] : choices[Number(occurrence)]);
}
function bind() {
  main.querySelectorAll("[data-period-owned]").forEach((form) =>
    bindPeriodSetup({
      form,
      state,
      run,
      uid,
      onSave: async (period, schedule) => {
        await commit((s) => {
          s.periods.push(period);
          s.paycycleSchedules.push(schedule);
        });
        selection = period.id;
        render();
      },
    }),
  );
  main
    .querySelectorAll(
      "form:not(#fund-form):not([data-rule-template]):not([data-audit-owned]):not([data-timeline-owned]):not([data-period-owned])",
    )
    .forEach((form) =>
      form.addEventListener("submit", (event) => {
        event.preventDefault();
        run(() => submit(form));
      }),
    );
  main
    .querySelectorAll("[data-action]")
    .forEach((b) =>
      b.addEventListener("click", () => run(() => action(b.dataset.action))),
    );
  main.querySelectorAll("[data-period]").forEach((b) =>
    b.addEventListener("click", () => {
      selection = b.dataset.period;
      tab = "pay";
      render();
    }),
  );
  main.querySelectorAll("[data-remove]").forEach((b) =>
    b.addEventListener("click", () => {
      const target = b.dataset.remove;
      const section = document.createElement("section");
      section.className = "preview";
      section.innerHTML =
        '<p>Remove this work entry from the open ledger? Saved paycheck checks retain their original snapshots.</p><button class="danger">Confirm removal</button>';
      b.after(section);
      section.querySelector("button").onclick = () =>
        run(() =>
          commit((s) => {
            const p = s.periods.find((p) => p.id === current().id);
            p.work = p.work.filter((w) => w.id !== target);
          }),
        );
      b.disabled = true;
    }),
  );
  for (const id of ["audit-form", "restore-form"]) {
    const form = main.querySelector("#" + id);
    const changed = (event) => {
      if (id === "audit-form") {
        pendingAudit = null;
        pendingPaycheckScope = null;
        if (
          ["reported-start", "reported-end", "reported-zone"].includes(
            event.target.name,
          )
        )
          form.elements["reported-confirmed"].checked = false;
        main.querySelector("#audit-preview").replaceChildren();
      } else {
        pendingRestore = null;
        main.querySelector("#restore-preview").replaceChildren();
      }
    };
    form?.addEventListener("input", changed);
    form?.addEventListener("change", changed);
  }
}
async function run(fn) {
  if (busy) return;
  busy = true;
  const pendingControls = [
    ...document.querySelectorAll(
      "nav button, main input, main select, main textarea, main button",
    ),
  ].filter((control) => !control.disabled);
  try {
    // Capture form values synchronously inside the handler before controls become disabled.
    const pending = fn();
    pendingControls.forEach((control) => {
      if (control.isConnected) control.disabled = true;
    });
    await pending;
  } catch (error) {
    message(
      error.message ||
        "This action could not finish. Your previous records are unchanged.",
      true,
    );
  } finally {
    pendingControls.forEach((control) => {
      if (control.isConnected) control.disabled = false;
    });
    busy = false;
  }
}
async function submit(form) {
  const data = new FormData(form),
    get = (name) => data.get(name),
    checked = (name) => data.has(name),
    nullable = (name) => (get(name) === "" ? null : get(name));
  if (form.id === "profile-form") {
    const profile = {
      id: uid(),
      version: "1",
      currency: get("currency"),
      hourlyRate: get("rate"),
      outsideScheduleMultiplier: "1",
      regularSchedule: [],
      dailyOvertimeTiers:
        get("threshold") === ""
          ? []
          : [{ afterHours: get("threshold"), multiplier: get("multiplier") }],
      weekdayPremiums: [],
      datePremiums: [],
      calloutMinimumHours: nullable("minimum"),
      perDiemPerWorkDate: nullable("perdiem"),
      rounding: { scale: 2, mode: "halfUp", scope: "payCategory" },
    };
    if (!checked("confirmed"))
      throw Error("Confirm the pay inputs before saving.");
    await commit((s) => s.profiles.push(profile));
    tab = "pay";
    render();
  } else if (form.id === "work-form") {
    const p = current();
    if (p.closed) throw Error("Closed work cannot be changed.");
    const startUTC = resolveClock(get("start"), p.zone, get("startOccurrence")),
      endUTC = resolveClock(get("end"), p.zone, get("endOccurrence")),
      breaks = [];
    if (get("breakStart") || get("breakEnd"))
      breaks.push({
        id: uid(),
        startUTC: resolveClock(get("breakStart"), p.zone),
        endUTC: resolveClock(get("breakEnd"), p.zone),
      });
    const entry = {
      id: uid(),
      startUTC,
      endUTC,
      timeZone: p.zone,
      kind: get("kind"),
      calloutEventID: get("kind") === "callout" ? uid() : null,
      unpaidBreaks: breaks,
    };
    await commit((s) => s.periods.find((x) => x.id === p.id).work.push(entry));
  } else if (form.id === "audit-form") {
    const p = current(),
      calculation = currentCalculation(state, p),
      facts = {
        completeWork: checked("complete"),
        grossBasis: get("basis"),
        unreviewedFields: checked("unreviewed"),
        unsupportedRules: checked("unsupported"),
        weeklyReviewPending: checked("weekly"),
        paidGross: get("gross"),
        paidPerDiem: nullable("perdiem"),
      };
    const auditID = uid(),
      reportedStart = nullable("reported-start"),
      reportedEnd = nullable("reported-end");
    pendingPaycheckScope = {
      auditID,
      periodID: p.id,
      startDate: reportedStart,
      endDate: reportedEnd,
      timeZone: get("reported-zone"),
      confirmed: checked("reported-confirmed"),
    };
    pendingAudit = {
      id: auditID,
      createdAt: now(),
      work: structuredClone(p.work),
      facts,
      calculation,
      assessment: assessForPeriod(
        calculation,
        facts,
        p.rule.rounding,
        p,
        pendingPaycheckScope,
      ),
    };
    main.querySelector("#audit-preview").innerHTML =
      `<div class="preview"><h2>Review before saving</h2>${resultView(pendingAudit.assessment, p.rule.currency)}<button class="primary" id="confirm-audit">Save this check</button></div>`;
    document.querySelector("#confirm-audit").onclick = () =>
      run(async () => {
        if (!pendingAudit) throw Error("Review the current facts again.");
        openAuditID = pendingAudit.id;
        await commit((s) => {
          s.periods.find((x) => x.id === p.id).audits.push(pendingAudit);
          s.paycheckScopes.push(pendingPaycheckScope);
        });
      });
  } else if (form.id === "export-form") {
    if (get("password") !== get("repeat"))
      throw Error("The passwords do not match.");
    for (const element of form.elements) element.disabled = true;
    message("Protecting the web backup…");
    try {
      const encoded = await encryptBackup(snapshot(state), get("password")),
        url = URL.createObjectURL(
          new Blob([encoded], { type: "application/octet-stream" }),
        ),
        a = document.createElement("a");
      a.href = url;
      a.download = "LinePaycheck-web.linepaybackup";
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 60000);
      message(
        "Encrypted download requested. Confirm the file is saved in your chosen location before relying on it.",
      );
    } finally {
      form.reset();
      for (const element of form.elements) element.disabled = false;
    }
  } else if (form.id === "restore-form") {
    pendingRestore = null;
    main.querySelector("#restore-preview").replaceChildren();
    const file = get("file");
    if (!file || file.size > 67108864)
      throw Error("Select a backup up to 64 MiB.");
    for (const element of form.elements) element.disabled = true;
    message("Unlocking the selected backup…");
    try {
      pendingRestore = inspectSnapshot(
        await decryptBackup(
          new Uint8Array(await file.arrayBuffer()),
          get("password"),
        ),
      );
    } finally {
      form.reset();
      for (const element of form.elements) element.disabled = false;
    }
    main.querySelector("#restore-preview").innerHTML =
      `<div class="preview"><h2>Backup inspected; records unchanged</h2><p>${pendingRestore.profiles.length} profile(s), ${pendingRestore.periods.length} period(s), ${pendingRestore.periods.reduce((n, p) => n + p.audits.length, 0)} saved paycheck check(s), ${pendingRestore.benefitChecks.length} fund check(s).</p><p>Replacing removes this browser’s current records. Export them first if you need to keep them.</p><button class="danger" id="confirm-restore">Replace with inspected backup</button></div>`;
    document.querySelector("#confirm-restore").onclick = () =>
      run(async () => {
        if (!pendingRestore) throw Error("Inspect the backup again.");
        state = await store.write(pendingRestore, state.revision);
        selection = null;
        fundSelection = null;
        fundEditing = false;
        render();
        message("Inspected web backup restored in this browser.");
      });
  }
}
async function action(name) {
  if (name === "profile") {
    tab = "profile";
    render();
  } else if (name === "discard") {
    const p = current();
    if (p.closed || p.work.length || p.audits.length)
      throw Error("Only an empty, unaudited open period can be discarded.");
    const section = document.createElement("section");
    section.className = "preview";
    section.innerHTML =
      '<p>Discard this empty period and its paycycle/rule-plan metadata? No recorded work or paycheck checks will be removed.</p><button id="confirm-discard">Confirm discard empty period</button>';
    main.append(section);
    section.querySelector("button").onclick = () =>
      run(async () => {
        await commit((s) => {
          s.periods = s.periods.filter((x) => x.id !== p.id);
          s.paycycleSchedules = s.paycycleSchedules.filter(
            (x) => x.periodID !== p.id,
          );
          s.ruleTimelines = s.ruleTimelines.filter((x) => x.periodID !== p.id);
        });
        selection = null;
        render();
      });
  } else if (name === "close") {
    const p = current();
    if (p.closed) return;
    const section = document.createElement("section");
    section.className = "preview";
    section.innerHTML =
      '<h2>Close this period?</h2><p>The recorded work, rule snapshot and expected calculation will be frozen. You can still append a paycheck comparison.</p><button id="confirm-close">Confirm close period</button>';
    main.append(section);
    section.querySelector("button").onclick = () =>
      run(() =>
        commit((s) => {
          const target = s.periods.find((x) => x.id === p.id);
          target.closedCalculation = currentCalculation(s, target);
          target.closed = true;
        }),
      );
  } else if (name === "persist") {
    const granted = await navigator.storage?.persist?.();
    message(
      granted
        ? "Persistent storage granted. Keep separate backups as well."
        : "Persistent storage was not granted. Keep a downloaded backup.",
    );
  } else if (name === "clear") {
    document.querySelector("#clear-preview").innerHTML =
      '<div class="preview"><p>Remove every LinePaycheck record from this browser?</p><button class="danger" id="confirm-clear">Confirm remove all local records</button></div>';
    document.querySelector("#confirm-clear").onclick = () =>
      run(async () => {
        state = await store.write(emptyState(), state.revision);
        selection = null;
        render();
        message("This browser’s LinePaycheck records were removed.");
      });
  }
}
document.querySelectorAll("[data-tab]").forEach((button) =>
  button.addEventListener("click", () => {
    if (busy) return;
    tab = button.dataset.tab;
    message("");
    render();
    main.focus();
  }),
);
try {
  store = await openStore();
  state = await store.read();
  render();
  message("Records opened from this browser.");
} catch (e) {
  message(e.message, true);
  main.innerHTML =
    "<h1>Local records could not open</h1><p>Your stored records were not reset or replaced. Close other tabs and reload. Keep your existing backup.</p>";
}
if ("serviceWorker" in navigator)
  navigator.serviceWorker
    .register(new URL("../sw.js", import.meta.url), {
      scope: new URL("../", import.meta.url).pathname,
    })
    .catch(() => {
      message(
        "Offline app caching is unavailable. Local records remain separate; keep a backup.",
        true,
      );
    });
