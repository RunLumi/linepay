import LinePayDomain
import QuickLook
import SwiftUI

struct AuditDetailView: View {
    let window: PayPeriodWindow
    let timeZoneIdentifier: String
    let agreement: AgreementSnapshot
    let calculation: CalculationResult
    let paystub: ConfirmedPaystub
    let reconciliation: ReconciliationResult?
    let findings: [AuditFinding]
    let evidenceURL: URL?
    let onRemoveEvidence: (() throws -> Void)?

    @State private var reportURL: URL?
    @State private var showingEvidence = false
    @State private var showingRemoveEvidenceConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                comparisonHeader
            }

            Section("What to review") {
                if reconciliation == nil {
                    Label(
                        "Re-run the audit after confirming changed work or rules.",
                        systemImage: "arrow.clockwise"
                    )
                    .foregroundStyle(LinePayColor.review)
                } else {
                    ForEach(findings) { finding in
                        NavigationLink {
                            FindingDetailView(
                                finding: finding,
                                agreement: agreement,
                                calculation: calculation,
                                paystub: paystub
                            )
                        } label: {
                            findingRow(finding)
                        }
                    }
                }
            }

            Section("Rule snapshot") {
                LabeledContent("Profile", value: agreement.displayName)
                LabeledContent("Version", value: agreement.version)
                LabeledContent("Base rate") {
                    Text("\(LinePayFormat.money(agreement.hourlyRate))/hr")
                        .monospacedDigit()
                }
                if agreement.sources.isEmpty {
                    Text("No source reference was saved for this rule snapshot.")
                        .foregroundStyle(LinePayColor.textSecondary)
                } else {
                    ForEach(Array(agreement.sources.enumerated()), id: \.offset) { _, source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.title).font(.headline)
                            if !source.url.isEmpty {
                                Text(source.url)
                                    .font(.footnote)
                                    .foregroundStyle(LinePayColor.textSecondary)
                                    .textSelection(.enabled)
                            }
                            if let section = source.section {
                                Text(section)
                                    .font(.footnote)
                                    .foregroundStyle(LinePayColor.textSecondary)
                            }
                        }
                    }
                }
            }

            Section("Paystub evidence") {
                if let evidence = paystub.evidence {
                    LabeledContent("Source", value: evidence.originalFilename)
                    LabeledContent("Imported as", value: sourceLabel(evidence.sourceKind))

                    if evidenceURL != nil {
                        Button {
                            showingEvidence = true
                        } label: {
                            Label("View original", systemImage: "doc")
                        }
                    }

                    if let recognizedText = evidence.recognizedText, !recognizedText.isEmpty {
                        DisclosureGroup("OCR text") {
                            Text(recognizedText)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    if onRemoveEvidence != nil {
                        Button(role: .destructive) {
                            showingRemoveEvidenceConfirmation = true
                        } label: {
                            Label("Remove original paystub", systemImage: "trash")
                        }
                    }
                } else {
                    Text("No original paystub is stored for this audit.")
                        .foregroundStyle(LinePayColor.textSecondary)
                }
            }

            Section("Export") {
                if let reportURL {
                    ShareLink(item: reportURL) {
                        Label("Share reconciliation report", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        makeReport()
                    } label: {
                        Label("Prepare reconciliation report", systemImage: "doc.richtext")
                    }
                }
                Text(
                    "The report does not include the original paystub unless you share it separately."
                )
                .font(.footnote)
                .foregroundStyle(LinePayColor.textSecondary)
            }

            Section {
                Text(
                    "LinePaycheck estimates and reconciles pay from the facts and rules you confirmed. "
                        + "A possible difference is a reason to review the paycheck, not a legal determination."
                )
                .font(.footnote)
                .foregroundStyle(LinePayColor.textSecondary)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(LinePayColor.difference)
                }
            }
        }
        .navigationTitle("Paycheck audit")
        .labeledContentStyle(LinePayValueStyle())
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(LinePayColor.canvas)
        .sheet(isPresented: $showingEvidence) {
            if let evidenceURL {
                QuickLookPreview(url: evidenceURL)
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "Remove the original paystub?",
            isPresented: $showingRemoveEvidenceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove original paystub", role: .destructive) {
                removeEvidence()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Confirmed audit values remain. The original image/PDF and local OCR evidence are deleted."
            )
        }
    }

    private var comparisonHeader: some View {
        VStack(spacing: LinePaySpacing.standard) {
            Text(LinePayFormat.payPeriod(window, timeZoneIdentifier: timeZoneIdentifier))
                .font(.subheadline)
                .foregroundStyle(LinePayColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LabeledContent("Expected gross") {
                Text(LinePayFormat.money(calculation.total)).monospacedDigit().bold()
            }
            LabeledContent("Paystub gross") {
                Text(LinePayFormat.money(paystub.grossPay)).monospacedDigit().bold()
            }

            Divider()

            if let reconciliation {
                VStack(spacing: 4) {
                    AuditStatusView(status: displayStatus(reconciliation.direction))
                    if reconciliation.direction != .matches {
                        Text(LinePayFormat.money(reconciliation.difference))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(LinePayColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("audit.difference")
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                AuditStatusView(status: .needsReview)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("audit.comparison")
        .padding(.vertical, LinePaySpacing.standard)
    }

    private func findingRow(_ finding: AuditFinding) -> some View {
        LabeledContent {
            Text(LinePayFormat.money(finding.difference))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(.headline)
                Text(
                    "Expected \(LinePayFormat.money(finding.expected)) · Paid \(LinePayFormat.money(finding.paid))"
                )
                .font(.footnote)
                .foregroundStyle(LinePayColor.textSecondary)
            }
        }
    }

    private func displayStatus(_ direction: ReconciliationDirection) -> AuditDisplayStatus {
        switch direction {
        case .matches: .matches
        case .possibleUnderpayment: .possibleShortfall
        case .possibleOverpayment: .possibleOverpayment
        }
    }

    private func sourceLabel(_ kind: PaystubSourceKind) -> String {
        switch kind {
        case .scan: "Document scan"
        case .photo: "Photo"
        case .file: "File"
        case .manual: "Manual entry"
        }
    }

    private func makeReport() {
        do {
            reportURL = try ReconciliationReportExporter().export(
                window: window,
                timeZoneIdentifier: timeZoneIdentifier,
                agreement: agreement,
                calculation: calculation,
                paystub: paystub,
                reconciliation: reconciliation,
                findings: findings
            )
            errorMessage = nil
        } catch {
            errorMessage = "LinePaycheck could not prepare the report."
        }
    }

    private func removeEvidence() {
        guard let onRemoveEvidence else { return }
        do {
            try onRemoveEvidence()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FindingDetailView: View {
    let finding: AuditFinding
    let agreement: AgreementSnapshot
    let calculation: CalculationResult
    let paystub: ConfirmedPaystub

    var body: some View {
        List {
            Section("Comparison") {
                LabeledContent("Expected") {
                    Text(LinePayFormat.money(finding.expected)).monospacedDigit()
                }
                LabeledContent("Confirmed paid") {
                    Text(LinePayFormat.money(finding.paid)).monospacedDigit()
                }
                LabeledContent("Difference") {
                    Text(LinePayFormat.money(finding.difference)).monospacedDigit()
                }
            }

            Section("Why") {
                Text(finding.explanation)
            }

            Section("Calculation evidence") {
                ForEach(calculation.components) { component in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(LinePayFormat.localDate(component.localDate))
                            Spacer()
                            Text(LinePayFormat.money(component.amount)).monospacedDigit()
                        }
                        Text(component.explanation)
                            .font(.footnote)
                            .foregroundStyle(LinePayColor.textSecondary)
                    }
                }
            }

            Section("Rule evidence") {
                LabeledContent("Rule version", value: agreement.version)
                if agreement.sources.isEmpty {
                    Text("No source reference saved.")
                        .foregroundStyle(LinePayColor.textSecondary)
                } else {
                    ForEach(Array(agreement.sources.enumerated()), id: \.offset) { _, source in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.title)
                            if !source.url.isEmpty {
                                Text(source.url)
                                    .font(.footnote)
                                    .foregroundStyle(LinePayColor.textSecondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }

            Section("Paystub fact") {
                LabeledContent("Gross pay") {
                    Text(LinePayFormat.money(paystub.grossPay)).monospacedDigit()
                }
                Text("Only values you confirmed are used as paycheck facts.")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
            }
        }
        .navigationTitle(finding.title)
        .labeledContentStyle(LinePayValueStyle())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}
