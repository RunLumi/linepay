import PDFKit
import SwiftUI

struct AgreementOriginalView: View {
    let model: AppModel
    let documentID: UUID
    var page = 0
    var expectedSHA256: String? = nil
    @State private var verifiedURL: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if let document = model.agreementDocument(id: documentID), document.evidence != nil {
                if let verifiedURL {
                    VStack(spacing: 0) {
                        Text("Original matches the recorded file")
                            .font(.caption).padding(.vertical, 6)
                            .accessibilityIdentifier("agreement.original-checked")
                        AgreementPDFPreview(url: verifiedURL, page: page)
                            .accessibilityIdentifier("agreement.original-pdf")
                    }
                } else if failed {
                    ContentUnavailableView(
                        "Original unavailable or changed", systemImage: "doc.badge.exclamationmark",
                        description: Text(
                            "The retained bytes or page could not be checked against this source's recorded fingerprint. Keep your records and restore the exact original if needed."
                        ))
                } else {
                    ProgressView("Checking retained original")
                }
            } else {
                ContentUnavailableView(
                    "Original not retained", systemImage: "doc",
                    description: Text(
                        "The recorded citation and rules remain. Reattach the exact original from Agreement documents to open it here."
                    ))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("Citation: PDF page \(page + 1). You can zoom and read the complete document.")
                .font(.caption).padding().frame(maxWidth: .infinity)
                .background(LinePayColor.canvas)
        }
        .navigationTitle("Agreement original").navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            verifiedURL = nil
            failed = false
            guard let document = model.agreementDocument(id: documentID),
                let evidence = document.evidence, let url = model.evidenceURL(for: evidence),
                expectedSHA256 == nil || expectedSHA256 == document.sha256
            else {
                failed = true
                return
            }
            do {
                let checked = try await AgreementDocumentService.verifiedURL(
                    url, sha256: document.sha256, page: page)
                try Task.checkCancellation()
                verifiedURL = checked
            } catch is CancellationError { return } catch { failed = true }
        }
    }

    private var taskID: String {
        "\(documentID)|\(page)|\(model.agreementDocument(id: documentID)?.evidence?.storedFilename ?? "missing")"
    }
}

private struct AgreementPDFPreview: UIViewRepresentable {
    let url: URL
    let page: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        if let target = view.document?.page(at: page) { view.go(to: target) }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
