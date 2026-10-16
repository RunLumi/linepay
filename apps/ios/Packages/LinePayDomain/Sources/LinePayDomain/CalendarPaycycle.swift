import Foundation

public enum CalendarPaycycleCadence: String, Codable, Hashable, Sendable {
    case weekly, biweekly, semimonthly, manual
}
public struct CalendarPaycycleWindow: Hashable, Sendable {
    public let start: LocalDate
    public let lastDate: LocalDate
    public let endExclusive: LocalDate
    public let startEpochSeconds: Int64
    public let endEpochSeconds: Int64
    public let timeZoneIdentifier: String
}
public enum CalendarPaycycleError: Error, Equatable, Sendable {
    case invalidDate, invalidTimeZone, unsupportedCutoff
}
/// Explicit local calendar dates, never a statutory workweek, clock, locale or fixed-hour period.
public enum CalendarPaycycle {
    public static func window(
        cadence: CalendarPaycycleCadence, start: LocalDate, manualEnd: LocalDate?,
        timeZoneIdentifier: String
    ) throws -> CalendarPaycycleWindow {
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else {
            throw CalendarPaycycleError.invalidTimeZone
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var dates = Calendar(identifier: .gregorian)
        dates.timeZone = TimeZone(secondsFromGMT: 0)!
        func local(_ date: Date, in context: Calendar) -> LocalDate {
            LocalDate(
                year: context.component(.year, from: date),
                month: context.component(.month, from: date),
                day: context.component(.day, from: date))
        }
        func instant(_ value: LocalDate, in context: Calendar) throws -> Date {
            guard (1...9999).contains(value.year),
                let date = context.date(
                    from: DateComponents(year: value.year, month: value.month, day: value.day)),
                local(date, in: context) == value
            else { throw CalendarPaycycleError.invalidDate }
            return context.startOfDay(for: date)
        }
        let first = try instant(start, in: calendar)
        // Advance date labels before resolving the zone: some zones skip a whole civil date.
        let firstDate = try instant(start, in: dates)
        let candidate: Date?
        switch cadence {
        case .weekly: candidate = dates.date(byAdding: .day, value: 7, to: firstDate)
        case .biweekly: candidate = dates.date(byAdding: .day, value: 14, to: firstDate)
        case .semimonthly:
            guard start.day == 1 || start.day == 16 else {
                throw CalendarPaycycleError.unsupportedCutoff
            }
            candidate =
                start.day == 1
                ? dates.date(byAdding: .day, value: 15, to: firstDate)
                : dates.dateInterval(of: .month, for: firstDate)?.end
        case .manual:
            guard let manualEnd, manualEnd >= start else { throw CalendarPaycycleError.invalidDate }
            _ = try instant(manualEnd, in: calendar)
            candidate = try dates.date(byAdding: .day, value: 1, to: instant(manualEnd, in: dates))
        }
        guard let candidate else { throw CalendarPaycycleError.invalidDate }
        let endingDate = local(candidate, in: dates)
        let end = try instant(endingDate, in: calendar)
        guard end > first,
            let previous = dates.date(byAdding: .day, value: -1, to: candidate)
        else { throw CalendarPaycycleError.invalidDate }
        return CalendarPaycycleWindow(
            start: start, lastDate: local(previous, in: dates), endExclusive: endingDate,
            startEpochSeconds: Int64(first.timeIntervalSince1970),
            endEpochSeconds: Int64(end.timeIntervalSince1970),
            timeZoneIdentifier: timeZoneIdentifier)
    }
}
