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
                    VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                        Text("Add a shift you worked.").font(.title2.bold())
                        Text(
                            "Pick one from this pay period\(periodText). You'll see what it should pay under the rules you just set, and every step of the math."
                        )
                        .foregroundStyle(LinePayColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    Button(model.workDraft == nil ? "Add a shift" : "Resume my work draft") {
                        addingWork = true
                    }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .accessibilityIdentifier("activation.add-work")
                    Button("I'll add shifts later") {
                        // Onboarding ends here for this worker, so this is the one offer moment.
                        if subscriptionStore.canPresentOffer {
                            offeringPro = true
                        } else {
                            deferWork()
                        }
                    }
                    .linePayRowAction()
                    .accessibilityIdentifier("activation.skip-work")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
            }
            .navigationTitle("Your first shift")
            .linePayCanvas()
            .sheet(isPresented: $offeringPro, onDismiss: deferWork) {
                ProPaywallView(store: subscriptionStore, context: .onboarding(expectedPay: nil)) {
                    offeringPro = false
                }
            }
        }
        .sheet(isPresented: $addingWork) { AddWorkView(model: model) }
    }

    private var periodText: String {
        guard let window = model.activePeriod?.window else { return "" }
        return
            " (\(LinePayFormat.payPeriod(window, timeZoneIdentifier: model.currentTimeZoneIdentifier)))"
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
                            "\(LinePayFormat.hours(model.totalHours)) h worked · pay period \(LinePayFormat.payPeriod(context.window, timeZoneIdentifier: context.timeZoneIdentifier))"
                        )
                        .font(.subheadline).monospacedDigit()
                        Text(
                            "Based only on the rules you entered and the work logged so far. Keep adding shifts; when the paycheck arrives, compare it with the full period."
                        )
                        .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
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
                    Button("Return to my work") { complete() }.linePayRowAction()
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
            }
            .navigationTitle("Your expected pay")
            .linePayCanvas()
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
