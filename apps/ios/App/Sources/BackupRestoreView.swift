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
                HStack(alignment: .firstTextBaseline, spacing: LinePaySpacing.standard) {
                    Image(systemName: "icloud.and.arrow.up")
                        .accessibilityHidden(true)
                    Text(title)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .linePayRowAction()
            }
            .buttonStyle(.plain)
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
    @State private var passwordProtect = false
    @State private var exportPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordKept = false
    @State private var encryptedSelection: URL?
    @State private var unlockPassword = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Optional password protection") {
                    ConfirmationCheckRow(
                        "Protect this copy with a password", isOn: $passwordProtect
                    )
                    .accessibilityIdentifier("backup.protect")
                    if passwordProtect {
                        SecureField("New backup password", text: $exportPassword)
                            .textContentType(.newPassword).accessibilityIdentifier(
                                "backup.password")
                        SecureField("Confirm backup password", text: $confirmPassword)
                            .textContentType(.newPassword).accessibilityIdentifier(
                                "backup.password-confirm")
                        Text(
                            "Use a long, unique passphrase of at least 12 characters. Spaces are kept. Store it separately; LinePaycheck cannot recover a forgotten password. Older app versions cannot open protected copies."
                        )
                        .font(.footnote)
                        ConfirmationCheckRow(
                            "I have kept the password separately", isOn: $passwordKept
                        )
                        .accessibilityIdentifier("backup.password-kept")
                    }
                }.disabled(session.isBusy)
                Section {
                    Button {
                        guard validateExportPassword() else { return }
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

                if let url = encryptedSelection {
                    Section("Unlock selected backup") {
                        Text(
                            "This copy is password-protected. Unlocking checks the file; it does not replace your records."
                        )
                        SecureField("Backup password", text: $unlockPassword)
                            .textContentType(.password).accessibilityIdentifier(
                                "backup.unlock-password")
                        Button("Unlock and review") { inspect(url, password: unlockPassword) }
                            .disabled(session.isBusy || unlockPassword.isEmpty)
                            .accessibilityIdentifier("backup.unlock")
                        Button("Discard locked selection", role: .cancel) {
                            encryptedSelection = nil
                            unlockPassword = ""
                        }.accessibilityIdentifier("backup.discard-locked")
                    }
                }
                if let archive = reviewedBackup {
                    Section("Review this backup") {
                        Text(
                            archive.wasPasswordProtected
                                ? "Password-protected copy unlocked"
                                : "This copy is not password-encrypted"
                        )
                        .accessibilityIdentifier("backup.protection-status")
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
                        "Saved pay profiles, exact rule snapshots, work entries, notes, pay periods, confirmed paycheck facts, saved paycheck checks, and retained original paystubs."
                    )
                    Text(
                        "Saved drafts and retained originals are included. Unsaved input, deleted originals, and App Store subscription entitlements are not included. Restore Purchases is separate."
                    )
                    .foregroundStyle(LinePayColor.textSecondary)
                }
                Section("Privacy & control") {
                    Text(
                        "With password protection off, the file is not password-encrypted by LinePaycheck. Anyone who can open that copy can read it. Protected copies require their password; weak or shared passwords reduce protection. Keep all copies in a private location."
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
            .disabled(session.isBusy)
            .linePayCanvas().linePayKeyboardDismiss()
            .labeledContentStyle(LinePayValueStyle())
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.disabled(session.isBusy)
                        .accessibilityIdentifier("backup.done")
                }
            }
        }
        .onChange(of: passwordProtect) { _, _ in clearExportPassword() }
        .onChange(of: exportPassword) { _, _ in passwordKept = false }
        .onChange(of: confirmPassword) { _, _ in passwordKept = false }
        .onDisappear {
            clearExportPassword()
            unlockPassword = ""
            encryptedSelection = nil
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
                passwordProtect
                    ? "Includes sensitive pay details and originals. This copy will require the password you entered. Keep the password separately; LinePaycheck cannot recover it."
                    : "Includes pay details and original paystubs. Not password-encrypted."
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

    private func clearExportPassword() {
        exportPassword = ""
        confirmPassword = ""
        passwordKept = false
    }

    private func validateExportPassword() -> Bool {
        guard passwordProtect else { return true }
        do { try BackupEncryption.validateNewPassword(exportPassword) } catch {
            showMessage(backupMessage(error), error: true)
            return false
        }
        guard
            exportPassword.precomposedStringWithCanonicalMapping
                == confirmPassword.precomposedStringWithCanonicalMapping
        else {
            showMessage(
                "The password confirmation does not match. Nothing was exported.", error: true)
            return false
        }
        guard passwordKept else {
            showMessage(
                "Keep the password separately and confirm before exporting. LinePaycheck cannot recover it.",
                error: true)
            return false
        }
        return true
    }

    private func prepare() {
        guard validateExportPassword() else { return }
        let password = passwordProtect ? exportPassword : nil
        operation = "Preparing complete backup..."
        message = nil
        Task {
            defer { clearExportPassword() }
            do {
                export = BackupTransfer(data: try await session.prepareBackup(password: password))
                exportName = "LinePaycheck-\(UUID().uuidString.prefix(8))"
                showExporter = true
            } catch {
                showMessage(backupMessage(error), error: true)
            }
        }
    }

    private func inspect(_ url: URL, password: String? = nil) {
        reviewedBackup = nil
        encryptedSelection = nil
        operation = "Checking backup integrity..."
        message = nil
        Task {
            defer { unlockPassword = "" }
            do {
                reviewedBackup = try await session.inspectBackup(at: url, password: password)
            } catch BackupError.passwordRequired {
                encryptedSelection = url
                showMessage(backupMessage(BackupError.passwordRequired))
            } catch {
                if password != nil { encryptedSelection = url }
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
