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
