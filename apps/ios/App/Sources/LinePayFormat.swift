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
}
