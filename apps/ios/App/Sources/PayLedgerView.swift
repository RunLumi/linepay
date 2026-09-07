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
                        PayAmount(
                            label: "Expected wages", money: context.calculation?.expectedWages,
                            prominent: true)
                        if let value = context.calculation?.expectedAllowances, value.amount > 0 {
                            PayAmount(label: "Expected per diem", money: value)
                        }
                        Text(
                            "\(LinePayFormat.hours(model.totalHours)) actual worked hours · rules v\(context.agreement.version)"
                        ).font(.footnote)
                        if let error = model.calculationError {
                            CalculationProblemView(message: error)
                        }
                        NavigationLink("Review rule snapshot") {
                            RuleSourcesView(agreement: context.agreement)
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
                            Text("No work to audit yet. Add an actual shift first.")
                            Button(workButtonTitle) { openWorkEntry() }.buttonStyle(
                                LinePayPrimaryButtonStyle())
                        }
                    } else {
                        Section("Paycheck") {
                            if let paystub = context.paystub {
                                AuditStatusView(status: model.status(for: context))
                                if let assessment = paystub.assessment {
                                    Text(
                                        assessment.scope == .grossOnly
                                            ? "Gross comparison only" : "Confirmed-line comparison"
                                    ).font(.footnote)
                                }
                                NavigationLink("Open paycheck audit") {
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
                        }
                    }
                    if let calculation = context.calculation {
                        PayLedgerRows(
                            calculation: calculation, agreement: context.agreement,
                            work: context.workEntries)
                        Section {
                            Button("Finish work period") { showingFinish = true }.frame(
                                minHeight: 48
                            )
                            .accessibilityIdentifier("pay.finish-period")
                            Text(
                                "The next work period can start before this paycheck arrives. Pending paychecks stay available in History."
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
            .listStyle(.plain).scrollContentBackground(.hidden).background(LinePayColor.canvas)
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
                        .disabled(context.calculation == nil)
                        .accessibilityIdentifier("period.confirm-close")
                        Button("Keep period open") { dismiss() }.frame(minHeight: 44)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
            }
            .navigationTitle("Finish work period").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
