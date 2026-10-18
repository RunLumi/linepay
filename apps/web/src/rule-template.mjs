import { dec, zero, one } from "./decimal.mjs";
import { calculate } from "./payroll.mjs";
const need = (condition, message) => {
  if (!condition) throw Error(message);
};
const keys = (value, expected) => {
  need(
    value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      Object.keys(value).sort().join("|") === expected.slice().sort().join("|"),
    "Unsupported rule-draft fields. Nothing was applied.",
  );
};
const encoder = new TextEncoder(),
  weekdays = [
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
  ];
const id = (value) =>
  need(
    typeof value === "string" &&
      /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value),
    "Invalid rule-draft identity.",
  );
function number(value, max = "10000000", minimum = zero) {
  need(
    typeof value === "string" && /^(0|[1-9]\d{0,7})(\.\d{1,8})?$/.test(value),
    "Rule-draft numbers must be unsigned decimal strings with up to eight fraction digits.",
  );
  const parsed = dec(value);
  need(
    parsed.compare(minimum) >= 0 && parsed.compare(dec(max)) <= 0,
    "A rule-draft number is outside its supported range.",
  );
  return parsed;
}
export function validateRuleTemplate(packet) {
  keys(packet, [
    "format",
    "version",
    "templateID",
    "revision",
    "title",
    "scope",
    "premiumCombination",
    "rules",
  ]);
  need(
    packet.format === "com.streamentry.linepay.rule-template" &&
      packet.version === 1 &&
      packet.scope === "workerConfirmedConfiguredRulesOnly" &&
      packet.premiumCombination === "highestApplicable",
    "This is not a supported worker-provided rule draft.",
  );
  id(packet.templateID);
  need(
    typeof packet.revision === "string" &&
      /^[A-Za-z0-9.-]{1,32}$/.test(packet.revision),
    "Enter a rule-draft revision up to 32 ASCII characters.",
  );
  need(
    typeof packet.title === "string" &&
      packet.title.trim().length > 0 &&
      encoder.encode(packet.title).length <= 240 &&
      !/[\u0000-\u001f\u007f]/.test(packet.title),
    "Enter a title up to 240 UTF-8 bytes without control characters.",
  );
  const r = packet.rules;
  keys(r, [
    "currency",
    "hourlyRate",
    "dailyOvertimeTiers",
    "weekdayPremiums",
    "calloutMinimumHours",
    "perDiem",
    "rounding",
  ]);
  need(
    typeof r.currency === "string" && /^[A-Z]{3}$/.test(r.currency),
    "Confirm an explicit three-letter currency.",
  );
  if (r.hourlyRate !== null) number(r.hourlyRate);
  need(
    Array.isArray(r.dailyOvertimeTiers) &&
      r.dailyOvertimeTiers.length <= 20 &&
      Array.isArray(r.weekdayPremiums) &&
      r.weekdayPremiums.length <= 7,
    "Too many rule-draft premiums.",
  );
  let previous = null;
  for (const t of r.dailyOvertimeTiers) {
    keys(t, ["afterHours", "multiplier"]);
    const after = number(t.afterHours, "168");
    number(t.multiplier, "10", one);
    need(
      after.mul(dec("3600")).d === 1n &&
        (!previous || after.compare(previous) > 0),
      "Daily thresholds must be distinct, increasing whole elapsed seconds.",
    );
    previous = after;
  }
  let previousDay = -1;
  for (const p of r.weekdayPremiums) {
    keys(p, ["weekday", "multiplier"]);
    const day = weekdays.indexOf(p.weekday);
    need(
      day > previousDay,
      "Weekday premiums must be unique and in Sunday-to-Saturday order.",
    );
    number(p.multiplier, "10", one);
    previousDay = day;
  }
  if (r.calloutMinimumHours !== null)
    need(
      number(r.calloutMinimumHours, "168").compare(zero) > 0,
      "Callout minimum must be positive.",
    );
  keys(r.perDiem, ["configured", "amount"]);
  need(
    typeof r.perDiem.configured === "boolean" &&
      (r.perDiem.configured || r.perDiem.amount === null),
    "Unconfigured per diem cannot carry an amount.",
  );
  if (r.perDiem.amount !== null) number(r.perDiem.amount);
  keys(r.rounding, ["scale", "mode", "scope"]);
  need(
    r.rounding.scope === "payCategory",
    "Legacy rounding is not a portable rule draft.",
  );
  zero.fixed(r.rounding.scale, r.rounding.mode);
  need(
    encoder.encode(JSON.stringify(packet)).length <= 65536,
    "Rule draft exceeds 64 KiB.",
  );
  return packet;
}
export function createRuleTemplate(
  profile,
  { templateID, revision, title, includeAmounts = false },
) {
  need(
    typeof includeAmounts === "boolean",
    "Confirm whether amounts may be included.",
  );
  need(
    Array.isArray(profile.regularSchedule) &&
      profile.regularSchedule.length === 0 &&
      Array.isArray(profile.datePremiums) &&
      profile.datePremiums.length === 0 &&
      profile.outsideScheduleMultiplier === "1" &&
      !profile.weeklyOvertime &&
      !profile.effectiveStart &&
      !profile.effectiveEnd &&
      !profile.unsupportedRuleNotes,
    "This profile has rules or applicability this draft format cannot preserve. No draft was created.",
  );
  calculate([], profile);
  const packet = {
    format: "com.streamentry.linepay.rule-template",
    version: 1,
    templateID,
    revision,
    title,
    scope: "workerConfirmedConfiguredRulesOnly",
    premiumCombination: "highestApplicable",
    rules: {
      currency: profile.currency,
      hourlyRate: includeAmounts ? dec(profile.hourlyRate).text() : null,
      dailyOvertimeTiers: profile.dailyOvertimeTiers.map((t) => ({
        afterHours: dec(t.afterHours).text(),
        multiplier: dec(t.multiplier).text(),
      })),
      weekdayPremiums: profile.weekdayPremiums
        .map((p) => ({
          weekday: p.weekday,
          multiplier: dec(p.multiplier).text(),
        }))
        .sort(
          (a, b) => weekdays.indexOf(a.weekday) - weekdays.indexOf(b.weekday),
        ),
      calloutMinimumHours:
        profile.calloutMinimumHours === null
          ? null
          : dec(profile.calloutMinimumHours).text(),
      perDiem: {
        configured: profile.perDiemPerWorkDate !== null,
        amount:
          includeAmounts && profile.perDiemPerWorkDate !== null
            ? dec(profile.perDiemPerWorkDate).text()
            : null,
      },
      rounding: structuredClone(profile.rounding),
    },
  };
  return validateRuleTemplate(packet);
}
function rejectDuplicateFields(text) {
  const stack = [];
  for (let i = 0; i < text.length; i++) {
    if (text[i] === "{") {
      stack.push(new Set());
      continue;
    }
    if (text[i] === "[") {
      stack.push(null);
      continue;
    }
    if (text[i] === "}" || text[i] === "]") {
      stack.pop();
      continue;
    }
    if (text[i] !== String.fromCharCode(34)) continue;
    const start = i;
    let end = i + 1;
    while (end < text.length) {
      if (text[end] === "\\") {
        end += 2;
        continue;
      }
      if (text[end] === String.fromCharCode(34)) break;
      end++;
    }
    i = end;
    let next = end + 1;
    while (/[ \t\r\n]/.test(text[next] ?? "!") && next < text.length) next++;
    if (text[next] === ":") {
      const key = JSON.parse(text.slice(start, end + 1)),
        fields = stack.at(-1);
      need(
        fields && !fields.has(key),
        "Duplicate rule-draft fields. Nothing was applied.",
      );
      fields.add(key);
    }
  }
}
export function decodeRuleTemplate(bytes) {
  need(
    bytes instanceof Uint8Array && bytes.length > 0 && bytes.length <= 65536,
    "Select a rule draft up to 64 KiB.",
  );
  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    packet = JSON.parse(text);
  rejectDuplicateFields(text);
  return validateRuleTemplate(packet);
}
export function encodeRuleTemplate(packet) {
  validateRuleTemplate(packet);
  const bytes = encoder.encode(JSON.stringify(packet, null, 2) + "\n");
  need(bytes.length <= 65536, "Rule draft exceeds 64 KiB.");
  return bytes;
}
export function adoptRuleTemplate(
  packet,
  {
    profileID,
    hourlyRate,
    perDiemDecision,
    perDiemAmount = null,
    applicabilityConfirmed,
    valuesConfirmed,
  },
) {
  validateRuleTemplate(packet);
  id(profileID);
  need(
    applicabilityConfirmed === true && valuesConfirmed === true,
    "Confirm the listed rules, applicability and your own values before saving.",
  );
  number(hourlyRate);
  const r = packet.rules;
  let allowance = null;
  if (r.perDiem.configured) {
    need(
      ["confirmedAmount", "notApplicable"].includes(perDiemDecision),
      "Review whether the configured allowance applies to your new profile.",
    );
    if (perDiemDecision === "confirmedAmount") {
      number(perDiemAmount);
      allowance = perDiemAmount;
    } else
      need(
        perDiemAmount === null,
        "A nonapplicable allowance cannot carry a paid amount.",
      );
  } else
    need(
      perDiemDecision === "notConfigured" && perDiemAmount === null,
      "This draft does not configure an allowance; it is not a waiver.",
    );
  const profile = {
    id: profileID,
    version: "1",
    currency: r.currency,
    hourlyRate,
    outsideScheduleMultiplier: "1",
    regularSchedule: [],
    dailyOvertimeTiers: structuredClone(r.dailyOvertimeTiers),
    weekdayPremiums: structuredClone(r.weekdayPremiums),
    datePremiums: [],
    calloutMinimumHours: r.calloutMinimumHours,
    perDiemPerWorkDate: allowance,
    rounding: structuredClone(r.rounding),
  };
  calculate([], profile);
  return profile;
}
export function ruleTemplateIdentity(packet) {
  validateRuleTemplate(packet);
  const canonical = (value) =>
    Array.isArray(value)
      ? value.map(canonical)
      : value && typeof value === "object"
        ? Object.fromEntries(
            Object.keys(value)
              .sort()
              .map((k) => [k, canonical(value[k])]),
          )
        : value;
  return JSON.stringify(
    canonical({ ...packet, templateID: packet.templateID.toLowerCase() }),
  );
}
