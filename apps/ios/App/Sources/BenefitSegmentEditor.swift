import LinePayDomain
import SwiftUI

struct BenefitSegmentEditor: View {
    let model: AppModel
    @Binding var line: BenefitRuleDraft
    let currencyCode: String
    let zone: String
    let separator: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editing: String?

    var body: some View {
        Form {
            Section("Explicit contribution rule") {
                Picker("Rate basis", selection: $line.basis) {
                    ForEach(BenefitContributionBasis.allCases, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
                LinePayTextField(
                    line.basis.rateTitle, text: $line.rate, focus: $editing,
                    identifier: "benefits.rate"
                ).linePayNumberEntry()
                LinePayTextField(
                    line.basis.quantityTitle, text: $line.quantity, focus: $editing,
                    identifier: "benefits.units"
                ).linePayNumberEntry()
                Text(
                    "Currency: \(currencyCode). Decimal separator: \(separator). Percentages use separately reviewed eligible earnings; wage gross and allowances are not inserted automatically."
                ).font(.footnote)
                if line.basis == .fixedPeriod {
                    Text(
                        "Enter 1 whole period. Its applicable dates must exactly match the whole check period; no monthly-to-weekly proration is inferred."
                    ).font(.footnote)
                }
            }
            Section("Dates for these eligible units") {
                DatePicker("First work date", selection: $line.start, displayedComponents: .date)
                DatePicker(
                    "Last work date", selection: benefitLastDate($line.end, zone: zone),
                    displayedComponents: .date)
            }
            Section("Reviewed applicability dates") {
                DatePicker(
                    "Rule applies from", selection: $line.effectiveStart, displayedComponents: .date
                )
                DatePicker(
                    "Rule applies through",
                    selection: benefitLastDate($line.effectiveEnd, zone: zone),
                    displayedComponents: .date)
                Text(
                    "Use only dates you checked this rate applies to. This is the scope of your review, not a guessed agreement expiry. Dates here are proposals until final confirmation."
                ).font(.footnote)
            }
            Section("Source reference") {
                LinePayTextField(
                    "Reference or version (optional)", text: $line.reference, focus: $editing,
                    identifier: "benefits.reference")
                Menu("Add a clause from a retained agreement") {
                    ForEach(model.agreementDocuments) { document in
                        Menu(document.filename) {
                            ForEach(document.candidates ?? []) { candidate in
                                Button("PDF page \(candidate.page + 1): \(candidate.kind.title)") {
                                    let source = AgreementSource(
                                        title: document.filename, url: "",
                                        section: "PDF page \(candidate.page + 1)",
                                        documentID: document.id,
                                        documentSHA256: document.sha256,
                                        documentPage: candidate.page,
                                        quotedText: candidate.quote)
                                    if !line.sources.contains(source) {
                                        line.sources.append(source)
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(model.agreementDocuments.isEmpty)
                .accessibilityIdentifier("benefits.add-source")
                ForEach(Array(line.sources.enumerated()), id: \.offset) { _, source in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(source.title).font(.headline)
                        if let quote = source.quotedText { Text(quote).font(.subheadline) }
                        if let id = source.documentID {
                            NavigationLink("Read cited agreement page") {
                                AgreementOriginalView(
                                    model: model, documentID: id,
                                    page: source.documentPage ?? 0,
                                    expectedSHA256: source.documentSHA256)
                            }
                        }
                        Button("Remove this reference from the draft", role: .destructive) {
                            line.sources.removeAll { $0 == source }
                        }.buttonStyle(.borderless)
                    }
                }
                Text(
                    "A citation records your source. It does not verify eligibility, legal authority or fund membership. Enter and review the rate separately."
                ).font(.footnote)
            }
        }
        .linePayCanvas().linePayKeyboardDismiss()
        .environment(\.timeZone, TimeZone(identifier: zone) ?? .gmt)
        .navigationTitle("Contribution segment").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.accessibilityIdentifier("benefits.segment-done")
            }
        }
    }
}
