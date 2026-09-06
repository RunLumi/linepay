import CoreTransferable
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Every current, archived and revision report uses this same preview-before-share path.
struct ReportSharingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var privacy = ReportPrivacyOptions()
    @State private var session: ReportShareSession
    @State private var showingPreview = false

    init(context: PayPeriodContext) {
        _session = State(
            initialValue: ReportShareSession { privacy in
                guard let calculation = context.calculation else {
                    throw AppModelError.calculationUnavailable
                }
                return try ReconciliationReportExporter().export(
                    window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
                    agreement: context.agreement, calculation: calculation,
                    paystub: context.paystub, reconciliation: context.reconciliation,
                    findings: [], privacy: privacy)
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose what to share") {
                    Text(
                        "The default copy includes pay amounts, dates, calculations and source page references. Original paystub pages, optional OCR source text, profile names and source identifiers are excluded. It is not anonymous."
                    )
                    Toggle("Include optional source details", isOn: $privacy.includeSourceDetails)
                        .accessibilityIdentifier("report.include-source-details")
                    if privacy.includeSourceDetails {
                        Label(
                            "This adds profile identity, source names and URLs, private rule notes and OCR source lines. Those lines may include unrelated personal information. Review every page before sharing.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(LinePayColor.review)
                    }
                }
                Section {
                    Button("Preview this report") {
                        session.prepare(privacy: privacy)
                        showingPreview = session.preparedReport != nil
                    }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .accessibilityIdentifier("report.preview")
                    Text(
                        "Nothing is sent automatically. Your original records stay unchanged. Deleting local data cannot remove a copy you previously shared or saved in Files."
                    ).font(.footnote)
                }
                if let message = session.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                        Button("Retry temporary cleanup") { session.discard() }
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Prepare report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        session.discard()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPreview, onDismiss: { session.discard() }) {
                if let report = session.preparedReport {
                    ReportPreviewView(report: report, session: $session)
                }
            }
        }
        .onChange(of: privacy) { _, _ in session.discard() }
        .onDisappear { session.discard() }
    }
}

private struct ReportPreviewView: View {
    let report: PreparedReport
    @Binding var session: ReportShareSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sensitive pay information. Review this exact copy before sharing.")
                    .font(.callout)
                    .padding(.horizontal)
                    .accessibilityIdentifier("report.preview-warning")
                if let document = PDFDocument(data: report.data), document.pageCount > 0 {
                    ReportPDFView(document: document)
                        .accessibilityIdentifier("report.pdf")
                        .task { session.previewLoaded(report) }
                    if session.shareURL == report.url {
                        ShareLink(
                            "Share report", item: ReportSharePayload(report: report),
                            preview: SharePreview(
                                "LinePaycheck report", image: Image(systemName: "doc.text"))
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal)
                        .accessibilityIdentifier("audit.share-report")
                    } else {
                        Text("Sharing is unavailable until this file is loaded and unchanged.")
                            .font(.footnote).padding(.horizontal)
                    }
                } else {
                    ContentUnavailableView(
                        "Preview unavailable", systemImage: "doc.badge.ellipsis",
                        description: Text(
                            "Go back and prepare the report again. Your records are unchanged.")
                    )
                    .task { session.previewFailed(report) }
                }
            }
            .padding(.vertical)
            .navigationTitle("Review report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}

private struct ReportPDFView: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = document
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

/// Transfer immutable preview bytes, not a temporary file URL. The system activity retains its
/// own value even if the report sheet closes and the app removes its temporary working copy.
struct ReportSharePayload: Transferable, Sendable {
    let data: Data
    init(report: PreparedReport) { data = report.data }
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { (payload: ReportSharePayload) in
            payload.data
        }
        .suggestedFileName("LinePaycheck-audit.pdf")
    }
}
