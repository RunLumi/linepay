import Foundation
import Testing

@testable import LinePayDomain

private let californiaOutsideLineURL = [
    "https://ibew1245.com/wp-content/uploads/2022/06/",
    "California-Outside-Line-Construction-Agreement-2022-2027-signed.pdf",
].joined()

private func californiaOutsideLine2026() throws -> AgreementSnapshot {
    let schedule = try weekdaySchedule(startHour: 7, endHour: 15)
    let weekendPremiums = try [
        WeekdayPremium(weekday: .saturday, multiplier: 2),
        WeekdayPremium(weekday: .sunday, multiplier: 2),
    ]

    return try AgreementSnapshot(
        id: "ibew-47-1245-ca-outside-line",
        version: "2026-06-01",
        displayName: "California Outside Line Construction Agreement",
        effectiveStart: LocalDate(year: 2026, month: 6, day: 1),
        effectiveEnd: LocalDate(year: 2027, month: 5, day: 31),
        hourlyRate: Money(amount: decimal("74.43"), currencyCode: "USD"),
        regularSchedule: schedule,
        outsideScheduleMultiplier: 2,
        weekdayPremiums: weekendPremiums,
        calloutMinimum: try CalloutMinimumRule(minimumHours: 4),
        sources: [
            AgreementSource(
                title: "California Outside Line Construction Agreement 2022-2027",
                url: californiaOutsideLineURL,
                section: "4.6 Minimum Call Out; 4.10 Holidays and Overtime; Exhibit A"
            )
        ]
    )
}

@Test("CA 2026 fixture: eight confirmed scheduled hours use $74.43 straight rate")
func californiaRegularDay() throws {
    let rules = try californiaOutsideLine2026()
    let shift = try work((2026, 9, 8, 7, 0), (2026, 9, 8, 15, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("595.44"))
}

@Test("CA 2026 fixture: Saturday work is double straight time")
func californiaSaturdayDoubleTime() throws {
    let rules = try californiaOutsideLine2026()
    let shift = try work((2026, 9, 5, 7, 0), (2026, 9, 5, 15, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("1190.88"))
    #expect(result.components.allSatisfy { $0.multiplier == 2 })
}

@Test("CA 2026 fixture: Sunday work is double straight time")
func californiaSundayDoubleTime() throws {
    let rules = try californiaOutsideLine2026()
    let shift = try work((2026, 9, 6, 7, 0), (2026, 9, 6, 15, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("1190.88"))
}

@Test("CA 2026 fixture: work outside confirmed regular hours is double time")
func californiaOutsideScheduleDoubleTime() throws {
    let rules = try californiaOutsideLine2026()
    let shift = try work((2026, 9, 8, 20, 0), (2026, 9, 8, 22, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("297.72"))
    #expect(result.components[0].multiplier == 2)
}

@Test("CA 2026 fixture: two-hour night callout is paid to four-hour minimum")
func californiaCalloutMinimum() throws {
    let rules = try californiaOutsideLine2026()
    let callout = try work(
        (2026, 9, 8, 20, 0),
        (2026, 9, 8, 22, 0),
        kind: .callout,
        calloutEventID: UUID()
    )

    let result = try PayCalculator().calculate(
        work: [callout],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("595.44"))
    #expect(result.components.last?.category == .calloutGuarantee)
    #expect(result.components.last?.hours == 2)
}

@Test("CA 2026 fixture: weekend and outside-schedule premiums do not pyramid")
func californiaNoPyramiding() throws {
    let rules = try californiaOutsideLine2026()
    let shift = try work((2026, 9, 5, 20, 0), (2026, 9, 5, 22, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("297.72"))
    #expect(result.components[0].multiplier == 2)
}
