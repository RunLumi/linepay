import SwiftUI
import UniformTypeIdentifiers

struct AgreementDocumentsView: View {
    let model: AppModel
    var onPrepared: (() -> Void)? = nil
    @State private var importing = false
    @State private var isReadingFile = false
    @State private var selectedDocument: UUID?
    @State private var showingSetup = false
    @State private var errorMessage: String?
    @State private var importTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                Text(
                    "Import an agreement PDF to find candidate pay rules with page citations. Everything is read on this device. No rule becomes active until you review and save it in the rule editor."
                )
                Button("Choose agreement PDF") { importing = true }
                    .linePayRowAction().disabled(isReadingFile)
                    .accessibilityIdentifier("agreements.choose-pdf")
                if isReadingFile { ProgressView("Reading selected file; not saved yet") }
            }
            if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
            }
            Section("Retained agreements") {
                if model.agreementDocuments.isEmpty { Text("No agreement PDFs imported yet.") }
                ForEach(model.agreementDocuments.reversed()) { document in
                    NavigationLink {
                        AgreementDocumentReviewView(model: model, documentID: document.id) {
                            if let onPrepared { onPrepared() } else { showingSetup = true }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(document.filename).font(.headline)
                            Text(
                                document.candidates.map {
                                    "\($0.count) candidate clauses · review required"
                                }
                                    ?? "Original saved · reading not completed"
                            )
                            .font(.subheadline).foregroundStyle(LinePayColor.textSecondary)
                            if document.evidence == nil {
                                Label(
                                    "Original not retained",
                                    systemImage: "doc.badge.exclamationmark"
                                )
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("agreements.document")
                }
            }
        }
        .linePayCanvas()
        .navigationTitle("Agreement documents")
        .navigationDestination(item: $selectedDocument) { id in
            AgreementDocumentReviewView(model: model, documentID: id) {
                if let onPrepared { onPrepared() } else { showingSetup = true }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else {
                if case .failure = result {
                    errorMessage =
                        "The file could not be selected. Your saved originals are unchanged."
                }
                return
            }
            isReadingFile = true
            importTask = Task {
                defer { isReadingFile = false }
                do {
                    let data = try await AgreementDocumentService.read(url)
                    try Task.checkCancellation()
                    selectedDocument = try model.retainAgreement(
                        data: data, filename: url.lastPathComponent)
                    errorMessage = nil
                } catch is CancellationError { return } catch {
                    errorMessage = agreementImportMessage(error)
                }
            }
        }
        .sheet(isPresented: $showingSetup) { PayProfileSetupView(model: model) }
        .onDisappear { importTask?.cancel() }
    }
}

func agreementImportMessage(_ error: any Error) -> String {
    if let error = error as? AppModelError { return error.localizedDescription }
    if let error = error as? PaystubOCRError, case .oversizedDocument = error {
        return error.localizedDescription
    }
    return
        "This document could not be read or saved safely. Existing records and retained originals are unchanged. Retry or use confirmed rules manually."
}
