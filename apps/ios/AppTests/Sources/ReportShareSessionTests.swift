import Foundation
import Testing

@testable import LinePay

@Suite("Report sharing: exact preview and scoped cleanup", .serialized)
@MainActor
struct ReportShareSessionTests {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func sharingRequiresTheExactPreviewAndOptionsInvalidateIt() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        var options: [Bool] = []
        var session = ReportShareSession(
            export: { privacy in
                options.append(privacy.includeSourceDetails)
                let url = root.appendingPathComponent(UUID().uuidString + ".pdf")
                try Data("SYNTHETIC PDF".utf8).write(to: url)
                return url
            }, remove: { try FileManager.default.removeItem(at: $0) })
        #expect(session.shareURL == nil)
        session.prepare(privacy: ReportPrivacyOptions())
        let first = try #require(session.preparedReport)
        #expect(session.shareURL == nil)
        session.previewLoaded(PreparedReport(url: first.url, data: Data("OTHER".utf8)))
        #expect(session.shareURL == nil)
        session.previewLoaded(first)
        #expect(session.shareURL == first.url)
        session.prepare(privacy: ReportPrivacyOptions(includeSourceDetails: true))
        let second = try #require(session.preparedReport)
        #expect(second.url != first.url && session.shareURL == nil)
        #expect(!FileManager.default.fileExists(atPath: first.url.path))
        session.previewLoaded(first)
        #expect(session.shareURL == nil)
        session.previewFailed(second)
        #expect(session.shareURL == nil && session.errorMessage != nil)
        session.previewLoaded(second)
        #expect(session.shareURL == second.url)
        session.discard()
        #expect(session.shareURL == nil && session.preparedReport == nil)
        #expect(!FileManager.default.fileExists(atPath: second.url.path))
        #expect(options == [false, true])
    }

    @Test func changedOrRemovedBytesCannotBeSharedUsingAnOldPreview() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic.pdf")
        var session = ReportShareSession(
            export: { _ in
                try Data("ORIGINAL-SYNTHETIC".utf8).write(to: url)
                return url
            }, remove: { try FileManager.default.removeItem(at: $0) })
        session.prepare(privacy: ReportPrivacyOptions())
        let report = try #require(session.preparedReport)
        session.previewLoaded(report)
        #expect(session.shareURL == url)
        try Data("CHANGED-SYNTHETIC!".utf8).write(to: url)
        #expect(session.shareURL == nil, "URL equality alone does not prove preview equality")
        try FileManager.default.removeItem(at: url)
        #expect(session.shareURL == nil)
    }

    @Test func failedExportAndCleanupCannotLeaveAStaleShareAction() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic.pdf")
        var failExport = false
        var failCleanup = true
        var session = ReportShareSession(
            export: { _ in
                if failExport { throw Failure.injected }
                try Data("SYNTHETIC".utf8).write(to: url)
                return url
            },
            remove: { path in
                if failCleanup { throw Failure.injected }
                try FileManager.default.removeItem(at: path)
            })
        session.prepare(privacy: ReportPrivacyOptions())
        session.previewLoaded(try #require(session.preparedReport))
        #expect(session.shareURL == url)
        failExport = true
        session.prepare(privacy: ReportPrivacyOptions(includeSourceDetails: true))
        #expect(session.preparedReport == nil && session.shareURL == nil)
        #expect(session.errorMessage != nil)
        #expect(FileManager.default.fileExists(atPath: url.path))
        failCleanup = false
        session.discard()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(session.errorMessage == nil)
    }

    @Test func unreadableNewOutputIsRemovedWithoutGrantingPreviewAccess() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic.pdf")
        var session = ReportShareSession(
            export: { _ in
                try Data("SYNTHETIC".utf8).write(to: url)
                return url
            }, remove: { try FileManager.default.removeItem(at: $0) },
            read: { _ in throw Failure.injected })
        session.prepare(privacy: ReportPrivacyOptions())
        #expect(session.preparedReport == nil && session.shareURL == nil)
        #expect(session.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func emptyOutputCannotUnlockSharing() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("empty.pdf")
        var session = ReportShareSession(
            export: { _ in
                try Data().write(to: url)
                return url
            }, remove: { try FileManager.default.removeItem(at: $0) })
        session.prepare(privacy: ReportPrivacyOptions())
        #expect(session.preparedReport == nil && session.shareURL == nil)
        #expect(session.errorMessage != nil)
    }

    @Test func scopedRemovalIsIdempotentAndPreservesOtherReports() throws {
        let first = try TemporaryExports.destination(name: "LinePaycheck-audit", extension: "pdf")
        let second = try TemporaryExports.destination(name: "LinePaycheck-audit", extension: "pdf")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        try Data("SYNTHETIC FIRST".utf8).write(to: first)
        try Data("SYNTHETIC SECOND".utf8).write(to: second)
        try TemporaryExports.removeReport(first)
        try TemporaryExports.removeReport(first)
        #expect(try Data(contentsOf: second) == Data("SYNTHETIC SECOND".utf8))
    }

    @Test func cleanupRefusesUnrelatedFilesAndSymlinkTargets() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("LinePaycheck-audit-\(UUID().uuidString).pdf")
        try Data("UNRELATED".utf8).write(to: outside)
        #expect(throws: (any Error).self) { try TemporaryExports.removeReport(outside) }
        let link = try TemporaryExports.destination(name: "LinePaycheck-audit", extension: "pdf")
        defer { try? FileManager.default.removeItem(at: link) }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(throws: (any Error).self) { try TemporaryExports.removeReport(link) }
        #expect(try Data(contentsOf: outside) == Data("UNRELATED".utf8))
    }

    @Test func aFileReplacedByASymlinkCannotBeShared() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic.pdf")
        let other = root.appendingPathComponent("other.pdf")
        let bytes = Data("SAME-SYNTHETIC-CONTENT".utf8)
        try bytes.write(to: other)
        var session = ReportShareSession(
            export: { _ in
                try bytes.write(to: url)
                return url
            }, remove: { try FileManager.default.removeItem(at: $0) })
        session.prepare(privacy: ReportPrivacyOptions())
        session.previewLoaded(try #require(session.preparedReport))
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: other)
        #expect(session.shareURL == nil)
    }

    @Test func cleanupRefusesDanglingSymlinksWithoutClaimingTheyWereDeleted() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let absent = root.appendingPathComponent("not-created.pdf")
        let link = try TemporaryExports.destination(name: "LinePaycheck-audit", extension: "pdf")
        defer { try? FileManager.default.removeItem(at: link) }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: absent)
        #expect(throws: (any Error).self) { try TemporaryExports.removeReport(link) }
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == absent.path)
    }

    private enum Failure: Error { case injected }
}
