import Foundation
import Testing

@testable import LinePayDomain

@Suite("Restricted weekly regular-rate capability")
struct WeeklyRegularRateTests {
    private let week = LocalDate(year: 2026, month: 9, day: 7)

    private func work(
        _ hours: String, rate: String, payPeriodID: UUID? = nil
    ) throws -> WeeklyWorkFact {
        try WeeklyWorkFact(
            payPeriodID: payPeriodID,
            hours: decimal(hours),
            straightRate: Money(amount: decimal(rate), currencyCode: "USD"))
    }

    private func money(_ amount: String) -> Money {
        Money(amount: decimal(amount), currencyCode: "USD")
    }

    private func input(
        work: [WeeklyWorkFact], remuneration: [WeeklyRemunerationFact], complete: Bool = true,
        applicability: WeeklyOvertimeApplicability = .coveredNonexemptHourly
    ) throws -> WeeklyRegularRateInput {
        try WeeklyRegularRateInput(
            weekStart: week, workweekStart: .monday, completeWorkweek: complete,
            applicability: applicability, work: work, remuneration: remuneration)
    }

    @Test("EX-10: six eight-hour days produce $2,600")
    func ordinaryFortyEightHourWeek() throws {
        let facts = try (0..<6).map { _ in try work("8", rate: "50") }
        let result = try WeeklyRegularRateCalculator().calculate(
            input(
                work: facts,
                remuneration: [
                    try WeeklyRemunerationFact(
                        amount: money("2400"), kind: .straightTime)
                ]))
        #expect(result.qualifyingHours == decimal("48"))
        #expect(result.regularRate?.amount == decimal("50"))
        #expect(result.statutoryAdditionalPremium.amount == decimal("200"))
        #expect(result.remainingAdditionalPremium.amount == decimal("200"))
        #expect(result.expectedCash.amount == decimal("2600"))
    }

    @Test("EX-11: workweek boundaries do not average a 50h and 30h week")
    func separateWeeksRemainSeparate() throws {
        let fifty = try WeeklyRegularRateCalculator().calculate(
            input(
                work: [try work("50", rate: "50")],
                remuneration: [
                    try WeeklyRemunerationFact(amount: money("2500"), kind: .straightTime)
                ]))
        let thirty = try WeeklyRegularRateCalculator().calculate(
            input(
                work: [try work("30", rate: "50")],
                remuneration: [
                    try WeeklyRemunerationFact(amount: money("1500"), kind: .straightTime)
                ]))
        #expect(fifty.expectedCash.amount == decimal("2750"))
        #expect(thirty.expectedCash.amount == decimal("1500"))
    }

    @Test("EX-12: includable bonus changes the regular rate")
    func allocatedBonusChangesRegularRate() throws {
        let result = try WeeklyRegularRateCalculator().calculate(
            input(
                work: [try work("48", rate: "50")],
                remuneration: [
                    try WeeklyRemunerationFact(amount: money("2400"), kind: .straightTime),
                    try WeeklyRemunerationFact(amount: money("240"), kind: .includableBonus),
                ]))
        #expect(result.regularRate?.amount == decimal("55"))
        #expect(result.statutoryAdditionalPremium.amount == decimal("220"))
        #expect(result.expectedCash.amount == decimal("2860"))
    }

    @Test("EX-13: weighted regular rate handles unequal multiple rates")
    func weightedMultipleRates() throws {
        let result = try WeeklyRegularRateCalculator().calculate(
            input(
                work: [try work("30", rate: "40"), try work("20", rate: "60")],
                remuneration: [
                    try WeeklyRemunerationFact(amount: money("2400"), kind: .straightTime)
                ]))
        #expect(result.regularRate?.amount == decimal("48"))
        #expect(result.overtimeHours == decimal("10"))
        #expect(result.statutoryAdditionalPremium.amount == decimal("240"))
        #expect(result.expectedCash.amount == decimal("2640"))
    }

    @Test("EX-14: only eligible extra premium credit reduces the remaining premium")
    func eligiblePremiumCreditIsNotWholeOvertimeLine() throws {
        let result = try WeeklyRegularRateCalculator().calculate(
            input(
                work: [try work("48", rate: "50")],
                remuneration: [
                    try WeeklyRemunerationFact(amount: money("2400"), kind: .straightTime),
                    try WeeklyRemunerationFact(
                        amount: money("400"), kind: .extraPremium,
                        premiumCredit: .eligibleExtraPremium),
                ]))
        #expect(result.statutoryAdditionalPremium.amount == decimal("200"))
        #expect(result.eligibleExtraPremiumCredit.amount == decimal("400"))
        #expect(result.remainingAdditionalPremium.amount == decimal("0"))
        #expect(result.expectedCash.amount == decimal("2800"))
    }

    @Test("Incomplete or unknown applicability fails closed")
    func unknownInputsDoNotBecomeZeroEntitlement() throws {
        let facts = [try work("48", rate: "50")]
        let remuneration = [try WeeklyRemunerationFact(amount: money("2400"), kind: .straightTime)]
        #expect(throws: WeeklyRegularRateError.incompleteWorkweek) {
            try WeeklyRegularRateCalculator().calculate(
                input(work: facts, remuneration: remuneration, complete: false))
        }
        #expect(throws: WeeklyRegularRateError.applicabilityUnknown) {
            try WeeklyRegularRateCalculator().calculate(
                input(
                    work: facts, remuneration: remuneration,
                    applicability: .unknown))
        }
    }

    @Test("Weekly calculation failures explain the recovery action")
    func failuresHaveActionableDescriptions() {
        let message = WeeklyRegularRateError.incompleteWorkweek.localizedDescription
        #expect(message.contains("workweek is not complete"))
        #expect(message.contains("Confirm"))
    }

    @Test("Remaining premium is allocated across pay periods and conserves cents")
    func premiumAllocationConservesTotal() throws {
        let first = UUID()
        let second = UUID()
        let result = try WeeklyRegularRateCalculator().calculate(
            input(
                work: [
                    try work("24", rate: "50", payPeriodID: first),
                    try work("24", rate: "50", payPeriodID: second),
                ],
                remuneration: [
                    try WeeklyRemunerationFact(amount: money("2400"), kind: .straightTime)
                ]))
        #expect(result.allocations.count == 2)
        #expect(result.allocations.reduce(Decimal.zero) { $0 + $1.amount.amount } == decimal("200"))
        #expect(result.allocations.map(\.payPeriodID).contains(first))
        #expect(result.allocations.map(\.payPeriodID).contains(second))
    }

    @Test("PayCalculator carries the explicitly supplied weekly layer")
    func calculationResultPreservesWeeklyLayer() throws {
        let agreement = try AgreementSnapshot(
            id: "weekly", version: "1", displayName: "Weekly", hourlyRate: money("50"),
            regularSchedule: [])
        let start = Int64(1_800_000_000)
        let interval = try WorkInterval(
            startEpochSeconds: start, endEpochSeconds: start + 8 * 3_600, timeZoneIdentifier: "UTC")
        let weekly = try input(
            work: [try work("48", rate: "50")],
            remuneration: [try WeeklyRemunerationFact(amount: money("2400"), kind: .straightTime)])
        let result = try PayCalculator().calculate(
            work: [interval], agreement: agreement, policy: .highestApplicable, weekly: weekly)
        #expect(result.weeklyRegularRate?.expectedCash.amount == decimal("2600"))
    }
}
