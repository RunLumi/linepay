import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Rule changes between manual pay periods")
@MainActor
struct NoOpenPeriodRuleTests {
    @Test func datedChangeKeepsEarlierRateAcrossSaveReloadAndNextPeriod() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store)
        let archived = model.history
        let baseline = try #require(model.profile?.baselineAgreement)
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        draft.changeEffectiveDate = UnitFixture.start + 4 * 86_400
        let beforePreview = store.state
        let saves = store.saveCount
        _ = try model.previewProfileChange(draft, scope: .prospective)
        #expect(store.state == beforePreview && store.saveCount == saves)
        try model.saveProfile(draft, scope: .prospective)
        #expect(model.activePeriod == nil && model.history == archived)
        #expect(model.profile?.baselineAgreement == baseline)
        #expect(model.profile?.agreementChanges?.count == 1)

        let restored = AppModel(store: store)
        try restored.startNewPayPeriod(
            startDate: UnitFixture.start + 2 * 86_400,
            manualEndDate: UnitFixture.start + 7 * 86_400)
        try restored.addWork(
            start: UnitFixture.start + 2 * 86_400,
            end: UnitFixture.start + 2 * 86_400 + 8 * 3_600, kind: .regular)
        #expect(restored.calculation?.total.amount == 400)
        try restored.addWork(
            start: UnitFixture.start + 4 * 86_400,
            end: UnitFixture.start + 4 * 86_400 + 8 * 3_600, kind: .regular)
        #expect(restored.calculation?.total.amount == 880)
        #expect(restored.calculation?.components.map(\.appliedAgreement?.version) == ["1", "2"])
        #expect(restored.history == archived)
        #expect(AppModel(store: store).calculation?.total.amount == 880)
    }

    @Test func insertionAndReplacementKeepOtherScheduledDates() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store, scheduleLaterRate: true)
        let archived = model.history
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        draft.changeEffectiveDate = UnitFixture.start + 3 * 86_400
        try model.saveProfile(draft)
        draft.hourlyRate = "65"
        try model.saveProfile(draft)
        let changes = try #require(model.profile?.agreementChanges)
        #expect(changes.map(\.agreement.hourlyRate.amount) == [65, 70])
        #expect(changes.map(\.agreement.version) == ["4", "2"])
        #expect(model.profile?.baselineAgreement?.hourlyRate.amount == 50)
        let restored = AppModel(store: store)
        try restored.startNewPayPeriod(
            startDate: UnitFixture.start + 2 * 86_400,
            manualEndDate: UnitFixture.start + 7 * 86_400)
        for day in [2, 3, 5] {
            let start = UnitFixture.start + Double(day) * 86_400
            try restored.addWork(start: start, end: start + 3_600, kind: .regular)
        }
        #expect(restored.calculation?.total.amount == 185)
        #expect(restored.history == archived)
    }

    @Test(arguments: [false, true])
    func effectiveDateFallbackMatchesConsent(_ useEffectiveStart: Bool) throws {
        let model = try closedManualPeriod(store: UnitStateStore())
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        draft.periodStartDate = UnitFixture.start + 3 * 86_400
        draft.useEffectiveStart = useEffectiveStart
        draft.effectiveStartDate = UnitFixture.start + 4 * 86_400
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date = useEffectiveStart ? draft.effectiveStartDate : draft.periodStartDate
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let expected = LocalDate(
            year: try #require(parts.year), month: try #require(parts.month),
            day: try #require(parts.day))
        try model.saveProfile(draft, scope: .prospective)
        #expect(model.profile?.agreementChanges?.first?.effectiveDate == expected)
        #expect(model.profile?.baselineAgreement?.hourlyRate.amount == 50)
    }

    @Test func correctionWithoutOpenPeriodCannotSilentlyChangeBaseline() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store)
        let before = store.state
        let saves = store.saveCount
        #expect(throws: AppModelError.missingActivePayPeriod) {
            try model.saveProfile(
                UnitFixture.profile(rate: "60", cadence: .manual), scope: .correctCurrentPeriod)
        }
        #expect(store.state == before && store.saveCount == saves)
    }

    @Test func datedTimezoneChangeIsRejectedWithoutMutatingTheTimeline() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store)
        let before = store.state
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        draft.changeEffectiveDate = UnitFixture.start + 4 * 86_400
        draft.timeZoneIdentifier = "America/Los_Angeles"
        #expect(throws: (any Error).self) { try model.saveProfile(draft, scope: .prospective) }
        #expect(store.state == before && model.currentTimeZoneIdentifier == "UTC")
    }

    @Test func backdatedChangeCannotClaimToStartBeforeArchivedWork() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store)
        let before = store.state
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        draft.changeEffectiveDate = UnitFixture.start
        #expect(throws: AppModelError.prospectiveChangeTouchesRecordedWork) {
            try model.saveProfile(draft, scope: .prospective)
        }
        #expect(store.state == before)
    }

    @Test func datedChangeCannotClaimToStartInsideAnArchivedWindow() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store)
        let before = store.state
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        // The archived manual period covers days 0 and 1, although work exists only on day 0.
        draft.changeEffectiveDate = UnitFixture.start + 86_400
        #expect(throws: AppModelError.prospectiveChangeTouchesRecordedWork) {
            try model.saveProfile(draft, scope: .prospective)
        }
        #expect(store.state == before)

        // Its exclusive end is the first date that can truthfully begin a new rule timeline.
        draft.changeEffectiveDate = UnitFixture.start + 2 * 86_400
        try model.saveProfile(draft, scope: .prospective)
        #expect(
            model.profile?.agreementChanges?.first?.effectiveDate
                == LocalDate(
                    year: 2026, month: 8, day: 9))
    }

    @Test func failedSaveKeepsBaselineScheduledDatesAndHistory() throws {
        let store = UnitStateStore()
        let model = try closedManualPeriod(store: store, scheduleLaterRate: true)
        let before = store.state
        let oldProfile = model.profile
        let history = model.history
        var draft = UnitFixture.profile(rate: "60", cadence: .manual)
        draft.editScope = .datedChange
        draft.changeEffectiveDate = UnitFixture.start + 3 * 86_400
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) { try model.saveProfile(draft) }
        #expect(store.state == before && model.profile == oldProfile && model.history == history)
    }

    @Test func undatedFuturePeriodEditStillAppliesToTheNextManualPeriod() throws {
        let model = try closedManualPeriod(store: UnitStateStore())
        let archived = model.history
        try model.saveProfile(
            UnitFixture.profile(rate: "60", cadence: .manual), scope: .futurePeriods)
        try model.startNewPayPeriod(
            startDate: UnitFixture.start + 2 * 86_400,
            manualEndDate: UnitFixture.start + 4 * 86_400)
        let start = UnitFixture.start + 2 * 86_400
        try model.addWork(start: start, end: start + 8 * 3_600, kind: .regular)
        #expect(model.calculation?.total.amount == 480 && model.history == archived)
    }

    private func closedManualPeriod(
        store: UnitStateStore, scheduleLaterRate: Bool = false
    ) throws -> AppModel {
        let model = AppModel(store: store)
        var profile = UnitFixture.profile(cadence: .manual)
        // The manual end date is inclusive. Close two calendar days, then start at day +2.
        profile.manualPeriodEndDate = UnitFixture.start + 86_400
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start + 8 * 3_600, kind: .regular)
        if scheduleLaterRate {
            var draft = UnitFixture.profile(rate: "70", cadence: .manual)
            draft.changeEffectiveDate = UnitFixture.start + 5 * 86_400
            try model.saveProfile(draft)
        }
        try model.archiveCurrentPeriod()
        #expect(model.activePeriod == nil && model.history.count == 1)
        return model
    }
}
