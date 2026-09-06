import SwiftUI

struct FirstWorkIntroductionView: View {
    let model: AppModel
    @State private var addingWork = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Start with work you actually performed.").font(.title2.bold())
                    Text(
                        "Enter one recent interval, review its dates and unpaid breaks, then see the calculation from your confirmed rules."
                    )
                    Button(model.workDraft == nil ? "Log my first work" : "Resume my work draft") {
                        addingWork = true
                    }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .accessibilityIdentifier("activation.add-work")
                    Button("I'll log work later") {
                        do { try model.deferFirstWork() } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("activation.skip-work")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
            }
            .navigationTitle("Your first work")
            .scrollContentBackground(.hidden).background(LinePayColor.canvas)
        }
        .sheet(isPresented: $addingWork) { AddWorkView(model: model) }
    }
}

struct FirstPayResultView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @State private var showingPro = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let context = model.periodContext(), let calculation = context.calculation {
                    Section {
                        PayAmount(
                            label: "Expected wages for this work", money: calculation.expectedWages,
                            prominent: true)
                        if calculation.expectedAllowances.amount > 0 {
                            PayAmount(
                                label: "Separate expected per diem",
                                money: calculation.expectedAllowances)
                        }
                        Text(
                            LinePayFormat.payPeriod(
                                context.window, timeZoneIdentifier: context.timeZoneIdentifier))
                        Text(
                            "\(LinePayFormat.hours(model.totalHours)) actual worked hours · \(context.timeZoneIdentifier)"
                        )
                        Text(
                            "Using the rules you confirmed. Add any missing premiums before treating this as a complete estimate."
                        )
                        .font(.footnote)
                        Text(
                            "This is an estimate for the work recorded so far. A full paycheck needs the matching full work period."
                        )
                        .font(.footnote)
                    }
                    Section {
                        Button("Check every paycheck") { showingPro = true }
                            .buttonStyle(LinePayPrimaryButtonStyle())
                            .accessibilityIdentifier("activation.view-pro")
                        Button("Keep logging work") { complete() }.frame(minHeight: 48)
                            .accessibilityIdentifier("activation.keep-logging")
                    }
                    PayLedgerRows(
                        calculation: calculation, agreement: context.agreement,
                        work: context.workEntries)
                } else {
                    CalculationProblemView(
                        message: model.calculationError ?? "Review your saved work and rules.")
                    Button("Return to my work") { complete() }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
            }
            .navigationTitle("Your expected pay")
            .scrollContentBackground(.hidden).background(LinePayColor.canvas)
        }
        .sheet(isPresented: $showingPro, onDismiss: complete) {
            ProPaywallView(store: subscriptionStore) { showingPro = false }
        }
    }

    private func complete() {
        do { try model.completeFirstResult() } catch { errorMessage = error.localizedDescription }
    }
}
