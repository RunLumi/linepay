import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Weekly regular-rate application boundaries")
@MainActor
struct WeeklyRegularRateAppTests {
    private let start = Date(timeIntervalSince1970: 1_788_739_200)

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
            weekStart: start, completeWorkweek: true,
            straightTimeRemuneration: Money(amount: 2400, currencyCode: "USD"),
            remunerationComplete: true, workweekBoundaryConfirmed: true)
        #expect(result.qualifyingHours == 48)
        #expect(result.remainingAdditionalPremium.amount == 200)
        #expect(result.expectedCash.amount == 2_600)
        #expect(result.allocations.count == 2)
        let before = model.activePeriod
        let premium = try WeeklyRemunerationFact(
            amount: Money(amount: 240, currencyCode: "USD"),
            kind: .extraPremium, premiumCredit: .ineligible)
        let withPremium = try model.calculateWeeklyRegularRate(
            weekStart: start, completeWorkweek: true,
            straightTimeRemuneration: Money(amount: 2400, currencyCode: "USD"),
            additionalRemuneration: [premium], remunerationComplete: true,
            workweekBoundaryConfirmed: true)
        #expect(
            withPremium.includableRemuneration.amount == 2640
                && withPremium.expectedCash.amount == 2860)
        #expect(model.activePeriod == before)
        #expect(throws: WeeklyRegularRateError.workweekBoundaryUnconfirmed) {
            try model.calculateWeeklyRegularRate(
                weekStart: start, completeWorkweek: true,
                straightTimeRemuneration: Money(amount: 2400, currencyCode: "USD"),
                remunerationComplete: true)
        }
        #expect(throws: WeeklyRegularRateError.remunerationIncomplete) {
            try model.calculateWeeklyRegularRate(
                weekStart: start, completeWorkweek: true, workweekBoundaryConfirmed: true)
        }
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

    @Test("Weekly review includes the underlying calculation failure")
    func weeklyErrorCopyIncludesReason() {
        let error = WeeklyRegularRateError.incompleteWorkweek
        let expected =
            "Needs review: The selected workweek is not complete. "
            + "Confirm all work in this week before calculating."
        let message = WeeklyOvertimeReviewView.errorMessage(for: error)
        #expect(
            message == expected
        )
        #expect(!message.contains("(error.localizedDescription)"))
    }

    @Test func aShiftCrossingTheWorkweekIsClippedWithoutRewritingItsSavedFacts() throws {
        let model = AppModel(store: UnitStateStore())
        var profile = UnitFixture.profile(cadence: .manual)
        profile.periodStartDate = start.addingTimeInterval(-86_400)
        profile.manualPeriodEndDate = start.addingTimeInterval(7 * 86_400)
        profile.useWeeklyOvertime = true
        profile.weeklyApplicabilityConfirmed = true
        try model.saveProfile(profile)
        try model.addWork(
            start: start.addingTimeInterval(-3_600),
            end: start.addingTimeInterval(4 * 3_600), kind: .regular)
        let original = model.activePeriod
        let result = try model.calculateWeeklyRegularRate(
            weekStart: start, completeWorkweek: true,
            straightTimeRemuneration: Money(amount: 200, currencyCode: "USD"),
            remunerationComplete: true, workweekBoundaryConfirmed: true)
        #expect(result.qualifyingHours == 4 && result.expectedCash.amount == 200)
        #expect(model.activePeriod == original && model.workIntervals.first?.durationHours == 5)
    }
}
