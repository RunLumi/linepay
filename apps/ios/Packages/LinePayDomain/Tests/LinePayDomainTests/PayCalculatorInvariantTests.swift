import Foundation
import Testing

@testable import LinePayDomain

@Suite("Payroll boundaries and conservation")
struct PayCalculatorInvariantTests {
    @Test func emptyWorkIsZeroWithoutAllowances() throws {
        let rules = try agreement(calloutMinimum: CalloutMinimumRule(minimumHours: 4),
                                  flatPerDiem: FlatPerDiemRule(amountPerWorkDate: Money(amount: 125, currencyCode: "USD")))
        let result = try PayCalculator().calculate(work: [], agreement: rules, policy: .highestApplicable)
        #expect(result.total == .zero(currencyCode: "USD"))
        #expect(result.components.isEmpty)
        #expect(result.agreementID == rules.id && result.agreementVersion == rules.version)
    }

    @Test(arguments: [7, 8, 9, 12, 13])
    func dailyTierBoundary(_ hours: Int) throws {
        let shift = try work((2026, 8, 3, 0, 0), (2026, 8, 3, hours, 0))
        let rules = try agreement(dailyOvertimeTiers: [
            DailyOvertimeTier(afterHours: 12, multiplier: 2),
            DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5")),
        ])
        let result = try PayCalculator().calculate(work: [shift], agreement: rules, policy: .highestApplicable)
        let expected = min(hours, 8) * 10 + max(min(hours - 8, 4), 0) * 15 + max(hours - 12, 0) * 20
        #expect(result.total.amount == Decimal(expected))
        #expect(result.components.reduce(Decimal(0)) { $0 + ($1.hours ?? 0) } == Decimal(hours))
        #expect(result.components.allSatisfy { $0.workIntervalID == shift.id && !$0.explanation.isEmpty })
    }

    @Test func inputOrderDoesNotChangeSemanticOutput() throws {
        let a = try work((2026, 8, 3, 8, 0), (2026, 8, 3, 12, 0))
        let b = try work((2026, 8, 3, 12, 0), (2026, 8, 3, 18, 0))
        let rules = try agreement(dailyOvertimeTiers: [DailyOvertimeTier(afterHours: 8, multiplier: 2)])
        let forward = try PayCalculator().calculate(work: [a, b], agreement: rules, policy: .highestApplicable)
        let reverse = try PayCalculator().calculate(work: [b, a], agreement: rules, policy: .highestApplicable)
        #expect(forward.total.amount == 120)
        #expect(forward.total == reverse.total)
        #expect(forward.components.map(\.amount) == reverse.components.map(\.amount))
        #expect(forward.components.map(\.hours) == reverse.components.map(\.hours))
        #expect(forward.components.map(\.workIntervalID) == reverse.components.map(\.workIntervalID))
        #expect(try forward.components.reduce(Money.zero(currencyCode: "USD")) {
            try $0.adding($1.amount)
        } == forward.total)
    }

    @Test func dailyOvertimeResetsAtMidnight() throws {
        let shift = try work((2026, 8, 3, 16, 0), (2026, 8, 4, 8, 0))
        let result = try PayCalculator().calculate(work: [shift],
            agreement: agreement(dailyOvertimeTiers: [DailyOvertimeTier(afterHours: 8, multiplier: 2)]),
            policy: .highestApplicable)
        #expect(result.total.amount == 160)
        #expect(result.components.count == 2)
        #expect(result.components.allSatisfy { $0.multiplier == 1 })
    }

    @Test func actualCalloutBreakAndGuaranteedPayStaySeparate() throws {
        let pause = try WorkBreak(startEpochSeconds: 3_600, endEpochSeconds: 5_400)
        let shift = try WorkInterval(startEpochSeconds: 0, endEpochSeconds: 7_200,
                                     timeZoneIdentifier: "UTC", kind: .callout, unpaidBreaks: [pause])
        let rules = try agreement(hourlyRate: "40", calloutMinimum: CalloutMinimumRule(minimumHours: 4))
        let result = try PayCalculator().calculate(work: [shift], agreement: rules, policy: .highestApplicable)
        #expect(shift.durationHours == decimal("1.5"))
        #expect(result.total.amount == 160)
        #expect(result.components.filter { $0.category == .workedHours }.reduce(Decimal(0)) { $0 + ($1.hours ?? 0) } == decimal("1.5"))
        #expect(result.components.first { $0.category == .calloutGuarantee }?.hours == decimal("2.5"))
    }

    @Test func ordinaryWorkNeverReceivesCalloutGuarantee() throws {
        let shift = try work((2026, 8, 3, 8, 0), (2026, 8, 3, 9, 0), kind: .other)
        let result = try PayCalculator().calculate(work: [shift],
            agreement: agreement(calloutMinimum: CalloutMinimumRule(minimumHours: 4)), policy: .highestApplicable)
        #expect(result.total.amount == 10)
        #expect(!result.components.contains { $0.category == .calloutGuarantee })
    }

    @Test func breakCoveringMidnightDoesNotCreatePhantomWorkDate() throws {
        let start = epoch(year: 2026, month: 8, day: 3, hour: 22, timeZoneIdentifier: "UTC")
        let pause = try WorkBreak(startEpochSeconds: start + 7_200, endEpochSeconds: start + 14_400)
        let shift = try WorkInterval(startEpochSeconds: start, endEpochSeconds: start + 14_400,
                                     timeZoneIdentifier: "UTC", unpaidBreaks: [pause])
        let result = try PayCalculator().calculate(work: [shift],
            agreement: agreement(flatPerDiem: FlatPerDiemRule(amountPerWorkDate: Money(amount: 100, currencyCode: "USD"))), policy: .highestApplicable)
        #expect(result.total.amount == 120)
        #expect(result.components.filter { $0.category == .perDiem }.count == 1)
    }

    @Test func effectiveDateBoundsAreInclusive() throws {
        let date = LocalDate(year: 2026, month: 8, day: 3)
        let rules = try agreement(effectiveStart: date, effectiveEnd: date)
        let valid = try work((2026, 8, 3, 0, 0), (2026, 8, 4, 0, 0))
        let result = try PayCalculator().calculate(work: [valid], agreement: rules, policy: .highestApplicable)
        #expect(result.total.amount == 240)
        let invalid = try work((2026, 8, 3, 23, 0), (2026, 8, 4, 1, 0))
        #expect(throws: PayCalculationError.workOutsideAgreementEffectiveDates(LocalDate(year: 2026, month: 8, day: 4))) {
            try PayCalculator().calculate(work: [invalid], agreement: rules, policy: .highestApplicable)
        }
    }

    @Test func absentScheduleDoesNotInventOutsideHours() throws {
        let shift = try work((2026, 8, 3, 8, 0), (2026, 8, 3, 9, 0))
        let result = try PayCalculator().calculate(work: [shift],
            agreement: agreement(outsideScheduleMultiplier: 3), policy: .highestApplicable)
        #expect(result.total.amount == 10)
    }
}
