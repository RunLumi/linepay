import Foundation
import LinePayDomain
import Testing
@testable import LinePay

@Suite("AppModel orchestration")
@MainActor
struct AppModelTests {
    private let testStart = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("First-run profile does not invent optional pay rules")
    func profileDefaultsDoNotInventRules() throws {
        let model = AppModel()
        let draft = makeDraft(rate: "50", start: testStart)

        try model.saveProfile(draft)

        let profile = try #require(model.profile)
        #expect(profile.agreement.version == "1")
        #expect(profile.agreement.hourlyRate.amount == Decimal(50))
        #expect(profile.agreement.dailyOvertimeTiers.isEmpty)
        #expect(profile.agreement.weekdayPremiums.isEmpty)
        #expect(profile.agreement.calloutMinimum == nil)
        #expect(profile.agreement.flatPerDiem == nil)
        #expect(model.activePeriod != nil)
    }

    @Test("Editing a profile creates a new agreement version while preserving identity")
    func profileEditsVersionAgreementSnapshot() throws {
        let model = AppModel()
        var draft = makeDraft(rate: "50", start: testStart)

        try model.saveProfile(draft)
        let original = try #require(model.profile)

        draft.hourlyRate = "55"
        try model.saveProfile(draft)
        let updated = try #require(model.profile)

        #expect(updated.id == original.id)
        #expect(updated.agreement.id == original.agreement.id)
        #expect(updated.agreement.version == "2")
        #expect(updated.agreement.hourlyRate.amount == Decimal(55))
    }

    @Test("Adding, editing, deleting and restoring work recalculates expected pay")
    func workMutationsRecalculate() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50", start: testStart))

        let eightHoursLater = testStart.addingTimeInterval(8 * 60 * 60)
        try model.addWork(start: testStart, end: eightHoursLater, kind: .regular)

        let interval = try #require(model.workIntervals.first)
        #expect(model.totalHours == Decimal(8))
        #expect(model.calculation?.total.amount == Decimal(400))

        let tenHoursLater = testStart.addingTimeInterval(10 * 60 * 60)
        try model.updateWork(
            id: interval.id,
            start: testStart,
            end: tenHoursLater,
            kind: .regular
        )

        #expect(model.totalHours == Decimal(10))
        #expect(model.calculation?.total.amount == Decimal(500))

        let removed = try #require(model.deleteWork(id: interval.id))
        #expect(model.workIntervals.isEmpty)
        #expect(model.calculation?.total.amount == 0)

        try model.restoreWork(removed)
        #expect(model.totalHours == Decimal(10))
        #expect(model.calculation?.total.amount == Decimal(500))
    }

    @Test("Rejected overlapping work does not mutate existing state")
    func overlapFailureIsAtomic() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50", start: testStart))

        let end = testStart.addingTimeInterval(8 * 60 * 60)
        try model.addWork(start: testStart, end: end, kind: .regular)
        let original = model.workIntervals

        let overlapStart = testStart.addingTimeInterval(4 * 60 * 60)
        let overlapEnd = end.addingTimeInterval(2 * 60 * 60)

        #expect(throws: (any Error).self) {
            try model.addWork(start: overlapStart, end: overlapEnd, kind: .regular)
        }
        #expect(model.workIntervals == original)
        #expect(model.calculation?.total.amount == Decimal(400))
    }

    @Test("First completed audit consumes free access but remains re-auditable")
    func firstAuditAccessIsPayPeriodScoped() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50", start: testStart))
        try model.addWork(
            start: testStart,
            end: testStart.addingTimeInterval(8 * 60 * 60),
            kind: .regular
        )

        var paystub = PaystubConfirmationDraft()
        paystub.payPeriodStartDate = testStart
        paystub.payPeriodEndDate = testStart.addingTimeInterval(6 * 24 * 60 * 60)
        paystub.grossPay = "400"
        try model.confirmPaystub(paystub)

        #expect(model.hasUsedFreeAudit)
        #expect(model.currentAuditStatus == .matches)
        #expect(model.canRunAudit(hasProAccess: false))

        let entry = try #require(model.workEntries.first)
        try model.updateWork(
            id: entry.id,
            start: testStart,
            end: testStart.addingTimeInterval(9 * 60 * 60),
            kind: .regular
        )

        #expect(model.currentAuditStatus == .needsReview)
        #expect(model.canRunAudit(hasProAccess: false))
    }

    @Test("Archived history keeps the exact old agreement snapshot after future rule edits")
    func archivedHistoryIsImmutable() throws {
        let model = AppModel()
        var draft = makeDraft(rate: "50", start: testStart)
        try model.saveProfile(draft)
        try model.addWork(
            start: testStart,
            end: testStart.addingTimeInterval(8 * 60 * 60),
            kind: .regular
        )
        try model.archiveCurrentPeriod()

        draft.hourlyRate = "75"
        try model.saveProfile(draft)

        let archived = try #require(model.history.first)
        #expect(archived.agreement.hourlyRate.amount == Decimal(50))
        #expect(archived.calculation.total.amount == Decimal(400))
        #expect(model.profile?.agreement.hourlyRate.amount == Decimal(75))
    }

    @Test("Versioned state survives a fresh AppModel instance")
    func localStateRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstStore = VersionedLocalStateStore(baseDirectory: directory)
        let firstModel = AppModel(store: firstStore, evidenceStore: MemoryEvidenceStore())
        try firstModel.saveProfile(makeDraft(rate: "61", start: testStart))
        try firstModel.addWork(
            start: testStart,
            end: testStart.addingTimeInterval(8 * 60 * 60),
            kind: .regular,
            note: "night crew"
        )

        let secondStore = VersionedLocalStateStore(baseDirectory: directory)
        let restored = AppModel(store: secondStore, evidenceStore: MemoryEvidenceStore())

        #expect(restored.profile?.agreement.hourlyRate.amount == Decimal(61))
        #expect(restored.workEntries.first?.note == "night crew")
        #expect(restored.calculation?.total.amount == Decimal(488))
    }

    private func makeDraft(rate: String, start: Date) -> PayProfileDraft {
        var draft = PayProfileDraft()
        draft.name = "Test agreement"
        draft.hourlyRate = rate
        draft.timeZoneIdentifier = "America/Los_Angeles"
        draft.preferredCadence = .weekly
        draft.periodStartDate = start
        return draft
    }
}
