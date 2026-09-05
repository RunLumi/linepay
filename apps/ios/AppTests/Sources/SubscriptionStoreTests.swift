import Testing
@testable import LinePay

@Suite("SubscriptionStore lifecycle")
@MainActor
struct SubscriptionStoreTests {
    @Test("Disabled commerce starts without network or entitlement state")
    func disabledCommerceStartIsNoOp() async {
        #expect(SubscriptionStore.commerceEnabled == false)

        let store = SubscriptionStore()
        await store.start()

        #expect(store.products.isEmpty)
        #expect(store.isPro == false)
        #expect(store.isLoading == false)
        #expect(store.errorMessage == nil)
    }

    @Test("Disabled commerce restore remains explicit")
    func disabledCommerceRestoreIsExplicit() async {
        let store = SubscriptionStore()

        await store.restorePurchases()

        #expect(store.isPro == false)
        #expect(store.errorMessage == "Pro purchasing isn't enabled in this build yet.")
    }
}
