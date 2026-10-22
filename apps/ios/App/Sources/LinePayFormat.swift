import Foundation
import LinePayDomain

enum LinePayFormat {
    static func money(_ money: Money) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = money.currencyCode
        // The currency's own minor units: two for USD and CAD, none for VND.
        let digits = fractionDigits(currencyCode: money.currencyCode)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSDecimalNumber(decimal: money.amount))
            ?? "\(money.currencyCode) \(decimal(money.amount))"
    }

    /// Rates may carry precision below a currency's payable minor unit. Keep that precision
    /// visible without converting the value through a binary floating-point formatter.
    static func rate(_ money: Money, locale: Locale = .current) -> String {
        var amount = money.amount
        var rounded = Decimal()
        let digits = fractionDigits(currencyCode: money.currencyCode)
        NSDecimalRound(&rounded, &amount, digits, .plain)
        let text = decimal(amount)
        let significantDigits = text.filter(\.isNumber).drop(while: { $0 == "0" }).count
        if rounded != amount || significantDigits > 15 {
            let separator = locale.decimalSeparator ?? "."
            return money.currencyCode + " " + text.replacingOccurrences(of: ".", with: separator)
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = money.currencyCode
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? money.currencyCode + " " + text
    }

    /// ISO 4217 minor units as Foundation reports them for the currency.
    static func fractionDigits(currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return min(max(formatter.maximumFractionDigits, 0), 4)
    }

    /// A value placed back into an editable field, written with the decimal separator the worker
    /// types, so editing a saved rate never changes its meaning.
    static func entry(_ value: Decimal) -> String {
        let text = decimal(value)
        return NumberEntry.decimalSeparator == ","
            ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    static func hours(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? decimal(value)
    }

    /// Display only: retain useful minute/second context instead of a rounded-hour equation.
    /// Monetary calculation never reads this presentation-normalized quantity.
    static func workDuration(_ hours: Decimal, locale: Locale = .current) -> String {
        guard !hours.isNaN, hours >= 0 else { return "—" }
        var seconds = hours * 3_600
        var displayed = Decimal()
        NSDecimalRound(&displayed, &seconds, 6, .plain)
        guard !displayed.isNaN, displayed <= Decimal(Int64.max) else { return "—" }
        if hours > 0 && displayed == 0 { return "<0.000001 s" }
        let prefix = displayed == seconds ? "" : "≈"
        let whole = NSDecimalNumber(decimal: displayed).int64Value
        if Decimal(whole) == displayed {
            let formatter = DateComponentsFormatter()
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = locale
            calendar.timeZone = .gmt
            formatter.calendar = calendar
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .short
            formatter.zeroFormattingBehavior = .dropAll
            if let text = formatter.string(from: TimeInterval(whole)) { return prefix + text }
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.locale = locale
        return prefix
            + (formatter.string(from: NSDecimalNumber(decimal: displayed)) ?? decimal(displayed))
            + " s"
    }

    static func decimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    /// A calendar date with its weekday and month name, so no reader has to guess whether
    /// `01/02` means January 2 or February 1.
    static func localDate(_ date: LocalDate) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard
            let instant = calendar.date(
                from: DateComponents(year: date.year, month: date.month, day: date.day))
        else {
            return String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMdyyyy")
        return formatter.string(from: instant)
    }

    /// A worker-facing name such as "Central Time (Chicago)" instead of an IANA identifier.
    static func timeZoneName(_ identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        let city =
            identifier.split(separator: "/").last.map {
                $0.replacingOccurrences(of: "_", with: " ")
            } ?? identifier
        guard let name = zone.localizedName(for: .generic, locale: .current), name != identifier
        else { return city }
        return name.contains(city) ? name : "\(name) (\(city))"
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

    /// A compact shift label for lists: "Sat, Oct 3 · 7:00 AM – 3:00 PM". Overnight work keeps
    /// both dates so the reader never has to infer that the end fell on the next day.
    static func shiftTimes(_ interval: WorkInterval) -> String {
        let zone = TimeZone(identifier: interval.timeZoneIdentifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = DateFormatter()
        day.timeZone = zone
        day.setLocalizedDateFormatFromTemplate("EEEMMMd")
        let time = DateFormatter()
        time.timeZone = zone
        time.dateStyle = .none
        time.timeStyle = .short

        let start = Date(timeIntervalSince1970: TimeInterval(interval.startEpochSeconds))
        let end = Date(timeIntervalSince1970: TimeInterval(interval.endEpochSeconds))
        if calendar.isDate(start, inSameDayAs: end) {
            return
                "\(day.string(from: start)) · \(time.string(from: start)) – \(time.string(from: end))"
        }
        return
            "\(day.string(from: start)) \(time.string(from: start)) – \(day.string(from: end)) \(time.string(from: end))"
    }

    static func payPeriod(
        _ window: PayPeriodWindow,
        timeZoneIdentifier: String
    ) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: window.startDate, to: window.displayEndDate)
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

/// The one place the app decides how typed numbers are read. The domain parser stays explicit:
/// it is handed the separator instead of reading the device locale.
enum NumberEntry {
    /// `,` where the region writes `58,40` (Vietnam, French Canada), otherwise `.`.
    static var decimalSeparator: Character {
        Locale.current.decimalSeparator == "," ? "," : "."
    }

    /// Currencies without minor units, such as VND, carry far larger nominal amounts: an ordinary
    /// paycheck is tens of millions of đồng.
    static func amountMaximum(currencyCode: String) -> Decimal {
        LinePayFormat.fractionDigits(currencyCode: currencyCode) == 0 ? 100_000_000_000 : 10_000_000
    }

    /// Decimals a typed money amount may carry: the currency's minor units, at most two. VND has
    /// none, so "45.00" is rejected instead of being read as 45 đồng when 45,000 was meant.
    static func amountFractionDigits(currencyCode: String) -> Int {
        min(2, LinePayFormat.fractionDigits(currencyCode: currencyCode))
    }

    static func amount(_ text: String, currencyCode: String, allowZero: Bool = true) throws
        -> Decimal
    {
        try StrictDecimal.parse(
            text, maximum: amountMaximum(currencyCode: currencyCode),
            fractionDigits: amountFractionDigits(currencyCode: currencyCode),
            allowZero: allowZero, allowDollarSign: true, decimalSeparator: decimalSeparator)
    }

    static func hours(_ text: String, maximum: Decimal = 10_000) throws -> Decimal {
        try StrictDecimal.parse(
            text, maximum: maximum, fractionDigits: 4, decimalSeparator: decimalSeparator)
    }
}
