import Testing

@testable import LinePay

@Suite("Subscription store")
@MainActor
struct SubscriptionStoreTests {
    @Test("Commerce remains disabled in ordinary debug tests")
    func commerceIsDisabledInDebugTests() {
        #if DEBUG
            #expect(!SubscriptionStore.commerceEnabled)
        #endif
    }

    @Test("Debug builds stay audit-able without App Store state")
    func debugAuditAccessDoesNotDependOnStoreKit() {
        let store = SubscriptionStore()
        #if DEBUG
            #expect(store.hasAuditAccess)
        #endif
    }

    @Test("Disabled commerce does not load products")
    func disabledCommerceLoadIsDeterministic() async {
        let store = SubscriptionStore()
        await store.load()

        if !SubscriptionStore.commerceEnabled {
            #expect(store.products.isEmpty)
            #expect(!store.isPro)
            #expect(store.errorMessage == nil)
        }
    }
}
