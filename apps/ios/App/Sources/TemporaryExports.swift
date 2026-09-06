import Foundation

/// Only app-owned temporary copies live here. User exports in Files are never deleted by the app.
enum TemporaryExports {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "LinePayExports", isDirectory: true)
    }
    static func destination(name: String, extension suffix: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(name)-\(UUID().uuidString).\(suffix)")
    }
    /// Removes only the specific app-owned report, never an imported original or provider copy.
    static func removeReport(_ url: URL) throws {
        let expected = directory.standardizedFileURL
        let candidate = url.standardizedFileURL
        let name = candidate.deletingPathExtension().lastPathComponent
        let prefix = "LinePaycheck-audit-"
        guard candidate.deletingLastPathComponent() == expected,
            candidate.pathExtension == "pdf", name.hasPrefix(prefix),
            UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
        else { throw TemporaryExportError.unsafePath }
        if FileManager.default.fileExists(atPath: expected.path) {
            let parent = try expected.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard parent.isSymbolicLink != true else { throw TemporaryExportError.unsafePath }
        }
        // A dangling link also fails: it must not be treated as an already removed report.
        let values: URLResourceValues
        do {
            values = try candidate.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        } catch CocoaError.fileReadNoSuchFile { return }
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw TemporaryExportError.unsafePath
        }
        try FileManager.default.removeItem(at: candidate)
    }

    static func removeAll() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        // Clean older app-owned exports produced before the scoped directory existed.
        let urls = try FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)
        for url in urls
        where ["LinePaycheck-", "LinePay-backup-"].contains(where: {
            url.lastPathComponent.hasPrefix($0)
        }) && ["json", "pdf"].contains(url.pathExtension) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

private enum TemporaryExportError: Error {
    case unsafePath
}
