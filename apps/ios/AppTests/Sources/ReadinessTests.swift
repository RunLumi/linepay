import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Readiness financial and data regressions")
@MainActor
struct ReadinessTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func configured(
        store: any AppStateStoring = MemoryStateStore(),
        evidence: any EvidenceStoring = MemoryEvidenceStore()
    ) throws -> AppModel {
        let model = AppModel(store: store, evidenceStore: evidence)
        var draft = PayProfileDraft()
        draft.name = "Synthetic agreement"
        draft.hourlyRate = "50"
        draft.timeZoneIdentifier = "UTC"
        draft.periodStartDate = start
        try model.saveProfile(draft)
        try model.addWork(start: start, end: start.addingTimeInterval(8 * 3600), kind: .regular)
        return model
    }
    func paycheck(_ model: AppModel, periodID: UUID? = nil) throws -> PaystubConfirmationDraft {
        let context = try #require(model.periodContext(id: periodID))
        var draft = try model.paycheckDraft(for: context.id)
        draft.grossPay = "400"
        draft.grossBasis = .wagesOnly
        draft.reviewedFields = [.grossPay, .periodStart, .periodEnd]
        return draft
    }
    @Test func nextWorkCanBeLoggedBeforePriorPaycheckArrives() throws {
        let model = try configured()
        let a = try #require(model.activePeriod?.id)
        try model.archiveCurrentPeriod()
        let b = try #require(model.activePeriod)
        let bStart = b.window.startDate.addingTimeInterval(9 * 3600)
        try model.addWork(start: bStart, end: bStart.addingTimeInterval(8 * 3600), kind: .regular)
        try model.confirmPaystub(paycheck(model, periodID: a), periodID: a)
        #expect(model.history.first?.paystub?.grossPay.amount == 400)
        #expect(model.history.first?.calculation.total.amount == 400)
        #expect(model.activePeriod?.id == b.id)
        #expect(model.workEntries.count == 1)
        #expect(!model.canRunAudit(hasProAccess: false))
        #expect(model.canRunAudit(periodID: a, hasProAccess: false))
    }
    @Test func futureRateDoesNotRepriceExistingWork() throws {
        let model = try configured()
        let profile = try #require(model.profile)
        var edit = PayProfileDraft(profile: profile, activePeriod: model.activePeriod)
        edit.hourlyRate = "60"
        try model.saveProfile(edit)
        #expect(model.calculation?.total.amount == 400)
        #expect(model.activePeriod?.agreement.hourlyRate.amount == 50)
        #expect(model.profile?.agreement.hourlyRate.amount == 60)
        edit.editScope = .currentPeriod
        try model.saveProfile(edit)
        #expect(model.calculation?.total.amount == 480)
    }
    @Test func invalidCurrentRuleChangeDoesNotCommit() throws {
        let model = try configured()
        var edit = PayProfileDraft(
            profile: try #require(model.profile), activePeriod: model.activePeriod)
        edit.editScope = .currentPeriod
        edit.useEffectiveStart = true
        edit.effectiveStartDate = start.addingTimeInterval(40 * 86400)
        #expect(throws: (any Error).self) { try model.saveProfile(edit) }
        #expect(model.calculation?.total.amount == 400)
    }
    @Test func closedAuditCorrectionsAppendRevisions() throws {
        let model = try configured()
        let a = try #require(model.activePeriod?.id)
        try model.confirmPaystub(paycheck(model))
        try model.archiveCurrentPeriod()
        var correction = try paycheck(model, periodID: a)
        correction.grossPay = "390"
        try model.confirmPaystub(correction, periodID: a)
        let closed = try #require(model.history.first)
        #expect(closed.auditRevisions?.count == 2)
        #expect(closed.auditRevisions?.first?.paystub.grossPay.amount == 400)
        #expect(closed.auditRevisions?.last?.paystub.grossPay.amount == 390)
    }
    @Test func staleUndoCannotMoveWorkToNextPeriod() throws {
        let model = try configured()
        let entry = try #require(model.workEntries.first)
        let token = try #require(model.deleteWork(id: entry.id))
        try model.archiveCurrentPeriod()
        #expect(throws: AppModelError.staleUndo) { try model.restoreWork(token) }
        #expect(model.workEntries.isEmpty)
    }
    @Test func undoRejectsAnInterveningEdit() throws {
        let model = try configured()
        let entry = try #require(model.workEntries.first)
        let token = try #require(model.deleteWork(id: entry.id))
        try model.addWork(start: start, end: start.addingTimeInterval(3600), kind: .regular)
        #expect(throws: AppModelError.staleUndo) { try model.restoreWork(token) }
    }
    @Test func correctionsRetainOriginalWithoutReloadingBytes() throws {
        let evidence = FaultEvidenceStore()
        let model = try configured(evidence: evidence)
        var first = try paycheck(model)
        first.sourceData = Data("synthetic evidence".utf8)
        first.originalFilename = "stub.pdf"
        first.mediaType = "application/pdf"
        first.sourceKind = .file
        try model.confirmPaystub(first)
        let id = try #require(model.currentPaystub?.evidence?.id)
        var correction = try paycheck(model)
        correction.grossPay = "390"
        correction.sourceData = nil
        correction.sourceEvidence = nil
        try model.confirmPaystub(correction)
        #expect(model.currentPaystub?.evidence?.id == id)
        #expect(evidence.deleted.isEmpty)
        #expect(model.currentPaystub?.assessment?.verdict == .possibleShortfall)
    }
    @Test func failedEvidenceDeletionRemainsRetryable() throws {
        let evidence = FaultEvidenceStore()
        let model = try configured(evidence: evidence)
        var first = try paycheck(model)
        first.sourceData = Data("synthetic".utf8)
        try model.confirmPaystub(first)
        evidence.failDeletion = true
        #expect(throws: AppModelError.evidenceDeletionPending) {
            try model.removeCurrentPaystubEvidence()
        }
        #expect(model.currentPaystub?.evidence == nil)
        #expect(model.pendingDeletionCount == 1)
        evidence.failDeletion = false
        try model.retryEvidenceDeletion()
        #expect(model.pendingDeletionCount == 0)
        #expect(evidence.deleted.count == 1)
    }
    @Test func workAndIntakeDraftsSurviveNewModel() throws {
        let store = MemoryStateStore()
        let evidence = FaultEvidenceStore()
        let model = try configured(store: store, evidence: evidence)
        let period = try #require(model.activePeriod)
        let draft = WorkDraft(
            periodID: period.id, editingEntryID: nil, start: start,
            end: start.addingTimeInterval(3600), kind: .regular, note: "Draft survives",
            hasUnpaidBreak: false, breakStart: start, breakEnd: start, copiedFrom: nil)
        try model.saveWorkDraft(draft)
        _ = try model.stagePaystub(
            data: Data("document before OCR".utf8), filename: "stub.pdf",
            mediaType: "application/pdf", kind: .file, periodID: period.id)
        let restored = AppModel(store: store, evidenceStore: evidence)
        #expect(restored.workDraft?.note == "Draft survives")
        #expect(restored.paystubDraft?.sourceEvidence != nil)
    }
    @Test func failureLeavesSavedWorkAndDraftUnchanged() throws {
        let store = FaultStateStore()
        let model = try configured(store: store)
        let before = model.workEntries
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.addWork(
                start: start.addingTimeInterval(86400),
                end: start.addingTimeInterval(90000), kind: .regular)
        }
        #expect(model.workEntries == before)
        #expect(AppModel(store: store).workEntries == before)
    }
    @Test func periodCorrectionRejectsMovingWorkOrOverlap() throws {
        let model = try configured()
        let old = try #require(model.activePeriod?.window)
        #expect(throws: AppModelError.workOutsideCurrentPayPeriod) {
            try model.correctCurrentPeriod(
                start: start.addingTimeInterval(86400), end: start.addingTimeInterval(6 * 86400))
        }
        #expect(model.activePeriod?.window == old)
        try model.correctCurrentPeriod(
            start: old.startDate, end: old.displayEndDate.addingTimeInterval(86400))
        #expect(model.activePeriod?.window.endEpochSeconds == old.endEpochSeconds + 86400)
    }
    @Test func unknownGrossDoesNotConsumeFreeAudit() throws {
        let model = try configured()
        var draft = try paycheck(model)
        draft.grossBasis = .unconfirmed
        try model.confirmPaystub(draft)
        #expect(model.currentAuditStatus == .notComparable)
        #expect(!model.hasUsedFreeAudit)
    }
    @Test func v1StateMigratesWithoutRecalculatingHistoricalMoney() throws {
        let store = MemoryStateStore()
        let model = try configured(store: store)
        try model.archiveCurrentPeriod()
        let before = try #require(try store.load())
        let encoded = try JSONEncoder().encode(before)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 1
        object.removeValue(forKey: "pendingEvidenceDeletions")
        let migrated = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(migrated.schemaVersion == 2)
        #expect(migrated.history == before.history)
    }
    @Test func corruptStateIsNotOverwrittenAndCanBeRetried() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("state-v1.json")
        let bad = Data("bad json".utf8)
        try bad.write(to: url)
        let model = AppModel(store: VersionedLocalStateStore(baseDirectory: folder))
        #expect(model.persistenceIssue != nil)
        #expect(try Data(contentsOf: url) == bad)
        try JSONEncoder().encode(AppPersistentState()).write(to: url)
        try model.retryLoad()
        #expect(model.persistenceIssue == nil)
    }
}

@MainActor
final class FaultStateStore: AppStateStoring {
    var state: AppPersistentState?
    var failSave = false
    var recoveryFileURL: URL? { nil }
    func load() throws -> AppPersistentState? { state }
    func save(_ state: AppPersistentState) throws {
        if failSave { throw CocoaError(.fileWriteOutOfSpace) }
        self.state = state
    }
    func reset() throws { state = nil }
}

@MainActor
final class FaultEvidenceStore: EvidenceStoring {
    var failDeletion = false
    var deleted: [UUID] = []
    func save(
        data: Data, originalFilename: String, mediaType: String, sourceKind: PaystubSourceKind,
        recognizedText: String?
    ) throws -> PaystubEvidence {
        PaystubEvidence(
            storedFilename: UUID().uuidString, originalFilename: originalFilename,
            mediaType: mediaType, sourceKind: sourceKind, recognizedText: recognizedText)
    }
    func url(for evidence: PaystubEvidence) -> URL? { nil }
    func delete(_ evidence: PaystubEvidence) throws {
        if failDeletion { throw CocoaError(.fileWriteNoPermission) }
        deleted.append(evidence.id)
    }
    func deleteAll() throws { if failDeletion { throw CocoaError(.fileWriteNoPermission) } }
}
