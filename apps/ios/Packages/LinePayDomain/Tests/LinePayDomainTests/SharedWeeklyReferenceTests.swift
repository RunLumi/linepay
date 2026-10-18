import Foundation
import Testing

@testable import LinePayDomain

@Suite("Shared restricted weekly reference vectors")
struct SharedWeeklyReferenceTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let cases: [Row]
        let refusals: [Row]
    }
    private struct Row: Decodable {
        let id: String
        let input: Input
        let expected: Expected?
    }
    private struct Amount: Decodable {
        let amount: String
        let currency: String
    }
    private struct Work: Decodable {
        let id: UUID
        let payPeriodID: UUID?
        let hours: String?
        let workedSeconds: Int64?
        let straightRate: Amount
        let qualifies: Bool
    }
    private struct Pay: Decodable {
        let id: UUID
        let amount: Amount
        let kind: WeeklyRemunerationKind
        let premiumCredit: WeeklyPremiumCredit
    }
    private struct Input: Decodable {
        let startUTC: String
        let timeZone: String
        let boundaryConfirmed: Bool
        let singleEmployerConfirmed: Bool
        let paymentsConfirmed: Bool
        let completeWorkweek: Bool
        let applicability: WeeklyOvertimeApplicability
        let work: [Work]
        let remuneration: [Pay]
        let rounding: MoneyRoundingRule
    }
    private struct Expected: Decodable {
        let qualifyingSeconds: String
        let regularRate: String
        let overtimeSeconds: String
        let statutoryAdditionalPremium: String
        let eligibleExtraPremiumCredit: String
        let remainingAdditionalPremium: String
        let cashRemuneration: String
        let expectedCash: String
        let allocationAmounts: [String]
    }
    private func corpus() throws -> Corpus {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(
            Corpus.self,
            from: Data(
                contentsOf: root.appendingPathComponent("shared/contracts/weekly/reference-v2.json")
            ))
    }
    private func number(_ text: String) throws -> Decimal {
        try StrictDecimal.parse(text, maximum: 10_000_000, fractionDigits: 8)
    }
    private func calculate(_ input: Input) throws -> WeeklyRegularRateResult {
        guard input.boundaryConfirmed else {
            throw WeeklyRegularRateError.workweekBoundaryUnconfirmed
        }
        guard input.singleEmployerConfirmed else {
            throw WeeklyRegularRateError.applicabilityUnknown
        }
        guard input.paymentsConfirmed else { throw WeeklyRegularRateError.remunerationIncomplete }
        let date = try #require(ISO8601DateFormatter().date(from: input.startUTC))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: input.timeZone))
        return try WeeklyRegularRateCalculator().calculate(
            WeeklyRegularRateInput(
                weekStart: LocalDate(
                    year: calendar.component(.year, from: date),
                    month: calendar.component(.month, from: date),
                    day: calendar.component(.day, from: date)),
                workweekStart: #require(
                    Weekday(rawValue: calendar.component(.weekday, from: date))),
                completeWorkweek: input.completeWorkweek, applicability: input.applicability,
                work: input.work.map {
                    try WeeklyWorkFact(
                        id: $0.id, payPeriodID: $0.payPeriodID,
                        hours: $0.workedSeconds.map { Decimal($0) / 3600 }
                            ?? number(#require($0.hours)),
                        straightRate: Money(
                            amount: number($0.straightRate.amount),
                            currencyCode: $0.straightRate.currency),
                        qualifiesForWeeklyOvertime: $0.qualifies, workedSeconds: $0.workedSeconds)
                },
                remuneration: input.remuneration.map {
                    try WeeklyRemunerationFact(
                        id: $0.id,
                        amount: Money(
                            amount: number($0.amount.amount), currencyCode: $0.amount.currency),
                        kind: $0.kind, premiumCredit: $0.premiumCredit)
                },
                rounding: input.rounding, startEpochSeconds: Int64(date.timeIntervalSince1970),
                timeZoneIdentifier: input.timeZone))
    }
    @Test func sevenIndependentPricesAndAllocationsMatch() throws {
        let corpus = try corpus()
        try #require(
            corpus.format == "com.streamentry.linepay.weekly-reference-fixtures"
                && corpus.version == 2 && corpus.cases.count == 7)
        for row in corpus.cases {
            let result = try calculate(row.input)
            let expected = try #require(row.expected)
            #expect(
                result.qualifyingHours == (try number(expected.qualifyingSeconds) / 3600),
                "\(row.id)")
            #expect(
                result.overtimeHours == (try number(expected.overtimeSeconds) / 3600), "\(row.id)")
            #expect(result.regularRate?.amount == (try number(expected.regularRate)), "\(row.id)")
            for (actual, value) in [
                (result.statutoryAdditionalPremium.amount, expected.statutoryAdditionalPremium),
                (result.eligibleExtraPremiumCredit.amount, expected.eligibleExtraPremiumCredit),
                (result.remainingAdditionalPremium.amount, expected.remainingAdditionalPremium),
                (result.cashRemuneration.amount, expected.cashRemuneration),
                (result.expectedCash.amount, expected.expectedCash),
            ] { #expect(actual == (try number(value)), "\(row.id)") }
            #expect(
                result.allocations.map(\.amount.amount)
                    == (try expected.allocationAmounts.map(number)), "\(row.id)")
        }
    }
    @Test func tenUnknownOrInvalidInputsRefuse() throws {
        let source = try corpus()
        try #require(
            source.format == "com.streamentry.linepay.weekly-reference-fixtures"
                && source.version == 2)
        let rows = source.refusals
        try #require(rows.count == 10)
        for row in rows {
            #expect(throws: (any Error).self, "\(row.id)") { try calculate(row.input) }
        }
    }
}
