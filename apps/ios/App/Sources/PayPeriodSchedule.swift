import Foundation

/// Calendar boundaries in the confirmed payroll zone, independent of the device's current zone.
/// Semi-monthly means the explicit 1–15 / 16–month-end schedule, never a fixed 15-day duration.
enum PayPeriodSchedule {
    static func window(
        cadence: PayPeriodCadence,
        startDate: Date,
        manualEndDate: Date,
        timeZoneIdentifier: String
    ) throws -> PayPeriodWindow {
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else {
            throw AppModelError.invalidField("Time zone")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: startDate)
        let end: Date?
        switch cadence {
        case .weekly, .biweekly:
            end = calendar.date(byAdding: .day, value: cadence == .weekly ? 7 : 14, to: start)
        case .semimonthly:
            let day = calendar.component(.day, from: start)
            guard day == 1 || day == 16 else { throw AppModelError.invalidPayPeriod }
            if day == 1 {
                end = calendar.date(byAdding: .day, value: 15, to: start)
            } else {
                guard let month = calendar.dateInterval(of: .month, for: start) else {
                    throw AppModelError.invalidPayPeriod
                }
                end = month.end
            }
        case .manual:
            let lastDay = calendar.startOfDay(for: manualEndDate)
            guard lastDay >= start else { throw AppModelError.invalidPayPeriod }
            end = calendar.date(byAdding: .day, value: 1, to: lastDay)
        }
        guard let end, end > start else { throw AppModelError.invalidPayPeriod }
        return PayPeriodWindow(
            startEpochSeconds: Int64(start.timeIntervalSince1970.rounded()),
            endEpochSeconds: Int64(end.timeIntervalSince1970.rounded()), cadence: cadence)
    }
}
