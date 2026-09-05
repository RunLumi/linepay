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
        paystub.workComplete = true
        paystub.grossBasis = .wagesOnly
        paystub.reviewedFields = [.grossPay, .periodStart, .periodEnd]
        try model.confirmPaystub(paystub)

        #expect(model.hasUsedFreeAudit)
        #expect(model.currentAuditStatus == .grossMatches)
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

    @Test("Regular schedule wall-clock time uses the payroll timezone")
    func regularScheduleUsesPayrollTimeZone() throws {
        let model = AppModel()
        var draft = makeDraft(rate: "50", start: testStart)
        draft.useRegularSchedule = true
        draft.regularWeekdays = [.monday]

        var payrollCalendar = Calendar(identifier: .gregorian)
        payrollCalendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        draft.regularStartTime = try #require(
            payrollCalendar.date(
                from: DateComponents(year: 2001, month: 1, day: 1, hour: 7, minute: 0)
            )
        )
        draft.regularEndTime = try #require(
            payrollCalendar.date(
                from: DateComponents(year: 2001, month: 1, day: 1, hour: 15, minute: 30)
            )
        )

        try model.saveProfile(draft)

        let window = try #require(model.profile?.agreement.regularSchedule.first)
        #expect(window.start.hour == 7)
        #expect(window.start.minute == 0)
        #expect(window.end.hour == 15)
        #expect(window.end.minute == 30)
    }

    @Test("Archived pay period keeps its original payroll timezone")
    func archivedPayPeriodKeepsTimeZone() throws {
        let model = AppModel()
        var draft = makeDraft(rate: "50", start: testStart)
        try model.saveProfile(draft)
        try model.addWork(
            start: testStart,
            end: testStart.addingTimeInterval(8 * 60 * 60),
            kind: .regular
        )
        try model.archiveCurrentPeriod()

        draft.timeZoneIdentifier = "America/New_York"
        try model.saveProfile(draft)

        let archived = try #require(model.history.first)
        #expect(archived.timeZoneIdentifier == "America/Los_Angeles")
        #expect(model.timeZoneIdentifier(for: archived) == "America/Los_Angeles")
        #expect(model.activePeriod?.timeZoneIdentifier == "America/Los_Angeles")
        #expect(model.profile?.timeZoneIdentifier == "America/New_York")
    }

    @Test("Paystub period dates must match the active pay period")
    func paystubPeriodMismatchIsRejected() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50", start: testStart))
        try model.addWork(
            start: testStart,
            end: testStart.addingTimeInterval(8 * 60 * 60),
            kind: .regular
        )

        var paystub = PaystubConfirmationDraft()
        paystub.payPeriodStartDate = testStart.addingTimeInterval(24 * 60 * 60)
        paystub.payPeriodEndDate = testStart.addingTimeInterval(6 * 24 * 60 * 60)
        paystub.grossPay = "400"
        paystub.workComplete = true
        paystub.grossBasis = .wagesOnly
        paystub.reviewedFields = [.grossPay, .periodStart, .periodEnd]

        #expect(throws: AppModelError.invalidPayPeriod) {
            try model.confirmPaystub(paystub)
        }
        #expect(model.currentPaystub == nil)
        #expect(!model.hasUsedFreeAudit)
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

    @Test(
        "Declared decimal-point input preserves the full entered rate",
        arguments: ["58.40", "$58.40", " 58.40 \n"])
    func decimalRateInput(_ input: String) throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: input, start: testStart))
        #expect(model.profile?.agreement.hourlyRate.amount == Decimal(5840) / 100)
    }

    @Test(
        "Partial numeric input cannot replace saved rules",
        arguments: ["58.40USD", "58,40", "1.234,56", "58.4.0", "1e3", "NaN", "-1"])
    func invalidRateInputIsAtomic(_ input: String) throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50", start: testStart))
        #expect(throws: (any Error).self) {
            try model.saveProfile(makeDraft(rate: input, start: testStart))
        }
        #expect(model.profile?.agreement.hourlyRate.amount == Decimal(50))
        #expect(model.profile?.agreement.version == "1")
    }

    @Test("Paycheck amounts and confirmed hours keep decimal precision")
    func decimalPaystubInputIsExact() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50", start: testStart))
        try model.addWork(
            start: testStart, end: testStart.addingTimeInterval(8 * 3600), kind: .regular)
        var draft = PaystubConfirmationDraft()
        draft.payPeriodStartDate = testStart
        draft.payPeriodEndDate = testStart.addingTimeInterval(6 * 24 * 3600)
        draft.grossPay = "400.50"
        draft.workComplete = true
        draft.grossBasis = .wagesOnly
        draft.reviewedFields = [.periodStart, .periodEnd, .grossPay, .regularHours]
        draft.regularHours = "8.25"
        try model.confirmPaystub(draft)
        #expect(model.currentPaystub?.grossPay.amount == Decimal(40050) / 100)
        #expect(model.currentPaystub?.regularHours == Decimal(825) / 100)

        draft.grossPay = "400.50USD"
        #expect(throws: (any Error).self) { try model.confirmPaystub(draft) }
        #expect(model.currentPaystub?.grossPay.amount == Decimal(40050) / 100)
    }
}
