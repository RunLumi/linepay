import Foundation
import Testing

@testable import LinePayDomain

@Suite("Shared explicitly confirmed fund fixtures")
struct SharedBenefitContractTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let cases: [Fixture]
    }
    private struct Period: Decodable {
        let start: String
        let endExclusive: String
        let timeZone: String
    }
    private struct Rule: Decodable {
        let id: UUID
        let fundID: UUID
        let version: String
        let basis: BenefitContributionBasis
        let rate: String
        let currency: String
        let effectivePeriod: Period
    }
    private struct Segment: Decodable {
        let id: UUID
        let period: Period
        let rule: Rule
        let quantity: String
        let eligibilityConfirmed: Bool
    }
    private struct Statement: Decodable {
        let fundID: UUID
        let currency: String
        let period: Period
        let employerContribution: String?
        let quantity: String?
        let quantityBasis: BenefitContributionBasis?
        let confirmed: Bool
    }
    private struct Expected: Decodable {
        let amount: String
        let currency: String
        let components: [String]
        let status: BenefitComparisonStatus
        let paid: String?
        let difference: String?
        let eligibleQuantity: String?
        let quantityBasis: BenefitContributionBasis?
        let quantityDifference: String?
    }
    private struct Fixture: Decodable {
        let id: String
        let period: Period
        let completeEligibilityConfirmed: Bool
        let rounding: MoneyRoundingRule
        let segments: [Segment]
        let statement: Statement?
        let expected: Expected
    }

    @Test func everyIndependentFundCaseKeepsUnknownsPrecisionAndSourceSnapshots() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let corpus = try JSONDecoder().decode(
            Corpus.self,
            from: Data(
                contentsOf:
                    root.appendingPathComponent("shared/contracts/benefits/confirmed-fund-v1.json"))
        )
        try #require(
            corpus.format == "com.streamentry.linepay.confirmed-benefit-fixtures"
                && corpus.version == 1)
        try #require(corpus.cases.count == 13 && Set(corpus.cases.map(\.id)).count == 13)
        for item in corpus.cases {
            let segments = try item.segments.map { source in
                BenefitEligibilitySegment(
                    id: source.id, period: try period(source.period),
                    rule: try BenefitRuleSnapshot(
                        id: source.rule.id, fundID: source.rule.fundID,
                        version: source.rule.version, basis: source.rule.basis,
                        rate: decimal(source.rule.rate),
                        currencyCode: source.rule.currency,
                        effectivePeriod: period(source.rule.effectivePeriod)),
                    quantity: try decimal(source.quantity),
                    eligibilityConfirmed: source.eligibilityConfirmed)
            }
            let statement = try item.statement.map { source in
                BenefitStatementObservation(
                    fundID: source.fundID, currencyCode: source.currency,
                    period: try period(source.period),
                    employerContribution: try source.employerContribution.map {
                        Money(amount: try decimal($0), currencyCode: source.currency)
                    }, quantity: try source.quantity.map(decimal),
                    quantityBasis: source.quantityBasis, confirmed: source.confirmed)
            }
            let result = try BenefitContributionCalculator().calculate(
                period: period(item.period), segments: segments,
                completeEligibilityConfirmed: item.completeEligibilityConfirmed,
                statement: statement, rounding: item.rounding)
            let expected = item.expected
            let amount = try decimal(expected.amount)
            let paid = try expected.paid.map(decimal)
            let difference = try expected.difference.map(decimal)
            let quantity = try expected.eligibleQuantity.map(decimal)
            let unitDifference = try expected.quantityDifference.map(decimal)
            #expect(result.expectedEmployerContribution.amount == amount, "\(item.id)")
            #expect(
                result.expectedEmployerContribution.currencyCode == expected.currency, "\(item.id)")
            #expect(result.confirmedEmployerContribution?.amount == paid, "\(item.id)")
            #expect(result.contributionDifference?.amount == difference, "\(item.id)")
            #expect(
                result.eligibleQuantity == quantity
                    && result.quantityBasis == expected.quantityBasis, "\(item.id)")
            #expect(
                result.quantityDifference == unitDifference && result.status == expected.status,
                "\(item.id)")
            let parts = try expected.components.map(decimal)
            #expect(result.components.map(\.unroundedContribution.amount) == parts, "\(item.id)")
            #expect(Set(result.segments.map(\.id)) == Set(segments.map(\.id)), "\(item.id)")
            #expect(
                result.segments.map(\.rule)
                    == segments.sorted { $0.period.start < $1.period.start }.map(\.rule),
                "\(item.id)")
        }
    }
    private func decimal(_ text: String) throws -> Decimal {
        try #require(text.range(of: #"^-?\d+(?:\.\d+)?$"#, options: .regularExpression) != nil)
        return try #require(Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")))
    }
    private func period(_ source: Period) throws -> BenefitPeriod {
        func day(_ value: String) throws -> LocalDate {
            let parts = value.split(separator: "-").compactMap { Int($0) }
            try #require(parts.count == 3)
            return LocalDate(year: parts[0], month: parts[1], day: parts[2])
        }
        return try BenefitPeriod(
            start: day(source.start), end: day(source.endExclusive),
            timeZoneIdentifier: source.timeZone)
    }
}
