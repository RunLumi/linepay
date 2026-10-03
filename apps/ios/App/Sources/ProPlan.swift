import Foundation

/// One Pro billing option as the worker sees it. Prices and offers come from StoreKit; nothing
/// here is hard-coded merchandising.
struct ProPlan: Identifiable, Equatable, Sendable {
    enum Period: Equatable, Sendable { case year, month }

    struct FreeTrial: Equatable, Sendable {
        /// "7 days", for terms such as "7 days free, then …".
        let duration: String
        /// "7-day", for "Start my 7-day free trial".
        let length: String
        /// Known only for day/week offers; month-based offers have no fixed day count.
        let days: Int?

        static func days(_ count: Int) -> FreeTrial { FreeTrial(count, unit: "day", days: count) }
        static func months(_ count: Int) -> FreeTrial { FreeTrial(count, unit: "month", days: nil) }
        static func years(_ count: Int) -> FreeTrial { FreeTrial(count, unit: "year", days: nil) }

        private init(_ count: Int, unit: String, days: Int?) {
            duration = "\(count) \(unit)\(count == 1 ? "" : "s")"
            length = "\(count)-\(unit)"
            self.days = days
        }
    }

    let id: String
    let period: Period
    let price: Decimal
    let currencyCode: String
    let displayPrice: String
    /// For comparison only. The billed amount is `displayPrice` once per `period`.
    let monthlyEquivalent: String?
    /// Present only when Apple supplies a free-trial introductory offer and reports eligibility.
    let freeTrial: FreeTrial?

    var periodName: String { period == .year ? "year" : "month" }

    /// Whole-percent saving of the annual plan against twelve monthly payments, rounded down so
    /// the claim is never overstated. Nil unless both prices exist in the same currency.
    static func annualSavingsPercent(annual: ProPlan, monthly: ProPlan) -> Int? {
        guard annual.period == .year, monthly.period == .month,
            annual.currencyCode == monthly.currencyCode, monthly.price > 0
        else { return nil }
        let twelveMonths = monthly.price * 12
        guard annual.price < twelveMonths else { return nil }
        var fraction = (twelveMonths - annual.price) / twelveMonths * 100
        var whole = Decimal()
        NSDecimalRound(&whole, &fraction, 0, .down)
        let percent = NSDecimalNumber(decimal: whole).intValue
        return percent > 0 ? percent : nil
    }
}
