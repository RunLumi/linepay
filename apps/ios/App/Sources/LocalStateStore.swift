import Foundation

@MainActor
protocol AppStateStoring: AnyObject {
    func load() throws -> AppPersistentState?
    func save(_ state: AppPersistentState) throws
    func reset() throws
    var recoveryFileURL: URL? { get }
}

@MainActor
final class MemoryStateStore: AppStateStoring {
    private var state: AppPersistentState?

    init(state: AppPersistentState? = nil) {
        self.state = state
    }

    func load() throws -> AppPersistentState? {
        state
    }

    func save(_ state: AppPersistentState) throws {
        self.state = state
    }

    func reset() throws {
        state = nil
    }

    var recoveryFileURL: URL? { nil }
}

@MainActor
final class VersionedLocalStateStore: AppStateStoring {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let stateURL: URL

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let baseDirectory {
            directoryURL = baseDirectory
        } else {
            let applicationSupport =
                fileManager.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first ?? fileManager.temporaryDirectory
            directoryURL = applicationSupport.appendingPathComponent("LinePay", isDirectory: true)
        }

        stateURL = directoryURL.appendingPathComponent("state-v1.json", isDirectory: false)
    }

    func load() throws -> AppPersistentState? {
        guard fileManager.fileExists(atPath: stateURL.path) else {
            return nil
        }

        let size = try stateURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 8 * 1024 * 1024 else { throw LocalStateStoreError.invalidState }
        let data = try Data(contentsOf: stateURL)
        let state = try JSONDecoder().decode(AppPersistentState.self, from: data)
        guard state.schemaVersion == AppPersistentState.currentSchemaVersion else {
            throw LocalStateStoreError.unsupportedSchema(state.schemaVersion)
        }
        try AppStateValidation.validate(state)
        return state
    }

    func save(_ state: AppPersistentState) throws {
        guard state.schemaVersion == AppPersistentState.currentSchemaVersion else {
            throw LocalStateStoreError.unsupportedSchema(state.schemaVersion)
        }

        try AppStateValidation.validate(state)
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        #if os(iOS)
            try data.write(
                to: stateURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
            try data.write(to: stateURL, options: [.atomic])
        #endif

    }

    func reset() throws {
        guard fileManager.fileExists(atPath: stateURL.path) else { return }
        try fileManager.removeItem(at: stateURL)
    }

    var recoveryFileURL: URL? {
        fileManager.fileExists(atPath: stateURL.path) ? stateURL : nil
    }

    private func ensureDirectory() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        #if os(iOS)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directoryURL.path
            )
        #endif
    }
}

enum LocalStateStoreError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidState

    var errorDescription: String? {
        switch self {
        case .invalidState:
            "The local file contains invalid or oversized records. Your saved file was not overwritten."
        case .unsupportedSchema(let version):
            "This LinePaycheck data uses unsupported local schema version \(version)."
        }
    }
}
