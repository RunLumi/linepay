import { Decimal, dec, zero, one, seconds, unitsText } from "./decimal.mjs";
import { calculate as calculateLegacy, localDate, epoch } from "./payroll.mjs";
const hour = seconds(3600),
  max = (a, b) => (a.compare(b) >= 0 ? a : b);
const requireFact = (condition, message) => {
  if (!condition) throw Error(message);
};
export function validateTimeline(baseline, timeline) {
  calculateLegacy([], baseline);
  requireFact(
    timeline &&
      typeof timeline.id === "string" &&
      timeline.id.length > 0 &&
      timeline.id.length <= 128 &&
      Array.isArray(timeline.changes) &&
      timeline.changes.length <= 256,
    "Invalid rule timeline.",
  );
  const ordered = timeline.changes
      .slice()
      .sort((a, b) =>
        a.effectiveDate < b.effectiveDate
          ? -1
          : a.effectiveDate > b.effectiveDate
            ? 1
            : 0,
      ),
    dates = new Set(),
    versions = new Set([baseline.version]);
  for (const c of ordered) {
    requireFact(
      typeof c.effectiveDate === "string" &&
        /^20\d\d-\d\d-\d\d$/.test(c.effectiveDate) &&
        new Date(c.effectiveDate + "T00:00:00Z").toISOString().slice(0, 10) ===
          c.effectiveDate &&
        !dates.has(c.effectiveDate),
      "Effective dates must be valid and unique.",
    );
    dates.add(c.effectiveDate);
    calculateLegacy([], c.agreement);
    requireFact(
      c.agreement.id === baseline.id &&
        c.agreement.currency === baseline.currency &&
        !versions.has(c.agreement.version) &&
        c.agreement.rounding.scale === baseline.rounding.scale &&
        c.agreement.rounding.mode === baseline.rounding.mode,
      "Rule versions, currency and rounding policy must be compatible with the baseline.",
    );
    versions.add(c.agreement.version);
  }
  return ordered;
}
function midnightAfter(start, end, zone) {
  const day = localDate(start, zone);
  if (localDate(end - 1, zone) === day) return end;
  let low = start + 1,
    high = Math.min(end, start + 172800);
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (localDate(middle, zone) === day) low = middle + 1;
    else high = middle;
  }
  return low;
}
export function calculateTimeline(work, baseline, timeline) {
  const ordered = validateTimeline(baseline, timeline),
    ruleFor = (date) =>
      ordered.filter((c) => c.effectiveDate <= date).at(-1)?.agreement ??
      baseline,
    currency = baseline.currency;
  requireFact(
    Array.isArray(work) && work.length <= 2000,
    "Too many work entries.",
  );
  const entries = work
    .map((item) => ({
      ...item,
      start: epoch(item.startUTC),
      end: epoch(item.endUTC),
    }))
    .sort((a, b) => a.start - b.start);
  requireFact(
    new Set(entries.map((x) => x.id)).size === entries.length,
    "Duplicate work identity.",
  );
  const cumulative = new Map(),
    raw = [],
    workDates = new Map();
  for (const [i, item] of entries.entries()) {
    requireFact(
      typeof item.id === "string" &&
        item.id.length > 0 &&
        ["regular", "callout", "other"].includes(item.kind),
      "Invalid work identity or kind.",
    );
    requireFact(
      item.kind === "callout" || item.calloutEventID === null,
      "A regular entry cannot carry a callout event identity.",
    );
    requireFact(
      item.end > item.start &&
        item.end - item.start <= 259200 &&
        (!i || entries[i - 1].end <= item.start),
      "Work must not overlap and each entry must be at most 72 elapsed hours.",
    );
    requireFact(
      Array.isArray(item.unpaidBreaks) && item.unpaidBreaks.length <= 100,
      "Invalid unpaid breaks.",
    );
    const breaks = item.unpaidBreaks
      .map((b) => ({ ...b, start: epoch(b.startUTC), end: epoch(b.endUTC) }))
      .sort((a, b) => a.start - b.start);
    requireFact(
      new Set(breaks.map((b) => b.id)).size === breaks.length &&
        breaks.every(
          (b, j) =>
            b.start >= item.start &&
            b.end <= item.end &&
            b.end > b.start &&
            (!j || breaks[j - 1].end <= b.start),
        ),
      "Unpaid breaks must be distinct, nonoverlapping and inside the entry.",
    );
    requireFact(
      breaks.reduce((n, b) => n + b.end - b.start, 0) < item.end - item.start,
      "Work needs positive actual time.",
    );
    item.workedSeconds =
      item.end - item.start - breaks.reduce((n, b) => n + b.end - b.start, 0);
    let cursor = item.start;
    while (cursor < item.end) {
      const rule = ruleFor(localDate(cursor, item.timeZone)),
        rate = dec(rule.hourlyRate),
        tiers = rule.dailyOvertimeTiers
          .map((t) => ({
            after: dec(t.afterHours).mul(hour),
            multiplier: dec(t.multiplier),
          }))
          .sort((a, b) => a.after.compare(b.after));
      const date = localDate(cursor, item.timeZone),
        end = midnightAfter(cursor, item.end, item.timeZone),
        key = date + "|" + item.timeZone;
      const bounds = [
        ...new Set([
          cursor,
          end,
          ...breaks
            .flatMap((b) => [b.start, b.end])
            .filter((b) => b > cursor && b < end),
        ]),
      ].sort((a, b) => a - b);
      const weekday = [
        "sunday",
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
      ][new Date(date + "T12:00:00Z").getUTCDay()];
      const premium = rule.weekdayPremiums
        .filter((p) => p.weekday === weekday)
        .reduce((n, p) => max(n, dec(p.multiplier)), one);
      for (let b = 0; b < bounds.length - 1; b++) {
        if (breaks.some((p) => bounds[b] >= p.start && bounds[b] < p.end))
          continue;
        workDates.set(key, { date, rule });
        let position = cumulative.get(key) || zero,
          remaining = seconds(bounds[b + 1] - bounds[b]);
        while (remaining.compare(zero) > 0) {
          const applied = tiers
              .filter((t) => t.after.compare(position) <= 0)
              .at(-1),
            next = tiers.find((t) => t.after.compare(position) > 0);
          const duration =
            next && next.after.sub(position).compare(remaining) < 0
              ? next.after.sub(position)
              : remaining;
          const multiplier = max(applied?.multiplier || one, premium);
          raw.push({
            category: "workedHours",
            workID: item.id,
            date,
            seconds: duration,
            multiplier,
            numerator: rate.mul(duration).mul(multiplier),
            rule,
          });
          position = position.add(duration);
          remaining = remaining.sub(duration);
        }
        cumulative.set(key, position);
      }
      cursor = end;
    }
  }
  const rulesInRange = (start, end, zone) => {
    const first = localDate(start, zone),
      last = localDate(end - 1, zone);
    return [
      ruleFor(first),
      ...ordered
        .filter((c) => c.effectiveDate > first && c.effectiveDate <= last)
        .map((c) => c.agreement),
    ];
  };
  const calls = new Map();
  for (const item of entries.filter((x) => x.kind === "callout")) {
    if (!item.calloutEventID) {
      requireFact(
        !rulesInRange(item.start, item.end, item.timeZone).some(
          (r) => r.calloutMinimumHours !== null,
        ),
        "Confirm the physical callout identity before applying a minimum.",
      );
      continue;
    }
    requireFact(
      typeof item.calloutEventID === "string",
      "Invalid callout identity.",
    );
    const list = calls.get(item.calloutEventID) || [];
    list.push(item);
    calls.set(item.calloutEventID, list);
  }
  for (const group of calls.values()) {
    const first = group[0],
      last = group.at(-1),
      duration = seconds(group.reduce((n, x) => n + x.workedSeconds, 0)),
      affected = rulesInRange(first.start, last.end, first.timeZone),
      rule = affected[0];
    requireFact(
      group.every(
        (x, i) =>
          x.timeZone === first.timeZone && (!i || group[i - 1].end === x.start),
      ),
      "Separated callout segments need review.",
    );
    requireFact(
      affected.length === 1 ||
        !affected.some(
          (r) =>
            r.calloutMinimumHours !== null &&
            dec(r.calloutMinimumHours).mul(hour).compare(duration) > 0,
        ),
      "A binding callout minimum crosses an effective rule change. Review is required.",
    );
    if (rule.calloutMinimumHours === null) continue;
    const minimum = dec(rule.calloutMinimumHours).mul(hour),
      missing = minimum.sub(duration);
    if (missing.compare(zero) <= 0) continue;
    const ids = new Set(group.map((x) => x.id)),
      priced = raw.filter((x) => ids.has(x.workID)),
      multiplier = priced[0].multiplier;
    requireFact(
      priced.every(
        (x) =>
          x.multiplier.compare(multiplier) === 0 &&
          dec(x.rule.hourlyRate).compare(dec(rule.hourlyRate)) === 0,
      ) &&
        !entries.some(
          (x) =>
            !ids.has(x.id) &&
            x.kind === "regular" &&
            x.start >= last.end &&
            seconds(x.start - first.start).compare(minimum) < 0,
        ),
      "This callout minimum interacts with another rule or regular shift; review is required.",
    );
    raw.push({
      category: "calloutGuarantee",
      workID: first.id,
      date: localDate(first.start, first.timeZone),
      seconds: missing,
      multiplier,
      numerator: dec(rule.hourlyRate).mul(missing).mul(multiplier),
      rule,
    });
  }
  for (const { date, rule } of workDates.values())
    if (rule.perDiemPerWorkDate !== null)
      raw.push({
        category: "perDiem",
        workID: null,
        date,
        seconds: null,
        multiplier: null,
        numerator: dec(rule.perDiemPerWorkDate).mul(hour),
        rule,
      });
  const groups = new Map(),
    scale = baseline.rounding.scale,
    mode = baseline.rounding.mode;
  raw.forEach((part, index) => {
    const key =
      part.category +
      "|" +
      (part.multiplier ? part.multiplier.n + "/" + part.multiplier.d : "");
    const list = groups.get(key) || [];
    list.push(index);
    groups.set(key, list);
  });
  const allocated = new Map();
  for (const indices of groups.values()) {
    const target = indices
      .reduce((n, i) => n.add(raw[i].numerator), zero)
      .div(hour)
      .units(scale, mode);
    let floors = 0n;
    const ranked = indices
      .map((i) => {
        const actual = raw[i].numerator.div(hour),
          floor = actual.units(scale, "down");
        allocated.set(i, floor);
        floors += floor;
        return {
          i,
          remainder: actual.sub(new Decimal(floor, 10n ** BigInt(scale))),
        };
      })
      .sort((a, b) => b.remainder.compare(a.remainder) || a.i - b.i);
    let residual = target - floors;
    for (const row of ranked)
      if (residual > 0n) {
        allocated.set(row.i, allocated.get(row.i) + 1n);
        residual--;
      }
    requireFact(residual === 0n, "Rounding allocation failed.");
  }
  const components = raw.map((part, i) => ({
    id: `${part.rule.id}:${part.rule.version}:${i}`,
    category: part.category,
    workID: part.workID,
    date: part.date,
    workedSeconds: part.seconds?.text() || null,
    baseRate: part.category === "perDiem" ? null : part.rule.hourlyRate,
    multiplier: part.multiplier?.text() || null,
    amount: unitsText(allocated.get(i), scale),
    currency,
    reference: { id: part.rule.id, version: part.rule.version },
    explanation:
      part.category === "perDiem"
        ? "Separate configured per diem"
        : part.category === "calloutGuarantee"
          ? "Confirmed isolated minimum; actual work unchanged"
          : "Actual work at highest configured daily/weekday multiplier",
  }));
  const wages = components
      .filter((x) => x.category !== "perDiem")
      .reduce((n, x) => n.add(dec(x.amount)), zero),
    allowances = components
      .filter((x) => x.category === "perDiem")
      .reduce((n, x) => n.add(dec(x.amount)), zero);
  return {
    engine: "linepay.web.configured-pay/2",
    ruleTimelineID: timeline.id,
    ruleSnapshots: structuredClone([
      baseline,
      ...ordered.map((c) => c.agreement),
    ]),
    coverage: "configuredRulesOnly",
    currency,
    components,
    wages: wages.fixed(scale, mode),
    allowances: allowances.fixed(scale, mode),
    total: wages.add(allowances).fixed(scale, mode),
  };
}
