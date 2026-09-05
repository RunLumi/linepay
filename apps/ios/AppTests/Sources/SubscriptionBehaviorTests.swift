import StoreKit
import Testing

@testable import LinePay

@Suite("Subscription application behavior without live commerce")
@MainActor
struct SubscriptionBehaviorTests {
    // Independent identifiers keep generated test arguments outside actor-isolated app state.
    @Test(arguments: ["linepay.pro.monthly", "linepay.pro.yearly"])
    func existingOwnershipSurvivesCatalogFailure(_ identifier: String) async {
        let client = TestStorefront()
        client.identifiers = [identifier]
        client.catalogFails = true
        let store = SubscriptionStore(commerceEnabled: true, operations: client.operations)
        await store.start()
        #expect(store.isPro && store.hasAuditAccess && store.products.isEmpty)
        #expect(!store.isLoading && store.errorMessage != nil)
        #expect(client.entitlementReads == 1 && client.loads == 1)
        #expect(store.product(id: "missing") == nil)
    }

    @Test func unknownProductsNeverGrantProAndExpirationRemovesAccess() async {
        let client = TestStorefront()
        client.identifiers = [SubscriptionStore.monthlyProductID]
        let store = SubscriptionStore(commerceEnabled: true, operations: client.operations)
        await store.load()
        #expect(store.isPro)
        client.identifiers = ["some.other.product"]
        await store.load()
        #expect(!store.isPro && !store.hasAuditAccess)
        // Expiry and revocation both remove the verified current entitlement.
        client.identifiers = []
        await store.load()
        #expect(!store.isPro)
        #expect(!store.isLoading && store.errorMessage == nil)
    }

    @Test(arguments: [
        SubscriptionOperations.PurchaseOutcome.pending, .cancelled, .unverified, .unknown,
    ])
    func unsuccessfulPurchasesNeverGrantAccess(_ outcome: SubscriptionOperations.PurchaseOutcome)
        async
    {
        let client = TestStorefront()
        client.outcome = outcome
        let store = SubscriptionStore(commerceEnabled: true, operations: client.operations)
        #expect(!(await store.purchase(productID: SubscriptionStore.monthlyProductID)))
        #expect(!store.isPro && client.purchases == [SubscriptionStore.monthlyProductID])
        #expect(client.entitlementReads == 0)
        switch outcome {
        case .cancelled: #expect(store.errorMessage == nil)
        default: #expect(store.errorMessage != nil)
        }
    }

    @Test func verifiedPurchaseRefreshesActualOwnershipRatherThanTrustingSuccessAlone() async {
        let client = TestStorefront()
        let store = SubscriptionStore(commerceEnabled: true, operations: client.operations)
        #expect(!(await store.purchase(productID: SubscriptionStore.monthlyProductID)))
        client.identifiers = [SubscriptionStore.yearlyProductID]
        #expect(await store.purchase(productID: SubscriptionStore.yearlyProductID))
        #expect(store.isPro && store.errorMessage == nil && client.entitlementReads == 2)
    }

    @Test func failuresAreRecoverableAndDoNotRevokeKnownOwnership() async {
        let client = TestStorefront()
        let store = SubscriptionStore(commerceEnabled: true, operations: client.operations)
        client.purchaseFails = true
        #expect(!(await store.purchase(productID: SubscriptionStore.monthlyProductID)))
        #expect(store.errorMessage != nil && !store.isPro)
        client.identifiers = [SubscriptionStore.monthlyProductID]
        await store.restorePurchases()
        #expect(store.isPro && store.errorMessage == nil && client.syncs == 1)
        client.syncFails = true
        await store.restorePurchases()
        #expect(store.isPro && store.errorMessage != nil)
        client.syncFails = false
        client.identifiers = []
        await store.restorePurchases()
        #expect(!store.isPro && store.errorMessage != nil)
    }

    @Test func disabledInstanceNeverCallsAnExternalService() async {
        let client = TestStorefront()
        let store = SubscriptionStore(commerceEnabled: false, operations: client.operations)
        await store.start()
        await store.load()
        await store.restorePurchases()
        #expect(!(await store.purchase(productID: SubscriptionStore.monthlyProductID)))
        #expect(store.hasAuditAccess && !store.isPro)
        #expect(
            client.loads == 0 && client.syncs == 0 && client.purchases.isEmpty
                && client.entitlementReads == 0)
    }

    @Test func liveAdapterRejectsUnavailableProductWithoutPurchase() async {
        await #expect(throws: SubscriptionOperationError.productUnavailable) {
            try await SubscriptionOperations.live.purchase("absent", [])
        }
    }
}

@MainActor
private final class TestStorefront {
    var identifiers: Set<String> = []
    var catalogFails = false
    var purchaseFails = false
    var syncFails = false
    var outcome: SubscriptionOperations.PurchaseOutcome = .verified
    var loads = 0
    var syncs = 0
    var purchases: [String] = []
    var entitlementReads = 0

    var operations: SubscriptionOperations {
        SubscriptionOperations(
            loadProducts: { [self] in
                loads += 1
                if catalogFails { throw UnitFailure.injected }
                return []
            },
            entitlementIDs: { [self] in
                entitlementReads += 1
                return identifiers
            },
            purchase: { [self] identifier, _ in
                purchases.append(identifier)
                if purchaseFails { throw UnitFailure.injected }
                return outcome
            },
            synchronize: { [self] in
                syncs += 1
                if syncFails { throw UnitFailure.injected }
            }
        )
    }
}
