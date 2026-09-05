import CryptoKit
import Foundation
import Testing

@testable import LinePay

@Suite("Complete backup and transactional restore")
@MainActor
struct BackupTests {
    @Test("Records, original bytes, and frozen history survive a backup and new session")
    func roundTrip() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VersionedLocalStateStore(
            baseDirectory: directory.appendingPathComponent("state"))
        let originals = LocalEvidenceStore(
            baseDirectory: directory.appendingPathComponent("originals"))
        let source = AppSession(store: store, evidenceStore: originals)
        try populate(source.model)
        try source.model.archiveCurrentPeriod()
        let before = try #require(try store.load())
        let data = try await source.prepareBackup()
        let archive = try BackupArchive.decode(data)
        #expect(archive.state == before)
        #expect(archive.files.count == 1)
        #expect(archive.files.first?.bytes == syntheticOriginal)

        let destinationStore = VersionedLocalStateStore(
            baseDirectory: directory.appendingPathComponent("destination-state"))
        let destinationOriginals = LocalEvidenceStore(
            baseDirectory: directory.appendingPathComponent("destination-originals"))
        let destination = AppSession(store: destinationStore, evidenceStore: destinationOriginals)
        let oldRevision = destination.revision
        try destination.restore(archive)
        let after = try #require(try destinationStore.load())
        #expect(after.profile == before.profile)
        #expect(after.history.first?.calculation == before.history.first?.calculation)
        #expect(after.history.first?.agreement == before.history.first?.agreement)
        #expect(after.history.first?.workEntries == before.history.first?.workEntries)
        #expect(after.history.first?.timeZoneIdentifier == before.history.first?.timeZoneIdentifier)
        #expect(after.hasUsedFreeAudit == before.hasUsedFreeAudit)
        #expect(destination.revision != oldRevision)
        let evidence = try #require(after.history.first?.paystub?.evidence)
        let prior = try #require(before.history.first?.paystub?.evidence)
        #expect(evidence.id == prior.id)
        #expect(evidence.createdEpochSeconds == prior.createdEpochSeconds)
        #expect(evidence.recognizedText == prior.recognizedText)
        #expect(evidence.storedFilename != prior.storedFilename)
        let url = try #require(destinationOriginals.url(for: evidence))
        #expect(try Data(contentsOf: url) == syntheticOriginal)
        let relaunched = AppModel(store: destinationStore, evidenceStore: destinationOriginals)
        #expect(relaunched.history.first?.calculation == before.history.first?.calculation)
        #expect(relaunched.persistenceIssue == nil)
    }

    @Test("Missing originals fail backup instead of silently producing an incomplete copy")
    func missingOriginal() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MemoryStateStore()
        let originals = LocalEvidenceStore(baseDirectory: directory)
        let session = AppSession(store: store, evidenceStore: originals)
        try populate(session.model)
        let before = try store.load()
        try originals.delete(try #require(session.model.currentPaystub?.evidence))
        await #expect(throws: BackupError.missingEvidence) { try await session.prepareBackup() }
        #expect(try store.load() == before)
        #expect(!session.isBusy)
    }

    @Test("Integrity mismatch, unsupported version, and legacy JSON cannot be restored")
    func rejectsInvalidContainers() throws {
        let archive = BackupArchive(createdAt: Date(), state: AppPersistentState(), files: [])
        let bytes = try archive.encoded()
        let envelope = try PropertyListDecoder().decode(BackupArchive.Envelope.self, from: bytes)
        let damaged = BackupArchive.Envelope(
            format: envelope.format, version: 1, payload: envelope.payload, sha256: Data([0]))
        let newer = BackupArchive.Envelope(
            format: envelope.format, version: 99, payload: envelope.payload, sha256: envelope.sha256
        )
        #expect(throws: BackupError.damagedArchive) {
            try BackupArchive.decode(PropertyListEncoder().encode(damaged))
        }
        #expect(throws: BackupError.newerVersion) {
            try BackupArchive.decode(PropertyListEncoder().encode(newer))
        }
        #expect(throws: BackupError.invalidArchive) {
            try BackupArchive.decode(JSONEncoder().encode(AppPersistentState()))
        }
        #expect(throws: BackupError.tooLarge) {
            try BackupArchive.decode(Data(count: BackupArchive.maximumBytes + 1))
        }
    }

    @Test("Extra and duplicate evidence IDs are rejected")
    func rejectsUnreferencedEvidence() throws {
        let file = BackupArchive.EvidenceFile(id: UUID(), bytes: Data([1]))
        for files in [[file], [file, file]] {
            #expect(throws: BackupError.missingEvidence) {
                try BackupArchive(createdAt: Date(), state: AppPersistentState(), files: files)
                    .encoded()
            }
        }
    }

    @Test("Imported paths cannot escape the evidence directory")
    func rejectsTraversal() {
        for name in ["../state-v1.json", "/tmp/paystub", "a/b.pdf", "..", "a\\b.pdf", ""] {
            #expect(!BackupArchive.isSafeFilename(name))
        }
        #expect(BackupArchive.isSafeFilename("7D7FDC4F-62AD-482A-BC17-37C208AAB919.pdf"))
    }

    @Test("A failed state commit retains existing records and removes staged originals")
    func failedCommitIsAtomic() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FailingBackupStateStore()
        let originals = LocalEvidenceStore(baseDirectory: directory)
        let session = AppSession(store: store, evidenceStore: originals)
        try populate(session.model)
        let archive = try BackupArchive.decode(await session.prepareBackup())
        let before = try store.load()
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .sorted()
        let revision = session.revision
        store.failSave = true
        #expect(throws: BackupError.restoreFailed) { try session.restore(archive) }
        #expect(try store.load() == before)
        #expect(session.revision == revision)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
                == filesBefore)
        #expect(!session.isBusy)
    }

    @Test("An evidence write failure never reaches the state commit")
    func failedEvidenceWriteIsAtomic() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MemoryStateStore()
        let originals = FailingBackupEvidenceStore(
            base: LocalEvidenceStore(baseDirectory: directory))
        let session = AppSession(store: store, evidenceStore: originals)
        try populate(session.model)
        let archive = try BackupArchive.decode(await session.prepareBackup())
        let before = try store.load()
        originals.failSave = true
        #expect(throws: BackupError.restoreFailed) { try session.restore(archive) }
        #expect(try store.load() == before)
        let evidence = try #require(session.model.currentPaystub?.evidence)
        #expect(originals.url(for: evidence) != nil)
    }

    @Test("Restoring an old free snapshot cannot reset previously consumed free access")
    func preservesFreeAllowance() throws {
        var current = AppPersistentState()
        current.hasUsedFreeAudit = true
        let store = MemoryStateStore(state: current)
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try session.restore(
            BackupArchive(createdAt: Date(), state: AppPersistentState(), files: []))
        #expect(session.model.hasUsedFreeAudit)
    }

    @Test("Unreadable state requires explicit replacement authorization")
    func unreadableDataNeedsConsent() throws {
        let store = FailingBackupStateStore()
        store.failLoad = true
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        let archive = BackupArchive(createdAt: Date(), state: AppPersistentState(), files: [])
        #expect(throws: BackupError.currentDataUnreadable) { try session.restore(archive) }
        #expect(store.savedCount == 0)
        // A successful save simulates replacing the corrupt state atomically.
        try session.restore(archive, replaceUnreadableData: true)
        #expect(store.savedCount == 1)
        #expect(session.model.persistenceIssue == nil)
        #expect(session.model.hasUsedFreeAudit)
    }

    @Test("Post-commit cleanup failure reports a warning, not a false failed restore")
    func reportsCleanupWarning() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MemoryStateStore()
        let originals = FailingBackupEvidenceStore(
            base: LocalEvidenceStore(baseDirectory: directory))
        let session = AppSession(store: store, evidenceStore: originals)
        try populate(session.model)
        let archive = try BackupArchive.decode(await session.prepareBackup())
        originals.failDelete = true
        try session.restore(archive)
        #expect(session.model.currentPaystub != nil)
        #expect(session.restoreNotice?.contains("may remain") == true)
    }

    @Test("Opening an archive does not modify or remove the selected file")
    func importDoesNotChangeSource() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = try BackupArchive(createdAt: Date(), state: AppPersistentState(), files: [])
            .encoded()
        let url = directory.appendingPathComponent("test.linepaybackup")
        try bytes.write(to: url)
        let session = AppSession(store: MemoryStateStore(), evidenceStore: MemoryEvidenceStore())
        let archive = try await session.inspectBackup(at: url)
        try session.restore(archive)
        #expect(try Data(contentsOf: url) == bytes)
    }

    private var syntheticOriginal: Data {
        Data("SYNTHETIC TEST DOCUMENT. NOT A REAL PAYSTUB.".utf8)
    }

    private func populate(_ model: AppModel) throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var draft = PayProfileDraft()
        draft.hourlyRate = "50"
        draft.timeZoneIdentifier = "UTC"
        draft.periodStartDate = start
        try model.saveProfile(draft)
        try model.addWork(
            start: start, end: start.addingTimeInterval(8 * 3_600), kind: .regular,
            note: "Synthetic note")
        let period = try #require(model.activePeriod)
        var stub = PaystubConfirmationDraft()
        stub.payPeriodStartDate = period.window.startDate
        stub.payPeriodEndDate = period.window.displayEndDate
        stub.grossPay = "400"
        stub.grossBasis = .wagesOnly
        stub.reviewedFields = [.grossPay, .periodStart, .periodEnd]
        stub.sourceData = syntheticOriginal
        stub.originalFilename = "synthetic.pdf"
        stub.mediaType = "application/pdf"
        stub.sourceKind = .file
        stub.recognizedText = "Synthetic OCR evidence"
        try model.confirmPaystub(stub)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
}

@MainActor
private final class FailingBackupStateStore: AppStateStoring {
    var state: AppPersistentState?
    var failSave = false
    var failLoad = false
    var savedCount = 0
    var recoveryFileURL: URL? { nil }
    func load() throws -> AppPersistentState? {
        if failLoad { throw BackupError.currentDataUnreadable }
        return state
    }
    func save(_ state: AppPersistentState) throws {
        if failSave { throw BackupError.restoreFailed }
        self.state = state
        failLoad = false
        savedCount += 1
    }
    func reset() throws { state = nil }
}

@MainActor
private final class FailingBackupEvidenceStore: EvidenceStoring {
    let base: LocalEvidenceStore
    var failSave = false
    var failDelete = false
    init(base: LocalEvidenceStore) { self.base = base }
    func save(
        data: Data, originalFilename: String, mediaType: String,
        sourceKind: PaystubSourceKind, recognizedText: String?
    ) throws -> PaystubEvidence {
        if failSave { throw BackupError.restoreFailed }
        return try base.save(
            data: data, originalFilename: originalFilename, mediaType: mediaType,
            sourceKind: sourceKind, recognizedText: recognizedText)
    }
    func url(for evidence: PaystubEvidence) -> URL? { base.url(for: evidence) }
    func delete(_ evidence: PaystubEvidence) throws {
        if failDelete { throw BackupError.cleanupFailed }
        try base.delete(evidence)
    }
    func deleteAll() throws { try base.deleteAll() }
}
