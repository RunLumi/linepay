import Foundation
import Testing

@testable import LinePay

@Suite("Backup ownership, cancellation, and exclusion")
@MainActor
struct BackupConcurrencyTests {
    @Test func overlappingOperationsAreRejectedAndCancellationReleasesBusyState() async throws {
        let io = SuspendedBackupIO()
        let store = MemoryStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore(), io: io)
        let initialRevision = session.revision
        let first = Task { try await session.prepareBackup() }
        await io.waitUntilStarted()
        #expect(session.isBusy)
        await #expect(throws: BackupError.operationInProgress) { try await session.prepareBackup() }
        await #expect(throws: BackupError.operationInProgress) {
            try await session.inspectBackup(at: URL(fileURLWithPath: "/synthetic"))
        }
        #expect(throws: BackupError.operationInProgress) {
            try session.restore(
                BackupArchive(createdAt: UnitFixture.start, state: AppPersistentState(), files: []))
        }
        first.cancel()
        await io.release()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(!session.isBusy && session.revision == initialRevision)
        #expect(try store.load() == nil)
    }

    @Test func failedReadLeavesExistingAppLifetimeUntouched() async throws {
        let store = MemoryStateStore()
        let session = AppSession(
            store: store, evidenceStore: MemoryEvidenceStore(), io: FailingBackupIO())
        try UnitFixture.populate(session.model)
        let state = try store.load()
        let revision = session.revision
        let model = session.model
        await #expect(throws: BackupError.unavailableFile) {
            try await session.inspectBackup(at: URL(fileURLWithPath: "/synthetic"))
        }
        #expect(!session.isBusy && session.revision == revision && session.model === model)
        #expect(try store.load() == state)
    }
}

private actor SuspendedBackupIO: BackupHandling {
    private var started = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var pending: CheckedContinuation<Void, Never>?

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }

    func create(state: AppPersistentState, sources: [BackupSource]) async throws -> Data {
        await withCheckedContinuation { continuation in
            pending = continuation
            started = true
            startedWaiter?.resume()
            startedWaiter = nil
        }
        try Task.checkCancellation()
        return try BackupArchive(createdAt: Date(), state: state, files: []).encoded()
    }

    func release() {
        pending?.resume()
        pending = nil
    }

    func open(_ url: URL) async throws -> BackupArchive { throw BackupError.unavailableFile }
}

private struct FailingBackupIO: BackupHandling {
    func create(state: AppPersistentState, sources: [BackupSource]) async throws -> Data {
        throw BackupError.unavailableFile
    }
    func open(_ url: URL) async throws -> BackupArchive { throw BackupError.unavailableFile }
}
