import SwiftUI

struct FirstWorkIntroductionView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @State private var addingWork = false
    @State private var offeringPro = false
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
                        // Onboarding ends here for this worker, so this is the one offer moment.
                        if subscriptionStore.canPresentOffer {
                            offeringPro = true
                        } else {
                            deferWork()
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
            .sheet(isPresented: $offeringPro, onDismiss: deferWork) {
                ProPaywallView(store: subscriptionStore, context: .onboarding(expectedPay: nil)) {
                    offeringPro = false
                }
            }
        }
        .sheet(isPresented: $addingWork) { AddWorkView(model: model) }
    }

    private func deferWork() {
        do { try model.deferFirstWork() } catch { errorMessage = error.localizedDescription }
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
                        Button("Continue") { continueAfterResult() }
                            .buttonStyle(LinePayPrimaryButtonStyle())
                            .accessibilityIdentifier("activation.continue")
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
            ProPaywallView(
                store: subscriptionStore,
                context: .onboarding(
                    expectedPay: model.periodContext()?.calculation.map {
                        LinePayFormat.money($0.expectedWages)
                    })
            ) { showingPro = false }
        }
    }

    /// The offer follows a readable result as the last onboarding step; it never covers the number.
    private func continueAfterResult() {
        if subscriptionStore.canPresentOffer { showingPro = true } else { complete() }
    }

    private func complete() {
        do { try model.completeFirstResult() } catch { errorMessage = error.localizedDescription }
    }
}
