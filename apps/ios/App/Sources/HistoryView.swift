import LinePayDomain
import SwiftUI

struct HistoryView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    var onOpenCurrent: () -> Void = {}
    var body: some View {
        NavigationStack {
            List {
                if model.history.isEmpty {
                    Section {
                        Text("No finished work periods yet").font(.title2.bold())
                        Text(
                            "Close a work period to keep it here. Its paycheck can be audited later."
                        )
                        Button("Go to current pay period") { onOpenCurrent() }.frame(minHeight: 48)
                    }
                } else {
                    let groups = Dictionary(grouping: model.history, by: monthKey)
                    ForEach(groups.keys.sorted().reversed(), id: \.self) { key in
                        Section(key) {
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
                                        if let calculation = period.calculation {
                                            Text(
                                                "Expected wages \(LinePayFormat.money(calculation.expectedWages))"
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
                                            if let difference = paid.assessment?.difference {
                                                Text(
                                                    "Difference \(LinePayFormat.money(difference))"
                                                ).monospacedDigit()
                                            }
                                            AuditStatusView(status: model.auditStatus(for: period))
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
            .listStyle(.plain).scrollContentBackground(.hidden).background(LinePayColor.canvas)
            .navigationTitle("History")
        }
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
                    Text(
                        "Timezone: \(context.timeZoneIdentifier) · rules v\(context.agreement.version)"
                    ).font(.footnote)
                    if context.paystub == nil {
                        Label("Awaiting paycheck", systemImage: "clock")
                    } else {
                        AuditStatusView(status: model.status(for: context))
                        NavigationLink("Open paycheck audit") {
                            LiveAuditView(
                                model: model, subscriptionStore: subscriptionStore,
                                periodID: periodID)
                        }
                    }
                    Button(context.paystub == nil ? "Add this paycheck" : "Correct paycheck facts")
                    { beginAudit() }
                    .buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                        "history.audit")
                    Text(
                        "Corrections append a new audit revision. Frozen work, rules and earlier audit revisions remain available."
                    ).font(.footnote)
                }
                if let calculation = context.calculation {
                    PayLedgerRows(
                        calculation: calculation, agreement: context.agreement,
                        work: context.workEntries)
                }
                Section("Audit revisions") {
                    if context.revisions.isEmpty { Text("No saved audit revisions yet.") }
                    ForEach(context.revisions.reversed()) { revision in
                        NavigationLink(
                            "Audit \(Date(timeIntervalSince1970: TimeInterval(revision.paystub.confirmedEpochSeconds)).formatted(date: .abbreviated, time: .shortened))"
                        ) {
                            AuditDetailView(
                                model: model, context: revision.context(periodID: periodID))
                        }
                    }
                }
                Section {
                    NavigationLink("Rule sources") { RuleSourcesView(agreement: context.agreement) }
                    Button("Delete work period and its audits", role: .destructive) {
                        showingDelete = true
                    }
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
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
    func context(periodID: UUID) -> PayPeriodContext {
        PayPeriodContext(
            id: periodID, window: window, agreement: agreement,
            timeZoneIdentifier: timeZoneIdentifier, workEntries: workEntries,
            calculation: calculation,
            paystub: paystub, reconciliation: reconciliation, revisions: [], isClosed: true,
            agreementChanges: agreementChanges)
    }
}
