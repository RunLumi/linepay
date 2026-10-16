import { calculate, localDate, epoch } from "./payroll.mjs";
import { assess } from "./assessment.mjs";
const encoder = new TextEncoder();
export const emptyState = () => ({
  format: "com.streamentry.linepay.web.state",
  version: 1,
  revision: 0,
  profiles: [],
  periods: [],
});
const need = (x, message) => {
  if (!x) throw Error(message);
};
const keys = (object, allowed) => {
  need(
    object && typeof object === "object" && !Array.isArray(object),
    "Invalid saved object.",
  );
  need(
    Object.keys(object).sort().join("|") === allowed.slice().sort().join("|"),
    "Unsupported saved fields; nothing was replaced.",
  );
};
const identity = (value) =>
  need(
    typeof value === "string" && /^[A-Za-z0-9-]{1,128}$/.test(value),
    "Invalid record identity.",
  );
function date(text) {
  need(
    typeof text === "string" &&
      /^20\d\d-\d\d-\d\d$/.test(text) &&
      new Date(text + "T00:00:00Z").toISOString().slice(0, 10) === text,
    "Invalid period date.",
  );
}
function rule(r) {
  keys(r, [
    "id",
    "version",
    "currency",
    "hourlyRate",
    "outsideScheduleMultiplier",
    "regularSchedule",
    "dailyOvertimeTiers",
    "weekdayPremiums",
    "datePremiums",
    "calloutMinimumHours",
    "perDiemPerWorkDate",
    "rounding",
  ]);
  identity(r.id);
  identity(r.version);
  keys(r.rounding, ["scale", "mode", "scope"]);
  for (const tier of r.dailyOvertimeTiers)
    keys(tier, ["afterHours", "multiplier"]);
  for (const premium of r.weekdayPremiums)
    keys(premium, ["weekday", "multiplier"]);
  calculate([], r);
}
function workFacts(work, period) {
  need(Array.isArray(work) && work.length <= 2000, "Too many work entries.");
  for (const w of work) {
    keys(w, [
      "id",
      "startUTC",
      "endUTC",
      "timeZone",
      "kind",
      "calloutEventID",
      "unpaidBreaks",
    ]);
    identity(w.id);
    need(
      w.calloutEventID === null || typeof w.calloutEventID === "string",
      "Invalid callout reference.",
    );
    need(
      w.timeZone === period.zone,
      "Work timezone does not match the saved period.",
    );
    need(
      localDate(epoch(w.startUTC), w.timeZone) >= period.start &&
        localDate(epoch(w.endUTC) - 1, w.timeZone) <= period.end,
      "Work falls outside this period.",
    );
    for (const b of w.unpaidBreaks) {
      keys(b, ["id", "startUTC", "endUTC"]);
      identity(b.id);
    }
  }
  return calculate(work, period.rule);
}
export function validateState(state) {
  need(
    encoder.encode(JSON.stringify(state)).length <= 8388608,
    "Saved data exceeds 8 MiB.",
  );
  keys(state, ["format", "version", "revision", "profiles", "periods"]);
  need(
    state.format === "com.streamentry.linepay.web.state" && state.version === 1,
    "This web app cannot open this state format. Native app backups are not yet supported.",
  );
  need(
    Number.isSafeInteger(state.revision) &&
      state.revision >= 0 &&
      state.revision < 1000000000,
    "Unsupported state revision.",
  );
  need(
    Array.isArray(state.profiles) &&
      state.profiles.length <= 100 &&
      Array.isArray(state.periods) &&
      state.periods.length <= 100,
    "Too many saved profiles or periods.",
  );
  const ids = new Set();
  const ruleDefinitions = new Map();
  const admitRule = (r) => {
    rule(r);
    const key = r.id + "|" + r.version,
      definition = JSON.stringify(r);
    need(
      !ruleDefinitions.has(key) || ruleDefinitions.get(key) === definition,
      "A saved rule identity has conflicting definitions.",
    );
    ruleDefinitions.set(key, definition);
  };
  let totalWork = 0,
    totalAudits = 0;
  const unique = (id) => {
    identity(id);
    need(!ids.has(id), "Duplicate saved identity.");
    ids.add(id);
  };
  for (const profile of state.profiles) {
    admitRule(profile);
    unique(profile.id);
  }
  need(
    state.periods.filter((p) => !p.closed).length <= 1,
    "Only one period can be open.",
  );
  for (const period of state.periods) {
    keys(period, [
      "id",
      "start",
      "end",
      "zone",
      "rule",
      "work",
      "audits",
      "closed",
      "closedCalculation",
    ]);
    unique(period.id);
    date(period.start);
    date(period.end);
    need(
      period.end >= period.start &&
        Date.parse(period.end) - Date.parse(period.start) <= 31968000000,
      "Invalid or oversized pay period.",
    );
    need(
      typeof period.zone === "string" &&
        typeof period.closed === "boolean" &&
        Array.isArray(period.audits),
      "Invalid period scope.",
    );
    new Intl.DateTimeFormat("en", { timeZone: period.zone });
    admitRule(period.rule);
    const current = workFacts(period.work, period);
    totalWork += period.work.length;
    for (const w of period.work) unique(w.id);
    need(
      period.closed
        ? JSON.stringify(current) === JSON.stringify(period.closedCalculation)
        : period.closedCalculation === null,
      "Closed calculation does not match its recorded version.",
    );
    totalAudits += period.audits.length;
    for (const audit of period.audits) {
      keys(audit, [
        "id",
        "createdAt",
        "work",
        "facts",
        "calculation",
        "assessment",
      ]);
      unique(audit.id);
      epoch(audit.createdAt);
      keys(audit.facts, [
        "completeWork",
        "grossBasis",
        "unreviewedFields",
        "unsupportedRules",
        "weeklyReviewPending",
        "paidGross",
        "paidPerDiem",
      ]);
      const calculation = workFacts(audit.work, period);
      totalWork += audit.work.length;
      need(
        JSON.stringify(calculation) === JSON.stringify(audit.calculation),
        "Saved audit calculation is unsupported or changed; nothing was replaced.",
      );
      need(
        JSON.stringify(
          assess(calculation, audit.facts, period.rule.rounding),
        ) === JSON.stringify(audit.assessment),
        "Saved assessment does not match its recorded facts.",
      );
    }
  }
  need(
    totalWork <= 10000 && totalAudits <= 1000,
    "Backup exceeds supported history limits.",
  );
  return state;
}
export function snapshot(state) {
  validateState(state);
  const bytes = new TextEncoder().encode(
    JSON.stringify({
      format: "com.streamentry.linepay.web.snapshot",
      version: 1,
      state,
    }),
  );
  need(bytes.length <= 8388608, "Web snapshot exceeds 8 MiB.");
  return bytes;
}
export function inspectSnapshot(bytes) {
  need(bytes.byteLength <= 8388608, "Web snapshot exceeds 8 MiB.");
  const payload = JSON.parse(
    new TextDecoder("utf-8", { fatal: true }).decode(bytes),
  );
  keys(payload, ["format", "version", "state"]);
  need(
    payload.format === "com.streamentry.linepay.web.snapshot" &&
      payload.version === 1,
    "This is not a supported web snapshot. Native snapshots need a future explicit migration.",
  );
  return validateState(payload.state);
}
export function openStore() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("linepaycheck-web", 1);
    request.onupgradeneeded = () => request.result.createObjectStore("state");
    request.onerror = () =>
      reject(Error("Browser storage is unavailable. No changes were saved."));
    request.onblocked = () =>
      reject(Error("Close other LinePaycheck tabs before opening storage."));
    request.onsuccess = () => {
      const db = request.result;
      db.onversionchange = () => db.close();
      resolve({
        read: () =>
          new Promise((done, fail) => {
            let result;
            const tx = db.transaction("state", "readonly"),
              r = tx.objectStore("state").get("current");
            r.onsuccess = () => {
              result = r.result ?? emptyState();
            };
            tx.oncomplete = () => {
              try {
                done(validateState(result));
              } catch (e) {
                fail(e);
              }
            };
            tx.onerror = () => fail(tx.error);
            tx.onabort = () =>
              fail(
                Error(
                  "Local records could not be read. They were not reset or replaced.",
                ),
              );
          }),
        write: (state, expectedRevision) =>
          new Promise((done, fail) => {
            let conflict = false;
            const replacement = structuredClone(state);
            replacement.revision = expectedRevision + 1;
            try {
              validateState(replacement);
            } catch (e) {
              fail(e);
              return;
            }
            const tx = db.transaction("state", "readwrite", {
                durability: "strict",
              }),
              store = tx.objectStore("state"),
              request = store.get("current");
            request.onsuccess = () => {
              if ((request.result?.revision ?? 0) !== expectedRevision) {
                conflict = true;
                tx.abort();
              } else store.put(replacement, "current");
            };
            tx.oncomplete = () => done(replacement);
            tx.onabort = () =>
              fail(
                Error(
                  conflict
                    ? "Another tab changed these records. Reload before trying again; nothing was replaced."
                    : "Storage could not commit. Your previous records are unchanged.",
                ),
              );
            tx.onerror = () => {};
          }),
      });
    };
  });
}
