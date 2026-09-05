import Foundation
import StoreKit
import StoreKitTest
import Testing

@testable import LinePay

private final class StoreKitResourceAnchor: NSObject {}

@Suite("Real local StoreKit lifecycle", .serialized)
@MainActor
struct StoreKitLifecycleTests {
    func session() throws -> SKTestSession {
        let url = try #require(
            Bundle(for: StoreKitResourceAnchor.self).url(
                forResource: "LinePay", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }
    @Test func purchaseRenewalCancellationExpirationAndMetadataFailure() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(testCommerceEnabled: true)
        await store.load()
        let monthly = try #require(store.product(id: SubscriptionStore.monthlyProductID))
        #expect(monthly.price == Decimal(string: "9.99"))
        #expect(await store.purchase(monthly))
        let transaction = try #require(session.allTransactions().first)
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await store.refreshEntitlements()
        #expect(store.isPro, "Cancelling renewal must not remove current paid access")
        try session.forceRenewalOfSubscription(productIdentifier: monthly.id)
        await expectAccess(true, store: store)
        let offline = SubscriptionStore(
            testCommerceEnabled: true,
            productLoader: { _ in throw URLError(.notConnectedToInternet) })
        await offline.load()
        #expect(offline.products.isEmpty)
        #expect(
            offline.isPro, "Product metadata failure must not prevent signed entitlement lookup")
        await store.restorePurchases()
        #expect(store.isPro)
        try session.expireSubscription(productIdentifier: monthly.id)
        await expectAccess(false, store: store)
    }
    @Test func refundedPurchaseDoesNotGrantPro() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let transaction = try await session.buyProduct(
            identifier: SubscriptionStore.yearlyProductID)
        let store = SubscriptionStore(testCommerceEnabled: true)
        await expectAccess(true, store: store)
        try session.refundTransaction(identifier: transaction.identifier)
        await expectAccess(false, store: store)
    }
    @Test func billingGraceKeepsAccessThenExpires() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        session.timeRate = .oneRenewalEveryTenSeconds
        _ = try await session.buyProduct(identifier: SubscriptionStore.monthlyProductID)
        let store = SubscriptionStore(testCommerceEnabled: true)
        await store.load()
        var sawGrace = false
        for _ in 0..<150 {
            await store.refreshEntitlements()
            if store.notice?.contains("grace") == true {
                #expect(store.isPro)
                sawGrace = true
                break
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        #expect(sawGrace, "StoreKit test environment should enter grace after failed renewal")
        try session.expireSubscription(productIdentifier: SubscriptionStore.monthlyProductID)
        await expectAccess(false, store: store)
    }
    private func expectAccess(_ expected: Bool, store: SubscriptionStore) async {
        for _ in 0..<30 {
            await store.refreshEntitlements()
            if store.isPro == expected { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
        #expect(store.isPro == expected)
    }
}
