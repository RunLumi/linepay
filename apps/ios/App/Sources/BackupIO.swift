import Foundation
import Synchronization

struct BackupSource: Sendable {
    let id: UUID
    let url: URL
}

protocol BackupHandling: Sendable {
    func create(state: AppPersistentState, sources: [BackupSource], password: String?) async throws
        -> Data
    func open(_ url: URL, password: String?) async throws -> BackupArchive
}

extension BackupHandling {
    func create(state: AppPersistentState, sources: [BackupSource]) async throws -> Data {
        try await create(state: state, sources: sources, password: nil)
    }
    func open(_ url: URL) async throws -> BackupArchive { try await open(url, password: nil) }
}

/// File-provider coordination and serialization never run on the UI actor.
actor BackupIO: BackupHandling {
    func create(state: AppPersistentState, sources: [BackupSource], password: String?) throws
        -> Data
    {
        if let password { try BackupEncryption.validateNewPassword(password) }
        var files: [BackupArchive.EvidenceFile] = []
        var total = 0
        for source in sources {
            try Task.checkCancellation()
            let bytes = try Self.readBounded(
                source.url, limit: BackupArchive.maximumEvidenceBytes)
            total += bytes.count
            guard total <= BackupArchive.maximumBytes else { throw BackupError.tooLarge }
            files.append(.init(id: source.id, bytes: bytes))
        }
        let archive = BackupArchive(createdAt: Date(), state: state, files: files)
        if let password {
            return try BackupEncryption.seal(archive.portableEncoded(), password: password)
        }
        return try archive.encoded()
    }

    func open(_ url: URL, password: String?) throws -> BackupArchive {
        guard url.isFileURL else { throw BackupError.unavailableFile }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        let result = CoordinatedReadResult()
        NSFileCoordinator().coordinate(
            readingItemAt: url, options: [], error: &coordinationError
        ) { coordinatedURL in
            let read = Result {
                try Self.readBounded(coordinatedURL, limit: BackupArchive.maximumBytes)
            }
            result.value.withLock { $0 = read }
        }
        if coordinationError != nil { throw BackupError.unavailableFile }
        guard let read = result.value.withLock({ $0 }) else { throw BackupError.unavailableFile }
        try Task.checkCancellation()
        let bytes = try read.get()
        if BackupEncryption.isEncrypted(bytes) {
            let plaintext = try BackupEncryption.open(bytes, password: password)
            try Task.checkCancellation()
            var archive = try BackupArchive.decodePortable(plaintext)
            archive.wasPasswordProtected = true
            return archive
        }
        return try BackupArchive.decode(bytes)
    }

    /// Bound allocation even when a provider's file-size metadata is absent or misleading.
    private static func readBounded(_ url: URL, limit: Int) throws -> Data {
        guard let stream = InputStream(url: url) else { throw BackupError.unavailableFile }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            try Task.checkCancellation()
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw BackupError.unavailableFile }
            if count == 0 { break }
            guard result.count <= limit - count else { throw BackupError.tooLarge }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
    }
}

/// Reference ownership lets the accessor and its caller borrow the same noncopyable lock.
private final class CoordinatedReadResult: Sendable {
    let value = Mutex<Result<Data, any Error>?>(nil)
}
