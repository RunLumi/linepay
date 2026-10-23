import SwiftUI
import UniformTypeIdentifiers

extension LocalMilestone {
    var title: String {
        switch self {
        case .firstObservedOpen: "First open observed by this ledger"
        case .appOpened: "App launches observed"
        case .profileStarted: "Profile setup started"
        case .profileReady: "Profile saved"
        case .workLogged: "New work entries saved"
        case .expectedPaySeen: "Periods with expected pay displayed"
        case .paycheckIntakeStarted: "Paycheck intake started"
        case .paycheckImported: "Periods with paycheck facts received"
        case .auditCompleted: "Periods with a comparable confirmed check"
        case .secondAudit: "Second comparable period observed"
        case .purchaseVerified: "Verified purchase outcomes"
        case .verifiedTrialObserved: "Verified trial transactions observed"
        case .verifiedPaidObserved: "Verified paid transactions observed"
        case .backupRestored: "Pay-data backups restored"
        }
    }
}

struct LocalDiagnosticsView: View {
    let ledger: LocalActivityLedger
    @State private var preview: DiagnosticPreview?
    @State private var clearing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text(
                    "These local usage counts help explain which steps were reached. No wages, payroll dates, employer or union names, documents or free-text attributes are recorded. Nothing is sent to a collector."
                ).fixedSize(horizontal: false, vertical: true)
                Toggle(
                    isOn: Binding(
                        get: { ledger.snapshot.recordingEnabled },
                        set: { enabled in
                            do {
                                try ledger.setRecordingEnabled(enabled)
                                errorMessage = nil
                            } catch {
                                errorMessage =
                                    "The recording preference could not be saved. Its previous value is still active."
                            }
                        })
                ) {
                    Text("Record device-local activity")
                        .font(.body)
                        .foregroundStyle(LinePayColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("activity.recording")
                Text(
                    "This is not an install counter or a global conversion report. Existing subscriptions, renewals and restored pay data are different from new paid customers. Turning recording off keeps prior observations until you clear them."
                ).font(.body).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("activity.recording-explanation")
                if let issue = ledger.issue {
                    Label(issue, systemImage: "exclamationmark.triangle")
                }
            } header: {
                localSectionHeader("Only on this device")
            }
            Section {
                ForEach(LocalMilestone.allCases, id: \.self) { event in
                    LabeledContent(event.title, value: "\(ledger.count(event))").monospacedDigit()
                        .accessibilityIdentifier("activity.count.\(event.rawValue)")
                }
                Text(
                    "Daily breakdown is limited to 400 observed UTC days. Internal deduplication is bounded; counts can be incomplete after failures, disabled recording or retention. Pay backups do not contain this ledger and do not backfill it."
                ).font(.body).fixedSize(horizontal: false, vertical: true)
            } header: {
                localSectionHeader("Observed since the local ledger started")
            }
            Section {
                Text(
                    "The export contains event labels, counts, usage days and recording status. Usage patterns can still be personal; it is not anonymous. It is not a pay-data backup."
                ).fixedSize(horizontal: false, vertical: true)
                Button("Preview local diagnostic file") {
                    do {
                        preview = DiagnosticPreview(data: try ledger.diagnosticData())
                        errorMessage = nil
                    } catch {
                        errorMessage =
                            "The diagnostic preview could not be prepared. Existing records are unchanged."
                    }
                }.linePayRowAction().accessibilityIdentifier("activity.preview")
                Button("Clear only local activity", role: .destructive) { clearing = true }
                    .accessibilityIdentifier("activity.clear")
            } header: {
                localSectionHeader("Manual diagnostic export")
            }
            if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
            }
        }
        .labeledContentStyle(LinePayValueStyle()).linePayCanvas()
        .navigationTitle("Device-local activity").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $preview) { value in LocalDiagnosticPreviewView(data: value.data) }
        .confirmationDialog(
            "Clear this device's activity observations?", isPresented: $clearing,
            titleVisibility: .visible
        ) {
            Button("Clear activity", role: .destructive) {
                do {
                    try ledger.clear()
                    errorMessage = nil
                } catch {
                    errorMessage =
                        "Activity could not be cleared. Retry after checking device storage."
                }
            }.accessibilityIdentifier("activity.confirm-clear")
        } message: {
            Text(
                "Work, rules, fund checks, paystubs, originals, backups and App Store access are unchanged. The recording preference is kept. Files you already exported are not deleted."
            )
        }
    }

    private func localSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .textCase(nil)
            .foregroundStyle(LinePayColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct DiagnosticPreview: Identifiable {
    let id = UUID()
    let data: Data
}

private struct LocalDiagnosticPreviewView: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        "Review this exact diagnostic copy. It includes local usage days and counts; choose a private destination yourself."
                    ).font(.callout)
                    Text(String(decoding: data, as: UTF8.self)).font(
                        .system(.footnote, design: .monospaced)
                    )
                    .textSelection(.enabled).accessibilityIdentifier("activity.preview-json")
                    if let message { Text(message) }
                }.padding()
            }
            .linePayCanvas().navigationTitle("Review local diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LinePayBottomBar {
                    Button("Choose destination") { exporting = true }
                        .buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                            "activity.export")
                }
            }
            .fileExporter(
                isPresented: $exporting, document: LocalDiagnosticDocument(data: data),
                contentType: .json,
                defaultFilename: "LinePaycheck-local-diagnostics"
            ) { result in
                switch result {
                case .success:
                    message =
                        "The selected provider accepted the file. Check the saved copy and any upload status; this screen does not verify delivery to another device."
                case .failure:
                    message =
                        "The file was not exported successfully. Your local observations and pay records are unchanged."
                }
            }
        }
    }
}

struct LocalDiagnosticDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
