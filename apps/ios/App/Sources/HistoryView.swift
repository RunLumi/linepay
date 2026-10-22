import LinePayDomain
import SwiftUI

struct HistoryView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    var onOpenCurrent: () -> Void = {}
    var body: some View {
        NavigationStack {
            List {
                if let imported = model.importedFinancialEvidence {
                    Section {
                        NavigationLink("Imported financial evidence") {
                            PortableReceiptEvidenceView(state: imported, model: model)
                        }
                        .accessibilityIdentifier("history.imported-evidence")
                    }
                }
                if model.history.isEmpty {
                    Section {
                        Text("No finished work periods yet").font(.title2.bold())
                        Text(
                            "When you finish a work period from Pay, it moves here. You can still check its paycheck when it arrives."
                        )
                        .foregroundStyle(LinePayColor.textSecondary)
                        Button("Go to current pay period") { onOpenCurrent() }.linePayRowAction()
                    }
                } else {
                    let groups = Dictionary(grouping: model.history, by: monthKey)
                    ForEach(groups.keys.sorted().reversed(), id: \.self) { key in
                        Section(monthTitle(key)) {
                            ForEach(
                                (groups[key] ?? []).sorted {
                                    $0.window.startEpochSeconds > $1.window.startEpochSeconds
                                }
                            ) { period in
                                let historyPeriodAccessibilityID =
                                    "history.period." + period.id.uuidString
                                let periodLabel = LinePayFormat.payPeriod(
                                    period.window,
                                    timeZoneIdentifier: model.timeZoneIdentifier(for: period))
                                NavigationLink {
                                    HistoricalPeriodView(
                                        model: model, subscriptionStore: subscriptionStore,
                                        periodID: period.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(periodLabel).font(.headline)
                                        if let calculation = period.comparisonCalculation {
                                            Text(
                                                "Saved expected \(LinePayFormat.money(calculation.expectedWages))"
                                            ).monospacedDigit()
                                        } else {
                                            Label(
                                                "Calculation needs review",
                                                systemImage: "exclamationmark.triangle"
                                            ).foregroundStyle(LinePayColor.review)
                                        }
                                        if let paid = period.paystub {
                                            Text("Paid gross \(LinePayFormat.money(paid.grossPay))")
                                                .monospacedDigit()
                                            if let difference = paid.assessment?.difference,
                                                difference.amount != 0
                                            {
                                                Text(
                                                    "\(difference.amount > 0 ? "Paystub lower by" : "Paystub higher by") \(LinePayFormat.money(Money(amount: difference.amount.magnitude, currencyCode: difference.currencyCode)))"
                                                ).monospacedDigit()
                                            }
                                            AuditStatusView(status: model.auditStatus(for: period))
                                            if AuditAssessment.legacyScopeNote(
                                                calculation: period.comparisonCalculation,
                                                paystub: paid, agreement: period.agreement) != nil
                                            {
                                                Label(
                                                    "Earlier recorded comparison",
                                                    systemImage: "clock"
                                                )
                                                .font(.footnote)
                                            }
                                        } else {
                                            Label("Awaiting paycheck", systemImage: "clock")
                                                .foregroundStyle(LinePayColor.review)
                                        }
                                    }.padding(.vertical, 8).accessibilityElement(children: .combine)
                                }
                                .accessibilityIdentifier(historyPeriodAccessibilityID)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain).linePayCanvas()
            .navigationTitle("History")
        }
    }
    /// Sorts by the stable "yyyy-MM" key but shows a readable month such as "October 2026".
    private func monthTitle(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard parts.count == 2,
            let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
        else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: date)
    }

    private func monthKey(_ period: CompletedPayPeriod) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: model.timeZoneIdentifier(for: period))
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: period.window.startDate)
    }
}

struct HistoricalPeriodView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    let periodID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showingImport = false
    @State private var showingResult = false
    @State private var showingPaywall = false
    @State private var showingDelete = false
    @State private var errorMessage: String?
    var body: some View {
        List {
            if let context = model.periodContext(id: periodID) {
                Section("Closed work period") {
                    Text(
                        LinePayFormat.payPeriod(
                            context.window, timeZoneIdentifier: context.timeZoneIdentifier)
                    ).font(.headline)
                    PayAmount(label: "Expected wages", money: context.calculation?.expectedWages)
                    if context.calculation?.provenance?.engine != PayCalculator.currentEngine {
                        Text(
                            "This is a saved calculation. A new paycheck review uses current precision; earlier records are kept."
                        )
                        .font(.footnote)
                    }
                    Text(
                        "\(LinePayFormat.timeZoneName(context.timeZoneIdentifier)) · rules version \(context.agreement.version)"
                    ).font(.footnote)
                    if context.paystub == nil {
                        Label("Awaiting paycheck", systemImage: "clock")
                    } else {
                        AuditStatusView(status: model.status(for: context))
                        if let note = AuditAssessment.legacyScopeNote(
                            calculation: context.calculation, paystub: context.paystub,
                            agreement: context.agreement)
                        {
                            Text(note).font(.footnote)
                        }
                        NavigationLink("View paycheck result") {
                            LiveAuditView(
                                model: model, subscriptionStore: subscriptionStore,
                                periodID: periodID)
                        }
                    }
                    Button(context.paystub == nil ? "Add this paycheck" : "Correct paycheck facts")
                    { beginAudit() }
                    .buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                        "history.audit")
                    if context.paystub == nil {
                        Text(
                            "This period's work and rules are frozen. Add its paycheck whenever it arrives."
                        ).font(.footnote)
                    } else {
                        Text(
                            "A correction is saved as a new check. The work, rules and earlier checks stay available."
                        ).font(.footnote)
                    }
                }
                if let calculation = context.calculation {
                    PayLedgerRows(
                        calculation: calculation, agreement: context.agreement,
                        work: context.workEntries, model: model)
                }
                Section("Saved paycheck checks") {
                    if context.revisions.isEmpty { Text("No saved paycheck checks yet.") }
                    ForEach(context.revisions.reversed()) { revision in
                        NavigationLink(
                            "Checked \(Date(timeIntervalSince1970: TimeInterval(revision.paystub.confirmedEpochSeconds)).formatted(date: .abbreviated, time: .shortened))"
                        ) {
                            AuditDetailView(
                                model: model,
                                context: revision.context(
                                    periodID: periodID,
                                    resolutionEvents: context.resolutionEvents.filter {
                                        $0.paystubID == revision.paystub.id
                                    }))
                        }
                        .accessibilityIdentifier("history.revision.\(revision.id.uuidString)")
                    }
                    if let issue = context.calculationIssue {
                        Label(
                            "Calculation needs review", systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(LinePayColor.review)
                        Text(issue).font(.footnote)
                    }
                }
                Section {
                    NavigationLink("Rule sources") {
                        RuleSourcesView(agreement: context.agreement, model: model)
                    }
                    Button("Delete work period and its checks", role: .destructive) {
                        showingDelete = true
                    }
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayCanvas()
        .navigationTitle("Pay period").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingResult) {
            LiveAuditView(model: model, subscriptionStore: subscriptionStore, periodID: periodID)
        }
        .sheet(isPresented: $showingImport) {
            PaystubImportView(
                model: model, subscriptionStore: subscriptionStore, periodID: periodID
            ) { showingResult = true }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(store: subscriptionStore) { showingPaywall = false }
        }
        .confirmationDialog(
            "Delete this period and all its audit revisions?", isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete period", role: .destructive) {
                do {
                    try model.deleteHistoryPeriod(id: periodID)
                    dismiss()
                } catch { errorMessage = error.localizedDescription }
            }
        } message: {
            Text(
                "This removes this period's work and confirmed facts. Unshared originals are deleted, or queued for cleanup if the device cannot remove them. Export a backup first to preserve them."
            )
        }
    }
    private func beginAudit() {
        Task {
            await subscriptionStore.refreshEntitlements()
            if model.canRunAudit(periodID: periodID, hasProAccess: subscriptionStore.hasAuditAccess)
            {
                showingImport = true
            } else {
                showingPaywall = true
            }
        }
    }
}

extension AuditRevision {
    func context(periodID: UUID, resolutionEvents: [ResolutionEvent] = []) -> PayPeriodContext {
        PayPeriodContext(
            id: periodID, window: window, agreement: agreement,
            timeZoneIdentifier: timeZoneIdentifier, workEntries: workEntries,
            calculation: calculation,
            paystub: paystub, reconciliation: reconciliation, revisions: [], isClosed: true,
            agreementChanges: agreementChanges, resolutionEvents: resolutionEvents)
    }
}
