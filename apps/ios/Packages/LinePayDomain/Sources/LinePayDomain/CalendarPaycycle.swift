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
        func local(_ date: Date) -> LocalDate {
            LocalDate(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date),
                day: calendar.component(.day, from: date))
        }
        func instant(_ value: LocalDate) throws -> Date {
            guard (1...9999).contains(value.year),
                let date = calendar.date(
                    from: DateComponents(year: value.year, month: value.month, day: value.day)),
                local(date) == value
            else { throw CalendarPaycycleError.invalidDate }
            return calendar.startOfDay(for: date)
        }
        let first = try instant(start)
        let candidate: Date?
        switch cadence {
        case .weekly: candidate = calendar.date(byAdding: .day, value: 7, to: first)
        case .biweekly: candidate = calendar.date(byAdding: .day, value: 14, to: first)
        case .semimonthly:
            guard start.day == 1 || start.day == 16 else {
                throw CalendarPaycycleError.unsupportedCutoff
            }
            candidate =
                start.day == 1
                ? calendar.date(byAdding: .day, value: 15, to: first)
                : calendar.dateInterval(of: .month, for: first)?.end
        case .manual:
            guard let manualEnd, manualEnd >= start else { throw CalendarPaycycleError.invalidDate }
            candidate = try calendar.date(byAdding: .day, value: 1, to: instant(manualEnd))
        }
        guard let candidate else { throw CalendarPaycycleError.invalidDate }
        // Calendar addition can retain 01:00 when the starting midnight was skipped.
        // A paycycle ends at the first instant of its ending date, not that retained hour.
        let end = calendar.startOfDay(for: candidate)
        guard end > first, (1...9999).contains(local(end).year),
            let previous = calendar.date(byAdding: .day, value: -1, to: end)
        else { throw CalendarPaycycleError.invalidDate }
        return CalendarPaycycleWindow(
            start: start, lastDate: local(previous), endExclusive: local(end),
            startEpochSeconds: Int64(first.timeIntervalSince1970),
            endEpochSeconds: Int64(end.timeIntervalSince1970),
            timeZoneIdentifier: timeZoneIdentifier)
    }
}
