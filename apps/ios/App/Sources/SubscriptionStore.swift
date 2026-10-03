import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    static let monthlyProductID = "linepay.pro.monthly"
    static let yearlyProductID = "linepay.pro.yearly"
    private static let productIDs = [monthlyProductID, yearlyProductID]
    static var commerceEnabled: Bool {
        #if DEBUG
            ProcessInfo.processInfo.environment["LINEPAY_COMMERCE_ENABLED"] == "1"
        #else
            true
        #endif
    }
    let purchasingEnabled: Bool
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var hasCheckedEntitlements = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var annualTrialDuration: String?
    /// Display facts derived only from loaded StoreKit metadata; empty until Apple supplies prices.
    private(set) var plans: [ProPlan] = []
    private(set) var renewalDate: Date?
    private(set) var willAutoRenew: Bool?
    private(set) var isTrial = false
    @ObservationIgnored private var transactionTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private let operations: SubscriptionOperations
    @ObservationIgnored private let observesStoreKit: Bool
    @ObservationIgnored private var fixturePlans: [ProPlan]?

    init(
        commerceEnabled: Bool? = nil,
        productLoader: (@MainActor ([String]) async throws -> [Product])? = nil,
        operations: SubscriptionOperations? = nil
    ) {
        #if DEBUG
            purchasingEnabled = commerceEnabled ?? Self.commerceEnabled
        #else
            purchasingEnabled = true
        #endif
        var selected = operations ?? .live
        if let productLoader {
            selected.loadProducts = { try await productLoader(Self.productIDs) }
        }
        self.operations = selected
        observesStoreKit = operations == nil
    }
    static func production() -> SubscriptionStore {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
                let fixture = UITestFixtures.subscriptionStore()
            {
                return fixture
            }
        #endif
        return SubscriptionStore()
    }
    deinit {
        transactionTask?.cancel()
        statusTask?.cancel()
    }
    var hasAuditAccess: Bool { isPro || !purchasingEnabled }
    func product(id: String) -> Product? { products.first { $0.id == id } }
    func plan(id: String) -> ProPlan? { plans.first { $0.id == id } }

    /// Whether the one-time onboarding offer can be shown: Apple can sell Pro right now and the
    /// worker does not already own it. An unsellable offer is skipped rather than shown broken.
    var canPresentOffer: Bool {
        purchasingEnabled && hasCheckedEntitlements && !isPro && !plans.isEmpty
    }

    var annualSavingsPercent: Int? {
        guard let annual = plan(id: Self.yearlyProductID),
            let monthly = plan(id: Self.monthlyProductID)
        else { return nil }
        return ProPlan.annualSavingsPercent(annual: annual, monthly: monthly)
    }

    func start() async {
        guard purchasingEnabled else { return }
        if observesStoreKit, transactionTask == nil {
            transactionTask = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self, !Task.isCancelled else { return }
                    guard case .verified(let transaction) = update else { continue }
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
            statusTask = Task { [weak self] in
                for await _ in Product.SubscriptionInfo.Status.updates {
                    guard let self, !Task.isCancelled else { return }
                    // Includes billing-grace/expiration changes that are not a new purchase.
                    await self.refreshEntitlements()
                }
            }
        }
        await load()
    }

    func load() async {
        guard purchasingEnabled else {
            products = []
            isPro = false
            errorMessage = nil
            return
        }
        // Signed on-device entitlements are independent of network product merchandising.
        await refreshEntitlements()
        if let fixturePlans {
            plans = fixturePlans
            annualTrialDuration = plan(id: Self.yearlyProductID)?.freeTrial?.duration
            return
        }
        guard !isLoading else { return }
        isLoading = true
        annualTrialDuration = nil
        defer { isLoading = false }
        do {
            products = try await operations.loadProducts().sorted { rank($0.id) < rank($1.id) }
            errorMessage =
                products.isEmpty
                ? "App Store prices are unavailable. Your saved pay data remains accessible." : nil
            var trial: ProPlan.FreeTrial?
            if let annual = product(id: Self.yearlyProductID)?.subscription,
                let offer = annual.introductoryOffer, offer.paymentMode == .freeTrial,
                await annual.isEligibleForIntroOffer
            {
                trial = Self.freeTrial(of: offer)
            }
            annualTrialDuration = trial?.duration
            plans = products.compactMap {
                Self.plan(for: $0, freeTrial: $0.id == Self.yearlyProductID ? trial : nil)
            }
            await refreshEntitlements()
        } catch {
            products = []
            plans = []
            errorMessage =
                "App Store prices could not be loaded. Verified access and saved pay data do not depend on this request."
            LinePayLog.storeKit.error("Product metadata unavailable")
        }
    }

    func refreshEntitlements() async {
        guard purchasingEnabled else {
            hasCheckedEntitlements = true
            return
        }
        refreshGeneration += 1
        let generation = refreshGeneration
        let identifiers = await operations.entitlementIDs()
        let entitled = !identifiers.isDisjoint(with: Self.productIDs)
        guard generation == refreshGeneration else { return }
        isPro = entitled
        hasCheckedEntitlements = true
        // Never reject an entitlement just because its paid period expired: StoreKit includes grace.
        notice = nil
        renewalDate = nil
        willAutoRenew = nil
        isTrial = false
        for product in products {
            guard let subscription = product.subscription,
                let statuses = try? await subscription.status
            else { continue }
            guard generation == refreshGeneration else { return }
            for status in statuses {
                guard case .verified(let renewal) = status.renewalInfo,
                    case .verified(let transaction) = status.transaction,
                    Self.productIDs.contains(transaction.productID)
                else { continue }
                if entitled, transaction.revocationDate == nil, !transaction.isUpgraded,
                    status.state == .subscribed || status.state == .inGracePeriod
                {
                    renewalDate = transaction.expirationDate
                    willAutoRenew = renewal.willAutoRenew
                    isTrial = transaction.offer?.paymentMode == .freeTrial
                }
                // The verified subscription state is the source of truth for grace. The
                // entitlement transaction set can briefly lag that state on a rebooted
                // StoreKit test device, so do not suppress the user-facing notice while
                // Apple's signed status is already in grace.
                if status.state == .inGracePeriod {
                    notice =
                        "Pro remains active during Apple's billing grace period. Review payment details in your App Store account."
                } else if renewal.isInBillingRetry && !entitled {
                    notice =
                        "Apple is retrying subscription payment. Existing records remain available."
                } else if status.state == .expired && !entitled {
                    notice = "Pro has expired. Existing audits and work records remain available."
                } else if status.state == .revoked && !entitled {
                    notice =
                        "The App Store entitlement is no longer active. Existing records remain available."
                }
            }
        }
    }

    func purchase(_ product: Product) async -> Bool {
        await purchase(productID: product.id)
    }

    func purchase(productID: String) async -> Bool {
        guard purchasingEnabled else {
            errorMessage = "Purchasing is disabled in this debug build."
            return false
        }
        do {
            switch try await operations.purchase(productID, products) {
            case .verified:
                await refreshEntitlements()
                if observesStoreKit && !isPro {
                    // StoreKit can return the verified purchase before currentEntitlements updates.
                    for _ in 0..<30 {
                        guard !Task.isCancelled, !isPro else { break }
                        try await Task.sleep(for: .milliseconds(100))
                        await refreshEntitlements()
                    }
                }
                errorMessage =
                    isPro
                    ? nil
                    : "Apple verified the purchase; access is still refreshing. Restore purchases to check again."
                return isPro
            case .unverified:
                errorMessage = "The App Store could not verify the purchase."
                return false
            case .pending:
                errorMessage = "This purchase is awaiting App Store approval."
                return false
            case .cancelled:
                errorMessage = nil
                return false
            case .unknown:
                errorMessage = "The purchase could not be completed."
                return false
            }
        } catch StoreKitError.userCancelled {
            errorMessage = nil
            return false
        } catch {
            errorMessage = "The purchase could not be completed. Try again later."
            return false
        }
    }
    func restorePurchases() async {
        guard purchasingEnabled else {
            errorMessage = "Purchasing is disabled in this debug build."
            return
        }
        do {
            try await operations.synchronize()
            await refreshEntitlements()
            errorMessage = isPro ? nil : "No active Pro purchase was found for this Apple account."
            if isPro { notice = "LinePaycheck Pro restored." }
        } catch {
            await refreshEntitlements()
            errorMessage =
                "Purchases could not be synchronized. Verified local entitlements were checked; your records are unchanged."
        }
    }
    private func rank(_ id: String) -> Int { id == Self.yearlyProductID ? 0 : 1 }

    private static func plan(for product: Product, freeTrial: ProPlan.FreeTrial?) -> ProPlan? {
        let period: ProPlan.Period
        switch product.id {
        case yearlyProductID: period = .year
        case monthlyProductID: period = .month
        default: return nil
        }
        let style = product.priceFormatStyle
        return ProPlan(
            id: product.id, period: period, price: product.price, currencyCode: style.currencyCode,
            displayPrice: product.displayPrice,
            monthlyEquivalent: period == .year ? (product.price / 12).formatted(style) : nil,
            freeTrial: freeTrial)
    }

    private static func freeTrial(of offer: Product.SubscriptionOffer) -> ProPlan.FreeTrial? {
        let count = offer.period.value * offer.periodCount
        guard count > 0 else { return nil }
        switch offer.period.unit {
        case .day: return .days(count)
        case .week: return .days(count * 7)
        case .month: return .months(count)
        case .year: return .years(count)
        @unknown default: return nil
        }
    }
}

#if DEBUG
    extension SubscriptionStore {
        /// Synthetic merchandising for UI tests and visual QA. It never grants Pro, and a purchase
        /// fails closed because no StoreKit product exists behind these display facts.
        static func fixture(plans: [ProPlan], entitled: Bool = false) -> SubscriptionStore {
            let store = SubscriptionStore(
                commerceEnabled: true,
                operations: SubscriptionOperations(
                    loadProducts: { [] },
                    entitlementIDs: { entitled ? [yearlyProductID] : [] },
                    purchase: { _, _ in throw SubscriptionOperationError.productUnavailable },
                    synchronize: {}))
            store.fixturePlans = plans
            return store
        }
    }
#endif
