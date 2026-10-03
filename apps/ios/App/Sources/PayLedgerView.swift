import LinePayDomain
import SwiftUI

struct PayLedgerView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @State private var showingAdd = false
    @State private var showingRepeatDraft = false
    @State private var showingImport = false
    @State private var showingPaywall = false
    @State private var showingFinish = false
    @State private var showingResult = false

    var body: some View {
        NavigationStack {
            List {
                if let context = model.periodContext() {
                    Section {
                        Text(
                            LinePayFormat.payPeriod(
                                context.window, timeZoneIdentifier: context.timeZoneIdentifier)
                        ).font(.subheadline)
                        if context.workEntries.isEmpty {
                            Text("No work logged yet").font(.title2.bold())
                        } else {
                            PayAmount(
                                label: "Expected wages", money: context.calculation?.expectedWages,
                                prominent: true)
                            if let value = context.calculation?.expectedAllowances,
                                value.amount > 0
                            {
                                PayAmount(label: "Expected per diem", money: value)
                            }
                            Text(
                                "\(LinePayFormat.hours(model.totalHours)) h worked · rules version \(context.agreement.version)"
                            ).font(.footnote).monospacedDigit()
                        }
                        if let error = model.calculationError {
                            CalculationProblemView(message: error)
                        }
                        NavigationLink("Rules used for this estimate") {
                            RuleSourcesView(agreement: context.agreement)
                        }
                        if context.agreement.weeklyOvertime != nil {
                            Text(
                                "Weekly overtime over 40 h is not included in this estimate. Check each complete workweek separately."
                            )
                            .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                        } else if model.totalHours > 40 {
                            // GAP-01: the main estimate never adds weekly overtime. Say so where
                            // it could matter instead of letting the total look complete.
                            Label(
                                "Over 40 h logged. Weekly overtime is not part of this estimate; turn on the weekly overtime review in your rules if it applies to you.",
                                systemImage: "info.circle"
                            )
                            .font(.footnote).foregroundStyle(LinePayColor.information)
                            .accessibilityIdentifier("pay.weekly-overtime-note")
                        }
                        if context.agreement.weeklyOvertime != nil {
                            NavigationLink("Review weekly overtime") {
                                WeeklyOvertimeReviewView(
                                    model: model, weekStart: context.window.startDate)
                            }
                            .accessibilityIdentifier("pay.review-weekly-overtime")
                        }
                    }
                    if context.workEntries.isEmpty {
                        Section {
                            Text("No work to check yet. Add a shift you worked first.")
                            Text(
                                "Log each shift as you work it. When the paycheck arrives, compare it with what this period should pay."
                            )
                            .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                            Button(workButtonTitle) { openWorkEntry() }.buttonStyle(
                                LinePayPrimaryButtonStyle())
                        }
                    } else {
                        Section("Paycheck") {
                            if let paystub = context.paystub {
                                AuditStatusView(status: model.status(for: context))
                                let presentation = AuditAssessment.evaluate(
                                    calculation: context.calculation, paystub: paystub,
                                    reconciliation: context.reconciliation)
                                if !presentation.isCurrent {
                                    Text(presentation.explanation).font(.footnote)
                                } else if let assessment = paystub.assessment {
                                    CheckSummaryRows(assessment: assessment)
                                    Text(
                                        assessment.scope == .grossOnly
                                            ? "Gross comparison only" : "Confirmed-line comparison"
                                    ).font(.footnote)
                                }
                                NavigationLink("View paycheck result") {
                                    LiveAuditView(
                                        model: model, subscriptionStore: subscriptionStore,
                                        periodID: context.id)
                                }
                                .accessibilityIdentifier("pay.open-audit")
                            }
                            Button(
                                context.paystub == nil
                                    ? (model.hasUsedFreeAudit
                                        ? "Check paycheck" : "Check first paycheck free")
                                    : "Review or correct paycheck"
                            ) {
                                beginAudit(context.id)
                            }
                            .buttonStyle(LinePayPrimaryButtonStyle())
                            .disabled(context.calculation == nil)
                            .accessibilityIdentifier("pay.check-paycheck")
                            if context.paystub == nil {
                                Text(
                                    "When the paycheck arrives, enter its gross pay or scan the paystub to compare it with this estimate."
                                )
                                .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                            }
                        }
                    }
                    if let calculation = context.calculation {
                        PayLedgerRows(
                            calculation: calculation, agreement: context.agreement,
                            work: context.workEntries)
                    }
                    if !context.workEntries.isEmpty {
                        Section {
                            Button("Finish work period") { showingFinish = true }
                                .linePayRowAction()
                                .accessibilityIdentifier("pay.finish-period")
                            Text(
                                context.calculation == nil
                                    ? "This period needs calculation review. Closing preserves the work and lets you continue logging the next period."
                                    : "The next work period can start before this paycheck arrives. Pending paychecks stay available in History."
                            ).font(.footnote)
                        }
                    }
                } else {
                    Section {
                        Text(
                            "Start the next manual period from Today. Earlier paychecks can still be checked from History."
                        )
                    }
                }
            }
            .listStyle(.plain).linePayCanvas()
            .navigationTitle("Pay")
            .labeledContentStyle(LinePayValueStyle())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(workButtonTitle, systemImage: "plus") { openWorkEntry() }.disabled(
                        model.activePeriod == nil)
                }
            }
            .navigationDestination(isPresented: $showingResult) {
                if let id = model.activePeriod?.id {
                    LiveAuditView(model: model, subscriptionStore: subscriptionStore, periodID: id)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddWorkView(model: model) }
        .sheet(isPresented: $showingRepeatDraft) { RepeatWorkView(model: model) }
        .sheet(isPresented: $showingImport) {
            if let id = model.activePeriod?.id {
                PaystubImportView(model: model, subscriptionStore: subscriptionStore, periodID: id)
                { showingResult = true }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(store: subscriptionStore) { showingPaywall = false }
        }
        .sheet(isPresented: $showingFinish) { FinishPayPeriodView(model: model) }
    }

    private var workButtonTitle: String {
        model.workDraft?.templateSource != nil ? "Resume repeated shift" : "Add work"
    }

    private func openWorkEntry() {
        if model.workDraft?.templateSource != nil {
            showingRepeatDraft = true
        } else {
            showingAdd = true
        }
    }

    private func beginAudit(_ id: UUID) {
        Task {
            await subscriptionStore.refreshEntitlements()
            if model.canRunAudit(periodID: id, hasProAccess: subscriptionStore.hasAuditAccess) {
                showingImport = true
            } else {
                showingPaywall = true
            }
        }
    }
}

struct FinishPayPeriodView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            List {
                if let context = model.periodContext() {
                    Section {
                        Text(
                            LinePayFormat.payPeriod(
                                context.window, timeZoneIdentifier: context.timeZoneIdentifier)
                        ).font(.headline)
                        PayAmount(
                            label: "Expected wages", money: context.calculation?.expectedWages)
                        if let paid = context.paystub {
                            PayAmount(label: "Confirmed paid gross", money: paid.grossPay)
                            AuditStatusView(status: model.status(for: context))
                        } else {
                            Label("Awaiting paycheck", systemImage: "clock")
                            Text(
                                "Work and rules will be frozen. Attach this paycheck later from History while continuing to log the next period."
                            )
                        }
                        if let issue = context.calculationIssue {
                            Label(
                                "Calculation needs review", systemImage: "exclamationmark.triangle"
                            )
                            .foregroundStyle(LinePayColor.review)
                            Text(issue).font(.footnote)
                        }
                        if let difference = context.paystub?.assessment?.difference {
                            PayAmount(label: "Possible difference", money: difference)
                        }
                    }
                    Section {
                        Button(
                            context.paystub == nil
                                ? "Close work, await paycheck" : "Finish and archive"
                        ) {
                            do {
                                try model.archiveCurrentPeriod()
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .accessibilityIdentifier("period.confirm-close")
                        Button("Keep period open") { dismiss() }.linePayRowAction()
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
            }
            .linePayCanvas()
            .navigationTitle("Finish work period").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
