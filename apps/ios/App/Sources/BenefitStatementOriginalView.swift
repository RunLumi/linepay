import PDFKit
import SwiftUI

enum BenefitStatementOrigin: Hashable {
    case draft(UUID)
    case revision(UUID, UUID)
}

struct BenefitStatementOriginalView: View {
    let model: AppModel
    let origin: BenefitStatementOrigin
    @Environment(\.dismiss) private var dismiss
    @State private var checkedURL: URL?
    @State private var failed = false

    private var input: BenefitAuditDraft? {
        switch origin {
        case .draft(let id): model.benefitAuditDraft.flatMap { $0.id == id ? $0 : nil }
        case .revision(let record, let revision):
            model.benefitAuditRecords.first { $0.id == record }?.revisions.first {
                $0.id == revision
            }?.input
        }
    }

    var body: some View {
        Group {
            if input?.statementEvidence == nil {
                ContentUnavailableView(
                    "Original not retained", systemImage: "doc",
                    description: Text(
                        "Saved observations and comparisons remain. A file created or shared elsewhere is separate from the original retained here."
                    ))
            } else if let checkedURL {
                VStack(spacing: 0) {
                    Text("Original matches the recorded file; values still need your review.").font(
                        .caption
                    ).padding()
                        .accessibilityIdentifier("benefits.original-checked")
                    BenefitPDFPreview(url: checkedURL)
                }
            } else if failed {
                ContentUnavailableView(
                    "Original unavailable or changed", systemImage: "doc.badge.exclamationmark",
                    description: Text(
                        "The retained PDF could not be checked against this statement's recorded fingerprint. Keep your records and review the source manually."
                    ))
            } else {
                ProgressView("Checking retained original")
            }
        }
        .navigationTitle("Original benefits statement").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.accessibilityIdentifier("benefits.source-done")
            }
        }
        .task(
            id:
                "\(input?.statementEvidence?.storedFilename ?? "missing")|\(input?.statementSHA256 ?? "missing")"
        ) {
            checkedURL = nil
            failed = false
            guard let value = input, let evidence = value.statementEvidence,
                let hash = value.statementSHA256, let url = model.evidenceURL(for: evidence)
            else { return }
            do {
                let checked = try await AgreementDocumentService.verifiedURL(
                    url, sha256: hash, page: 0)
                try Task.checkCancellation()
                checkedURL = checked
            } catch is CancellationError { return } catch { failed = true }
        }
    }
}

private struct BenefitPDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
