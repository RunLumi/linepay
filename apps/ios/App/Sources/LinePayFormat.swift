import Foundation
import LinePayDomain

enum LinePayFormat {
    static func money(_ money: Money) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = money.currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: money.amount))
            ?? "\(money.currencyCode) \(decimal(money.amount))"
    }

    static func hours(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? decimal(value)
    }

    static func decimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func localDate(_ date: LocalDate) -> String {
        String(format: "%02d/%02d/%04d", date.month, date.day, date.year)
    }

    static func workDateRange(_ interval: WorkInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: interval.timeZoneIdentifier)

        let start = Date(timeIntervalSince1970: TimeInterval(interval.startEpochSeconds))
        let end = Date(timeIntervalSince1970: TimeInterval(interval.endEpochSeconds))
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    static func payPeriod(
        _ window: PayPeriodWindow,
        timeZoneIdentifier: String
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return "\(formatter.string(from: window.startDate)) – \(formatter.string(from: window.displayEndDate))"
    }

    static func breakDuration(_ interval: WorkInterval) -> String? {
        let total = interval.unpaidBreaks.reduce(Decimal.zero) { $0 + $1.durationHours }
        guard total > 0 else { return nil }
        return "\(hours(total)) h unpaid break"
    }

    static func signedMoney(_ money: Money) -> String {
        if money.amount > 0 {
            return "+\(self.money(money))"
        }
        return self.money(money)
    }
}
