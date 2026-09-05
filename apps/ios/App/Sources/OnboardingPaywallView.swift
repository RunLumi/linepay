import StoreKit
import SwiftUI

struct ProPaywallView: View {
    let store: SubscriptionStore
    let onPurchaseCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = SubscriptionStore.yearlyProductID
    @State private var isPurchasing = false
    @State private var purchaseConfirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.section) {
                    Text("Check every paycheck.").font(.largeTitle.bold())
                    Text(
                        "Compare your recorded work and confirmed rules with the paycheck facts you review."
                    )
                    .foregroundStyle(LinePayColor.textSecondary)
                    plan(SubscriptionStore.yearlyProductID, title: "Annual — recommended")
                    plan(SubscriptionStore.monthlyProductID, title: "Monthly")
                    if store.isLoading { ProgressView("Checking App Store prices and offers…") }
                    Button(purchaseTitle) { purchase() }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .disabled(!canPurchase || isPurchasing)
                        .accessibilityIdentifier("paywall.purchase")
                    Text(billingTerms).font(.footnote)
                        .accessibilityIdentifier("paywall.terms")
                    Button("Continue free") { dismiss() }.frame(minHeight: 48)
                        .accessibilityIdentifier("paywall.continue-free")
                    if let message = store.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LinePayColor.review)
                    }
                    if store.products.isEmpty, !store.isLoading {
                        Button("Retry App Store prices") { Task { await store.load() } }
                            .frame(minHeight: 48)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            "Check future paychecks with scanning or manual entry",
                            systemImage: "doc.text.magnifyingglass")
                        Label(
                            "Trace possible differences to work, rules and sources",
                            systemImage: "list.bullet.rectangle")
                        Label(
                            "Keep and share the evidence behind each audit",
                            systemImage: "square.and.arrow.up")
                    }
                    Text(
                        "No LinePaycheck account or paycheck upload to our servers. Your first complete audit is free; saved records remain accessible after Pro ends."
                    )
                    .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                    Button("Restore Purchases") {
                        Task {
                            await store.restorePurchases()
                            if store.isPro { purchaseConfirmed = true }
                        }
                    }
                    .disabled(!store.purchasingEnabled)
                    .frame(minHeight: 44).accessibilityIdentifier("paywall.restore")
                    Link("Manage subscription", destination: AppLinks.subscriptions).frame(
                        minHeight: 44)
                    NavigationLink("Privacy policy") { LegalTextView(kind: .privacy) }.frame(
                        minHeight: 44)
                    NavigationLink("Terms of use") { LegalTextView(kind: .terms) }.frame(
                        minHeight: 44)
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .accessibilityIdentifier("paywall.screen")
            .navigationTitle("LinePaycheck Pro").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }.accessibilityIdentifier("paywall.dismiss")
                }
            }
            .alert("LinePaycheck Pro active", isPresented: $purchaseConfirmed) {
                Button("Continue") {
                    onPurchaseCompleted()
                    dismiss()
                }
            } message: {
                Text(confirmationText)
            }
        }
        .tint(LinePayColor.actionText)
        .task { await store.load() }
    }

    private var canPurchase: Bool {
        store.purchasingEnabled && !store.isLoading && store.product(id: selectedProductID) != nil
    }
    private var annualSelected: Bool { selectedProductID == SubscriptionStore.yearlyProductID }
    private var trial: String? { annualSelected ? store.annualTrialDuration : nil }
    private var purchaseTitle: String {
        if isPurchasing { return "Purchasing…" }
        guard canPurchase else { return store.isLoading ? "Loading prices…" : "Prices unavailable" }
        if let trial { return "Start my \(trial) free trial" }
        return annualSelected ? "Subscribe yearly" : "Subscribe monthly"
    }
    private var billingTerms: String {
        guard let product = store.product(id: selectedProductID) else {
            return
                "A purchase is available only after Apple supplies its price. Your saved work and first free audit remain available."
        }
        let period = annualSelected ? "year" : "month"
        if let trial {
            return
                "\(trial) free, then \(product.displayPrice) per \(period), automatically renewing. Cancel at least 24 hours before the trial ends to avoid renewal."
        }
        return
            "\(product.displayPrice) billed today and every \(period) until cancelled. No free trial is offered for this selection. Manage or cancel through Apple subscription settings."
    }
    private var confirmationText: String {
        guard let date = store.renewalDate else {
            return
                "Apple verified your Pro access. Your saved work is ready to continue. Manage billing in Apple subscription settings."
        }
        let action = store.willAutoRenew == true ? "Renews" : "Ends"
        let prefix = store.isTrial ? "Your free trial is active. " : "Your subscription is active. "
        return prefix
            + "\(action) on \(date.formatted(date: .abbreviated, time: .shortened)). Manage billing in Apple subscription settings."
    }
    private func plan(_ id: String, title: String) -> some View {
        let product = store.product(id: id)
        let yearly = id == SubscriptionStore.yearlyProductID
        let price =
            product.map { "\($0.displayPrice) per \(yearly ? "year" : "month")" }
            ?? "Price unavailable"
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.headline)
                    Text(price).font(.title3.bold().monospacedDigit())
                    if yearly, let duration = store.annualTrialDuration {
                        Text("\(duration) free, then billed yearly")
                    } else if product != nil {
                        Text("Billed today. No free trial.")
                    }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinePayColor.surfacePrimary)
            .overlay {
                RoundedRectangle(cornerRadius: 10).stroke(
                    selected ? LinePayColor.actionText : LinePayColor.lineStrong,
                    lineWidth: selected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(yearly ? "paywall.yearly" : "paywall.monthly")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func purchase() {
        guard canPurchase, let product = store.product(id: selectedProductID) else { return }
        isPurchasing = true
        Task {
            purchaseConfirmed = await store.purchase(product)
            isPurchasing = false
        }
    }
}
