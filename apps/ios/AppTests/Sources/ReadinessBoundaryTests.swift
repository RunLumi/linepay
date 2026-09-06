import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Readiness period and evidence boundaries")
@MainActor
struct ReadinessBoundaryTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func changedTimezoneClosesOldPeriodWithoutOverlap() throws {
        for zones in [
            ["America/Los_Angeles", "America/New_York"],
            ["America/New_York", "America/Los_Angeles"],
        ] {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let model = try configured(
                store: VersionedLocalStateStore(baseDirectory: directory), zone: zones[0])
            let old = try #require(model.activePeriod)
            var edit = PayProfileDraft(
                profile: try #require(model.profile), activePeriod: old)
            edit.timeZoneIdentifier = zones[1]
            try model.saveProfile(edit)
            try model.archiveCurrentPeriod()
            #expect(
                model.activePeriod == nil, "A timezone change requires an explicit new boundary")
            let closed = try #require(model.history.first)
            #expect(closed.window == old.window)
            #expect(closed.timeZoneIdentifier == zones[0])
            let closedCalculation = try #require(closed.calculation)
            #expect(closedCalculation.total.amount == 400)
            try model.startNewPayPeriod(startDate: old.window.endDate.addingTimeInterval(86_400))
            #expect(model.currentTimeZoneIdentifier == zones[1])
            let next = try #require(model.activePeriod)
            #expect(next.window.startEpochSeconds >= old.window.endEpochSeconds)
            let reloaded = AppModel(store: VersionedLocalStateStore(baseDirectory: directory))
            #expect(reloaded.persistenceIssue == nil)
            let reloadedCalculation = try #require(reloaded.history.first?.calculation)
            #expect(reloadedCalculation.total.amount == 400)
        }
    }

    @Test func missingIntakePeriodDoesNotCreateAnOriginal() throws {
        let evidence = BoundaryEvidenceStore()
        let model = try configured(evidence: evidence)
        #expect(throws: AppModelError.missingActivePayPeriod) {
            _ = try model.stagePaystub(
                data: Data("synthetic".utf8), filename: "stub.pdf", mediaType: "application/pdf",
                kind: .file, periodID: UUID())
        }
        #expect(evidence.saved.isEmpty)
        #expect(model.paystubDraft == nil)
    }

    @Test func anotherIntakeCannotCreateAnOrphanOriginal() throws {
        let evidence = BoundaryEvidenceStore()
        let model = try configured(evidence: evidence)
        let first = try #require(model.activePeriod?.id)
        _ = try model.stagePaystub(
            data: Data("synthetic A".utf8), filename: "a.pdf", mediaType: "application/pdf",
            kind: .file, periodID: first)
        try model.archiveCurrentPeriod()
        let next = try #require(model.activePeriod?.id)
        #expect(throws: AppModelError.otherPaystubDraft) {
            _ = try model.stagePaystub(
                data: Data("synthetic B".utf8), filename: "b.pdf", mediaType: "application/pdf",
                kind: .file, periodID: next)
        }
        #expect(evidence.saved.count == 1)
        #expect(model.paystubDraft?.targetPeriodID == first)
    }

    @Test func deletingPendingPeriodAlsoDeletesItsUnconfirmedOriginal() throws {
        let evidence = BoundaryEvidenceStore()
        let model = try configured(evidence: evidence)
        let first = try #require(model.activePeriod?.id)
        try model.archiveCurrentPeriod()
        let draft = try model.stagePaystub(
            data: Data("synthetic draft".utf8), filename: "draft.pdf",
            mediaType: "application/pdf", kind: .file, periodID: first)
        let original = try #require(draft.sourceEvidence)
        evidence.failDeletion = true
        #expect(throws: AppModelError.evidenceDeletionPending) {
            try model.deleteHistoryPeriod(id: first)
        }
        #expect(model.paystubDraft == nil)
        #expect(model.history.isEmpty)
        #expect(model.pendingDeletionCount == 1)
        evidence.failDeletion = false
        try model.retryEvidenceDeletion()
        #expect(evidence.deleted == [original.id])
        #expect(model.pendingDeletionCount == 0)
    }

    private func configured(
        store: any AppStateStoring = MemoryStateStore(),
        evidence: any EvidenceStoring = MemoryEvidenceStore(), zone: String = "UTC"
    ) throws -> AppModel {
        let model = AppModel(store: store, evidenceStore: evidence)
        var draft = PayProfileDraft()
        draft.name = "Synthetic boundary agreement"
        draft.hourlyRate = "50"
        draft.timeZoneIdentifier = zone
        draft.periodStartDate = start
        try model.saveProfile(draft)
        try model.addWork(start: start, end: start.addingTimeInterval(28_800), kind: .regular)
        return model
    }
}

@MainActor
private final class BoundaryEvidenceStore: EvidenceStoring {
    var saved: [UUID] = []
    var deleted: [UUID] = []
    var failDeletion = false

    func save(
        data: Data, originalFilename: String, mediaType: String, sourceKind: PaystubSourceKind,
        recognizedText: String?
    ) throws -> PaystubEvidence {
        let result = PaystubEvidence(
            storedFilename: UUID().uuidString, originalFilename: originalFilename,
            mediaType: mediaType, sourceKind: sourceKind, recognizedText: recognizedText)
        saved.append(result.id)
        return result
    }
    func url(for evidence: PaystubEvidence) -> URL? { nil }
    func delete(_ evidence: PaystubEvidence) throws {
        if failDeletion { throw CocoaError(.fileWriteNoPermission) }
        deleted.append(evidence.id)
    }
    func deleteAll() throws { if failDeletion { throw CocoaError(.fileWriteNoPermission) } }
}
