import Foundation
import Observation

/// Owns the local model's lifetime, including an explicit replacement after a successful restore.
/// StoreKit is intentionally not part of a data snapshot or this ownership boundary.
@MainActor
@Observable
final class AppSession {
    @ObservationIgnored private let store: any AppStateStoring
    @ObservationIgnored private let evidenceStore: any EvidenceStoring
    @ObservationIgnored private let io = BackupIO()

    private(set) var model: AppModel
    private(set) var revision = UUID()
    private(set) var isBusy = false
    var restoreNotice: String?

    init(store: any AppStateStoring, evidenceStore: any EvidenceStoring) {
        self.store = store
        self.evidenceStore = evidenceStore
        model = AppModel(store: store, evidenceStore: evidenceStore)
    }

    static func production() -> AppSession {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                return UITestFixtures.session()
            }
        #endif
        return AppSession(store: VersionedLocalStateStore(), evidenceStore: LocalEvidenceStore())
    }

    func prepareBackup() async throws -> Data {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        guard model.persistenceIssue == nil else { throw BackupError.currentDataUnreadable }
        let state = try store.load() ?? AppPersistentState()
        let references = try BackupArchive.evidence(in: state)
        let sources = try references.map { reference in
            guard let url = evidenceStore.url(for: reference) else {
                throw BackupError.missingEvidence
            }
            return BackupSource(id: reference.id, url: url)
        }
        return try await io.create(state: state, sources: sources)
    }

    func inspectBackup(at url: URL) async throws -> BackupArchive {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        return try await io.open(url)
    }

    /// Call only after the worker confirms the replace-not-merge preview.
    /// Staged evidence is written first. The atomic state-file save is the commit point.
    func restore(_ archive: BackupArchive, replaceUnreadableData: Bool = false) throws {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        try archive.validate()

        let previous: AppPersistentState?
        do {
            previous = try store.load()
        } catch {
            guard replaceUnreadableData else { throw BackupError.currentDataUnreadable }
            previous = nil
        }
        let wasUnreadable = model.persistenceIssue != nil
        let oldReferences = try previous.map { try BackupArchive.evidence(in: $0) } ?? []
        let incomingReferences = try BackupArchive.evidence(in: archive.state)
        let bytesByID = Dictionary(uniqueKeysWithValues: archive.files.map { ($0.id, $0.bytes) })
        var staged: [PaystubEvidence] = []
        var replacements: [UUID: PaystubEvidence] = [:]

        do {
            for reference in incomingReferences {
                guard let data = bytesByID[reference.id] else { throw BackupError.missingEvidence }
                // Never reuse imported physical paths or overwrite an existing original.
                let saved = try evidenceStore.save(
                    data: data, originalFilename: safeFilename(for: reference.mediaType),
                    mediaType: reference.mediaType, sourceKind: reference.sourceKind,
                    recognizedText: reference.recognizedText
                )
                staged.append(saved)
                replacements[reference.id] = PaystubEvidence(
                    id: reference.id, storedFilename: saved.storedFilename,
                    originalFilename: reference.originalFilename, mediaType: reference.mediaType,
                    sourceKind: reference.sourceKind,
                    createdEpochSeconds: reference.createdEpochSeconds,
                    recognizedText: reference.recognizedText
                )
            }
            var candidate = archive.state.replacingEvidence(replacements)
            // Imported deletion queues contain physical filenames from a different install.
            candidate.pendingEvidenceDeletions =
                oldReferences + (previous?.pendingEvidenceDeletions ?? [])
            // A data restore is not a way to grant Pro or reset previously used free access.
            candidate.hasUsedFreeAudit =
                candidate.hasUsedFreeAudit
                || (previous?.hasUsedFreeAudit ?? wasUnreadable)
            try store.save(candidate)
        } catch {
            var cleanupFailed = false
            for file in staged {
                do { try evidenceStore.delete(file) } catch { cleanupFailed = true }
            }
            throw cleanupFailed ? BackupError.cleanupFailed : BackupError.restoreFailed
        }

        // The state is now committed; retain a retryable queue for failed old-file cleanup.
        model = AppModel(store: store, evidenceStore: evidenceStore)
        var cleanupFailed = false
        do { try model.retryEvidenceDeletion() } catch { cleanupFailed = true }
        revision = UUID()
        if model.persistenceIssue != nil {
            restoreNotice =
                "The restored file was saved but could not be reopened. Use Data recovery."
        } else if cleanupFailed || wasUnreadable {
            restoreNotice =
                "Backup restored. Some previous original files may remain on this iPhone. "
                + "Use Delete all local data only when you intend to remove all local records. "
                + "Your iCloud backup was not changed."
        } else {
            restoreNotice =
                "Backup restored, including retained paystub originals. "
                + "Your App Store subscription is unchanged. Your iCloud backup was not changed."
        }
    }

    private func safeFilename(for mediaType: String) -> String {
        switch mediaType {
        case "application/pdf": "paystub.pdf"
        case "image/png": "paystub.png"
        case "image/heic": "paystub.heic"
        case "image/jpeg": "paystub.jpg"
        default: "paystub.bin"
        }
    }
}
