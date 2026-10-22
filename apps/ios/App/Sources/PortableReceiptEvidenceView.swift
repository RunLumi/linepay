import SwiftUI

/// Foreign results are evidence. This view never calls the receiving payroll engine.
struct PortableReceiptEvidenceView: View {
    let state: PortableState
    var model: AppModel? = nil
    var body: some View {
        List {
            Section {
                Text("Imported financial evidence").font(.headline)
                Text(
                    "Read-only records from another saved financial state. The original producer's result is preserved; this iPhone has not recalculated or verified its legal coverage."
                )
                LabeledContent("Producing client", value: state.source.client)
                LabeledContent("Profiles", value: "\(state.profiles.count)")
                LabeledContent("Pay periods", value: "\(state.periods.count)")
                LabeledContent(
                    "Work entries", value: "\(state.workSnapshots.reduce(0) { $0 + $1.work.count })"
                )
            }
            if let model, model.canAdoptImportedContext {
                Section { PortableAdoptionEntryPoint(model: model, document: state) }
            }
            ForEach(state.paycheckReceipts, id: \.id) { receipt in
                Section("Saved paycheck comparison") {
                    LabeledContent(
                        "Original result", value: resultTitle(receipt.assessment.verdict))
                    LabeledContent(
                        "Compared scope",
                        value: receipt.assessment.scope == "grossOnly"
                            ? "Gross total only" : "Confirmed earnings lines")
                    LabeledContent("Producer", value: receipt.producer.client)
                    LabeledContent(
                        "Original engine",
                        value: receipt.producer.assessmentEngineID ?? "Source engine not recorded")
                    if let expected = receipt.assessment.expectedGross {
                        LabeledContent(
                            "Saved expected gross", value: expected.currency + " " + expected.amount
                        ).monospacedDigit()
                    }
                    LabeledContent(
                        "Paid gross",
                        value: receipt.paystubFacts.currency + " " + receipt.paystubFacts.grossPay
                    ).monospacedDigit()
                    if let difference = receipt.assessment.difference {
                        LabeledContent(
                            "Saved difference", value: difference.currency + " " + difference.amount
                        ).monospacedDigit()
                    }
                    if receipt.reviewFacts.weeklyReviewPending == true {
                        Label(
                            "Weekly review remains pending", systemImage: "exclamationmark.triangle"
                        )
                    }
                    ForEach(receipt.assessment.reviewReasons, id: \.self) { reason in Text(reason) }
                    DisclosureGroup("Original calculation and source references") {
                        Text("Receipt reference: " + receipt.id).textSelection(.enabled)
                        ForEach(receipt.ruleRefs, id: \.self) {
                            Text("Rule reference: " + $0).textSelection(.enabled)
                        }
                        ForEach(receipt.calculation?.components ?? [], id: \.id) { component in
                            VStack(alignment: .leading) {
                                Text(component.explanation)
                                Text(component.amount.currency + " " + component.amount.amount)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            ForEach(state.workSnapshots, id: \.id) { snapshot in
                Section(
                    snapshot.role == "currentLedger"
                        ? "Current ledger facts" : "Frozen earlier work facts"
                ) {
                    ForEach(snapshot.work, id: \.id) { work in
                        VStack(alignment: .leading) {
                            Text(work.kind.capitalized).font(.headline)
                            Text(
                                "\(work.startEpochSeconds)–\(work.endEpochSeconds) · \(work.timeZone)"
                            ).monospacedDigit()
                            if let note = work.note, !note.isEmpty { Text(note) }
                        }
                    }
                }
            }
        }
        .labeledContentStyle(LinePayValueStyle())
        .linePayCanvas()
        .navigationTitle("Imported evidence")
        .accessibilityIdentifier("portable.evidence")
    }
    private func resultTitle(_ verdict: String) -> String {
        switch verdict {
        case "matches": "No difference within compared items"
        case "needsReview": "Needs review"
        case "notComparable": "Unable to verify"
        case "possibleShortfall": "Possible difference: paystub is lower"
        case "possibleOverpayment": "Possible difference: paystub is higher"
        default: "Unable to verify"
        }
    }

}

/// Missing source facts stay missing until the worker explicitly configures new native rules.
struct PortableImportedLandingView: View {
    let model: AppModel
    let state: PortableState
    @State private var configuring = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Imported records are preserved").font(.title2.bold())
                    Text(
                        "The source did not record every rule or exact period boundary needed for a new iPhone estimate. Your saved work and original results remain available as read-only evidence."
                    )
                    NavigationLink("View imported financial evidence") {
                        PortableReceiptEvidenceView(state: state)
                    }.accessibilityIdentifier("portable.open-evidence")
                }
                Section {
                    Button("Confirm rules for new iPhone estimates") { configuring = true }
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("portable.configure-new-rules")
                    Text(
                        "New setup does not change an imported receipt or fill in its missing facts. Keep a portable copy before creating new records."
                    ).font(.footnote)
                    BackupRestoreEntryPoint()
                }
            }
            .linePayCanvas()
            .navigationTitle("Imported records")
            .sheet(isPresented: $configuring) {
                PortableAdoptionSetupView(model: model, document: state) { configuring = false }
            }
        }
    }
}

struct PortableAdoptionEntryPoint: View {
    let model: AppModel
    let document: PortableState
    @State private var presented = false
    var body: some View {
        Button("Create a new confirmed copy of imported work") { presented = true }
            .frame(minHeight: 48)
            .accessibilityIdentifier("portable.configure-new-rules")
            .sheet(isPresented: $presented) {
                PortableAdoptionSetupView(model: model, document: document) { presented = false }
            }
    }
}
