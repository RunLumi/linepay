import Foundation
import Testing

@testable import LinePayDomain

@Suite("Domain value contracts")
struct DomainContractTests {
    @Test(arguments: [(0, 0), (23, 59), (12, 30)])
    func validClock(_ hour: Int, _ minute: Int) throws {
        let value = try LocalTime(hour: hour, minute: minute)
        #expect(value.minuteOfDay == hour * 60 + minute)
        #expect(try JSONDecoder().decode(LocalTime.self, from: JSONEncoder().encode(value)) == value)
    }

    @Test(arguments: [(-1, 0), (24, 0), (0, -1), (0, 60)])
    func invalidClock(_ hour: Int, _ minute: Int) {
        #expect(throws: DomainValidationError.invalidLocalTime(hour: hour, minute: minute)) {
            try LocalTime(hour: hour, minute: minute)
        }
    }

    @Test func localDatesSortAcrossMonthAndYear() {
        let dates = [LocalDate(year: 2027, month: 1, day: 1),
                     LocalDate(year: 2026, month: 12, day: 31),
                     LocalDate(year: 2026, month: 1, day: 1)]
        #expect(dates.sorted() == dates.reversed())
        #expect(!(dates[0] < dates[0]))
        #expect(Weekday.allCases.map(\.rawValue) == Array(1...7))
    }

    @Test(arguments: [0, -1])
    func invalidWorkAndBreak(_ end: Int64) {
        #expect(throws: DomainValidationError.invalidWorkInterval) {
            try WorkInterval(startEpochSeconds: 0, endEpochSeconds: end, timeZoneIdentifier: "UTC")
        }
        #expect(throws: DomainValidationError.invalidWorkBreak) {
            try WorkBreak(startEpochSeconds: 0, endEpochSeconds: end)
        }
    }

    @Test func invalidTimeZone() {
        #expect(throws: DomainValidationError.invalidTimeZone("Not/AZone")) {
            try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 3_600,
                             timeZoneIdentifier: "Not/AZone")
        }
    }

    @Test func breakContracts() throws {
        let first = try WorkBreak(startEpochSeconds: 600, endEpochSeconds: 900)
        let second = try WorkBreak(startEpochSeconds: 900, endEpochSeconds: 1_200)
        let value = try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 3_600,
                                    timeZoneIdentifier: "UTC", unpaidBreaks: [second, first])
        #expect(value.unpaidBreaks == [first, second])
        #expect(value.elapsedHours == 1)
        #expect(value.durationHours == 1 - Decimal(600) / 3_600)
        #expect(first.durationHours == Decimal(300) / 3_600)
        #expect(try JSONDecoder().decode(WorkInterval.self, from: JSONEncoder().encode(value)) == value)
        #expect(throws: DomainValidationError.duplicateWorkBreakID) {
            try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 3_600,
                             timeZoneIdentifier: "UTC", unpaidBreaks: [first, first])
        }
        let overlap = try WorkBreak(startEpochSeconds: 800, endEpochSeconds: 1_000)
        #expect(throws: DomainValidationError.overlappingWorkBreaks) {
            try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 3_600,
                             timeZoneIdentifier: "UTC", unpaidBreaks: [first, overlap])
        }
        let whole = try WorkBreak(startEpochSeconds: 0, endEpochSeconds: 3_600)
        #expect(throws: DomainValidationError.workBreakConsumesEntireInterval) {
            try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 3_600,
                             timeZoneIdentifier: "UTC", unpaidBreaks: [whole])
        }
    }

    @Test(arguments: [(-1, 1_000), (2_000, 3_601)])
    func breakOutsideShift(_ start: Int64, _ end: Int64) throws {
        let pause = try WorkBreak(startEpochSeconds: start, endEpochSeconds: end)
        #expect(throws: DomainValidationError.workBreakOutsideInterval) {
            try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 3_600,
                             timeZoneIdentifier: "UTC", unpaidBreaks: [pause])
        }
    }

    @Test(arguments: [0, -1])
    func invalidMultipliers(_ value: Decimal) {
        #expect(throws: DomainValidationError.invalidMultiplier) {
            try WeekdayPremium(weekday: .monday, multiplier: value)
        }
        #expect(throws: DomainValidationError.invalidMultiplier) {
            try DatePremium(date: LocalDate(year: 2026, month: 1, day: 1), multiplier: value)
        }
        #expect(throws: DomainValidationError.invalidMultiplier) {
            try agreement(outsideScheduleMultiplier: value)
        }
        #expect(throws: DomainValidationError.invalidCalloutMinimum) {
            try CalloutMinimumRule(minimumHours: value)
        }
    }

    @Test func tierValidationAndCanonicalOrder() throws {
        #expect(throws: DomainValidationError.invalidOvertimeTier) {
            try DailyOvertimeTier(afterHours: -1, multiplier: 2)
        }
        #expect(throws: DomainValidationError.invalidOvertimeTier) {
            try DailyOvertimeTier(afterHours: 0, multiplier: 0)
        }
        let a = try DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5"))
        let b = try DailyOvertimeTier(afterHours: 12, multiplier: 2)
        let snapshot = try agreement(dailyOvertimeTiers: [b, a])
        #expect(snapshot.dailyOvertimeTiers == [a, b])
        #expect(throws: DomainValidationError.duplicateOvertimeThreshold) {
            try agreement(dailyOvertimeTiers: [a, a])
        }
        #expect(try JSONDecoder().decode(AgreementSnapshot.self,
                                        from: JSONEncoder().encode(snapshot)) == snapshot)
    }

    @Test(arguments: [(8, 8), (16, 8)])
    func scheduleRejectsEmptyAndOvernight(_ start: Int, _ end: Int) {
        #expect(throws: DomainValidationError.overnightScheduleWindowUnsupported) {
            try RegularScheduleWindow(weekday: .monday,
                                      start: LocalTime(hour: start, minute: 0),
                                      end: LocalTime(hour: end, minute: 0))
        }
    }

    @Test func invalidCurrencyAndSourceRoundTrip() throws {
        #expect(throws: DomainValidationError.invalidCurrencyCode("US")) {
            try AgreementSnapshot(id: "a", version: "1", displayName: "Synthetic",
                                  hourlyRate: Money(amount: 10, currencyCode: "US"), regularSchedule: [])
        }
        let source = AgreementSource(title: "Synthetic source", url: "https://example.invalid/rule",
                                     section: "7", verifiedEpochSeconds: 42)
        #expect(try JSONDecoder().decode(AgreementSource.self,
                                        from: JSONEncoder().encode(source)) == source)
    }
}

@Suite("Exact money and rounded reconciliation")
struct ExactMoneyContractTests {
    @Test(arguments: [MoneyRoundingMode.halfUp, .bankers, .down, .up])
    func roundingModes(_ mode: MoneyRoundingMode) throws {
        let expected: Decimal = switch mode {
        case .halfUp, .up: decimal("1.23")
        case .bankers, .down: decimal("1.22")
        }
        let amount = Money(amount: decimal("1.225"), currencyCode: "usd")
        #expect(amount.rounded(using: .init(scale: 2, mode: mode)).amount == expected)
        #expect(amount.amount == decimal("1.225"))
        let rule = MoneyRoundingRule(scale: 2, mode: mode)
        #expect(try JSONDecoder().decode(MoneyRoundingRule.self,
                                        from: JSONEncoder().encode(rule)) == rule)
    }

    @Test func arithmeticDoesNotLoseCentsOrCurrency() throws {
        let amount = Money(amount: decimal("999999.99"), currencyCode: "usd")
        let cent = Money(amount: decimal("0.01"), currencyCode: "USD")
        #expect(try amount.adding(cent).amount == 1_000_000)
        #expect(try cent.subtracting(amount).amount == decimal("-999999.98"))
        #expect(amount.multiplied(by: 0) == .zero(currencyCode: "USD"))
        #expect(cent.multiplied(by: decimal("1.5")).amount == decimal("0.015"))
        #expect(try amount.subtracting(amount) == .zero(currencyCode: "usd"))
        #expect(throws: MoneyError.currencyMismatch(lhs: "USD", rhs: "EUR")) {
            try amount.subtracting(.zero(currencyCode: "EUR"))
        }
        #expect(try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(amount)) == amount)
    }

    @Test(arguments: ["0.004", "0.005", "-0.004", "-0.005"])
    func comparisonRoundsDifferenceOnly(_ delta: String) throws {
        let expected = Money(amount: 100 + decimal(delta), currencyCode: "USD")
        let calculation = CalculationResult(agreementID: "a", agreementVersion: "1",
                                            components: [], total: expected)
        let actual = Money(amount: 100, currencyCode: "USD")
        let result = try PayReconciler().reconcile(expected: calculation,
                                                  paystub: PaystubSummary(grossPay: actual))
        let rounded = delta == "0.005" ? decimal("0.01")
            : delta == "-0.005" ? decimal("-0.01") : 0
        #expect(result.difference.amount == rounded)
        #expect(result.direction == (rounded == 0 ? .matches
                                      : rounded > 0 ? .possibleUnderpayment : .possibleOverpayment))
        #expect(result.expectedGross == expected)
        #expect(result.actualGross == actual)
        #expect(try JSONDecoder().decode(ReconciliationResult.self,
                                        from: JSONEncoder().encode(result)) == result)
    }
}
