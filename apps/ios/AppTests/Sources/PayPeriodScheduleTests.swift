import Foundation
import Testing

@testable import LinePay

@Suite("Calendar paycycles")
@MainActor
struct PayPeriodScheduleTests {
    @Test(arguments: [
        (2026, 1, 1, 2026, 1, 16),
        (2026, 1, 16, 2026, 2, 1),
        (2026, 2, 16, 2026, 3, 1),
        (2028, 2, 16, 2028, 3, 1),
        (2026, 4, 16, 2026, 5, 1),
        (2026, 12, 16, 2027, 1, 1),
    ])
    func twiceMonthlyUsesConfirmedCalendarBoundaries(
        _ year: Int, _ month: Int, _ day: Int,
        _ endYear: Int, _ endMonth: Int, _ endDay: Int
    ) throws {
        let calendar = try calendar("UTC")
        let start = try date(year, month, day, in: calendar)
        let window = try PayPeriodSchedule.window(
            cadence: .semimonthly, startDate: start, manualEndDate: start,
            timeZoneIdentifier: "UTC")
        #expect(window.endDate == (try date(endYear, endMonth, endDay, in: calendar)))
        #expect(window.startDate == start)
        #expect(window.displayEndDate.addingTimeInterval(1) == window.endDate)
    }

    @Test(arguments: [(3, 1, 359), (11, 1, 361)])
    func twiceMonthlyPreservesLocalMidnightAcrossDST(_ month: Int, _ day: Int, _ hours: Int)
        throws
    {
        let calendar = try calendar("America/Los_Angeles")
        let start = try date(2026, month, day, in: calendar)
        let window = try PayPeriodSchedule.window(
            cadence: .semimonthly, startDate: start, manualEndDate: start,
            timeZoneIdentifier: calendar.timeZone.identifier)
        #expect(window.endDate == (try date(2026, month, 16, in: calendar)))
        #expect(window.endEpochSeconds - window.startEpochSeconds == Int64(hours * 3_600))
    }

    @Test(arguments: [2, 15, 17, 31])
    func unsupportedCutoffsFailWithoutSaving(_ day: Int) throws {
        let model = AppModel(store: UnitStateStore())
        var draft = UnitFixture.profile(cadence: .semimonthly)
        draft.periodStartDate = try date(2026, 1, day, in: calendar("UTC"))
        #expect(throws: AppModelError.invalidPayPeriod) { try model.saveProfile(draft) }
        #expect(model.profile == nil)
        #expect(model.activePeriod == nil)
    }

    @Test func archiveContinuesIntoNextHalfAndRestoresWithoutRewritingHistory() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        let calendar = try calendar("UTC")
        var draft = UnitFixture.profile(cadence: .semimonthly)
        draft.periodStartDate = try date(2028, 2, 16, in: calendar)
        try model.saveProfile(draft)
        let original = try #require(model.activePeriod)
        try model.archiveCurrentPeriod()
        #expect(model.activePeriod?.window.startDate == (try date(2028, 3, 1, in: calendar)))
        #expect(model.activePeriod?.window.endDate == (try date(2028, 3, 16, in: calendar)))
        #expect(model.history.first?.window == original.window)
        #expect(model.history.first?.agreement == original.agreement)
        let saved = try #require(store.state)
        let bytes = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(AppPersistentState.self, from: bytes)
        #expect(restored == saved)
        try AppStateValidation.validate(restored)
    }

    @Test func cadenceEditDoesNotInventPartialCycleOrPreventClosing() throws {
        let model = AppModel(store: UnitStateStore())
        try model.saveProfile(UnitFixture.profile())
        let original = try #require(model.activePeriod)
        var edited = PayProfileDraft(profile: try #require(model.profile), activePeriod: original)
        edited.preferredCadence = .semimonthly
        try model.saveProfile(edited, scope: .futurePeriods)
        try model.archiveCurrentPeriod()
        #expect(model.activePeriod == nil)
        #expect(model.history.first?.window == original.window)
        let calendar = try calendar("UTC")
        try model.startNewPayPeriod(startDate: date(2026, 8, 16, in: calendar))
        #expect(model.activePeriod?.window.endDate == (try date(2026, 9, 1, in: calendar)))
    }

    @Test func existingCadenceWireValuesRemainStable() throws {
        for cadence in [PayPeriodCadence.weekly, .biweekly, .manual] {
            let data = Data("\"\(cadence.rawValue)\"".utf8)
            #expect(try JSONDecoder().decode(PayPeriodCadence.self, from: data) == cadence)
        }
    }

    private func calendar(_ zone: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
