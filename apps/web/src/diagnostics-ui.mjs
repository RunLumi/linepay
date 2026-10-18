import { localActivityMilestones } from "./local-activity.mjs";

const escapeHTML = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (character) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
      character
    ],
  );

const titles = {
  firstObservedOpen: "First open observed by this browser ledger",
  appOpened: "App opens observed",
  profileStarted: "Pay-rule setup started",
  profileReady: "Pay profiles saved",
  workLogged: "New work entries saved",
  expectedPaySeen: "Periods with expected pay displayed",
  paycheckIntakeStarted: "Paycheck checks started",
  paycheckCheckSaved: "Paycheck checks saved",
  auditCompleted: "Comparable confirmed checks saved",
  secondAudit: "Second comparable check observed",
  backupRestored: "Protected financial backups restored",
};

export async function renderLocalDiagnostics({
  container,
  ledger,
  run,
  message,
  onRendered = () => {},
  isCurrent = () => true,
}) {
  await ledger.refresh();
  if (!isCurrent()) return;
  const snapshot = ledger.snapshot;
  container.innerHTML = `<h1 id="diagnostics-heading">Device-local activity</h1>
    <section class="rule-note"><h2>Only in this browser</h2>
      <p id="activity-explanation">These closed milestone counts stay in a separate local database. No usage event is sent to a collector. Pay amounts, payroll dates, names, documents and free text are not recorded here. Restoring a financial backup does not create old activity.</p>
      <label for="activity-recording"><input id="activity-recording" type="checkbox" aria-describedby="diagnostics-heading activity-explanation" ${snapshot.recordingEnabled ? "checked" : ""} ${ledger.readable ? "" : "disabled"}> Record device-local activity</label>
      <p class="note">These are not App Store install counts, global cohorts or subscriber numbers. Usage days and counts can still be personal; a manual export is not anonymous. Browser clearing or eviction can remove this ledger.</p>
      ${ledger.issue ? `<p role="alert">${escapeHTML(ledger.issue)}</p>` : ""}
    </section>
    <section><h2>Observed since the local ledger started</h2>
      <p>First observed day (UTC): ${escapeHTML(snapshot.firstObservedDayUTC ?? "not recorded")}. Counts may be incomplete after disabled recording, storage errors or retention.</p>
      <ul class="ledger">${localActivityMilestones.map((milestone) => `<li><span>${escapeHTML(titles[milestone])}</span><strong class="money" data-activity-count="${escapeHTML(milestone)}">${ledger.count(milestone)}</strong></li>`).join("")}</ul>
      <p class="note">Daily detail is limited to 400 UTC days. Internal deduplication digests are limited to 20,000 and never included in an export.</p>
    </section>
    <section><h2>Manual diagnostic export</h2>
      <p>Preview the exact JSON before downloading it. The file contains event labels, counts, observed UTC days and recording status. It is separate from pay backups and may reveal personal usage patterns.</p>
      <button id="activity-preview">Preview local diagnostic file</button>
      <section id="activity-preview-result" aria-live="polite"></section>
      <button class="danger" id="activity-clear">Clear only local activity</button>
      <section id="activity-clear-result" aria-live="polite"></section>
    </section>`;

  const recording = container.querySelector("#activity-recording");
  recording?.addEventListener("change", () => {
    const enabled = recording.checked;
    run(async () => {
      await ledger.setRecordingEnabled(enabled);
      await renderLocalDiagnostics({ container, ledger, run, message, onRendered, isCurrent });
      message(enabled ? "Local activity recording enabled in this browser." : "Local activity recording paused; existing observations remain.");
    });
  });

  container.querySelector("#activity-preview")?.addEventListener("click", () =>
    run(async () => {
      const data = await ledger.diagnosticData();
      const preview = container.querySelector("#activity-preview-result");
      preview.innerHTML = `<div class="preview"><h3>Review this exact diagnostic copy</h3><p>It contains local usage days and counts. It is not anonymous or a pay-data backup. Choose a private destination yourself.</p><pre id="activity-preview-json" tabindex="0">${escapeHTML(data)}</pre><button class="primary" id="activity-download">Download reviewed JSON</button></div>`;
      preview.querySelector("#activity-download").addEventListener("click", () =>
        run(async () => {
          const url = URL.createObjectURL(new Blob([data], { type: "application/json" }));
          const link = document.createElement("a");
          link.href = url;
          link.download = "LinePaycheck-web-local-diagnostics.json";
          link.click();
          setTimeout(() => URL.revokeObjectURL(url), 60_000);
          message("Diagnostic download requested. Confirm the file is saved in your chosen location; this screen does not verify delivery.");
        }),
      );
      preview.querySelector("#activity-preview-json").focus();
    }),
  );

  container.querySelector("#activity-clear")?.addEventListener("click", () => {
    container.querySelector("#activity-clear-result").innerHTML =
      '<div class="preview"><p>Clear activity observations only? Pay profiles, periods, work, paycheck and fund checks, and protected backups are unchanged. The recording preference is kept. Files already exported are not removed.</p><button class="danger" id="activity-confirm-clear">Confirm clear local activity</button></div>';
    container.querySelector("#activity-confirm-clear").addEventListener("click", () =>
      run(async () => {
        await ledger.clear();
        await renderLocalDiagnostics({ container, ledger, run, message, onRendered, isCurrent });
        message("Only local activity was cleared. Pay records are unchanged.");
      }),
    );
  });
  onRendered();
}
