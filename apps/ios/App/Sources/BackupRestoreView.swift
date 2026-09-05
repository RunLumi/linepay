import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let linePayBackup = UTType(
        exportedAs: "com.streamentry.linepay.backup", conformingTo: .data)
}

struct BackupTransfer: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .linePayBackup) { $0.data }
    }
}

private struct AppSessionKey: EnvironmentKey {
    static let defaultValue: AppSession? = nil
}

extension EnvironmentValues {
    var linePaySession: AppSession? {
        get { self[AppSessionKey.self] }
        set { self[AppSessionKey.self] = newValue }
    }
}

/// Reused by Settings, first launch, and the local-data recovery screen.
struct BackupRestoreEntryPoint: View {
    @Environment(\.linePaySession) private var session
    @State private var isPresented = false
    var title = "iCloud backup & restore"

    var body: some View {
        if let session {
            Button {
                isPresented = true
            } label: {
                Label(title, systemImage: "icloud.and.arrow.up")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("backup.open")
            .sheet(isPresented: $isPresented) {
                BackupRestoreView(session: session)
            }
        }
    }
}

struct BackupRestoreView: View {
    let session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var export: BackupTransfer?
    @State private var exportName = "LinePaycheck"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showExportConsent = false
    @State private var showRestoreConfirmation = false
    @State private var reviewedBackup: BackupArchive?
    @State private var message: String?
    @State private var isError = false
    @State private var operation = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showExportConsent = true
                    } label: {
                        Label("Back up to iCloud Drive", systemImage: "icloud.and.arrow.up")
                            .frame(minHeight: 48)
                    }
                    .disabled(session.model.persistenceIssue != nil || session.isBusy)
                    .accessibilityIdentifier("backup.save")
                    Button {
                        reviewedBackup = nil
                        message = nil
                        showImporter = true
                    } label: {
                        Label("Restore from iCloud Drive", systemImage: "icloud.and.arrow.down")
                            .frame(minHeight: 48)
                    }
                    .disabled(session.isBusy)
                    .accessibilityIdentifier("backup.restore")
                } header: {
                    Text("Your saved records")
                } footer: {
                    Text(
                        "Save a manual copy using Files, then restore it on this or another iPhone. "
                            + "Choose a private iCloud Drive folder or another Files location. "
                            + "This does not turn on automatic backup or live sync."
                    )
                }

                if let archive = reviewedBackup {
                    Section("Review this backup") {
                        LabeledContent("Created") { Text(archive.createdAt, format: .dateTime) }
                        LabeledContent("Pay periods", value: "\(archive.periodCount)")
                        LabeledContent("Work entries", value: "\(archive.workCount)")
                        LabeledContent("Original paystubs", value: "\(archive.files.count)")
                        Text(
                            "Restoring replaces this iPhone's saved LinePaycheck data. It does not merge records. Back up current data first if you need to keep it."
                        )
                        .font(.footnote)
                        if session.model.persistenceIssue != nil {
                            Text(
                                "Your current data is unreadable. Export its recovery file before replacing it. Older original files may remain until you delete all local data."
                            )
                            .font(.footnote)
                        }
                        Button("Replace local data with this backup", role: .destructive) {
                            showRestoreConfirmation = true
                        }
                        .frame(minHeight: 48)
                        .disabled(session.isBusy)
                        .accessibilityIdentifier("backup.confirm-restore")
                        Button("Discard selection", role: .cancel) { reviewedBackup = nil }
                            .accessibilityIdentifier("backup.discard-selection")
                    }
                }

                if session.isBusy {
                    Section { ProgressView(operation) }
                }
                if let message {
                    Section {
                        Label(
                            message,
                            systemImage: isError ? "exclamationmark.triangle" : "info.circle"
                        )
                        .foregroundStyle(LinePayColor.textPrimary)
                        .accessibilityIdentifier("backup.status")
                    }
                }

                Section("What is included") {
                    Text(
                        "Saved pay profiles, exact rule snapshots, work entries, notes, pay periods, confirmed paycheck facts, audit history, and retained original paystubs."
                    )
                    Text(
                        "Unsaved drafts, deleted originals, and App Store subscription entitlements are not included. Restore Purchases is separate."
                    )
                    .foregroundStyle(LinePayColor.textSecondary)
                }
                Section("Privacy & control") {
                    Text(
                        "The file contains sensitive pay data and is not password-encrypted by LinePaycheck. Use a private folder. Anyone who can open the file can access its contents."
                    )
                    Text(
                        "Data leaves this device only when you choose a destination. LinePaycheck does not upload it to its own server. Deleting local data does not delete copies saved in iCloud Drive or Files."
                    )
                    Text(
                        "After saving to iCloud Drive, check in Files that upload has completed before relying on the copy on another device."
                    )
                }
                .font(.footnote)
            }
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.disabled(session.isBusy)
                        .accessibilityIdentifier("backup.done")
                }
            }
        }
        .interactiveDismissDisabled(session.isBusy)
        .fileExporter(
            isPresented: $showExporter, item: export, contentTypes: [.linePayBackup],
            defaultFilename: exportName
        ) { result in
            export = nil
            switch result {
            case .success:
                showMessage(
                    "Saved to your selected location. For iCloud Drive, confirm upload in Files.")
            case .failure:
                showMessage(
                    "The backup was not saved. Check storage and your chosen Files location, then retry.",
                    error: true)
            }
        } onCancellation: {
            export = nil
            showMessage("Backup cancelled. No destination was saved by this operation.")
        }
        .fileImporter(
            isPresented: $showImporter, allowedContentTypes: [.linePayBackup, .data]
        ) { result in
            switch result {
            case .success(let url): inspect(url)
            case .failure: showMessage("No backup was opened. Retry from Files.", error: true)
            }
        }
        .alert(
            "Save a backup?", isPresented: $showExportConsent
        ) {
            Button("Choose location") { prepare() }
                .accessibilityIdentifier("backup.choose-location")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Includes pay details and original paystubs. Not password-encrypted."
            )
        }
        .confirmationDialog(
            "Replace local LinePaycheck data?", isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore and replace", role: .destructive) { restore() }
                .accessibilityIdentifier("backup.perform-restore")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Current saved records will be replaced, not merged. Your selected backup and App Store purchases will not change. Export current data or its recovery file first if you need to preserve it."
            )
        }
    }

    private func showMessage(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }

    private func prepare() {
        operation = "Preparing complete backup..."
        message = nil
        Task {
            do {
                export = BackupTransfer(data: try await session.prepareBackup())
                exportName = "LinePaycheck-\(UUID().uuidString.prefix(8))"
                showExporter = true
            } catch {
                showMessage(backupMessage(error), error: true)
            }
        }
    }

    private func inspect(_ url: URL) {
        operation = "Checking backup integrity..."
        message = nil
        Task {
            do { reviewedBackup = try await session.inspectBackup(at: url) } catch {
                showMessage(backupMessage(error), error: true)
            }
        }
    }

    private func restore() {
        guard let archive = reviewedBackup else { return }
        operation = "Restoring saved data..."
        do {
            try session.restore(
                archive, replaceUnreadableData: session.model.persistenceIssue != nil)
            reviewedBackup = nil
            dismiss()
        } catch {
            showMessage(backupMessage(error), error: true)
        }
    }

    private func backupMessage(_ error: any Error) -> String {
        (error as? BackupError)?.errorDescription
            ?? "The operation could not complete. Check device storage and Files, then retry."
    }
}
