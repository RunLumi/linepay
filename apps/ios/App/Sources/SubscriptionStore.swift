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
    @ObservationIgnored private var transactionTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private let productLoader: @MainActor ([String]) async throws -> [Product]

    init(
        testCommerceEnabled: Bool? = nil,
        productLoader: @escaping @MainActor ([String]) async throws -> [Product] = {
            try await Product.products(for: $0)
        }
    ) {
        #if DEBUG
            purchasingEnabled = testCommerceEnabled ?? Self.commerceEnabled
        #else
            purchasingEnabled = true
        #endif
        self.productLoader = productLoader
    }
    deinit {
        transactionTask?.cancel()
        statusTask?.cancel()
    }
    var hasAuditAccess: Bool { isPro || !purchasingEnabled }
    func product(id: String) -> Product? { products.first { $0.id == id } }

    func start() async {
        guard purchasingEnabled else { return }
        if transactionTask == nil {
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
        defer { isLoading = false }
        do {
            products = try await productLoader(Self.productIDs).sorted { rank($0.id) < rank($1.id) }
            errorMessage =
                products.isEmpty
                ? "App Store prices are unavailable. Your saved pay data remains accessible." : nil
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
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil,
                !transaction.isUpgraded
            {
                entitled = true
            }
        }
        guard generation == refreshGeneration else { return }
        isPro = entitled
        hasCheckedEntitlements = true
        // Never reject an entitlement just because its paid period expired: StoreKit includes grace.
        notice = nil
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
                if status.state == .inGracePeriod, entitled {
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
        guard purchasingEnabled else {
            errorMessage = "Purchasing is disabled in this debug build."
            return false
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    errorMessage = "The App Store could not verify the purchase."
                    return false
                }
                await refreshEntitlements()
                await transaction.finish()
                errorMessage = nil
                return isPro
            case .pending:
                errorMessage = "This purchase is awaiting App Store approval."
                return false
            case .userCancelled:
                errorMessage = nil
                return false
            @unknown default:
                errorMessage = "The purchase could not be completed."
                return false
            }
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
            try await AppStore.sync()
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
}
