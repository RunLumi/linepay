import Foundation
import LinePayDomain

/// Native adapter for explicit calendar boundaries in the confirmed payroll zone.
/// Stored windows remain unchanged; the helper is used only to create a new window.
enum PayPeriodSchedule {
    static func window(
        cadence: PayPeriodCadence, startDate: Date, manualEndDate: Date,
        timeZoneIdentifier: String
    ) throws -> PayPeriodWindow {
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else {
            throw AppModelError.invalidField("Time zone")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        func local(_ date: Date) -> LocalDate {
            LocalDate(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date),
                day: calendar.component(.day, from: date))
        }
        guard let kind = CalendarPaycycleCadence(rawValue: cadence.rawValue) else {
            throw AppModelError.invalidPayPeriod
        }
        do {
            let result = try CalendarPaycycle.window(
                cadence: kind, start: local(startDate), manualEnd: local(manualEndDate),
                timeZoneIdentifier: timeZoneIdentifier)
            return PayPeriodWindow(
                startEpochSeconds: result.startEpochSeconds,
                endEpochSeconds: result.endEpochSeconds, cadence: cadence)
        } catch { throw AppModelError.invalidPayPeriod }
    }
}
