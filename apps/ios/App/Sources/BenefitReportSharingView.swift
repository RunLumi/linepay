import SwiftUI

struct BenefitReportSharingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var privacy = ReportPrivacyOptions()
    @State private var session: ReportShareSession
    @State private var showingPreview = false

    init(revision: BenefitAuditRevision) {
        _session = State(
            initialValue: ReportShareSession { privacy in
                try BenefitReportExporter().export(revision, privacy: privacy)
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose what to share") {
                    Text(
                        "The default report includes covered dates, amounts, eligible units, rates and comparison limits. Fund/source names, original pages, quotations, fingerprints and your private note are excluded. It is not anonymous."
                    )
                    Toggle("Include optional source details", isOn: $privacy.includeSourceDetails)
                        .accessibilityIdentifier("benefits.report-sources")
                    Toggle("Include this check's private note", isOn: $privacy.includeBenefitNotes)
                        .accessibilityIdentifier("benefits.report-note")
                    if privacy.includeSourceDetails || privacy.includeBenefitNotes {
                        Label(
                            "This can reveal fund/source names, source quotations, file fingerprints or personal notes. Inspect the exact PDF before sharing.",
                            systemImage: "exclamationmark.triangle")
                    }
                }
                Section {
                    Button("Preview this report") {
                        session.prepare(privacy: privacy)
                        showingPreview = session.preparedReport != nil
                    }
                    .buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                        "benefits.report-preview")
                    Text(
                        "Nothing is sent automatically. Sharing becomes available only after the exact copy loads."
                    ).font(.footnote)
                }
                if let error = session.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                        Button("Retry temporary cleanup") { session.discard() }
                    }
                }
            }
            .linePayCanvas().navigationTitle("Prepare benefits report")
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
            .onChange(of: privacy) { _, _ in session.discard() }
            .onDisappear { session.discard() }
        }
    }
}
