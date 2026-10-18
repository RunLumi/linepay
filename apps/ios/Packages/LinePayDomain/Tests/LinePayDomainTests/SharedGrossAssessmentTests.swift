import Foundation
import Testing

@testable import LinePayDomain

@Suite("Shared configured-gross comparison fixtures")
struct SharedGrossAssessmentTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let currency: String
        let hourlyRate: String
        let work: Work
        let cases: [Fixture]
    }
    private struct Work: Decodable {
        let id: UUID
        let startUTC: String
        let timeZone: String
    }
    private struct Fixture: Decodable {
        let id: String
        let hasCalculation: Bool
        let perDiemPerWorkDate: String?
        let roundingScope: PayRoundingScope
        let workEndUTC: String
        let facts: Facts
        let expected: Expected
    }
    private struct Facts: Decodable {
        let completeWork: Bool
        let grossBasis: PaystubGrossBasis
        let unreviewedFields: Bool
        let unsupportedRules: Bool
        let weeklyReviewPending: Bool
        let paidGross: String
        let paidPerDiem: String?
    }
    private struct Expected: Decodable {
        let gross: String?
        let difference: String?
        let verdict: PaycheckVerdict
        let comparisons: [Comparison]
    }
    private struct Comparison: Decodable {
        let field: PaystubField
        let expected: String
        let paid: String
        let difference: String
    }

    @Test func everyComparisonMatchesIndependentScopeAndAmounts() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent(
            "shared/contracts/reconciliation/configured-gross-v1.json")
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        try #require(corpus.format == "com.streamentry.linepay.configured-gross-fixtures")
        try #require(corpus.version == 1 && corpus.cases.count == 16)
        try #require(Set(corpus.cases.map(\.id)).count == corpus.cases.count)
        let start = try epoch(corpus.work.startUTC)
        for fixture in corpus.cases {
            func money(_ value: String) throws -> Money {
                try Money(amount: decimal(value), currencyCode: corpus.currency)
            }
            let facts = fixture.facts
            let agreement = try AgreementSnapshot(
                id: "synthetic-gross", version: "1", displayName: "SYNTHETIC gross fixture",
                hourlyRate: money(corpus.hourlyRate), regularSchedule: [],
                outsideScheduleMultiplier: 1, weekdayPremiums: [], dailyOvertimeTiers: [],
                flatPerDiem: fixture.perDiemPerWorkDate.map {
                    try FlatPerDiemRule(amountPerWorkDate: money($0))
                },
                weeklyOvertime: facts.weeklyReviewPending
                    ? WeeklyOvertimeRule(
                        workweekStart: .monday, applicability: .coveredNonexemptHourly)
                    : nil, rounding: MoneyRoundingRule(scope: fixture.roundingScope))
            let work = try WorkInterval(
                id: corpus.work.id, startEpochSeconds: start,
                endEpochSeconds: epoch(fixture.workEndUTC), timeZoneIdentifier: corpus.work.timeZone
            )
            let calculation =
                try fixture.hasCalculation
                ? PayCalculator().calculate(
                    work: [work], agreement: agreement, policy: .highestApplicable)
                : nil
            let input = try PaycheckFacts(
                hasCompleteWork: facts.completeWork, grossPay: money(facts.paidGross),
                amounts: facts.paidPerDiem.map { [.perDiemPay: try money($0)] } ?? [:],
                grossBasis: facts.grossBasis, hasUnreviewedFields: facts.unreviewedFields,
                hasUnsupportedRules: facts.unsupportedRules)
            let result: PaycheckAssessment
            if let calculation {
                result = try PaycheckAssessor().assess(
                    calculation: calculation, agreement: agreement, facts: input)
            } else {
                result = try PaycheckAssessor().assessWithoutCalculation(
                    agreement: agreement, facts: input, reason: "SYNTHETIC missing calculation")
            }
            let expectedGross = try fixture.expected.gross.map(decimal)
            let expectedDifference = try fixture.expected.difference.map(decimal)
            let paidGross = try money(facts.paidGross)
            #expect(result.verdict == fixture.expected.verdict, "\(fixture.id)")
            #expect(
                result.expectedGross?.amount == expectedGross, "\(fixture.id)"
            )
            #expect(
                result.difference?.amount == expectedDifference,
                "\(fixture.id)")
            #expect(result.paidGross == paidGross, "\(fixture.id)")
            try #require(result.comparisons.count == fixture.expected.comparisons.count)
            for (actual, expected) in zip(result.comparisons, fixture.expected.comparisons) {
                let expectedAmount = try decimal(expected.expected)
                let paidAmount = try decimal(expected.paid)
                let differenceAmount = try decimal(expected.difference)
                #expect(actual.field == expected.field, "\(fixture.id)")
                #expect(actual.expected == expectedAmount, "\(fixture.id)")
                #expect(actual.paid == paidAmount, "\(fixture.id)")
                #expect(actual.difference == differenceAmount, "\(fixture.id)")
                if let calculation {
                    let selected = calculation.components.filter {
                        expected.field == .perDiemPay
                            ? $0.category == .perDiem
                            : facts.grossBasis == .wagesAndPerDiem || $0.category != .perDiem
                    }
                    #expect(actual.componentIDs == selected.map(\.id), "\(fixture.id)")
                }
            }
            #expect(!result.scopeNotes.isEmpty)
            if result.verdict == .needsReview || result.verdict == .notComparable {
                #expect(!result.reviewReasons.isEmpty, "\(fixture.id)")
            } else {
                #expect(result.reviewReasons.isEmpty, "\(fixture.id)")
            }
        }
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
    private func epoch(_ value: String) throws -> Int64 {
        try Int64(#require(ISO8601DateFormatter().date(from: value)).timeIntervalSince1970)
    }
}
