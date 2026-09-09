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
    private(set) var renewalDate: Date?
    private(set) var willAutoRenew: Bool?
    private(set) var isTrial = false
    @ObservationIgnored private var transactionTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private let operations: SubscriptionOperations
    @ObservationIgnored private let observesStoreKit: Bool

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
    deinit {
        transactionTask?.cancel()
        statusTask?.cancel()
    }
    var hasAuditAccess: Bool { isPro || !purchasingEnabled }
    func product(id: String) -> Product? { products.first { $0.id == id } }

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
        guard !isLoading else { return }
        isLoading = true
        annualTrialDuration = nil
        defer { isLoading = false }
        do {
            products = try await operations.loadProducts().sorted { rank($0.id) < rank($1.id) }
            errorMessage =
                products.isEmpty
                ? "App Store prices are unavailable. Your saved pay data remains accessible." : nil
            if let annual = product(id: Self.yearlyProductID)?.subscription,
                let offer = annual.introductoryOffer, offer.paymentMode == .freeTrial,
                await annual.isEligibleForIntroOffer
            {
                annualTrialDuration = Self.duration(of: offer)
            }
            await refreshEntitlements()
        } catch {
            products = []
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

    private static func duration(of offer: Product.SubscriptionOffer) -> String? {
        let count = offer.period.value * offer.periodCount
        guard count > 0 else { return nil }
        switch offer.period.unit {
        case .day: return "\(count) \(count == 1 ? "day" : "days")"
        case .week: return "\(count * 7) days"
        case .month: return "\(count) \(count == 1 ? "month" : "months")"
        case .year: return "\(count) \(count == 1 ? "year" : "years")"
        @unknown default: return nil
        }
    }
}
