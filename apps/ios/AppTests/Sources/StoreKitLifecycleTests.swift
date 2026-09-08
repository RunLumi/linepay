import Foundation
import StoreKit
import StoreKitTest
import Testing

@testable import LinePay

private final class StoreKitResourceAnchor: NSObject {}

@Suite("Real local StoreKit lifecycle", .serialized)
@MainActor
struct StoreKitLifecycleTests {
    func session() async throws -> SKTestSession {
        let url = try #require(
            Bundle(for: StoreKitResourceAnchor.self).url(
                forResource: "LinePay", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        try await resetSession(session)
        return session
    }

    private func resetSession(_ session: SKTestSession) async throws {
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        try await AppStore.sync()
        // Require StoreKit's receipt to reflect deletion before another test or UI launch.
        for _ in 0..<50 {
            if session.allTransactions().isEmpty,
                await SubscriptionOperations.live.entitlementIDs().isEmpty
            {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        try #require(
            session.allTransactions().isEmpty, "StoreKit test transactions were not cleared")
        try #require(
            await SubscriptionOperations.live.entitlementIDs().isEmpty,
            "StoreKit test entitlements were not cleared")
    }
    @Test func purchaseRenewalCancellationExpirationAndMetadataFailure() async throws {
        let session = try await session()
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
        try await resetSession(session)
    }
    @Test func refundedPurchaseDoesNotGrantPro() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let transaction = try await session.buyProduct(
            identifier: SubscriptionStore.yearlyProductID)
        let store = SubscriptionStore(commerceEnabled: true)
        await expectAccess(true, store: store)
        let identifier = try #require(UInt(exactly: transaction.id))
        try session.refundTransaction(identifier: identifier)
        await expectAccess(false, store: store)
        try await resetSession(session)
    }
    @Test func billingGraceKeepsAccessThenExpires() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        // Keep the grace window observable on a busy CI simulator.
        session.timeRate = .oneRenewalEveryThirtySeconds
        let store = SubscriptionStore(commerceEnabled: true)
        await store.start()
        let subscription = try #require(
            store.product(id: SubscriptionStore.monthlyProductID)?.subscription)
        _ = try await session.buyProduct(identifier: SubscriptionStore.monthlyProductID)
        let clock = ContinuousClock()
        // A rebooted self-hosted simulator can take longer to advance its first
        // renewal than the nominal 30-second StoreKitTest rate. Keep the same
        // verified grace/receipt assertions, but allow the daemon four minutes
        // to publish the renewal state before treating it as absent.
        let deadline = clock.now.advanced(by: .seconds(240))
        var sawGrace = false
        var sawGraceEnd = false
        var observedStates: Set<String> = []
        while clock.now < deadline {
            await store.refreshEntitlements()
            let statuses = try await subscription.status.filter { status in
                guard case .verified(let transaction) = status.transaction,
                    case .verified = status.renewalInfo,
                    transaction.productID == SubscriptionStore.monthlyProductID
                else { return false }
                return true
            }
            for status in statuses {
                observedStates.insert(String(describing: status.state))
            }
            let receiptIDs = await SubscriptionOperations.live.entitlementIDs()
            let graceEnds = statuses.compactMap { status -> Date? in
                guard case .verified(let renewal) = status.renewalInfo else { return nil }
                return renewal.gracePeriodExpirationDate
            }
            let observedAt = Date()
            // StoreKitTest can retain the grace enum after its signed expiration has passed.
            // Use the SDK's verified dates and receipt, not the app's notice, as the oracle.
            if statuses.contains(where: { $0.state == .inGracePeriod }),
                graceEnds.contains(where: { $0 > observedAt })
            {
                try #require(
                    store.isPro,
                    "Native grace; receipt IDs: \(receiptIDs.sorted()); grace ends: \(graceEnds.map(\.timeIntervalSince1970)); observed: \(observedAt.timeIntervalSince1970)"
                )
                try #require(receiptIDs.contains(SubscriptionStore.monthlyProductID))
                try #require(store.notice?.contains("grace") == true)
                sawGrace = true
            } else if sawGrace, receiptIDs.isEmpty,
                (!graceEnds.isEmpty && graceEnds.allSatisfy { $0 <= observedAt })
                    || statuses.contains(where: {
                        $0.state == .expired || $0.state == .inBillingRetryPeriod
                    })
            {
                await expectAccess(false, store: store)
                sawGraceEnd = true
                break
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        #expect(sawGrace, "Native StoreKit states observed: \(observedStates.sorted())")
        #expect(sawGraceEnd, "Native StoreKit must leave grace before access is removed")
        try await resetSession(session)
    }

    @Test func annualTrialUsesRealOfferAndBecomesPaidWithoutAnotherFreeAudit() async throws {
        let session = try await session()
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
        try await resetSession(session)
    }

    @Test func nativeCancellationDoesNotGrantAccessOrShowFailure() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(commerceEnabled: true)
        await store.start()
        let monthly = try #require(store.product(id: SubscriptionStore.monthlyProductID))
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        #expect(!(await store.purchase(monthly)))
        #expect(!store.isPro && store.errorMessage == nil)
        try await resetSession(session)
    }

    @Test func pendingPurchaseRequiresNativeApproval() async throws {
        let session = try await session()
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
        try await resetSession(session)
    }

    @Test func interruptedPurchaseRecoversOnlyAfterStoreResolvesIssue() async throws {
        let session = try await session()
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
        try await resetSession(session)
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
