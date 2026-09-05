import StoreKit
import SwiftUI

struct OnboardingPaywallView: View {
    let model: AppModel
    let store: SubscriptionStore
    let onContinueFree: () -> Void
    let onPurchaseCompleted: () -> Void

    @State private var selectedProductID = SubscriptionStore.yearlyProductID
    @State private var isPurchasing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                header
                profileReadySection
                benefits
                planSelector
                actions
                footer
            }
            .padding(LinePaySpacing.section)
        }
        .background(LinePayColor.canvas.ignoresSafeArea())
        .tint(LinePayColor.brandPrimary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            LineGapMark()

            Text("Audit every paycheck.")
                .font(.largeTitle.bold())
                .foregroundStyle(LinePayColor.textPrimary)

            Text(
                "LinePaycheck Pro is built for recurring paycheck checks. Free still lets you "
                    + "track work, calculate expected pay, and complete your first paycheck audit."
            )
            .font(.title3)
            .foregroundStyle(LinePayColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var profileReadySection: some View {
        if let profile = model.profile {
            VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                Text("YOUR PAY PROFILE IS READY")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(LinePayColor.textSecondary)

                Text(profileSummary(profile))
                    .font(.headline)
                    .foregroundStyle(LinePayColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LinePaySpacing.standard)
            .background(LinePayColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            benefit(
                icon: "doc.text.magnifyingglass",
                title: "Check every paycheck",
                detail: "Compare recorded work with what your paycheck actually paid."
            )
            benefit(
                icon: "list.bullet.rectangle",
                title: "See the math",
                detail: "Review possible differences through an explainable Pay Ledger."
            )
            benefit(
                icon: "lock.shield",
                title: "Private by default",
                detail: "No LinePaycheck account. Pay data stays on this device by default."
            )
        }
    }

    private var planSelector: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("Choose a plan")
                .font(.headline)
                .foregroundStyle(LinePayColor.textPrimary)

            planRow(
                productID: SubscriptionStore.yearlyProductID,
                title: "Yearly",
                badge: "Best value"
            )
            planRow(
                productID: SubscriptionStore.monthlyProductID,
                title: "Monthly",
                badge: nil
            )

            if store.isLoading {
                ProgressView("Loading App Store prices…")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
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
            .tint(LinePayColor.brandPrimary)
            .frame(maxWidth: .infinity)
            .disabled(!canPurchase || isPurchasing)

            Button("Continue free") {
                onContinueFree()
            }
            .buttonStyle(.plain)
            .font(.headline)
            .foregroundStyle(LinePayColor.brandPrimary)
            .frame(minHeight: 48)
            .accessibilityIdentifier("paywall.continue-free")
            .accessibilityHint("Skips the Pro offer and continues with LinePaycheck Free")

            if !SubscriptionStore.commerceEnabled {
                Text("Pro purchasing is disabled until recurring paycheck audits are shipping.")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else if store.products.isEmpty && !store.isLoading {
                Text("Pro isn't available right now. You can keep using LinePaycheck Free.")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    }
                }
            }
            .font(.footnote.weight(.semibold))
            .disabled(!SubscriptionStore.commerceEnabled)

            Text(
                "Subscriptions renew automatically unless cancelled through your App Store "
                    + "subscription settings. Prices and billing terms are shown by the App Store."
            )
            .font(.caption)
            .foregroundStyle(LinePayColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var canPurchase: Bool {
        SubscriptionStore.commerceEnabled
            && store.product(id: selectedProductID) != nil
    }

    private var primaryButtonTitle: String {
        if isPurchasing {
            return "Working…"
        }
        return selectedProductID == SubscriptionStore.yearlyProductID
            ? "Continue with Yearly"
            : "Continue with Monthly"
    }

    private func planRow(productID: String, title: String, badge: String?) -> some View {
        let isSelected = selectedProductID == productID
        let product = store.product(id: productID)

        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: LinePaySpacing.standard) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        isSelected ? LinePayColor.brandPrimary : LinePayColor.textSecondary
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: LinePaySpacing.compact) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(LinePayColor.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LinePayColor.brandPrimary)
                        }
                    }

                    Text(priceLabel(product: product, productID: productID))
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
        .accessibilityLabel("\(title), \(priceLabel(product: product, productID: productID))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func priceLabel(product: Product?, productID: String) -> String {
        guard let product else {
            return store.isLoading ? "Loading price" : "Price unavailable"
        }

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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(LinePayColor.textPrimary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func profileSummary(_ profile: PayProfile) -> String {
        let agreement = profile.agreement
        var rules: [String] = []

        if !agreement.dailyOvertimeTiers.isEmpty {
            rules.append("daily OT")
        }
        if agreement.weekdayPremiums.contains(where: { $0.weekday == .sunday }) {
            rules.append("Sunday premium")
        }
        if agreement.calloutMinimum != nil {
            rules.append("callout minimum")
        }
        if agreement.flatPerDiem != nil {
            rules.append("per diem")
        }

        let rate = "\(LinePayFormat.money(agreement.hourlyRate))/hr"
        if rules.isEmpty {
            return "\(rate). Optional premium rules remain off until you confirm them."
        }

        return "\(rate) with \(rules.joined(separator: ", "))."
    }

    private func purchaseSelectedPlan() {
        guard let product = store.product(id: selectedProductID) else { return }

        Task {
            isPurchasing = true
            let purchased = await store.purchase(product)
            isPurchasing = false
            if purchased {
                onPurchaseCompleted()
            }
        }
    }
}
