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
        // An inset, not a bottom toolbar: a toolbar renders beneath the floating tab bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !subscriptionStore.isPro, model.hasUsedFreeAudit, SubscriptionStore.commerceEnabled {
                // The moment a worker has seen what one check shows is when Pro's value is
                // clearest; offer it plainly, with the free trial when Apple reports one.
                LinePayBottomBar {
                    Button(
                        subscriptionStore.annualTrialDuration.map { "Try Pro free for \($0)" }
                            ?? "Check every paycheck with Pro"
                    ) { paywall = true }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .accessibilityIdentifier("audit.view-pro")
                    Text(offerNote)
                        .font(.footnote)
                        .foregroundStyle(LinePayColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// Names what the free check found, only while that result is current and only as a possible
    /// shortfall; otherwise states plainly what Pro adds.
    private var offerNote: String {
        if let context = model.periodContext(id: periodID), let paid = context.paystub,
            let calculation = context.calculation,
            AuditAssessment.evaluate(
                calculation: calculation, paystub: paid, reconciliation: context.reconciliation
            ).isCurrent,
            let difference = paid.assessment?.difference, difference.amount > 0
        {
            return
                "This check found a possible shortfall of \(LinePayFormat.money(difference)). Pro checks every paycheck after this one."
        }
        return "Your free check is used. Pro checks every paycheck after this one."
    }
}

struct AuditDetailView: View {
    let model: AppModel
    let context: PayPeriodContext
    var onCorrect: (() -> Void)? = nil
    @State private var showingReport = false
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
                        // Verdict first, then the one number that answers "by how much?".
                        AuditStatusView(status: .assessment(assessment))
                        if let difference = assessment.difference, difference.amount != 0 {
                            PayAmount(
                                label: "Possible gross difference",
                                money: Money(
                                    amount: difference.amount.magnitude,
                                    currencyCode: difference.currencyCode),
                                prominent: true
                            )
                            .accessibilityIdentifier("audit.difference")
                            Text(
                                difference.amount > 0
                                    ? "Your paystub shows less than the expected gross for the work and rules you confirmed."
                                    : "Your paystub shows more than the expected gross. Check for work or pay lines that are not recorded here."
                            )
                            .font(.subheadline)
                        }
                        ComparisonAmounts(
                            expected: assessment.expectedGross, paid: assessment.paidGross)
                        LineGapComparison(difference: assessment.difference)
                        Text(
                            assessment.scope == .grossOnly
                                ? "Compared: gross total" : "Compared: confirmed lines"
                        )
                        .font(.footnote).accessibilityIdentifier("audit.scope")
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
                        Button("Review or correct paycheck facts", action: onCorrect)
                            .linePayRowAction()
                            .accessibilityIdentifier("audit.correct")
                    }
                }
                Section { ComparisonScopeView() }
                if let assessment = paid.assessment, presentation.isCurrent,
                    context.reconciliation != nil
                {
                    Section {
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
                    } header: {
                        Text("Line by line")
                    } footer: {
                        Text("A positive difference means the expected amount was higher.")
                    }
                }
                Section("Original evidence") {
                    if let evidence = paid.evidence, let url = model.evidenceURL(for: evidence) {
                        NavigationLink("View original paystub") {
                            SourceEvidenceView(url: url, region: nil)
                        }
                        .accessibilityIdentifier("audit.view-original")
                        Text(evidence.originalFilename).font(.footnote)
                        Button("Remove this original", role: .destructive) { showingRemove = true }
                    } else {
                        Text(
                            "No original is available for this audit. Confirmed values are still retained."
                        )
                    }
                }
                Section("Rule snapshot") {
                    NavigationLink("Rules used · version \(context.agreement.version)") {
                        RuleSourcesView(agreement: context.agreement)
                    }
                }
                Section("Share with payroll") {
                    Button("Prepare a report to share") { showingReport = true }
                        .linePayRowAction()
                        .accessibilityIdentifier("audit.export")
                    Text(
                        "Preview a short PDF of this comparison before you share it. It contains sensitive pay data. Your records and exports stay available without Pro."
                    ).font(.footnote)
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayCanvas()
        .navigationTitle("Paycheck result").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReport) { ReportSharingView(context: context) }
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
        .linePayCanvas()
        .navigationTitle(comparison.field.title).navigationBarTitleDisplayMode(.inline)
    }
    private func formatted(_ value: Decimal) -> String {
        comparison.unit == .hours
            ? "\(LinePayFormat.hours(value)) h"
            : LinePayFormat.money(Money(amount: value, currencyCode: comparison.currencyCode))
    }
}
