import LinePayDomain
import SwiftUI

struct LiveAuditView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    let periodID: UUID
    @State private var correction = false
    @State private var paywall = false
    var body: some View {
        Group {
            if let context = model.periodContext(id: periodID) {
                AuditDetailView(model: model, context: context, onCorrect: { correction = true })
            } else {
                ContentUnavailableView("Period unavailable", systemImage: "doc")
            }
        }
        .toolbar {
            if !subscriptionStore.isPro, model.hasUsedFreeAudit, SubscriptionStore.commerceEnabled {
                ToolbarItem(placement: .bottomBar) {
                    Button("Audit future paychecks with Pro") { paywall = true }
                }
            }
        }
        .sheet(isPresented: $correction) {
            PaystubImportView(
                model: model, subscriptionStore: subscriptionStore, periodID: periodID
            ) {}
        }
        .sheet(isPresented: $paywall) {
            ProPaywallView(store: subscriptionStore) { paywall = false }
        }
    }
}

struct AuditDetailView: View {
    let model: AppModel
    let context: PayPeriodContext
    var onCorrect: (() -> Void)? = nil
    @State private var reportURL: URL?
    @State private var showingRemove = false
    @State private var errorMessage: String?
    var body: some View {
        List {
            if let paid = context.paystub, let calculation = context.calculation {
                let presentation = AuditAssessment.evaluate(
                    calculation: calculation, paystub: paid, reconciliation: context.reconciliation)
                Section {
                    Text(
                        LinePayFormat.payPeriod(
                            context.window, timeZoneIdentifier: context.timeZoneIdentifier)
                    ).font(.subheadline)
                    if !presentation.isCurrent {
                        AuditStatusView(status: .needsReview)
                        Text(
                            "Work or rules changed since this audit. Review the paycheck again; earlier audit revisions remain in History."
                        )
                    } else if let assessment = paid.assessment {
                        ComparisonAmounts(
                            expected: assessment.expectedGross, paid: assessment.paidGross)
                        LineGapComparison(difference: assessment.difference)
                        AuditStatusView(status: .assessment(assessment))
                        Text(
                            assessment.scope == .grossOnly
                                ? "Gross total only" : "Only confirmed lines compared"
                        )
                        .font(.footnote).accessibilityIdentifier("audit.scope")
                        if let difference = assessment.difference, difference.amount != 0 {
                            PayAmount(label: "Expected minus confirmed paid", money: difference)
                        }
                        Text(paid.confirmation?.grossBasis.title ?? "Gross basis not confirmed")
                            .font(.footnote)
                        ForEach(assessment.reviewReasons, id: \.self) {
                            Text($0).foregroundStyle(LinePayColor.review)
                        }
                        ForEach(assessment.scopeNotes, id: \.self) {
                            Text($0).font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                        }
                    } else {
                        AuditStatusView(status: .needsReview)
                        Text(
                            "This older audit compared gross totals without recording their basis. Review the paycheck to create an evidence-aware revision; the original record is preserved."
                        )
                    }
                    if let onCorrect {
                        Button("Review or correct confirmed facts", action: onCorrect).frame(
                            minHeight: 48
                        ).accessibilityIdentifier("audit.correct")
                    }
                }
                if let assessment = paid.assessment, presentation.isCurrent,
                    context.reconciliation != nil
                {
                    Section("Compared lines; positive difference means expected was higher") {
                        ForEach(assessment.comparisons.sorted { $0.differs && !$1.differs }) {
                            comparison in
                            NavigationLink {
                                PaycheckComparisonDetail(
                                    model: model, context: context, comparison: comparison)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(comparison.field.title).font(.headline)
                                    Text("Expected \(format(comparison.expected, comparison))")
                                    Text("Confirmed \(format(comparison.paid, comparison))")
                                    Text(
                                        comparison.differs
                                            ? "Difference \(format(comparison.difference, comparison))"
                                            : "Compared value matches"
                                    )
                                    .foregroundStyle(
                                        comparison.differs
                                            ? LinePayColor.difference : LinePayColor.textSecondary)
                                }.monospacedDigit().padding(.vertical, 6)
                            }
                        }
                    }
                }
                Section("Original evidence") {
                    if let evidence = paid.evidence, let url = model.evidenceURL(for: evidence) {
                        NavigationLink("View original paystub") {
                            SourceEvidenceView(url: url, region: nil)
                        }
                        Text(evidence.originalFilename).font(.footnote)
                        Button("Remove this original", role: .destructive) { showingRemove = true }
                    } else {
                        Text(
                            "No original is available for this audit. Confirmed values are still retained."
                        )
                    }
                }
                Section("Rule snapshot") {
                    NavigationLink("Rules and sources v\(context.agreement.version)") {
                        RuleSourcesView(agreement: context.agreement)
                    }
                }
                Section("Worker-owned report") {
                    if let reportURL { ShareLink("Share report", item: reportURL) }
                    Button("Prepare audit report") {
                        do {
                            reportURL = try ReconciliationReportExporter().export(
                                window: context.window,
                                timeZoneIdentifier: context.timeZoneIdentifier,
                                agreement: context.agreement,
                                calculation: calculation, paystub: paid,
                                reconciliation: context.reconciliation,
                                findings: model.auditFindings(
                                    calculation: calculation, paystub: paid))
                        } catch { errorMessage = error.localizedDescription }
                    }.accessibilityIdentifier("audit.export")
                    Text(
                        "This report excludes original paystub pages. Existing records and exports remain available without Pro."
                    ).font(.footnote)
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .navigationTitle("Paycheck audit").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this original from the device?", isPresented: $showingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove original", role: .destructive) {
                guard let id = context.paystub?.evidence?.id else { return }
                do { try model.removeEvidence(id: id) } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: {
            Text(
                "Every audit revision sharing this source loses access to the original. Confirmed amounts and calculation records remain. Copies you exported to Files are not removed."
            )
        }
    }
    private func format(_ value: Decimal, _ comparison: PaycheckComparison) -> String {
        comparison.unit == .hours
            ? "\(LinePayFormat.hours(value)) h"
            : LinePayFormat.money(Money(amount: value, currencyCode: comparison.currencyCode))
    }
}

struct PaycheckComparisonDetail: View {
    let model: AppModel
    let context: PayPeriodContext
    let comparison: PaycheckComparison
    var body: some View {
        List {
            Section("This comparison") {
                Text(comparison.field.title).font(.title2.bold())
                LabeledContent("Expected", value: formatted(comparison.expected))
                LabeledContent("Confirmed paid", value: formatted(comparison.paid))
                LabeledContent("Difference", value: formatted(comparison.difference))
            }
            if let calculation = context.calculation {
                Section("Only the work behind this line") {
                    let selected = calculation.components.filter {
                        comparison.componentIDs.contains($0.id)
                    }
                    if selected.isEmpty {
                        Text(
                            "No applicable expected components. Check whether your recorded work or selected paystub layout is incomplete."
                        )
                    }
                    ForEach(selected) { component in
                        NavigationLink(
                            "\(componentTitle(component)): \(LinePayFormat.money(component.amount))"
                        ) {
                            EvidenceReceiptView(
                                component: component,
                                agreement: appliedSnapshot(
                                    for: component, in: calculation, fallback: context.agreement),
                                work: context.workEntries)
                        }
                    }
                }
            }
            Section("Paystub evidence") {
                if let paid = context.paystub {
                    Text("Confirmed \(comparison.field.title): \(formatted(comparison.paid))")
                        .monospacedDigit()
                    Text("Layout: \(paid.confirmation?.lineLayout.title ?? "Not recorded")").font(
                        .footnote)
                    if let source = paid.evidence, let url = model.evidenceURL(for: source) {
                        NavigationLink("View source for this field") {
                            SourceEvidenceView(
                                url: url,
                                region: paid.confirmation?.suggestions[comparison.field]?.region)
                        }
                    } else {
                        Text("Entered or confirmed by you. Original not available.")
                    }
                    if let text = paid.confirmation?.suggestions[comparison.field]?.sourceText {
                        Text(text).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
            Section {
                Text(
                    "Check this line on your paystub or with payroll. A difference is not a determination of wages legally owed."
                ).font(.footnote)
            }
        }
        .navigationTitle(comparison.field.title).navigationBarTitleDisplayMode(.inline)
    }
    private func formatted(_ value: Decimal) -> String {
        comparison.unit == .hours
            ? "\(LinePayFormat.hours(value)) h"
            : LinePayFormat.money(Money(amount: value, currencyCode: comparison.currencyCode))
    }
}
