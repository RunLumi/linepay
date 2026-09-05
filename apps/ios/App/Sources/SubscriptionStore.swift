import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    static let monthlyProductID = "linepay.pro.monthly"
    static let yearlyProductID = "linepay.pro.yearly"

    /// Release builds use real StoreKit. Debug builds stay frictionless unless explicitly enabled
    /// with LINEPAY_COMMERCE_ENABLED=1 so previews/tests never depend on App Store state.
    static var commerceEnabled: Bool {
        #if DEBUG
            ProcessInfo.processInfo.environment["LINEPAY_COMMERCE_ENABLED"] == "1"
        #else
            true
        #endif
    }

    private static let productIDs = [monthlyProductID, yearlyProductID]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let operations: SubscriptionOperations
    @ObservationIgnored private let isCommerceEnabled: Bool
    @ObservationIgnored private let observesStoreKit: Bool
    @ObservationIgnored
    private var transactionUpdatesTask: Task<Void, Never>?

    init(commerceEnabled: Bool? = nil, operations: SubscriptionOperations? = nil) {
        self.isCommerceEnabled = commerceEnabled ?? Self.commerceEnabled
        self.operations = operations ?? .live
        self.observesStoreKit = operations == nil
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var hasAuditAccess: Bool {
        isPro || !isCommerceEnabled
    }

    func start() async {
        guard isCommerceEnabled else { return }
        if observesStoreKit { startTransactionUpdatesIfNeeded() }
        await load()
    }

    func load() async {
        guard isCommerceEnabled else {
            products = []
            isPro = false
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            products = try await operations.loadProducts()
                .sorted { lhs, rhs in
                    rank(lhs.id) < rank(rhs.id)
                }
            errorMessage = nil
        } catch {
            products = []
            errorMessage = "Pro isn't available right now. You can keep using LinePaycheck Free."
            LinePayLog.storeKit.error("Failed to load StoreKit products")
        }
        // Local verified ownership must not depend on a successful catalog/network request.
        await refreshEntitlements()
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func purchase(_ product: Product) async -> Bool {
        await purchase(productID: product.id)
    }

    func purchase(productID: String) async -> Bool {
        guard isCommerceEnabled else {
            errorMessage = "Purchases are disabled in this debug build."
            return false
        }

        do {
            let result = try await operations.purchase(productID, products)
            switch result {
            case .verified:
                await refreshEntitlements()
                errorMessage = nil
                return isPro

            case .unverified:
                errorMessage = "The App Store couldn't verify this purchase."
                LinePayLog.storeKit.error("StoreKit returned an unverified purchase")
                return false

            case .pending:
                errorMessage = "This purchase is waiting for App Store approval."
                return false

            case .cancelled:
                errorMessage = nil
                return false

            case .unknown:
                errorMessage = "The purchase couldn't be completed. Try again later."
                LinePayLog.storeKit.error("StoreKit returned an unknown purchase result")
                return false
            }
        } catch {
            errorMessage = "The purchase couldn't be completed. Try again later."
            LinePayLog.storeKit.error("StoreKit purchase failed")
            return false
        }
    }

    func restorePurchases() async {
        guard isCommerceEnabled else {
            errorMessage = "Purchases are disabled in this debug build."
            return
        }

        do {
            try await operations.synchronize()
            await refreshEntitlements()
            errorMessage = isPro ? nil : "No active LinePaycheck Pro purchase was found."
        } catch {
            errorMessage = "Purchases couldn't be restored right now."
            LinePayLog.storeKit.error("StoreKit restore failed")
        }
    }

    private func startTransactionUpdatesIfNeeded() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                guard case .verified(let transaction) = result else {
                    LinePayLog.storeKit.error("StoreKit emitted an unverified transaction update")
                    continue
                }

                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func refreshEntitlements() async {
        let identifiers = await operations.entitlementIDs()
        isPro = !identifiers.isDisjoint(with: Self.productIDs)
    }

    private func rank(_ productID: String) -> Int {
        switch productID {
        case Self.yearlyProductID: 0
        case Self.monthlyProductID: 1
        default: 2
        }
    }
}
