import SwiftUI

struct PaycheckResolutionView: View {
    let model: AppModel
    let periodID: UUID
    var paystubID: UUID? = nil
    @State private var status: ResolutionStatus = .reviewing
    @State private var findingID = ""
    @State private var note = ""
    @State private var errorMessage: String?
    @FocusState private var noteFocused: Bool

    var body: some View {
        Form {
            if let context = model.periodContext(id: periodID),
                let paystub = selectedPaystub(in: context)
            {
                let findings = AuditFinding.from(paystub: paystub)
                Section {
                    Text(
                        "Keep a record of what you reviewed, shared or heard back. These are your notes; they do not change the paycheck comparison or establish that money is owed or recovered."
                    )
                    Text(
                        "A useful question: Could you help me understand the difference between these confirmed work records and the paystub for this period?"
                    )
                    .font(.footnote)
                }
                if !findings.isEmpty {
                    Section("Comparison item") {
                        Picker("Follow-up scope", selection: $findingID) {
                            Text("Whole paycheck comparison").tag("")
                            ForEach(findings) { finding in
                                Text(finding.title).tag(finding.id)
                            }
                        }
                        .accessibilityIdentifier("resolution.finding")
                        if let finding = findings.first(where: { $0.id == findingID }) {
                            LabeledContent(
                                "Expected", value: LinePayFormat.money(finding.expected))
                            LabeledContent(
                                "Confirmed paid", value: LinePayFormat.money(finding.paid))
                            LabeledContent(
                                "Expected minus confirmed",
                                value: LinePayFormat.money(finding.difference))
                            Text(finding.explanation).font(.footnote)
                        }
                    }
                }
                Section("Record a follow-up") {
                    Picker("Status", selection: $status) {
                        ForEach(ResolutionStatus.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("resolution.status")
                    TextField("What happened?", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($noteFocused)
                        .accessibilityIdentifier("resolution.note")
                    Button("Save follow-up") { save() }
                        .linePayRowAction()
                        .accessibilityIdentifier("resolution.save")
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text(
                        "Saved on this device. Nothing is sent to your employer or union. Avoid entering other people’s personal information."
                    )
                    .font(.footnote)
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
                }
                Section("Follow-up history") {
                    if context.resolutionEvents.isEmpty {
                        Text("No follow-up recorded yet.")
                    }
                    ForEach(context.resolutionEvents.reversed()) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.status.title).font(.headline)
                            Text(
                                Date(
                                    timeIntervalSince1970: TimeInterval(event.recordedEpochSeconds)),
                                format: .dateTime.year().month().day().hour().minute()
                            )
                            .font(.caption).foregroundStyle(LinePayColor.textSecondary)
                            Text(resolutionScope(for: event, in: context))
                                .font(.subheadline)
                                .accessibilityIdentifier("resolution.history-scope")
                            Text(event.note)
                            if event.paystubID != paystub.id {
                                Label(
                                    "Different paycheck revision",
                                    systemImage: "clock.arrow.circlepath"
                                )
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Confirm a paycheck first", systemImage: "doc.text.magnifyingglass")
            }
        }
        .linePayCanvas()
        .linePayKeyboardDismiss()
        .navigationTitle("Paycheck follow-up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectedPaystub(in context: PayPeriodContext) -> ConfirmedPaystub? {
        guard let paystubID else { return context.paystub }
        return context.paystub?.id == paystubID
            ? context.paystub : context.revisions.first { $0.paystub.id == paystubID }?.paystub
    }

    private func save() {
        do {
            try model.recordResolution(
                periodID: periodID, paystubID: paystubID,
                findingID: findingID.isEmpty ? nil : findingID, status: status, note: note)
            note = ""
            noteFocused = false
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func resolutionScope(for event: ResolutionEvent, in context: PayPeriodContext)
        -> String
    {
        guard let findingID = event.findingID else { return "Whole paycheck comparison" }
        let paystub =
            context.paystub?.id == event.paystubID
            ? context.paystub
            : context.revisions.first { $0.paystub.id == event.paystubID }?.paystub
        guard let paystub,
            let finding = AuditFinding.from(paystub: paystub).first(where: { $0.id == findingID })
        else { return "Specific item from a saved paycheck revision" }
        return "Comparison item: \(finding.title)"
    }
}
