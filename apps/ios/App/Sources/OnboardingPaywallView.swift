import StoreKit
import SwiftUI

struct ProPaywallView: View {
    let store: SubscriptionStore
    let onPurchaseCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = SubscriptionStore.yearlyProductID
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    header
                    benefits
                    planSelector
                    actions
                    footer
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("LinePay Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .tint(LinePayColor.brandPrimary)
        .task {
            if SubscriptionStore.commerceEnabled, store.products.isEmpty {
                await store.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            LineGapMark()
            Text("Audit every paycheck.")
                .font(.largeTitle.bold())
                .foregroundStyle(LinePayColor.textPrimary)
            Text(
                "You have seen what a LinePay audit does. Pro keeps that independent check "
                    + "available for every future paycheck."
            )
            .font(.title3)
            .foregroundStyle(LinePayColor.textSecondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            benefit(
                icon: "doc.text.magnifyingglass",
                title: "Unlimited paycheck audits",
                detail: "Scan or enter each paycheck and compare it with your confirmed work."
            )
            benefit(
                icon: "clock.arrow.circlepath",
                title: "Durable history",
                detail: "Keep immutable pay-period records and audit evidence on your iPhone."
            )
            benefit(
                icon: "square.and.arrow.up",
                title: "Export the evidence",
                detail: "Create a concise reconciliation report you control."
            )
            benefit(
                icon: "lock.shield",
                title: "Still private",
                detail: "Pro does not create a LinePay account or upload your paycheck."
            )
        }
    }

    private var planSelector: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            planRow(
                productID: SubscriptionStore.yearlyProductID,
                title: "Yearly",
                fallbackPrice: "$79.99/year",
                badge: "Best value"
            )
            planRow(
                productID: SubscriptionStore.monthlyProductID,
                title: "Monthly",
                fallbackPrice: "$9.99/month",
                badge: nil
            )
            if store.isLoading {
                ProgressView("Loading App Store prices…")
                    .font(.footnote)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: LinePaySpacing.standard) {
            Button(primaryButtonTitle) {
                purchaseSelectedPlan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!canPurchase || isPurchasing)

            if !SubscriptionStore.commerceEnabled {
                Text("Purchasing is disabled in this debug build. Audit access remains open for testing.")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else if store.products.isEmpty, !store.isLoading {
                Text("App Store prices are unavailable right now. Your existing LinePay data is unaffected.")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: LinePaySpacing.compact) {
            Button("Restore Purchases") {
                Task {
                    await store.restorePurchases()
                    if store.isPro {
                        onPurchaseCompleted()
                        dismiss()
                    }
                }
            }
            .font(.footnote.weight(.semibold))
            .disabled(!SubscriptionStore.commerceEnabled)

            Text(
                "Subscriptions renew automatically unless cancelled in App Store subscription "
                    + "settings. The App Store shows the final localized price and billing terms."
            )
            .font(.caption)
            .foregroundStyle(LinePayColor.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var canPurchase: Bool {
        SubscriptionStore.commerceEnabled && store.product(id: selectedProductID) != nil
    }

    private var primaryButtonTitle: String {
        if isPurchasing { return "Working…" }
        return selectedProductID == SubscriptionStore.yearlyProductID
            ? "Continue with Yearly"
            : "Continue with Monthly"
    }

    private func planRow(
        productID: String,
        title: String,
        fallbackPrice: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedProductID == productID
        let price = priceLabel(
            product: store.product(id: productID),
            productID: productID,
            fallback: fallbackPrice
        )

        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: LinePaySpacing.standard) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? LinePayColor.brandPrimary : LinePayColor.textSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: LinePaySpacing.compact) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LinePayColor.brandPrimary)
                        }
                    }
                    Text(price)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(LinePayColor.textSecondary)
                }
                Spacer()
            }
            .padding(LinePaySpacing.standard)
            .background(LinePayColor.surfacePrimary)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? LinePayColor.brandPrimary : Color(uiColor: .separator),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(price)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func priceLabel(product: Product?, productID: String, fallback: String) -> String {
        guard let product else { return fallback }
        return productID == SubscriptionStore.yearlyProductID
            ? "\(product.displayPrice) per year"
            : "\(product.displayPrice) per month"
    }

    private func benefit(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LinePayColor.brandPrimary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(LinePayColor.textSecondary)
            }
        }
    }

    private func purchaseSelectedPlan() {
        guard let product = store.product(id: selectedProductID) else { return }
        Task {
            isPurchasing = true
            let purchased = await store.purchase(product)
            isPurchasing = false
            if purchased {
                onPurchaseCompleted()
                dismiss()
            }
        }
    }
}

struct LineGapMark: View {
    var body: some View {
        HStack(spacing: 7) {
            Rectangle().frame(width: 64, height: 1)
            Rectangle().frame(width: 32, height: 1)
        }
        .foregroundStyle(LinePayColor.brandCopper)
        .accessibilityHidden(true)
    }
}
