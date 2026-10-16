import { epoch } from "./payroll.mjs";
export const resolutionStatuses = {
  reviewing: "Reviewing evidence",
  shared: "Shared for review",
  awaitingResponse: "Awaiting a response",
  corrected: "Correction confirmed by me",
  explained: "Explanation accepted by me",
  unresolved: "Still unresolved",
};
const need = (condition, message) => {
  if (!condition) throw Error(message);
};
export function selectedAudit(state, periodID, auditID) {
  const period = state.periods.find((p) => p.id === periodID),
    audit = period?.audits.find((a) => a.id === auditID);
  need(period && audit, "Select an existing saved paycheck check.");
  return { period, audit };
}
export function validateResolutionEvent(event, state) {
  need(
    event &&
      typeof event === "object" &&
      !Array.isArray(event) &&
      Object.keys(event).sort().join("|") ===
        ["id", "periodID", "auditID", "status", "note", "createdAt"]
          .sort()
          .join("|"),
    "Unsupported follow-up record.",
  );
  need(
    typeof event.id === "string" && /^[A-Za-z0-9-]{1,128}$/.test(event.id),
    "Invalid follow-up identity.",
  );
  selectedAudit(state, event.periodID, event.auditID);
  need(
    typeof event.status === "string" &&
      Object.hasOwn(resolutionStatuses, event.status),
    "Select a supported worker-recorded status.",
  );
  need(
    typeof event.note === "string" &&
      event.note.trim().length > 0 &&
      event.note.length <= 4000 &&
      !/[\uD800-\uDFFF]/u.test(event.note) &&
      !/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(event.note),
    "Enter a follow-up note up to 4,000 characters with valid Unicode and no unsupported control characters.",
  );
  epoch(event.createdAt);
  return event;
}
export function createResolutionEvent(
  state,
  { id, periodID, auditID, status, note, createdAt },
) {
  need(typeof note === "string", "Enter a follow-up note.");
  return validateResolutionEvent(
    { id, periodID, auditID, status, note: note.trim(), createdAt },
    state,
  );
}
