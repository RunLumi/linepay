import SwiftUI

struct DataRecoveryView: View {
    let model: AppModel

    @State private var showingResetConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                        Text("Your saved LinePaycheck data needs attention")
                            .font(.title.bold())
                        Text(
                            "LinePaycheck could not safely read the local state file, so it did not "
                                + "overwrite it or invent a partial recovery."
                        )
                        .foregroundStyle(LinePayColor.textSecondary)
                    }

                    if let issue = model.persistenceIssue {
                        Text(issue)
                            .font(.callout)
                            .foregroundStyle(LinePayColor.textSecondary)
                            .textSelection(.enabled)
                    }

                    if let recoveryURL = model.recoveryFileURL {
                        ShareLink(item: recoveryURL) {
                            Label("Export recovery file", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LinePayColor.brandPrimary)

                        Text(
                            "Export the raw local file before resetting or restoring to preserve it "
                                + "for support or manual recovery."
                        )
                        .font(.footnote)
                        .foregroundStyle(LinePayColor.textSecondary)
                    }

                    Button("Try opening data again") {
                        do {
                            try model.retryLoad()
                            errorMessage = nil
                        } catch { errorMessage = error.localizedDescription }
                    }.buttonStyle(LinePayPrimaryButtonStyle())
                    NavigationLink("Support and recovery information") {
                        LegalTextView(kind: .support)
                    }
                    BackupRestoreEntryPoint(title: "Restore from iCloud Drive")

                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset local LinePaycheck data", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("Data recovery")
        }
        .confirmationDialog(
            "Reset LinePay?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset local data", role: .destructive) { reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This removes the unreadable local state and stored paystub evidence from this iPhone. Backups saved in iCloud Drive or Files are not deleted."
            )
        }
    }

    private func reset() {
        do {
            try model.resetAfterPersistenceFailure()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
