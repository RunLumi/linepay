import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Weekly regular-rate application boundaries")
@MainActor
struct WeeklyRegularRateAppTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A complete workweek can span two stored pay periods")
    func completeWeekAcrossPayPeriods() throws {
        let model = AppModel()
        var profile = PayProfileDraft()
        profile.name = "Weekly synthetic"
        profile.hourlyRate = "50"
        profile.timeZoneIdentifier = "UTC"
        profile.preferredCadence = .manual
        profile.periodStartDate = start
        profile.manualPeriodEndDate = start.addingTimeInterval(3 * 86_400)
        profile.useWeeklyOvertime = true
        profile.weeklyWorkweekStart = .monday
        profile.weeklyApplicabilityConfirmed = true
        try model.saveProfile(profile)

        for day in 0..<4 {
            let shift = start.addingTimeInterval(TimeInterval(day) * 86_400 + 8 * 3_600)
            try model.addWork(
                start: shift, end: shift.addingTimeInterval(8 * 3_600), kind: .regular)
        }
        try model.archiveCurrentPeriod()
        try model.startNewPayPeriod(
            startDate: start.addingTimeInterval(4 * 86_400),
            manualEndDate: start.addingTimeInterval(6 * 86_400))
        for day in 4..<6 {
            let shift = start.addingTimeInterval(TimeInterval(day) * 86_400 + 8 * 3_600)
            try model.addWork(
                start: shift, end: shift.addingTimeInterval(8 * 3_600), kind: .regular)
        }

        let result = try model.calculateWeeklyRegularRate(
            weekStart: start, completeWorkweek: true)
        #expect(result.qualifyingHours == 48)
        #expect(result.remainingAdditionalPremium.amount == 200)
        #expect(result.expectedCash.amount == 2_600)
        #expect(result.allocations.count == 2)
    }

    @Test("The application does not turn an incomplete week into zero entitlement")
    func incompleteWeekFailsClosed() throws {
        let model = AppModel()
        var profile = PayProfileDraft()
        profile.name = "Weekly synthetic"
        profile.hourlyRate = "50"
        profile.timeZoneIdentifier = "UTC"
        profile.useWeeklyOvertime = true
        profile.weeklyApplicabilityConfirmed = true
        try model.saveProfile(profile)
        #expect(throws: WeeklyRegularRateError.incompleteWorkweek) {
            try model.calculateWeeklyRegularRate(weekStart: start, completeWorkweek: false)
        }
    }
}
