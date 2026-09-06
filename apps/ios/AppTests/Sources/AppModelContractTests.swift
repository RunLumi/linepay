import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Application inputs and atomic mutations")
@MainActor
struct AppModelContractTests {
    @Test(arguments: ["", "0", "-1", "NaN", "1e3", "50,25", "1.2.3", "50junk"])
    func invalidRateDoesNotCreateProfile(_ value: String) {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        #expect(throws: (any Error).self) {
            try model.saveProfile(UnitFixture.profile(rate: value))
        }
        #expect(!model.isOnboarded && model.profile == nil && model.activePeriod == nil)
        #expect(store.saveCount == 0)
    }

    @Test(arguments: ["50.25", "$50.25", " 50.25\n"])
    func acceptedDecimalInput(_ value: String) throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile(rate: value))
        #expect(model.profile?.agreement.hourlyRate.amount == (try UnitFixture.decimal("50.25")))
    }

    @Test(arguments: [
        "name", "timezone", "weekdays", "overtime", "sunday", "callout", "perdiem", "effective",
    ])
    func invalidProfileFieldIsAtomic(_ field: String) throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        var draft = UnitFixture.profile()
        switch field {
        case "name": draft.name = " \n "
        case "timezone": draft.timeZoneIdentifier = "Invalid/Timezone"
        case "weekdays":
            draft.useRegularSchedule = true
            draft.regularWeekdays = []
        case "overtime":
            draft.useDailyOvertime = true
            draft.overtimeAfterHours = "-1"
        case "sunday":
            draft.useSundayPremium = true
            draft.sundayMultiplier = "0.5"
        case "callout":
            draft.useCalloutMinimum = true
            draft.calloutMinimumHours = "0"
        case "perdiem":
            draft.usePerDiem = true
            draft.perDiemAmount = "-1"
        default:
            draft.useEffectiveStart = true
            draft.useEffectiveEnd = true
            draft.effectiveStartDate = UnitFixture.start.addingTimeInterval(86_400)
            draft.effectiveEndDate = UnitFixture.start
        }
        #expect(throws: (any Error).self) { try model.saveProfile(draft) }
        #expect(store.state == before)
        #expect(model.calculation?.total.amount == 400)
    }

    @Test func profileDraftRoundTripsConfiguredFields() throws {
        let model = AppModel()
        var draft = UnitFixture.profile()
        draft.name = "  Crew A  "
        draft.useDailyOvertime = true
        draft.overtimeAfterHours = "8"
        draft.overtimeMultiplier = "1.5"
        draft.useSundayPremium = true
        draft.sundayMultiplier = "2"
        draft.useCalloutMinimum = true
        draft.calloutMinimumHours = "4"
        draft.usePerDiem = true
        draft.perDiemAmount = "100"
        draft.useEffectiveStart = true
        draft.effectiveStartDate = UnitFixture.start
        draft.useEffectiveEnd = true
        draft.effectiveEndDate = UnitFixture.start.addingTimeInterval(86_400)
        draft.sourceTitle = " Synthetic agreement "
        draft.sourceSection = " §1 "
        draft.sourceURL = "https://example.invalid/contract"
        draft.datePremiums = [DatePremiumDraft(date: UnitFixture.start, multiplier: "3")]
        try model.saveProfile(draft)
        let profile = try #require(model.profile)
        let restored = PayProfileDraft(profile: profile, activePeriod: model.activePeriod)
        #expect(restored.name == "Crew A")
        #expect(restored.useDailyOvertime && restored.overtimeMultiplier == "1.5")
        #expect(restored.useSundayPremium && restored.sundayMultiplier == "2")
        #expect(restored.useCalloutMinimum && restored.calloutMinimumHours == "4")
        #expect(restored.usePerDiem && restored.perDiemAmount == "100")
        #expect(restored.useEffectiveStart && restored.useEffectiveEnd)
        #expect(restored.sourceTitle == "Synthetic agreement")
        #expect(restored.datePremiums.first?.multiplier == "3")
        #expect(profile.agreement.sources.first?.section == "§1")
    }

    @Test func saveFailureDoesNotChangeStateAndNextSaveRecovers() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.saveProfile(UnitFixture.profile(rate: "75"))
        }
        #expect(store.state == before && model.profile?.agreement.hourlyRate.amount == 50)
        let entry = try #require(model.workEntries.first)
        #expect(model.deleteWork(id: entry.id) == nil)
        #expect(model.workEntries.count == 1 && model.lastPersistenceError != nil)
        store.failSave = false
        try model.updateWork(
            id: entry.id, start: UnitFixture.start,
            end: UnitFixture.start.addingTimeInterval(9 * 3_600), kind: .other, note: "  amended  ")
        #expect(model.totalHours == 9 && model.calculation?.total.amount == 450)
        #expect(model.workEntries.first?.note == "amended" && model.lastPersistenceError == nil)
    }

    @Test func workGuardsAndUndoAreSafe() throws {
        let model = AppModel()
        #expect(throws: AppModelError.missingActivePayPeriod) {
            try model.addWork(
                start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(60),
                kind: .regular)
        }
        try UnitFixture.populate(model)
        #expect(model.deleteWork(id: UUID()) == nil)
        #expect(throws: AppModelError.missingWorkInterval) {
            try model.updateWork(
                id: UUID(), start: UnitFixture.start, end: UnitFixture.start, kind: .regular)
        }
        let entry = try #require(model.workEntries.first)
        let undo = try #require(model.deleteWork(id: entry.id))
        try model.restoreWork(undo)
        #expect(model.workEntries.count == 1)
        #expect(throws: AppModelError.workOutsideCurrentPayPeriod) {
            try model.addWork(
                start: UnitFixture.start.addingTimeInterval(-86_400), end: UnitFixture.start,
                kind: .regular)
        }
        #expect(throws: (any Error).self) {
            try model.updateWork(
                id: entry.id, start: UnitFixture.start,
                end: UnitFixture.start.addingTimeInterval(3_600), kind: .regular,
                unpaidBreakStart: UnitFixture.start, unpaidBreakEnd: nil)
        }
        try model.archiveCurrentPeriod()
        #expect(throws: AppModelError.staleUndo) { try model.restoreWork(undo) }
        #expect(model.workEntries.isEmpty)
    }

    @Test(arguments: ["0", "399.99", "400", "400.01"])
    func confirmedGrossHasCorrectDirection(_ gross: String) throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: gross))
        let value = try UnitFixture.decimal(gross)
        #expect(
            model.currentAuditStatus
                == (value == 400
                    ? .grossMatches : value < 400 ? .possibleShortfall : .possibleOverpayment))
        #expect(model.reconciliation?.difference.amount == 400 - value)
        #expect(model.hasUsedFreeAudit)
        try model.clearCurrentPaystub()
        #expect(model.currentPaystub == nil && model.currentAuditStatus == .notAudited)
        #expect(model.hasUsedFreeAudit && model.canRunAudit(hasProAccess: false))
        try model.archiveCurrentPeriod()
        #expect(!model.canRunAudit(hasProAccess: false))
        #expect(model.canRunAudit(hasProAccess: true))
    }

    @Test func everyConfirmedFieldAndOptionalZeroIsPreserved() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.regularHours = "8"
        stub.regularPay = "400"
        stub.overtimeHours = "0"
        stub.overtimePay = "0"
        stub.doubleTimeHours = "0"
        stub.doubleTimePay = "0"
        stub.calloutPay = "0"
        stub.perDiemPay = "0"
        stub.notes = "  verified manually  "
        stub.reviewedFields = Set(PaystubField.allCases)
        stub.lineLayout = .fullRateBuckets
        stub.hoursBasis = .actualWork
        stub.guaranteeLayout = .separateLine
        try model.confirmPaystub(stub)
        let confirmed = try #require(model.currentPaystub)
        #expect(confirmed.regularHours == 8 && confirmed.regularPay?.amount == 400)
        #expect(confirmed.overtimeHours == 0 && confirmed.overtimePay?.amount == 0)
        #expect(confirmed.doubleTimeHours == 0 && confirmed.doubleTimePay?.amount == 0)
        #expect(confirmed.calloutPay?.amount == 0 && confirmed.perDiemPay?.amount == 0)
        #expect(confirmed.notes == "verified manually")
        let findings = model.auditFindings(
            calculation: try #require(model.calculation), paystub: confirmed)
        #expect(
            Set(findings.map(\.id)) == [
                "grossPay", "regularPay", "overtimePay", "doubleTimePay", "calloutPay",
                "perDiemPay",
            ])
        #expect(findings.allSatisfy { $0.difference.amount == 0 && !$0.explanation.isEmpty })
    }

    @Test func invalidOptionalFieldDoesNotConsumeAccess() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        var stub = UnitFixture.paystub(model)
        stub.overtimeHours = "8oops"
        stub.reviewedFields.insert(.overtimeHours)
        #expect(throws: (any Error).self) { try model.confirmPaystub(stub) }
        #expect(store.state == before && !model.hasUsedFreeAudit)
    }

    @Test func loadFailureIsVisibleAndNotSilentlySaved() {
        let store = UnitStateStore()
        store.failLoad = true
        let model = AppModel(store: store)
        #expect(model.persistenceIssue != nil && !model.isOnboarded)
        #expect(store.saveCount == 0 && model.calculation == nil)
    }

    @Test func resetAndMissingHistoryAreIdempotent() throws {
        let model = AppModel()
        try model.deleteHistoryPeriod(id: UUID())
        try model.removeHistoricalPaystubEvidence(periodID: UUID())
        try model.removeCurrentPaystubEvidence()
        try UnitFixture.populate(model)
        try model.resetAllData()
        try model.resetAfterPersistenceFailure()
        #expect(model.profile == nil && model.activePeriod == nil && model.history.isEmpty)
        #expect(model.calculation == nil && !model.hasUsedFreeAudit)
    }
}
