import { calculate, localDate, epoch } from "./payroll.mjs";
import {
  reproduceAssessment,
  validatePaycheckScope,
} from "./assessment-period.mjs";
import { paycycleWindow } from "./paycycle.mjs";
import {
  calculateContributions,
  contributionRuleDefinition,
  validateContributionPeriod,
} from "./benefits.mjs";
import {
  validateRuleTemplate,
  adoptRuleTemplate,
  ruleTemplateIdentity,
} from "./rule-template.mjs";
import { validateResolutionEvent } from "./resolution.mjs";
import { validateTimeline } from "./payroll-v2.mjs";
import { validateWeeklyReview } from "./weekly.mjs";
import {
  currentCalculation,
  reproduceSavedCalculation,
} from "./calculation-context.mjs";
const encoder = new TextEncoder();
export const emptyState = () => ({
  format: "com.streamentry.linepay.web.state",
  version: 7,
  revision: 0,
  profiles: [],
  periods: [],
  benefitChecks: [],
  templateOrigins: [],
  resolutionEvents: [],
  ruleTimelines: [],
  paycycleSchedules: [],
  paycheckScopes: [],
  weeklyReviews: [],
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
  return work;
}
export function validateState(state) {
  need(
    encoder.encode(JSON.stringify(state)).length <= 8388608,
    "Saved data exceeds 8 MiB.",
  );
  keys(state, [
    "format",
    "version",
    "revision",
    "profiles",
    "periods",
    "benefitChecks",
    "templateOrigins",
    "resolutionEvents",
    "ruleTimelines",
    "paycycleSchedules",
    "paycheckScopes",
    "weeklyReviews",
  ]);
  need(
    state.format === "com.streamentry.linepay.web.state" && state.version === 7,
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
    Array.isArray(state.ruleTimelines) && state.ruleTimelines.length <= 1000,
    "Too many rule timeline revisions.",
  );
  let datedChanges = 0;
  for (const timeline of state.ruleTimelines) {
    keys(timeline, ["id", "periodID", "createdAt", "confirmed", "changes"]);
    need(
      timeline.confirmed === true,
      "An effective-date plan needs explicit confirmation.",
    );
    unique(timeline.id);
    epoch(timeline.createdAt);
    const period = state.periods.find((p) => p.id === timeline.periodID);
    need(period, "Rule timeline has no retained period.");
    need(
      Array.isArray(timeline.changes) && timeline.changes.length <= 256,
      "Too many effective changes.",
    );
    datedChanges += timeline.changes.length;
    need(
      datedChanges <= 10000,
      "Rule timeline history exceeds its supported limit.",
    );
    for (const change of timeline.changes) {
      keys(change, ["effectiveDate", "sourceProfileID", "agreement"]);
      date(change.effectiveDate);
      need(
        change.effectiveDate >= period.start &&
          change.effectiveDate <= period.end,
        "Effective change lies outside its period.",
      );
      admitRule(change.agreement);
      const source = state.profiles.find(
        (p) => p.id === change.sourceProfileID,
      );
      need(source, "Effective rule has no retained source profile.");
      const params = (value) =>
        Object.fromEntries(
          Object.entries(value).filter(
            ([key]) => key !== "id" && key !== "version",
          ),
        );
      need(
        JSON.stringify(params(source)) ===
          JSON.stringify(params(change.agreement)),
        "Effective snapshot no longer matches its confirmed source profile.",
      );
    }
    validateTimeline(period.rule, timeline);
  }
  need(
    Array.isArray(state.weeklyReviews) && state.weeklyReviews.length <= 128,
    "Too many weekly review records.",
  );
  for (const review of state.weeklyReviews) {
    validateWeeklyReview(review);
    unique(review.id);
    for (const source of review.source.periods) {
      admitRule(source.rule);
      for (const change of source.timeline?.changes ?? [])
        admitRule(change.agreement);
      totalWork += source.work.length;
    }
  }
  need(
    Array.isArray(state.paycycleSchedules) &&
      state.paycycleSchedules.length <= 100 &&
      Array.isArray(state.paycheckScopes) &&
      state.paycheckScopes.length <= 1000,
    "Paycycle/source-period metadata exceeds its limit.",
  );
  const scheduledPeriods = new Set(),
    scopedAudits = new Set();
  for (const schedule of state.paycycleSchedules) {
    keys(schedule, ["periodID", "window"]);
    need(
      !scheduledPeriods.has(schedule.periodID),
      "Duplicate saved paycycle metadata.",
    );
    scheduledPeriods.add(schedule.periodID);
    const period = state.periods.find((p) => p.id === schedule.periodID);
    need(period, "Saved paycycle has no retained period.");
    const window = paycycleWindow({
      cadence: schedule.window.cadence,
      startDate: period.start,
      manualEndDate: period.end,
      timeZone: period.zone,
    });
    need(
      window.endDate === period.end &&
        JSON.stringify(window) === JSON.stringify(schedule.window),
      "Saved paycycle does not match its confirmed dates/timezone.",
    );
  }
  for (const scope of state.paycheckScopes) {
    validatePaycheckScope(scope);
    need(!scopedAudits.has(scope.auditID), "Duplicate reported-period facts.");
    scopedAudits.add(scope.auditID);
    const period = state.periods.find((p) => p.id === scope.periodID),
      audit = period?.audits.find((a) => a.id === scope.auditID);
    need(
      audit &&
        [
          "linepay.web.configured-gross/2",
          "linepay.web.configured-gross/3",
        ].includes(audit.assessment.engine),
      "Reported-period facts have no compatible saved comparison.",
    );
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
    workFacts(period.work, period);
    const current = currentCalculation(state, period);
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
      workFacts(audit.work, period);
      const calculation = reproduceSavedCalculation(
        state,
        period,
        audit.work,
        audit.calculation,
      );
      totalWork += audit.work.length;
      need(
        JSON.stringify(calculation) === JSON.stringify(audit.calculation),
        "Saved audit calculation is unsupported or changed; nothing was replaced.",
      );
      need(
        JSON.stringify(
          reproduceAssessment(state, period, audit, calculation),
        ) === JSON.stringify(audit.assessment),
        "Saved assessment does not match its recorded facts.",
      );
    }
  }
  need(
    totalWork <= 10000 && totalAudits <= 1000,
    "Backup exceeds supported history limits.",
  );
  need(
    Array.isArray(state.benefitChecks) && state.benefitChecks.length <= 100,
    "Too many saved fund checks.",
  );
  const fundRules = new Map();
  let fundRevisions = 0,
    eligibilitySegments = 0;
  const periodShape = (value) => {
    keys(value, ["start", "endExclusive", "timeZone"]);
    validateContributionPeriod(value);
  };
  for (const check of state.benefitChecks) {
    keys(check, ["id", "fundID", "name", "currency", "period", "revisions"]);
    unique(check.id);
    identity(check.fundID);
    need(
      typeof check.name === "string" &&
        check.name.trim().length > 0 &&
        check.name.length <= 120 &&
        /^[A-Z]{3}$/.test(check.currency),
      "Confirm the fund name and currency.",
    );
    periodShape(check.period);
    need(
      Array.isArray(check.revisions) &&
        check.revisions.length > 0 &&
        check.revisions.length <= 100,
      "A fund check needs a retained revision.",
    );
    fundRevisions += check.revisions.length;
    for (const revision of check.revisions) {
      keys(revision, [
        "id",
        "createdAt",
        "sourceReference",
        "segments",
        "completeEligibilityConfirmed",
        "rounding",
        "statement",
        "result",
      ]);
      unique(revision.id);
      epoch(revision.createdAt);
      need(
        typeof revision.sourceReference === "string" &&
          revision.sourceReference.length <= 2000,
        "Source reference is too long.",
      );
      keys(revision.rounding, ["scale", "mode", "scope"]);
      need(
        Array.isArray(revision.segments) &&
          revision.segments.length > 0 &&
          revision.segments.length <= 1000,
        "Invalid eligibility segment list.",
      );
      eligibilitySegments += revision.segments.length;
      for (const segment of revision.segments) {
        keys(segment, [
          "id",
          "period",
          "rule",
          "quantity",
          "eligibilityConfirmed",
        ]);
        periodShape(segment.period);
        const r = segment.rule;
        keys(r, [
          "id",
          "fundID",
          "version",
          "basis",
          "rate",
          "currency",
          "effectivePeriod",
        ]);
        periodShape(r.effectivePeriod);
        need(
          r.fundID.toLowerCase() === check.fundID.toLowerCase() &&
            r.currency === check.currency,
          "A saved fund revision changed fund or currency.",
        );
        const definition = contributionRuleDefinition(r);
        const ruleIdentity = r.id.toLowerCase();
        need(
          !fundRules.has(ruleIdentity) ||
            fundRules.get(ruleIdentity) === definition,
          "One saved fund rule has conflicting immutable definitions.",
        );
        fundRules.set(ruleIdentity, definition);
      }
      if (revision.statement !== null) {
        keys(revision.statement, [
          "fundID",
          "currency",
          "period",
          "employerContribution",
          "quantity",
          "quantityBasis",
          "confirmed",
        ]);
        periodShape(revision.statement.period);
      }
      const result = calculateContributions({
        period: check.period,
        segments: revision.segments,
        completeEligibilityConfirmed: revision.completeEligibilityConfirmed,
        rounding: revision.rounding,
        statement: revision.statement,
      });
      need(
        JSON.stringify(result) === JSON.stringify(revision.result),
        "A saved fund result no longer matches its recorded facts. Nothing was replaced.",
      );
    }
  }
  need(
    fundRevisions <= 1000 && eligibilitySegments <= 10000,
    "Fund history exceeds supported limits.",
  );
  need(
    Array.isArray(state.templateOrigins) && state.templateOrigins.length <= 100,
    "Too many retained rule-draft origins.",
  );
  const importedProfiles = new Set(),
    templateDefinitions = new Map();
  for (const origin of state.templateOrigins) {
    keys(origin, [
      "profileID",
      "packet",
      "perDiemDecision",
      "recipientHourlyRate",
      "recipientPerDiemAmount",
      "applicabilityConfirmed",
      "valuesConfirmed",
    ]);
    need(
      !importedProfiles.has(origin.profileID),
      "Duplicate imported profile provenance.",
    );
    importedProfiles.add(origin.profileID);
    const profile = state.profiles.find((p) => p.id === origin.profileID);
    need(profile, "Imported rule provenance has no saved profile.");
    validateRuleTemplate(origin.packet);
    const definition = ruleTemplateIdentity(origin.packet),
      identity =
        origin.packet.templateID.toLowerCase() + "|" + origin.packet.revision;
    need(
      !templateDefinitions.has(identity) ||
        templateDefinitions.get(identity) === definition,
      "One rule-draft identity/revision has conflicting contents.",
    );
    templateDefinitions.set(identity, definition);
    const adopted = adoptRuleTemplate(origin.packet, {
      profileID: profile.id,
      hourlyRate: origin.recipientHourlyRate,
      perDiemDecision: origin.perDiemDecision,
      perDiemAmount: origin.recipientPerDiemAmount,
      applicabilityConfirmed: origin.applicabilityConfirmed,
      valuesConfirmed: origin.valuesConfirmed,
    });
    need(
      JSON.stringify(adopted) === JSON.stringify(profile),
      "Imported profile no longer matches its confirmed draft and recipient choices.",
    );
  }
  need(
    Array.isArray(state.resolutionEvents) &&
      state.resolutionEvents.length <= 10000,
    "Follow-up history exceeds its supported limit.",
  );
  for (const event of state.resolutionEvents) {
    validateResolutionEvent(event, state);
    unique(event.id);
  }
  need(
    encoder.encode(
      JSON.stringify({
        format: "com.streamentry.linepay.web.snapshot",
        version: 1,
        state,
      }),
    ).byteLength <= 8388608,
    "Financial state exceeds the restorable 8 MiB web snapshot limit.",
  );
  return state;
}
// Known prior schemas add only empty missing metadata; retain every existing record.
// Reading does not write back, change revision or reprice any saved wage calculation/check.
export function decodeState(state) {
  let candidate = state;
  if (
    candidate?.format === "com.streamentry.linepay.web.state" &&
    candidate.version === 1
  ) {
    keys(candidate, ["format", "version", "revision", "profiles", "periods"]);
    candidate = {
      ...structuredClone(candidate),
      version: 2,
      benefitChecks: [],
    };
  }
  if (
    candidate?.format === "com.streamentry.linepay.web.state" &&
    candidate.version === 2
  ) {
    keys(candidate, [
      "format",
      "version",
      "revision",
      "profiles",
      "periods",
      "benefitChecks",
    ]);
    candidate = {
      ...structuredClone(candidate),
      version: 3,
      templateOrigins: [],
    };
  }
  if (
    candidate?.format === "com.streamentry.linepay.web.state" &&
    candidate.version === 3
  ) {
    keys(candidate, [
      "format",
      "version",
      "revision",
      "profiles",
      "periods",
      "benefitChecks",
      "templateOrigins",
    ]);
    candidate = {
      ...structuredClone(candidate),
      version: 4,
      resolutionEvents: [],
    };
  }
  if (
    candidate?.format === "com.streamentry.linepay.web.state" &&
    candidate.version === 4
  ) {
    keys(candidate, [
      "format",
      "version",
      "revision",
      "profiles",
      "periods",
      "benefitChecks",
      "templateOrigins",
      "resolutionEvents",
    ]);
    candidate = {
      ...structuredClone(candidate),
      version: 5,
      ruleTimelines: [],
    };
  }
  if (
    candidate?.format === "com.streamentry.linepay.web.state" &&
    candidate.version === 5
  ) {
    keys(candidate, [
      "format",
      "version",
      "revision",
      "profiles",
      "periods",
      "benefitChecks",
      "templateOrigins",
      "resolutionEvents",
      "ruleTimelines",
    ]);
    candidate = {
      ...structuredClone(candidate),
      version: 6,
      paycycleSchedules: [],
      paycheckScopes: [],
    };
  }
  if (
    candidate?.format === "com.streamentry.linepay.web.state" &&
    candidate.version === 6
  ) {
    keys(candidate, [
      "format",
      "version",
      "revision",
      "profiles",
      "periods",
      "benefitChecks",
      "templateOrigins",
      "resolutionEvents",
      "ruleTimelines",
      "paycycleSchedules",
      "paycheckScopes",
    ]);
    candidate = {
      ...structuredClone(candidate),
      version: 7,
      weeklyReviews: [],
    };
  }
  return validateState(candidate);
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
  return decodeState(payload.state);
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
                done(decodeState(result));
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
