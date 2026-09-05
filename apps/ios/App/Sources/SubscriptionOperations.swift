import StoreKit

/// A narrow SDK boundary so entitlement and failure handling are testable without an Apple account.
/// Live closures only accept verified StoreKit transactions; tests supply synthetic outcomes.
@MainActor
struct SubscriptionOperations {
    enum PurchaseOutcome: Sendable {
        case verified, unverified, pending, cancelled, unknown
    }

    var loadProducts: () async throws -> [Product]
    var entitlementIDs: () async -> Set<String>
    var purchase: (String, [Product]) async throws -> PurchaseOutcome
    var synchronize: () async throws -> Void

    static var live: SubscriptionOperations {
        SubscriptionOperations(
            loadProducts: {
                try await Product.products(for: [SubscriptionStore.monthlyProductID, SubscriptionStore.yearlyProductID])
            },
            entitlementIDs: {
                var identifiers: Set<String> = []
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        identifiers.insert(transaction.productID)
                    }
                }
                return identifiers
            },
            purchase: { identifier, products in
                guard let product = products.first(where: { $0.id == identifier }) else {
                    throw SubscriptionOperationError.productUnavailable
                }
                switch try await product.purchase() {
                case .success(let verification):
                    guard case .verified(let transaction) = verification else { return .unverified }
                    await transaction.finish()
                    return .verified
                case .pending: return .pending
                case .userCancelled: return .cancelled
                @unknown default: return .unknown
                }
            },
            synchronize: { try await AppStore.sync() }
        )
    }
}

enum SubscriptionOperationError: Error { case productUnavailable }
