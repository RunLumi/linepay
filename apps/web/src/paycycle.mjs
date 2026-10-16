import { localDate } from "./payroll.mjs";
const need = (condition, message) => {
  if (!condition) throw Error(message);
};
export function calendarDate(value) {
  need(
    typeof value === "string" && /^20\d\d-\d\d-\d\d$/.test(value),
    "Enter a calendar date from 2000 through 2099.",
  );
  const time = Date.parse(value + "T00:00:00Z");
  need(
    Number.isFinite(time) &&
      new Date(time).toISOString().slice(0, 10) === value,
    "Enter a valid complete calendar date.",
  );
  return value;
}
function addDays(value, days) {
  return new Date(Date.parse(value + "T00:00:00Z") + days * 86400000)
    .toISOString()
    .slice(0, 10);
}
function firstInstant(value, zone) {
  const nominal = Date.parse(value + "T00:00:00Z") / 1000;
  let low = nominal - 172800,
    high = nominal + 172800;
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (localDate(middle, zone) < value) low = middle + 1;
    else high = middle;
  }
  need(
    localDate(low, zone) === value,
    "This local calendar date does not exist in the payroll timezone.",
  );
  return low;
}
const utc = (seconds) =>
  new Date(seconds * 1000).toISOString().replace(".000Z", "Z");
export function paycycleWindow({
  cadence,
  startDate,
  manualEndDate,
  timeZone,
}) {
  calendarDate(startDate);
  need(typeof timeZone === "string", "Confirm the payroll timezone.");
  new Intl.DateTimeFormat("en", { timeZone });
  let endExclusive;
  if (cadence === "weekly" || cadence === "biweekly")
    endExclusive = addDays(startDate, cadence === "weekly" ? 7 : 14);
  else if (cadence === "semimonthly") {
    const [year, month, day] = startDate.split("-").map(Number);
    need(
      day === 1 || day === 16,
      "Twice-monthly cycles start on the 1st or 16th.",
    );
    endExclusive =
      day === 1
        ? `${startDate.slice(0, 7)}-16`
        : new Date(Date.UTC(year, month, 1)).toISOString().slice(0, 10);
  } else if (cadence === "manual") {
    calendarDate(manualEndDate);
    need(
      manualEndDate >= startDate,
      "The last date must not precede the first.",
    );
    endExclusive = addDays(manualEndDate, 1);
  } else throw Error("Select a supported paycycle.");
  const endDate = addDays(endExclusive, -1);
  calendarDate(endDate);
  need(
    Date.parse(endDate) - Date.parse(startDate) <= 31968000000,
    "Paycycle exceeds the supported calendar span.",
  );
  const start = firstInstant(startDate, timeZone),
    end = firstInstant(endExclusive, timeZone);
  need(end > start, "Invalid paycycle boundaries.");
  return {
    cadence,
    startDate,
    endDate,
    endExclusiveDate: endExclusive,
    timeZone,
    startUTC: utc(start),
    endExclusiveUTC: utc(end),
    elapsedSeconds: end - start,
  };
}
