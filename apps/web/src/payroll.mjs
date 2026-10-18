import { Decimal, dec, zero, one, seconds, unitsText } from "./decimal.mjs";
const hour = seconds(3600),
  max = (a, b) => (a.compare(b) >= 0 ? a : b);
const requireFact = (condition, message) => {
  if (!condition) throw Error(message);
};
const formatters = new Map();
export function localParts(epoch, zone) {
  let formatter = formatters.get(zone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: zone,
      calendar: "iso8601",
      numberingSystem: "latn",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    });
    formatters.set(zone, formatter);
  }
  return Object.fromEntries(
    formatter
      .formatToParts(new Date(epoch * 1000))
      .filter((x) => x.type !== "literal")
      .map((x) => [x.type, x.value]),
  );
}
export function localDate(epoch, zone) {
  const p = localParts(epoch, zone);
  return `${p.year}-${p.month}-${p.day}`;
}
export function epoch(text) {
  requireFact(
    typeof text === "string" &&
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$/.test(text),
    "A timestamp needs seconds and an explicit UTC offset.",
  );
  const wall = text.slice(0, 19);
  requireFact(
    new Date(wall + "Z").toISOString().slice(0, 19) === wall,
    "Invalid calendar date or clock time.",
  );
  const value = Date.parse(text) / 1000;
  requireFact(
    Number.isSafeInteger(value) && value >= 946684800 && value < 4102444800,
    "Use work dates from 2000 through 2099.",
  );
  return value;
}
export function localCandidates(text, zone) {
  requireFact(
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(text),
    "Enter a complete local date and time.",
  );
  const wall = epoch(text + ":00Z");
  const offsets = new Set();
  for (let delta = -172800; delta <= 172800; delta += 21600) {
    const at = wall + delta,
      p = localParts(at, zone);
    offsets.add(
      Date.parse(
        `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}:${p.second}Z`,
      ) /
        1000 -
        at,
    );
  }
  return [...offsets]
    .map((offset) => wall - offset)
    .filter((at) => {
      const p = localParts(at, zone);
      return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}` === text;
    })
    .sort((a, b) => a - b);
}
function midnightAfter(start, end, zone) {
  const day = localDate(start, zone);
  if (localDate(end - 1, zone) === day) return end;
  let low = start + 1,
    high = Math.min(end, start + 172800);
  while (low < high) {
    const mid = Math.floor((low + high) / 2);
    if (localDate(mid, zone) === day) low = mid + 1;
    else high = mid;
  }
  return low;
}
function validateRule(rule) {
  requireFact(
    rule &&
      typeof rule.id === "string" &&
      rule.id.length > 0 &&
      typeof rule.version === "string" &&
      rule.version.length > 0,
    "Rules need an immutable ID and version.",
  );
  requireFact(/^[A-Z]{3}$/.test(rule.currency), "Select an explicit currency.");
  requireFact(
    dec(rule.hourlyRate).compare(zero) >= 0,
    "Rate cannot be negative.",
  );
  requireFact(
    Array.isArray(rule.regularSchedule) &&
      rule.regularSchedule.length === 0 &&
      Array.isArray(rule.datePremiums) &&
      rule.datePremiums.length === 0,
    "Scheduled/date-specific rules need review in this web version.",
  );
  requireFact(
    rule.outsideScheduleMultiplier === "1",
    "Off-schedule premium mapping needs review in this web version.",
  );
  requireFact(
    rule.rounding.scope === "payCategory",
    "Legacy segment rounding needs review.",
  );
  zero.units(rule.rounding.scale, rule.rounding.mode);
  requireFact(
    Array.isArray(rule.dailyOvertimeTiers) &&
      rule.dailyOvertimeTiers.length <= 20 &&
      Array.isArray(rule.weekdayPremiums) &&
      rule.weekdayPremiums.length <= 7,
    "Invalid premium list.",
  );
  const tiers = rule.dailyOvertimeTiers
    .map((x) => ({
      after: dec(x.afterHours).mul(hour),
      multiplier: dec(x.multiplier),
    }))
    .sort((a, b) => a.after.compare(b.after));
  requireFact(
    tiers.every(
      (x, i) =>
        x.after.compare(zero) >= 0 &&
        x.after.d === 1n &&
        x.multiplier.compare(one) >= 0 &&
        (!i || x.after.compare(tiers[i - 1].after) > 0),
    ),
    "Daily premium boundaries must be distinct, nonnegative whole elapsed seconds.",
  );
  const weekdays = [
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
  ];
  requireFact(
    rule.weekdayPremiums.every(
      (x) =>
        weekdays.includes(x.weekday) && dec(x.multiplier).compare(one) >= 0,
    ),
    "Invalid weekday premium.",
  );
  if (rule.calloutMinimumHours !== null)
    requireFact(
      dec(rule.calloutMinimumHours).compare(zero) > 0,
      "Callout minimum must be positive.",
    );
  if (rule.perDiemPerWorkDate !== null)
    requireFact(
      dec(rule.perDiemPerWorkDate).compare(zero) >= 0,
      "Per diem cannot be negative.",
    );
  return tiers;
}
export function calculate(work, rule) {
  const tiers = validateRule(rule),
    rate = dec(rule.hourlyRate),
    currency = rule.currency;
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
        workDates.set(key, date);
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
          });
          position = position.add(duration);
          remaining = remaining.sub(duration);
        }
        cumulative.set(key, position);
      }
      cursor = end;
    }
  }
  const calls = new Map();
  for (const item of entries.filter((x) => x.kind === "callout")) {
    if (rule.calloutMinimumHours === null) continue;
    requireFact(
      typeof item.calloutEventID === "string" && item.calloutEventID.length > 0,
      "Confirm the physical callout identity before applying a minimum.",
    );
    const list = calls.get(item.calloutEventID) || [];
    list.push(item);
    calls.set(item.calloutEventID, list);
  }
  for (const group of calls.values()) {
    const first = group[0],
      last = group.at(-1),
      duration = seconds(group.reduce((n, x) => n + x.workedSeconds, 0));
    requireFact(
      group.every(
        (x, i) =>
          x.timeZone === first.timeZone && (!i || group[i - 1].end === x.start),
      ),
      "Separated callout segments need review.",
    );
    const minimum = dec(rule.calloutMinimumHours).mul(hour),
      missing = minimum.sub(duration);
    if (missing.compare(zero) <= 0) continue;
    const ids = new Set(group.map((x) => x.id)),
      priced = raw.filter((x) => ids.has(x.workID)),
      multiplier = priced[0].multiplier;
    requireFact(
      priced.every((x) => x.multiplier.compare(multiplier) === 0) &&
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
      numerator: rate.mul(missing).mul(multiplier),
    });
  }
  if (rule.perDiemPerWorkDate !== null)
    for (const date of workDates.values())
      raw.push({
        category: "perDiem",
        workID: null,
        date,
        seconds: null,
        multiplier: null,
        numerator: dec(rule.perDiemPerWorkDate).mul(hour),
      });
  const groups = new Map(),
    scale = rule.rounding.scale,
    mode = rule.rounding.mode;
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
    id: `${rule.id}:${rule.version}:${i}`,
    category: part.category,
    workID: part.workID,
    date: part.date,
    workedSeconds: part.seconds?.fixed(8) || null,
    multiplier: part.multiplier?.text() || null,
    amount: unitsText(allocated.get(i), scale),
    currency,
    reference: { id: rule.id, version: rule.version },
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
    engine: "linepay.web.configured-pay/1",
    coverage: "configuredRulesOnly",
    currency,
    components,
    wages: wages.fixed(scale, mode),
    allowances: allowances.fixed(scale, mode),
    total: wages.add(allowances).fixed(scale, mode),
  };
}
