import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Rule scope: prospective dates and explicit corrections")
@MainActor
struct RuleScopeRegressionTests {
    @Test(arguments: ["60", "40"])
    func prospectiveChangePreservesEarlierWorkAndPricesLaterWork(_ rate: String) throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let oldWork = model.workEntries
        let oldRule = try #require(model.activePeriod?.agreement)
        var draft = UnitFixture.profile(rate: rate)
        draft.useEffectiveStart = true
        draft.effectiveStartDate = UnitFixture.start.addingTimeInterval(86_400)
        try model.saveProfile(draft)
        #expect(model.calculation?.total.amount == 400)
        #expect(model.workEntries == oldWork && model.activePeriod?.agreement == oldRule)
        let tomorrow = UnitFixture.start.addingTimeInterval(86_400)
        try model.addWork(
            start: tomorrow, end: tomorrow.addingTimeInterval(8 * 3_600), kind: .regular)
        let expected = 400 + (try UnitFixture.decimal(rate)) * 8
        #expect(model.calculation?.total.amount == expected)
        #expect(model.calculation?.components.map(\.appliedAgreement?.version) == ["1", "2"])
        let reloaded = AppModel(store: store)
        #expect(reloaded.calculation?.total.amount == expected)
        #expect(reloaded.activePeriod?.agreementChanges == model.activePeriod?.agreementChanges)
    }

    @Test func oldWorkCanBeEditedWithoutBeingRepricedByNewRate() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "60")
        draft.changeEffectiveDate = UnitFixture.start.addingTimeInterval(86_400)
        try model.saveProfile(draft)
        let first = try #require(model.workEntries.first)
        try model.updateWork(
            id: first.id, start: UnitFixture.start,
            end: UnitFixture.start.addingTimeInterval(7 * 3_600), kind: .regular)
        #expect(model.calculation?.total.amount == 350)
        #expect(model.calculation?.components.first?.appliedAgreement?.version == "1")
    }

    @Test func previewIsReadOnlyAndCorrectionIsExplicit() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let before = store.state
        let saves = store.saveCount
        let draft = UnitFixture.profile(rate: "60")
        let prospective = try model.previewProfileChange(draft, scope: .prospective)
        #expect(prospective.before?.amount == 400 && prospective.after?.amount == 400)
        let correction = try model.previewProfileChange(draft, scope: .correctCurrentPeriod)
        #expect(correction.before?.amount == 400 && correction.after?.amount == 480)
        #expect(correction.workCount == 1)
        #expect(store.state == before && store.saveCount == saves)
        try model.saveProfile(draft, scope: .correctCurrentPeriod)
        #expect(model.calculation?.total.amount == 480)
        #expect(model.currentPaystub != nil && model.reconciliation == nil)
        #expect(model.currentAuditStatus == .needsReview)
    }

    @Test func scheduleKeepsCompletedAuditValidUntilWorkActuallyChanges() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let old = model.reconciliation
        try model.saveProfile(UnitFixture.profile(rate: "60"))
        #expect(model.reconciliation == old && model.currentAuditStatus == .grossMatches)
        #expect(model.calculation?.total.amount == 400)
        try model.archiveCurrentPeriod()
        let history = try #require(model.history.first)
        let calculation = try #require(history.calculation)
        #expect(calculation.total.amount == 400 && history.agreement.hourlyRate.amount == 50)
        let next = try #require(model.activePeriod)
        try model.addWork(
            start: next.window.startDate,
            end: next.window.startDate.addingTimeInterval(8 * 3_600), kind: .regular)
        #expect(model.calculation?.total.amount == 480)
        try model.saveProfile(UnitFixture.profile(rate: "75"), scope: .correctCurrentPeriod)
        #expect(model.history.first == history)
    }

    @Test func prospectiveEditCannotTouchAnOvernightTail() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try model.saveProfile(UnitFixture.profile())
        let boundary = try nextMidnight()
        try model.addWork(
            start: boundary.addingTimeInterval(-3_600),
            end: boundary.addingTimeInterval(3_600), kind: .regular)
        let before = store.state
        var draft = UnitFixture.profile(rate: "60")
        draft.changeEffectiveDate = boundary
        #expect(throws: AppModelError.prospectiveChangeTouchesRecordedWork) {
            try model.saveProfile(draft)
        }
        #expect(store.state == before && model.calculation?.total.amount == 100)
    }

    @Test func failedSaveDoesNotInstallRuleTimeline() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.saveProfile(UnitFixture.profile(rate: "60"))
        }
        #expect(store.state == before && model.activePeriod?.agreementChanges == nil)
        #expect(model.calculation?.total.amount == 400)
    }

    @Test func insertedAndReplacedScheduledDatesKeepUniqueVersions() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "70")
        draft.changeEffectiveDate = UnitFixture.start.addingTimeInterval(3 * 86_400)
        try model.saveProfile(draft)
        draft.hourlyRate = "60"
        draft.changeEffectiveDate = UnitFixture.start.addingTimeInterval(86_400)
        try model.saveProfile(draft)
        draft.hourlyRate = "65"
        try model.saveProfile(draft)
        let changes = try #require(model.activePeriod?.agreementChanges)
        #expect(changes.map(\.agreement.version) == ["4", "2"])
        #expect(changes.map(\.agreement.hourlyRate.amount) == [65, 70])
        #expect(model.calculation?.total.amount == 400)
    }

    @Test func ambiguousCalloutRetainsFactsWithoutInventingPayOrConsumingAudit() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        var draft = UnitFixture.profile()
        draft.useCalloutMinimum = true
        draft.calloutMinimumHours = "4"
        try model.saveProfile(draft)
        let boundary = try nextMidnight()
        draft.hourlyRate = "60"
        draft.changeEffectiveDate = boundary
        try model.saveProfile(draft)
        try model.addWork(
            start: boundary.addingTimeInterval(-3_600),
            end: boundary.addingTimeInterval(3_600), kind: .callout)
        #expect(model.totalHours == 2 && model.workEntries.count == 1)
        #expect(
            model.calculation == nil
                && model.calculationError?.contains("Your work is saved") == true)
        #expect(throws: AppModelError.calculationUnavailable) {
            try model.confirmPaystub(UnitFixture.paystub(model))
        }
        #expect(!model.hasUsedFreeAudit && model.currentPaystub == nil)
        #expect(AppModel(store: store).workEntries == model.workEntries)

        try model.archiveCurrentPeriod()
        let archived = try #require(model.history.first)
        #expect(archived.calculation == nil)
        #expect(archived.calculationIssue?.isEmpty == false)
        #expect(model.activePeriod != nil)
        try model.addWork(
            start: model.activePeriod!.window.startDate,
            end: model.activePeriod!.window.startDate.addingTimeInterval(3_600),
            kind: .regular)
        #expect(model.workEntries.count == 1)
    }

    @Test(arguments: [RuleChangeScope.prospective, .correctCurrentPeriod])
    func openPeriodTimeZoneChangeIsRejectedAtomically(_ scope: RuleChangeScope) throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        let saveCount = store.saveCount
        var draft = UnitFixture.profile()
        draft.timeZoneIdentifier = "America/New_York"
        #expect(throws: (any Error).self) {
            try model.saveProfile(draft, scope: scope)
        }
        #expect(store.state == before && store.saveCount == saveCount)
        #expect(model.currentTimeZoneIdentifier == "UTC")
        #expect(model.calculation?.total.amount == 400)
    }

    private func nextMidnight() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        // UnitFixture.start is 08:00, not midnight. Anchor boundary tests to the calendar.
        let midnight = calendar.startOfDay(for: UnitFixture.start)
        return try #require(calendar.date(byAdding: .day, value: 1, to: midnight))
    }
}
