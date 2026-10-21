import Foundation
import SwiftUI
import Synchronization
import UniformTypeIdentifiers

extension UTType {
    static let linePayCrewRules = UTType(
        exportedAs: "com.streamentry.linepay.crew-rules", conformingTo: .json)
}

struct CrewRuleFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.linePayCrewRules] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents, bytes.count <= 65_536 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Provider access stays off the UI actor and never allocates an unbounded selected file.
actor CrewRuleFileIO {
    func read(_ url: URL) throws -> Data {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let result = CrewRuleReadResult()
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { selected in
            result.value.withLock { value in
                value = Result {
                    guard let stream = InputStream(url: selected) else {
                        throw CocoaError(.fileReadUnknown)
                    }
                    stream.open()
                    defer { stream.close() }
                    var bytes = Data()
                    var buffer = [UInt8](repeating: 0, count: 4_096)
                    while true {
                        try Task.checkCancellation()
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        guard count >= 0 else { throw CocoaError(.fileReadUnknown) }
                        if count == 0 { break }
                        guard bytes.count <= 65_536 - count else {
                            throw CocoaError(.fileReadTooLarge)
                        }
                        bytes.append(contentsOf: buffer.prefix(count))
                    }
                    return bytes
                }
            }
        }
        if let error { throw error }
        try Task.checkCancellation()
        guard let value = result.value.withLock({ $0 }) else { throw CocoaError(.fileReadUnknown) }
        return try value.get()
    }
}

private final class CrewRuleReadResult: Sendable {
    let value = Mutex<Result<Data, any Error>?>(nil)
}
