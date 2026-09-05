import Foundation
import Testing

@testable import LinePayDomain

@Suite("Remaining calendar and schedule boundaries")
struct AdditionalBoundaryTests {
    @Test func shiftCrossingScheduleStartSplitsOutsideAndInsidePay() throws {
        let rules = try agreement(schedule: weekdaySchedule(), outsideScheduleMultiplier: 2)
        let shift = try work((2026, 8, 3, 6, 0), (2026, 8, 3, 10, 0))
        let result = try PayCalculator().calculate(
            work: [shift], agreement: rules, policy: .highestApplicable)
        #expect(result.total.amount == 60)
        #expect(result.components.map(\.hours) == [2, 2])
        #expect(result.components.map(\.multiplier) == [2, 1])
        #expect(result.components.allSatisfy { $0.workIntervalID == shift.id })
        #expect(result.components[0].explanation != result.components[1].explanation)
    }

    @Test func sameLocalDateInDifferentPayrollZonesHasIndependentPerDiem() throws {
        let a = try work((2026, 8, 3, 1, 0), (2026, 8, 3, 2, 0), timeZoneIdentifier: "Asia/Tokyo")
        let b = try work(
            (2026, 8, 3, 1, 0), (2026, 8, 3, 2, 0), timeZoneIdentifier: "America/Los_Angeles")
        let rules = try agreement(
            flatPerDiem: FlatPerDiemRule(amountPerWorkDate: Money(amount: 25, currencyCode: "USD")))
        let result = try PayCalculator().calculate(
            work: [b, a], agreement: rules, policy: .highestApplicable)
        #expect(result.total.amount == 70)
        let allowances = result.components.filter { $0.category == .perDiem }
        #expect(allowances.count == 2)
        #expect(allowances.allSatisfy { $0.localDate == LocalDate(year: 2026, month: 8, day: 3) })
    }

    @Test func invalidDecodedTimeZoneStillFailsAtCalculationBoundary() throws {
        let valid = try work((2026, 8, 3, 1, 0), (2026, 8, 3, 2, 0))
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        object["timeZoneIdentifier"] = "Invalid/Imported-Zone"
        let decoded = try JSONDecoder().decode(
            WorkInterval.self, from: JSONSerialization.data(withJSONObject: object))
        let rules = try agreement()
        #expect(throws: DomainValidationError.invalidTimeZone("Invalid/Imported-Zone")) {
            try PayCalculator().calculate(
                work: [decoded], agreement: rules, policy: .highestApplicable)
        }
    }

    @Test func adjacentSchedulesDoNotInventAnOutsideMinute() throws {
        let windows = try [
            RegularScheduleWindow(
                weekday: .monday, start: LocalTime(hour: 8, minute: 0),
                end: LocalTime(hour: 12, minute: 0)),
            RegularScheduleWindow(
                weekday: .monday, start: LocalTime(hour: 12, minute: 0),
                end: LocalTime(hour: 16, minute: 0)),
        ]
        let rules = try agreement(schedule: windows, outsideScheduleMultiplier: 2)
        let shift = try work((2026, 8, 3, 11, 59), (2026, 8, 3, 12, 1))
        let result = try PayCalculator().calculate(
            work: [shift], agreement: rules, policy: .highestApplicable)
        #expect(result.components.count == 2)
        #expect(result.components.allSatisfy { $0.multiplier == 1 })
        // Each one-minute component rounds independently: 10 / 60 -> 0.17, twice.
        #expect(result.total.amount == decimal("0.34"))
    }
}
