import { Decimal, dec, zero, seconds, unitsText } from "./decimal.mjs";
import { epoch, localDate, calculate } from "./payroll.mjs";
import { validateTimeline } from "./payroll-v2.mjs";
const need = (ok, message) => {
  if (!ok) throw Error(message);
};
const keys = (value, fields) =>
  need(
    value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      Object.keys(value).sort().join("|") === fields.slice().sort().join("|"),
    "Unsupported weekly fields.",
  );
const identity = (value, limit = 128) =>
  need(
    typeof value === "string" &&
      value.length <= limit &&
      /^[A-Za-z0-9-]+$/.test(value),
    "Invalid weekly identity.",
  );
const amount = (value) => {
  need(
    typeof value === "string" && /^\d{1,8}(\.\d{1,8})?$/.test(value),
    "Use an explicit unsigned decimal, up to eight fractional digits.",
  );
  const number = dec(value);
  need(
    number.compare(dec("10000000")) <= 0,
    "Weekly amount exceeds its representation limit.",
  );
  return number;
};
const money = (value, currency) => {
  keys(value, ["amount", "currency"]);
  need(value.currency === currency, "Weekly currencies do not match.");
  return amount(value.amount);
};
export const weeklyMappingReason =
  "A separate weekly reference does not map complete workweeks and additional premium into this paycheck. Review that mapping before relying on the gross difference.";

export function calculateWeekly(input) {
  return calculateWeeklyVersion(input, 3);
}

function calculateWeeklyVersion(input, version) {
  keys(input, [
    "startUTC",
    "timeZone",
    "currency",
    "boundaryConfirmed",
    "singleEmployerConfirmed",
    "paymentsConfirmed",
    "completeWorkweek",
    "applicability",
    "work",
    "remuneration",
    "rounding",
  ]);
  need(
    typeof input.boundaryConfirmed === "boolean" && input.boundaryConfirmed,
    "Confirm the employer's exact recurring workweek boundary.",
  );
  need(
    input.singleEmployerConfirmed === true,
    "Confirm that selected source periods belong to one employer and this workweek.",
  );
  need(
    input.paymentsConfirmed === true,
    "Confirm every remuneration amount and classification.",
  );
  need(
    typeof input.completeWorkweek === "boolean" && input.completeWorkweek,
    "Confirm the complete workweek, not one paycheck fragment.",
  );
  need(
    input.applicability === "coveredNonexemptHourly",
    "Weekly applicability is unknown or unsupported.",
  );
  need(
    typeof input.currency === "string" && /^[A-Z]{3}$/.test(input.currency),
    "Confirm the weekly currency.",
  );
  const start = epoch(input.startUTC),
    end = start + 604800;
  need(
    end < 4102444800 && typeof input.timeZone === "string",
    "Unsupported weekly boundary.",
  );
  new Intl.DateTimeFormat("en", { timeZone: input.timeZone });
  keys(input.rounding, ["scale", "mode", "scope"]);
  need(
    input.rounding.scope === "payCategory",
    "Review the weekly rounding scope.",
  );
  zero.units(input.rounding.scale, input.rounding.mode);
  need(
    Array.isArray(input.work) &&
      input.work.length <= 2000 &&
      Array.isArray(input.remuneration) &&
      input.remuneration.length <= 100,
    "Too many weekly facts.",
  );
  let qualifying = zero,
    recordedSeconds = zero,
    numerator = zero,
    cash = zero,
    credit = zero;
  const seen = new Set(),
    bases = new Map();
  for (const row of input.work) {
    keys(row, [
      "id",
      "payPeriodID",
      "hours",
      "workedSeconds",
      "straightRate",
      "qualifies",
    ]);
    identity(row.id, 512);
    need(
      !seen.has(row.id) && typeof row.qualifies === "boolean",
      "Duplicate or invalid weekly work.",
    );
    seen.add(row.id);
    if (row.payPeriodID !== null) identity(row.payPeriodID);
    const rate = money(row.straightRate, input.currency);
    let duration;
    if (row.workedSeconds !== null) {
      need(
        row.hours === null &&
          Number.isSafeInteger(row.workedSeconds) &&
          row.workedSeconds >= 0 &&
          row.workedSeconds <= 604800,
        "Confirm exact worked seconds.",
      );
      duration = seconds(row.workedSeconds);
    } else {
      duration = amount(row.hours).mul(seconds(3600));
    }
    if (version === 3) {
      recordedSeconds = recordedSeconds.add(duration);
      need(
        duration.compare(seconds(604800)) <= 0 &&
          recordedSeconds.compare(seconds(604800)) <= 0,
        "Actual work exceeds the reviewed 168-hour window, including nonqualifying work.",
      );
    }
    if (!row.qualifies) continue;
    qualifying = qualifying.add(duration);
    if (duration.compare(zero) <= 0) continue;
    const key = row.payPeriodID ?? "",
      existing = bases.get(key);
    bases.set(key, {
      payPeriodID: row.payPeriodID,
      basis: (existing?.basis ?? zero).add(rate.mul(duration)),
      id: existing && existing.id < row.id ? existing.id : row.id,
    });
  }
  const paymentIDs = new Set();
  for (const row of input.remuneration) {
    keys(row, ["id", "amount", "kind", "premiumCredit"]);
    identity(row.id);
    need(!paymentIDs.has(row.id), "Duplicate weekly payment identity.");
    paymentIDs.add(row.id);
    const value = money(row.amount, input.currency);
    need(
      [
        "straightTime",
        "includableBonus",
        "excludedCash",
        "extraPremium",
      ].includes(row.kind),
      "Classify every weekly payment.",
    );
    if (row.kind === "extraPremium")
      need(
        ["eligibleExtraPremium", "ineligible"].includes(row.premiumCredit),
        "Unknown premium treatment requires review.",
      );
    else
      need(
        row.premiumCredit === "notApplicable",
        "Invalid premium classification.",
      );
    cash = cash.add(value);
    if (
      row.kind === "straightTime" ||
      row.kind === "includableBonus" ||
      (row.kind === "extraPremium" && row.premiumCredit === "ineligible")
    )
      numerator = numerator.add(value);
    if (row.premiumCredit === "eligibleExtraPremium")
      credit = credit.add(value);
  }
  need(
    qualifying.compare(zero) > 0 || numerator.compare(zero) === 0,
    "Remuneration has no qualifying worked hours.",
  );
  const overtime =
    qualifying.sub(seconds(144000)).compare(zero) > 0
      ? qualifying.sub(seconds(144000))
      : zero;
  const statutory =
    qualifying.compare(zero) > 0
      ? numerator.mul(overtime).div(qualifying.mul(seconds(2)))
      : zero;
  const remaining =
    statutory.sub(credit).compare(zero) > 0 ? statutory.sub(credit) : zero;
  const { scale, mode } = input.rounding,
    target = remaining.units(scale, mode);
  let allocations = [];
  if (target > 0n) {
    const total = [...bases.values()].reduce(
      (sum, b) => sum.add(b.basis),
      zero,
    );
    need(
      total.compare(zero) > 0,
      "Additional premium has no confirmed allocation basis.",
    );
    const ordered = [...bases.entries()].sort(([a], [b]) =>
      a < b ? -1 : a > b ? 1 : 0,
    );
    const rows = ordered.map(([, b]) => ({
      ...b,
      units: new Decimal(target).mul(b.basis).div(total).units(0, "down"),
    }));
    let residual = target - rows.reduce((sum, b) => sum + b.units, 0n);
    for (const row of rows)
      // V2 receipts retain their original allocation, including the zero-basis defect.
      if (residual > 0n && (version === 2 || row.basis.compare(zero) > 0)) {
        row.units++;
        residual--;
      }
    need(
      residual === 0n,
      "Weekly allocation did not conserve the rounded total.",
    );
    allocations = rows.map((b) => ({
      id: b.id,
      payPeriodID: b.payPeriodID,
      amount: unitsText(b.units, scale),
      basisNumerator: b.basis.text(),
      basisDenominator: "3600",
    }));
  }
  const remainingText = remaining.fixed(scale, mode),
    cashText = cash.fixed(scale, mode);
  return {
    engine: `linepay.web.weekly-regular-rate/${version}`,
    currency: input.currency,
    startUTC: input.startUTC,
    endExclusiveUTC: new Date(end * 1000).toISOString().replace(".000Z", "Z"),
    timeZone: input.timeZone,
    qualifyingSeconds: qualifying.text(),
    qualifyingHoursDisplay: qualifying.div(seconds(3600)).fixed(8),
    overtimeSeconds: overtime.text(),
    overtimeHoursDisplay: overtime.div(seconds(3600)).fixed(8),
    includableRemuneration: numerator.text(),
    regularRate:
      qualifying.compare(zero) > 0
        ? numerator.mul(seconds(3600)).div(qualifying).fixed(scale, mode)
        : null,
    statutoryAdditionalPremium: statutory.fixed(scale, mode),
    eligibleExtraPremiumCredit: credit.fixed(scale, mode),
    remainingAdditionalPremium: remainingText,
    cashRemuneration: cashText,
    expectedCash: dec(cashText).add(dec(remainingText)).fixed(scale, mode),
    allocations,
  };
}

export function weeklySource(
  state,
  startUTC,
  timeZone,
  currency,
  selectedPeriodIDs,
) {
  const start = epoch(startUTC),
    end = start + 604800;
  need(
    Array.isArray(selectedPeriodIDs) &&
      new Set(selectedPeriodIDs).size === selectedPeriodIDs.length &&
      selectedPeriodIDs.every((id) => state.periods.some((p) => p.id === id)),
    "Review selected weekly source periods.",
  );
  const periods = state.periods
    .filter((p) => selectedPeriodIDs.includes(p.id))
    .map((p) => ({
      periodID: p.id,
      timeZone: p.zone,
      rule: structuredClone(p.rule),
      timeline: structuredClone(
        state.ruleTimelines.filter((t) => t.periodID === p.id).at(-1) ?? null,
      ),
      work: structuredClone(
        p.work.filter(
          (w) => epoch(w.startUTC) < end && epoch(w.endUTC) > start,
        ),
      ),
    }));
  const source = { startUTC, timeZone, currency, periods };
  workFromWeeklySource(source);
  return source;
}
export function workFromWeeklySource(source) {
  keys(source, ["startUTC", "timeZone", "currency", "periods"]);
  const start = epoch(source.startUTC),
    end = start + 604800;
  need(
    end < 4102444800 &&
      typeof source.timeZone === "string" &&
      Array.isArray(source.periods) &&
      source.periods.length <= 100,
    "Invalid weekly source scope.",
  );
  new Intl.DateTimeFormat("en", { timeZone: source.timeZone });
  const facts = [],
    occupied = [],
    seen = new Set(),
    periods = new Set();
  let sourceCount = 0;
  for (const p of source.periods) {
    keys(p, ["periodID", "timeZone", "rule", "timeline", "work"]);
    identity(p.periodID);
    need(
      !periods.has(p.periodID) &&
        p.timeZone === source.timeZone &&
        p.rule.currency === source.currency,
      "Relevant weekly periods use incompatible scope.",
    );
    periods.add(p.periodID);
    calculate([], p.rule);
    if (p.timeline !== null) {
      keys(p.timeline, ["id", "periodID", "createdAt", "confirmed", "changes"]);
      need(
        p.timeline.periodID === p.periodID && p.timeline.confirmed === true,
        "Weekly source plan has incompatible ownership.",
      );
      epoch(p.timeline.createdAt);
      identity(p.timeline.id);
      need(
        Array.isArray(p.timeline.changes) && p.timeline.changes.length <= 256,
        "Invalid weekly source plan.",
      );
      for (const change of p.timeline.changes) {
        keys(change, ["effectiveDate", "sourceProfileID", "agreement"]);
        identity(change.sourceProfileID);
      }
    }
    const changes =
      p.timeline === null ? [] : validateTimeline(p.rule, p.timeline);
    need(
      Array.isArray(p.work) && p.work.length <= 2000,
      "Invalid weekly source work.",
    );
    sourceCount += p.work.length;
    need(sourceCount <= 2000, "Weekly source work exceeds its limit.");
    for (const w of p.work) {
      keys(w, [
        "id",
        "startUTC",
        "endUTC",
        "timeZone",
        "kind",
        "unpaidBreaks",
        "calloutEventID",
      ]);
      identity(w.id);
      if (w.calloutEventID !== null) identity(w.calloutEventID);
      const a = epoch(w.startUTC),
        b = epoch(w.endUTC);
      need(
        !seen.has(w.id) &&
          w.timeZone === source.timeZone &&
          b > a &&
          b - a <= 259200 &&
          a < end &&
          b > start &&
          ["regular", "callout", "other"].includes(w.kind) &&
          (w.kind === "callout" || w.calloutEventID === null),
        "Invalid or duplicate weekly source work.",
      );
      seen.add(w.id);
      need(
        Array.isArray(w.unpaidBreaks) && w.unpaidBreaks.length <= 100,
        "Invalid weekly break collection.",
      );
      const pauses = w.unpaidBreaks
        .map((pause) => {
          keys(pause, ["id", "startUTC", "endUTC"]);
          identity(pause.id);
          return {
            id: pause.id,
            start: epoch(pause.startUTC),
            end: epoch(pause.endUTC),
          };
        })
        .sort((x, y) => x.start - y.start);
      need(
        new Set(pauses.map((x) => x.id)).size === pauses.length &&
          pauses.every(
            (x, i) =>
              x.end > x.start &&
              x.start >= a &&
              x.end <= b &&
              (!i || pauses[i - 1].end <= x.start),
          ),
        "Review the original weekly break spans.",
      );
      need(
        pauses.reduce((sum, pause) => sum + pause.end - pause.start, 0) < b - a,
        "Breaks consume the original shift.",
      );
      const first = Math.max(a, start),
        last = Math.min(b, end);
      occupied.push([first, last]);
      const cuts = new Set([first, last]);
      for (const pause of pauses)
        for (const point of [pause.start, pause.end])
          if (point > first && point < last) cuts.add(point);
      let at = first;
      while (
        localDate(at, source.timeZone) !== localDate(last - 1, source.timeZone)
      ) {
        const day = localDate(at, source.timeZone);
        let low = at + 1,
          high = Math.min(last, at + 172800);
        while (low < high) {
          const middle = Math.floor((low + high) / 2);
          if (localDate(middle, source.timeZone) === day) low = middle + 1;
          else high = middle;
        }
        need(low > at, "Invalid local date boundary.");
        cuts.add(low);
        at = low;
      }
      const ordered = [...cuts].sort((x, y) => x - y);
      for (let i = 1; i < ordered.length; i++) {
        const x = ordered[i - 1],
          y = ordered[i];
        if (pauses.some((p) => x >= p.start && y <= p.end)) continue;
        const date = localDate(x, source.timeZone),
          rule =
            changes.filter((c) => c.effectiveDate <= date).at(-1)?.agreement ??
            p.rule;
        facts.push({
          id: `${p.periodID}-${w.id}-${x}-${y}`,
          payPeriodID: p.periodID,
          hours: null,
          workedSeconds: y - x,
          straightRate: { amount: rule.hourlyRate, currency: rule.currency },
          qualifies: true,
        });
        need(facts.length <= 2000, "Too many weekly source slices.");
      }
    }
  }
  occupied.sort((a, b) => a[0] - b[0]);
  need(
    occupied.every((x, i) => !i || occupied[i - 1][1] <= x[0]),
    "Weekly source entries overlap.",
  );
  return facts;
}

export function validateWeeklyReview(record) {
  keys(record, ["id", "createdAt", "reference", "source", "input", "result"]);
  identity(record.id);
  epoch(record.createdAt);
  need(
    typeof record.reference === "string" && record.reference.length <= 2000,
    "Weekly source note exceeds its limit.",
  );
  need(
    record.result?.engine === "linepay.web.weekly-regular-rate/2" ||
      record.result?.engine === "linepay.web.weekly-regular-rate/3",
    "Unsupported weekly engine version.",
  );
  const work = workFromWeeklySource(record.source),
    result = calculateWeeklyVersion(
      record.input,
      record.result.engine === "linepay.web.weekly-regular-rate/2" ? 2 : 3,
    );
  need(
    record.input.startUTC === record.source.startUTC &&
      record.input.timeZone === record.source.timeZone &&
      record.input.currency === record.source.currency &&
      JSON.stringify(work) === JSON.stringify(record.input.work),
    "Weekly input does not match its frozen clock/rate sources.",
  );
  need(
    JSON.stringify(result) === JSON.stringify(record.result),
    "Saved weekly result does not reproduce from its facts.",
  );
  return record;
}
export function relatedWeeklyReviews(reviews, periodID) {
  return (reviews ?? []).filter((r) =>
    r.source.periods.some((p) => p.periodID === periodID),
  );
}
