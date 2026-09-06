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
        let store = SubscriptionStore(commerceEnabled: true)
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
            commerceEnabled: true,
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
        let store = SubscriptionStore(commerceEnabled: true)
        await expectAccess(true, store: store)
        let identifier = try #require(UInt(exactly: transaction.id))
        try session.refundTransaction(identifier: identifier)
        await expectAccess(false, store: store)
    }
    @Test func billingGraceKeepsAccessThenExpires() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        session.timeRate = .oneRenewalEveryTenSeconds
        _ = try await session.buyProduct(identifier: SubscriptionStore.monthlyProductID)
        let store = SubscriptionStore(commerceEnabled: true)
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
        // A grace-period transaction has already expired. Forcing expiry is invalid in StoreKitTest.
        // Let accelerated time end grace and prove access is removed without a new purchase.
        await expectAccess(false, store: store, attempts: 300)
    }

    @Test func annualTrialUsesRealOfferAndBecomesPaidWithoutAnotherFreeAudit() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(commerceEnabled: true)
        await store.start()
        let annual = try #require(store.product(id: SubscriptionStore.yearlyProductID))
        #expect(store.annualTrialDuration == "7 days")
        #expect(
            store.product(id: SubscriptionStore.monthlyProductID)?.subscription?.introductoryOffer
                == nil)
        #expect(await store.purchase(annual))
        await expectTrial(true, store: store)
        #expect(store.renewalDate != nil)
        try session.forceRenewalOfSubscription(productIdentifier: annual.id)
        await expectTrial(false, store: store)
        #expect(store.isPro)
        await store.load()
        #expect(store.annualTrialDuration == nil)
    }

    @Test func nativeCancellationDoesNotGrantAccessOrShowFailure() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(commerceEnabled: true)
        await store.start()
        let monthly = try #require(store.product(id: SubscriptionStore.monthlyProductID))
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        #expect(!(await store.purchase(monthly)))
        #expect(!store.isPro && store.errorMessage == nil)
    }

    @Test func pendingPurchaseRequiresNativeApproval() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let store = SubscriptionStore(commerceEnabled: true)
        await store.start()
        let monthly = try #require(store.product(id: SubscriptionStore.monthlyProductID))
        #expect(!(await store.purchase(monthly)))
        #expect(!store.isPro)
        let pending = try #require(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        await expectAccess(true, store: store)
    }

    @Test func interruptedPurchaseRecoversOnlyAfterStoreResolvesIssue() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        session.interruptedPurchasesEnabled = true
        let store = SubscriptionStore(commerceEnabled: true)
        await store.start()
        let monthly = try #require(store.product(id: SubscriptionStore.monthlyProductID))
        #expect(!(await store.purchase(monthly)))
        #expect(!store.isPro)
        let interrupted = try #require(session.allTransactions().first)
        session.interruptedPurchasesEnabled = false
        try session.resolveIssueForTransaction(identifier: interrupted.identifier)
        await expectAccess(true, store: store)
    }

    private func expectTrial(_ expected: Bool, store: SubscriptionStore) async {
        for _ in 0..<30 {
            await store.refreshEntitlements()
            if store.isTrial == expected { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
        #expect(store.isTrial == expected)
    }
    private func expectAccess(
        _ expected: Bool, store: SubscriptionStore, attempts: Int = 30
    ) async {
        for _ in 0..<attempts {
            await store.refreshEntitlements()
            if store.isPro == expected { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
        #expect(store.isPro == expected)
    }
}
