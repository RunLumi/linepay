import Foundation
import Testing

@testable import LinePayDomain

@Suite("Strict worker-entered numbers")
struct StrictDecimalTests {
    @Test(arguments: ["1,000.00", "1000.00", "$1,000.00", " 1000 "])
    func completeNumbers(_ input: String) throws {
        #expect(try StrictDecimal.parse(input, allowDollarSign: true) == 1000)
    }
    @Test(arguments: [
        "58oops", "1,00.00", "12,34,567", "1.000,00", "1e3", "NaN", "-50", "", "1.", ".5", "1.234",
        "1 000", "1,,000", "+1",
    ])
    func rejectsPrefixesAndAmbiguousFormatting(_ input: String) {
        #expect(throws: (any Error).self) { try StrictDecimal.parse(input) }
    }
    @Test func precisionAndRange() throws {
        #expect(try StrictDecimal.parse("12.1234", fractionDigits: 4) == Decimal(string: "12.1234"))
        #expect(throws: DecimalInputError.outOfRange) { try StrictDecimal.parse("10000001") }
        #expect(throws: DecimalInputError.outOfRange) {
            try StrictDecimal.parse("0", allowZero: false)
        }
    }
}

@Suite("Evidence-aware paycheck assessment")
struct PaycheckAssessmentTests {
    let rate = Money(amount: 50, currencyCode: "USD")
    func example(includePerDiem: Bool = false) throws -> (AgreementSnapshot, CalculationResult) {
        let agreement = try AgreementSnapshot(
            id: "synthetic", version: "1", displayName: "Test",
            hourlyRate: rate, regularSchedule: [],
            dailyOvertimeTiers: [DailyOvertimeTier(afterHours: 8, multiplier: Decimal(15) / 10)],
            flatPerDiem: includePerDiem
                ? FlatPerDiemRule(amountPerWorkDate: Money(amount: 125, currencyCode: "USD")) : nil)
        let interval = try WorkInterval(
            startEpochSeconds: 1_788_264_000,
            endEpochSeconds: 1_788_264_000 + 10 * 3600, timeZoneIdentifier: "UTC", kind: .regular)
        return (
            agreement,
            try PayCalculator().calculate(
                work: [interval], agreement: agreement, policy: .highestApplicable)
        )
    }
    @Test func matchingGrossDoesNotHideOffsettingErrors() throws {
        let (agreement, calculation) = try example()
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true,
                grossPay: Money(amount: 550, currencyCode: "USD"),
                amounts: [
                    .regularPay: Money(amount: 350, currencyCode: "USD"),
                    .overtimePay: Money(amount: 200, currencyCode: "USD"),
                ],
                grossBasis: .wagesOnly, lineLayout: .fullRateBuckets))
        #expect(result.verdict == .needsReview)
        #expect(result.comparisons.filter(\.differs).count == 2)
    }
    @Test func perDiemExcludedFromWageGross() throws {
        let (agreement, calculation) = try example(includePerDiem: true)
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true,
                grossPay: Money(amount: 550, currencyCode: "USD"),
                amounts: [.perDiemPay: Money(amount: 125, currencyCode: "USD")],
                grossBasis: .wagesOnly))
        #expect(calculation.total.amount == 675)
        #expect(result.expectedGross?.amount == 550)
        #expect(result.verdict == .matches)
        #expect(result.comparisons.allSatisfy { !$0.differs })
    }
    @Test func premiumOnlyLayoutAndHours() throws {
        let (agreement, calculation) = try example()
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true,
                grossPay: Money(amount: 550, currencyCode: "USD"),
                amounts: [
                    .regularPay: Money(amount: 500, currencyCode: "USD"),
                    .overtimePay: Money(amount: 50, currencyCode: "USD"),
                ],
                hours: [.regularHours: 10, .overtimeHours: 2],
                grossBasis: .wagesOnly, lineLayout: .basePlusPremium, hoursBasis: .actualWork))
        #expect(result.verdict == .matches)
        #expect(result.comparisons.count == 5)
        #expect(result.comparisons.allSatisfy { !$0.differs })
    }
    @Test func unconfirmedBasisIsNotComparable() throws {
        let (agreement, calculation) = try example()
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: calculation.total, grossBasis: .unconfirmed))
        #expect(result.verdict == .notComparable)
        #expect(result.difference == nil)
    }
    @Test func scopeIsExplicit() throws {
        let (agreement, calculation) = try example()
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: calculation.total, grossBasis: .wagesOnly))
        #expect(result.scope == .grossOnly)
        #expect(result.verdict == .matches)
        #expect(result.scopeNotes.contains { $0.contains("Gross total only") })
    }
    @Test func uncertainComponentsAndUnsupportedRulesCannotPassCleanly() throws {
        let (agreement, calculation) = try example()
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true,
                grossPay: calculation.total,
                amounts: [.overtimePay: Money(amount: 150, currencyCode: "USD")],
                grossBasis: .wagesOnly, hasUnreviewedFields: true, hasUnsupportedRules: true))
        #expect(result.verdict == .needsReview)
        #expect(result.reviewReasons.count >= 3)
    }
    @Test func hoursAreNotSilentlyIgnored() throws {
        let (agreement, calculation) = try example()
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true,
                grossPay: calculation.total,
                hours: [.regularHours: 7], grossBasis: .wagesOnly,
                lineLayout: .fullRateBuckets, hoursBasis: .actualWork))
        #expect(result.verdict == .needsReview)
        #expect(result.comparisons.first { $0.field == .regularHours }?.difference == 1)
    }
}
