import Foundation
import Testing

@testable import LinePayDomain

@Test("Eight scheduled hours pay straight time")
func scheduledStraightTime() throws {
    let rules = try agreement(schedule: weekdaySchedule())
    let shift = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 16, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("80.00"))
    #expect(result.components.count == 1)
    #expect(result.components[0].multiplier == 1)
}

@Test("Hours outside confirmed regular schedule receive configured premium")
func outsideSchedulePremium() throws {
    let rules = try agreement(
        schedule: weekdaySchedule(),
        outsideScheduleMultiplier: 2
    )
    let shift = try work((2026, 9, 7, 16, 0), (2026, 9, 7, 18, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("40.00"))
    #expect(result.components[0].multiplier == 2)
}

@Test("Work spanning schedule boundary is split into auditable components")
func splitAtScheduleBoundary() throws {
    let rules = try agreement(
        schedule: weekdaySchedule(),
        outsideScheduleMultiplier: 2
    )
    let shift = try work((2026, 9, 7, 14, 0), (2026, 9, 7, 18, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("60.00"))
    #expect(result.components.map(\.hours) == [2, 2])
    #expect(result.components.map(\.multiplier) == [1, 2])
}

@Test("Sunday premium applies even when no schedule is configured")
func sundayPremium() throws {
    let rules = try agreement(
        weekdayPremiums: [try WeekdayPremium(weekday: .sunday, multiplier: 2)]
    )
    let shift = try work((2026, 9, 6, 8, 0), (2026, 9, 6, 12, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("80.00"))
    #expect(result.components[0].multiplier == 2)
}

@Test("Cross-midnight work changes premium at the local calendar boundary")
func crossMidnightSundayTransition() throws {
    let rules = try agreement(
        weekdayPremiums: [try WeekdayPremium(weekday: .sunday, multiplier: 2)]
    )
    let shift = try work((2026, 9, 5, 23, 0), (2026, 9, 6, 1, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("30.00"))
    #expect(result.components.map(\.multiplier) == [1, 2])
}

@Test("Explicit holiday date premium applies")
func holidayPremium() throws {
    let julyFourth = LocalDate(year: 2026, month: 7, day: 4)
    let rules = try agreement(
        datePremiums: [try DatePremium(date: julyFourth, multiplier: 2)]
    )
    let shift = try work((2026, 7, 4, 8, 0), (2026, 7, 4, 16, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("160.00"))
}

@Test("Premiums do not pyramid under highest-applicable policy")
func premiumsDoNotPyramid() throws {
    let sunday = LocalDate(year: 2026, month: 9, day: 6)
    let rules = try agreement(
        outsideScheduleMultiplier: 2,
        weekdayPremiums: [try WeekdayPremium(weekday: .sunday, multiplier: 2)],
        datePremiums: [try DatePremium(date: sunday, multiplier: 2)]
    )
    let shift = try work((2026, 9, 6, 8, 0), (2026, 9, 6, 12, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("80.00"))
    #expect(result.components[0].multiplier == 2)
}

@Test("Short callout is topped up to its minimum at applicable rate")
func calloutMinimum() throws {
    let rules = try agreement(
        schedule: weekdaySchedule(),
        outsideScheduleMultiplier: 2,
        calloutMinimum: try CalloutMinimumRule(minimumHours: 4)
    )
    let callout = try work(
        (2026, 9, 7, 20, 0),
        (2026, 9, 7, 22, 0),
        kind: .callout,
        calloutEventID: UUID()
    )

    let result = try PayCalculator().calculate(
        work: [callout],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("80.00"))
    #expect(result.components.count == 2)
    #expect(result.components.last?.category == .calloutGuarantee)
    #expect(result.components.last?.hours == 2)
    #expect(result.components.last?.multiplier == 2)
}

@Test("Callout longer than minimum receives no guarantee top-up")
func calloutAboveMinimum() throws {
    let rules = try agreement(
        schedule: weekdaySchedule(),
        outsideScheduleMultiplier: 2,
        calloutMinimum: try CalloutMinimumRule(minimumHours: 4)
    )
    let callout = try work(
        (2026, 9, 7, 18, 0),
        (2026, 9, 7, 23, 0),
        kind: .callout,
        calloutEventID: UUID()
    )

    let result = try PayCalculator().calculate(
        work: [callout],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("100.00"))
    #expect(!result.components.contains { $0.category == .calloutGuarantee })
}
