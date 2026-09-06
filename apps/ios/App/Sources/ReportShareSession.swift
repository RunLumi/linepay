import Foundation

struct ReportPrivacyOptions: Equatable, Sendable {
    var includeSourceDetails = false
}

/// The preview reads immutable bytes. A stale, replaced or deleted file cannot grant a share URL.
struct PreparedReport: Equatable, Sendable {
    let url: URL
    let data: Data
}

@MainActor
struct ReportShareSession {
    private let export: (ReportPrivacyOptions) throws -> URL
    private let remove: (URL) throws -> Void
    private let read: (URL) throws -> Data
    private(set) var preparedReport: PreparedReport?
    private(set) var previewedReport: PreparedReport?
    private(set) var errorMessage: String?
    private var pendingCleanup: Set<URL> = []

    init(
        export: @escaping (ReportPrivacyOptions) throws -> URL,
        remove: @escaping (URL) throws -> Void = TemporaryExports.removeReport,
        read: @escaping (URL) throws -> Data = ReportShareSession.readReport
    ) {
        self.export = export
        self.remove = remove
        self.read = read
    }

    var shareURL: URL? {
        guard let preparedReport, preparedReport == previewedReport,
            let current = try? read(preparedReport.url), current == preparedReport.data
        else { return nil }
        return preparedReport.url
    }

    mutating func prepare(privacy: ReportPrivacyOptions) {
        discard()
        var createdURL: URL?
        do {
            let url = try export(privacy)
            createdURL = url
            preparedReport = PreparedReport(url: url, data: try read(url))
        } catch {
            if let createdURL { pendingCleanup.insert(createdURL) }
            retryCleanup()
            errorMessage =
                "The report could not be prepared. Your original records are unchanged. Check device storage and retry."
            if !pendingCleanup.isEmpty {
                errorMessage =
                    "The report could not be prepared, and a temporary copy could not be removed. Your original records are unchanged. Retry temporary cleanup after freeing device storage."
            }
        }
    }

    mutating func previewLoaded(_ report: PreparedReport) {
        guard report == preparedReport else { return }
        previewedReport = report
    }

    mutating func previewFailed(_ report: PreparedReport) {
        guard report == preparedReport else { return }
        previewedReport = nil
        errorMessage =
            "The report preview could not be opened. Sharing is unavailable; go back and prepare it again."
    }

    /// Invalidate access before attempting deletion. Failed deletion remains retryable.
    mutating func discard() {
        if let report = preparedReport { pendingCleanup.insert(report.url) }
        preparedReport = nil
        previewedReport = nil
        errorMessage = nil
        retryCleanup()
    }

    private mutating func retryCleanup() {
        for url in Array(pendingCleanup) {
            do {
                try remove(url)
                pendingCleanup.remove(url)
            } catch {
                errorMessage =
                    "A temporary report could not be removed. It is no longer available to share here. Retry or use Delete all local data to retry app-owned cleanup."
            }
        }
    }

    nonisolated private static func readReport(_ url: URL) throws -> Data {
        guard url.isFileURL else { throw ReportShareError.unreadableFile }
        guard (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) == nil else {
            throw ReportShareError.unreadableFile
        }
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
            let size = values.fileSize, size > 0, size <= 20 * 1024 * 1024
        else { throw ReportShareError.unreadableFile }
        let data = try Data(contentsOf: url)
        guard data.count == size else { throw ReportShareError.unreadableFile }
        return data
    }
}

private enum ReportShareError: Error {
    case unreadableFile
}
