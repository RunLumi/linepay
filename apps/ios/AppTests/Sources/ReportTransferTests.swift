import CoreTransferable
import Foundation
import PDFKit
import Testing
import UniformTypeIdentifiers

@testable import LinePay

/// Exercise the real Transferable conformance, not just its stored Data property.
/// Native Apple-framework test: never substitute the portable sharing-core suite for this.
@Suite("PDF receiver handoff preserves the preview", .serialized)
@MainActor
struct ReportTransferTests {
    @available(iOS 18.2, *)
    @Test func actualTransferRepresentationSurvivesWorkingFileCleanup() async throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let context = try #require(model.periodContext())
        let stateBefore = store.state
        var session = ReportShareSession { privacy in
            try ReconciliationReportExporter().export(
                window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
                agreement: context.agreement, calculation: #require(context.calculation),
                paystub: context.paystub, reconciliation: context.reconciliation,
                findings: [], privacy: privacy)
        }
        defer { session.discard() }
        session.prepare(privacy: ReportPrivacyOptions())
        let report = try #require(session.preparedReport)
        session.previewLoaded(report)
        #expect(session.shareURL == report.url)
        let payload = ReportSharePayload(report: report)
        let transferredBeforeCleanup = try await payload.exported(as: .pdf)
        #expect(transferredBeforeCleanup == report.data)

        session.discard()
        #expect(session.shareURL == nil)
        #expect(!FileManager.default.fileExists(atPath: report.url.path))
        let transferredAfterCleanup = try await payload.exported(as: .pdf)
        #expect(transferredAfterCleanup == transferredBeforeCleanup)
        let document = try #require(PDFDocument(data: transferredAfterCleanup))
        #expect(document.pageCount > 0)
        let text = try #require(document.string)
        #expect(text.contains("Expected wage pay:") && text.contains("400"))
        #expect(text.contains("Not a complete wage-law check"))
        #expect(text.contains("not anonymous"))
        #expect(store.state == stateBefore)
    }

    @available(iOS 18.2, *)
    @Test func unsupportedReceiverTypeCannotSilentlyExportAnotherFormat() async throws {
        let data = Data("SYNTHETIC PDF REPRESENTATION".utf8)
        let payload = ReportSharePayload(
            report: PreparedReport(url: URL(fileURLWithPath: "/synthetic/not-read.pdf"), data: data)
        )
        do {
            _ = try await payload.exported(as: .plainText)
            Issue.record("A PDF-only transfer must not masquerade as plain text")
        } catch {
            // The system rejects the unsupported content type; it must not change representations.
        }
    }
}
