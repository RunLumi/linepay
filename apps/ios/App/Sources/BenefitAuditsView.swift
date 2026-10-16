import LinePayDomain
import SwiftUI

struct BenefitAuditsView: View {
    let model: AppModel
    @State private var editing: BenefitAuditDraft?
    @State private var selection: BenefitRecordSelection?
    @State private var discard = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text(
                    "Check employer contributions separately from wages and deductions. Use the fund's covered work period and rates you explicitly confirmed."
                )
                if let draft = model.benefitAuditDraft {
                    Button("Resume benefits draft") { editing = draft }
                        .linePayRowAction().accessibilityIdentifier("benefits.resume")
                    Button("Discard benefits draft", role: .destructive) { discard = true }
                } else {
                    Button("Start a benefits check") { editing = model.makeBenefitDraft() }
                        .linePayRowAction().accessibilityIdentifier("benefits.new")
                }
            }
            Section("Saved checks") {
                if model.benefitAuditRecords.isEmpty {
                    Text(
                        "No benefits checks saved yet. A missing statement can be kept explicitly unverified."
                    )
                }
                ForEach(model.benefitAuditRecords.reversed()) { record in
                    if let latest = record.revisions.last {
                        NavigationLink {
                            BenefitAuditDetailView(model: model, recordID: record.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(latest.input.fundName).font(.headline)
                                Text(benefitPeriodLabel(latest.result.period)).font(.subheadline)
                                Text(latest.result.comparisonTitle)
                                Text(
                                    "Expected employer contribution: \(benefitMoney(latest.result.expectedEmployerContribution))"
                                ).monospacedDigit()
                            }
                        }.accessibilityIdentifier("benefits.record")
                    }
                }
            }
            if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
            }
        }
        .linePayCanvas().navigationTitle("Employer benefits")
        .sheet(item: $editing) { draft in
            BenefitAuditEditorView(model: model, draft: draft) { id in
                editing = nil
                selection = BenefitRecordSelection(id: id)
            }
        }
        .navigationDestination(item: $selection) { value in
            BenefitAuditDetailView(model: model, recordID: value.id)
        }
        .confirmationDialog(
            "Discard this unfinished benefits check?", isPresented: $discard,
            titleVisibility: .visible
        ) {
            Button("Discard draft", role: .destructive) {
                if let draft = model.benefitAuditDraft {
                    do { try model.discardBenefitDraft(id: draft.id) } catch {
                        errorMessage = benefitErrorMessage(error)
                    }
                }
            }
        } message: {
            Text(
                "Saved checks and earlier revisions remain. Originals used only by this draft may be removed or queued for cleanup."
            )
        }
    }
}

private struct BenefitRecordSelection: Hashable { let id: UUID }

struct BenefitAuditDetailView: View {
    let model: AppModel
    let recordID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRevision: UUID?
    @State private var editing: BenefitAuditDraft?
    @State private var sharing: BenefitAuditRevision?
    @State private var deleteRecord = false
    @State private var removeOriginal = false
    @State private var errorMessage: String?

    private var record: BenefitAuditRecord? {
        model.benefitAuditRecords.first { $0.id == recordID }
    }
    private var revision: BenefitAuditRevision? {
        record?.revisions.first { $0.id == selectedRevision } ?? record?.revisions.last
    }

    var body: some View {
        Group {
            if let record, let revision {
                List {
                    Section {
                        Text(revision.input.fundName).font(.headline)
                        Text(revision.input.kind.title)
                        if record.revisions.count > 1 {
                            Picker(
                                "Saved revision",
                                selection: Binding(
                                    get: { selectedRevision ?? revision.id },
                                    set: { selectedRevision = $0 })
                            ) {
                                ForEach(Array(record.revisions.enumerated()), id: \.element.id) {
                                    index, value in
                                    Text(
                                        "Review \(index + 1)\(index == record.revisions.count - 1 ? " · latest" : "")"
                                    ).tag(value.id)
                                }
                            }.accessibilityIdentifier("benefits.revision")
                        }
                        Text(
                            Date(
                                timeIntervalSince1970: TimeInterval(revision.recordedEpochSeconds)),
                            format: .dateTime.year().month().day().hour().minute()
                        )
                        .font(.footnote)
                    }
                    BenefitResultSections(result: revision.result)
                    Section("Reviewed source snapshots") {
                        ForEach(revision.result.segments) { line in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(line.rule.basis.title).font(.headline)
                                Text(
                                    "Rate \(LinePayFormat.entry(line.rule.rate)) · Eligible units \(LinePayFormat.entry(line.quantity))"
                                ).monospacedDigit()
                                Text(benefitPeriodLabel(line.period)).font(.subheadline)
                                Text(
                                    "Reviewed applicability: \(benefitPeriodLabel(line.rule.effectivePeriod))"
                                ).font(.footnote)
                                if line.rule.sources.isEmpty {
                                    Text("Worker-entered rule; no source reference recorded.").font(
                                        .footnote)
                                }
                                ForEach(Array(line.rule.sources.enumerated()), id: \.offset) {
                                    _, source in
                                    Text(source.title).font(.subheadline)
                                    if let quote = source.quotedText { Text(quote).font(.footnote) }
                                    if let id = source.documentID {
                                        NavigationLink("Read cited agreement page") {
                                            AgreementOriginalView(
                                                model: model, documentID: id,
                                                page: source.documentPage ?? 0,
                                                expectedSHA256: source.documentSHA256)
                                        }.buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                    Section("Statement original") {
                        if revision.input.statementEvidence != nil {
                            NavigationLink("Read retained statement") {
                                BenefitStatementOriginalView(
                                    model: model, origin: .revision(recordID, revision.id))
                            }.accessibilityIdentifier("benefits.open-original")
                            Button("Remove retained statement original", role: .destructive) {
                                removeOriginal = true
                            }
                        } else {
                            Text(
                                "No original retained. The saved observation and comparison are still available."
                            )
                        }
                    }
                    if !revision.input.note.isEmpty {
                        Section("Private note") { Text(revision.input.note) }
                    }
                    Section("Keep a record or continue") {
                        Button("Prepare a benefits report") { sharing = revision }
                            .linePayRowAction().accessibilityIdentifier("benefits.report")
                        Button("Correct latest saved check") {
                            do { editing = try model.reviseBenefitCheck(id: recordID) } catch {
                                errorMessage = benefitErrorMessage(error)
                            }
                        }.linePayRowAction().accessibilityIdentifier("benefits.correct")
                        Button("Check another period for this fund") {
                            do {
                                editing = try model.startAnotherBenefitPeriod(recordID: recordID)
                            } catch { errorMessage = benefitErrorMessage(error) }
                        }.linePayRowAction().accessibilityIdentifier("benefits.next-period")
                        Text(
                            "Corrections append a revision to the latest check. Another period reuses only the fund identity; rates, eligibility and statement values need a new review."
                        ).font(.footnote)
                        Button("Delete this check and all its revisions", role: .destructive) {
                            deleteRecord = true
                        }
                    }
                    if let errorMessage {
                        Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
                    }
                }
                .id(revision.id)
                .confirmationDialog(
                    "Remove this retained original?", isPresented: $removeOriginal,
                    titleVisibility: .visible
                ) {
                    Button("Remove original", role: .destructive) {
                        if let evidence = revision.input.statementEvidence {
                            do { try model.removeEvidence(id: evidence.id) } catch {
                                errorMessage = benefitErrorMessage(error)
                            }
                        }
                    }
                } message: {
                    Text(
                        "Every revision sharing this original loses access to its bytes. Saved figures and comparisons remain. External copies are not removed."
                    )
                }
            } else {
                ContentUnavailableView(
                    "Benefits check unavailable", systemImage: "list.bullet.rectangle")
            }
        }
        .labeledContentStyle(LinePayValueStyle())
        .linePayCanvas().navigationTitle("Benefits result").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharing) { value in BenefitReportSharingView(revision: value) }
        .sheet(item: $editing) { value in
            BenefitAuditEditorView(model: model, draft: value) { id in
                editing = nil
                if id != recordID { dismiss() } else { selectedRevision = nil }
            }
        }
        .confirmationDialog(
            "Delete this benefits check?", isPresented: $deleteRecord, titleVisibility: .visible
        ) {
            Button("Delete check", role: .destructive) {
                do {
                    try model.deleteBenefitCheck(id: recordID)
                    dismiss()
                } catch { errorMessage = benefitErrorMessage(error) }
            }
        } message: {
            Text(
                "This removes this local check and all its revisions. Other funds, periods and wage records remain. Exported copies are not deleted."
            )
        }
    }
}
