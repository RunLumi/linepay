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

        let data = try Data(contentsOf: stateURL)
        let state = try JSONDecoder().decode(AppPersistentState.self, from: data)
        guard state.schemaVersion == AppPersistentState.currentSchemaVersion else {
            throw LocalStateStoreError.unsupportedSchema(state.schemaVersion)
        }
        return state
    }

    func save(_ state: AppPersistentState) throws {
        guard state.schemaVersion == AppPersistentState.currentSchemaVersion else {
            throw LocalStateStoreError.unsupportedSchema(state.schemaVersion)
        }

        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: [.atomic])
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: stateURL.path
        )
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
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directoryURL.path
        )
    }
}

enum LocalStateStoreError: LocalizedError, Equatable {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "This LinePay data uses unsupported local schema version \(version)."
        }
    }
}
