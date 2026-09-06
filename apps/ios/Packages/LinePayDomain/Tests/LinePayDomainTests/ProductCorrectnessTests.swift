import Foundation
import Testing

@testable import LinePayDomain

@Suite("Product mapping correctness regressions")
struct ProductCorrectnessTests {
    @Test func contradictoryPaidTotalsRequireReview() throws {
        let (rules, calculated) = try PaycheckAssessmentTests().example()
        let result = try PaycheckAssessor().assess(
            calculation: calculated, agreement: rules,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: Money(amount: 500, currencyCode: "USD"),
                amounts: [
                    .regularPay: Money(amount: 400, currencyCode: "USD"),
                    .overtimePay: Money(amount: 150, currencyCode: "USD"),
                ],
                grossBasis: .wagesOnly, lineLayout: .fullRateBuckets))
        #expect(result.verdict == .needsReview)
        #expect(!result.reviewReasons.isEmpty)
    }

    @Test func irrelevantSegmentationDoesNotChangeWages() throws {
        let rules = try agreement(hourlyRate: "50")
        let whole = try work((2026, 9, 1, 8, 0), (2026, 9, 1, 8, 2))
        let left = try work((2026, 9, 1, 8, 0), (2026, 9, 1, 8, 1))
        let right = try work((2026, 9, 1, 8, 1), (2026, 9, 1, 8, 2))
        let full = try PayCalculator().calculate(
            work: [whole], agreement: rules, policy: .highestApplicable)
        let split = try PayCalculator().calculate(
            work: [left, right], agreement: rules, policy: .highestApplicable)
        #expect(full.total.amount == decimal("1.67"))
        #expect(split.total == full.total)
        let scheduled = try agreement(
            hourlyRate: "50",
            schedule: [
                RegularScheduleWindow(
                    weekday: .tuesday, start: LocalTime(hour: 8, minute: 1),
                    end: LocalTime(hour: 16, minute: 0))
            ])
        let noOpBoundary = try PayCalculator().calculate(
            work: [whole], agreement: scheduled, policy: .highestApplicable)
        #expect(noOpBoundary.total == full.total)
    }
}
