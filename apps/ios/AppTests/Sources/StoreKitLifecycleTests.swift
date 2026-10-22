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
        var trace: [String] = []
        func verifiedStatuses() async throws -> [Product.SubscriptionInfo.Status] {
            try await subscription.status.filter { status in
                guard case .verified(let transaction) = status.transaction,
                    case .verified = status.renewalInfo,
                    transaction.productID == SubscriptionStore.monthlyProductID
                else { return false }
                return true
            }
        }
        func signedGraceEnds(_ statuses: [Product.SubscriptionInfo.Status]) -> [Date] {
            statuses.compactMap { status in
                guard case .verified(let renewal) = status.renewalInfo else { return nil }
                return renewal.gracePeriodExpirationDate
            }
        }
        while clock.now < deadline {
            let beforeReadStarted = Date()
            let before = try await verifiedStatuses()
            let beforeReadEnded = Date()
            let beforeGraceEnds = signedGraceEnds(before)
            let noticeBeforeRefresh = store.notice
            await store.refreshEntitlements()
            let refreshEnded = Date()
            let noticeAfterRefresh = store.notice
            let statuses = try await verifiedStatuses()
            let afterReadEnded = Date()
            for status in before + statuses {
                observedStates.insert(String(describing: status.state))
            }
            let receiptIDs = await SubscriptionOperations.live.entitlementIDs()
            let graceEnds = signedGraceEnds(statuses)
            let observedAt = Date()
            let diagnostic =
                "beforeReadStarted=\(beforeReadStarted.timeIntervalSince1970); beforeReadEnded=\(beforeReadEnded.timeIntervalSince1970); beforeStates=\(before.map { String(describing: $0.state) }); beforeGraceEnds=\(beforeGraceEnds.map(\.timeIntervalSince1970)); refreshEnded=\(refreshEnded.timeIntervalSince1970); afterReadEnded=\(afterReadEnded.timeIntervalSince1970); afterStates=\(statuses.map { String(describing: $0.state) }); afterGraceEnds=\(graceEnds.map(\.timeIntervalSince1970)); observed=\(observedAt.timeIntervalSince1970); receiptIDs=\(receiptIDs.sorted()); isPro=\(store.isPro); noticeBeforeRefresh=\(String(describing: noticeBeforeRefresh)); noticeAfterRefresh=\(String(describing: noticeAfterRefresh)); noticeAtAssertion=\(String(describing: store.notice))"
            trace.append(diagnostic)
            // SDK status and the model refresh are separate async reads. Require the same
            // signed, unexpired grace window on both sides before comparing model details.
            // A transition first seen after refresh is observed again on the next normal poll.
            let stableGraceEnds = Set(beforeGraceEnds).intersection(graceEnds)
            if before.contains(where: { $0.state == .inGracePeriod }),
                statuses.contains(where: { $0.state == .inGracePeriod }),
                stableGraceEnds.contains(where: { $0 > observedAt })
            {
                print("STOREKIT_COHERENT_GRACE \(diagnostic)")
                try #require(store.isPro, "\(diagnostic)")
                try #require(
                    receiptIDs.contains(SubscriptionStore.monthlyProductID), "\(diagnostic)")
                try #require(store.notice?.contains("grace") == true, "\(diagnostic)")
                sawGrace = true
            } else if sawGrace, receiptIDs.isEmpty,
                (!graceEnds.isEmpty && graceEnds.allSatisfy { $0 <= observedAt })
                    || statuses.contains(where: {
                        $0.state == .expired || $0.state == .inBillingRetryPeriod
                    })
            {
                print("STOREKIT_GRACE_END \(diagnostic)")
                await expectAccess(false, store: store)
                sawGraceEnd = true
                break
            } else if before.contains(where: { $0.state == .inGracePeriod })
                || statuses.contains(where: { $0.state == .inGracePeriod })
            {
                print("STOREKIT_TRANSITION_SAMPLE \(diagnostic)")
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        #expect(
            sawGrace,
            "Native StoreKit states observed: \(observedStates.sorted()); SDK/model trace: \(trace.joined(separator: "\n"))"
        )
        if !sawGraceEnd {
            print("STOREKIT_MISSING_GRACE_END_TRACE \(trace.joined(separator: "\n"))")
        }
        #expect(sawGraceEnd, "Native StoreKit must leave grace before access is removed")
        try await resetSession(session)
    }

    @Test func annualTrialUsesRealOfferAndBecomesPaidWithoutAnotherFreeAudit() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(commerceEnabled: true)
        let activity = LocalActivityLedger()
        store.localActivity = activity
        await store.start()
        let annual = try #require(store.product(id: SubscriptionStore.yearlyProductID))
        #expect(store.annualTrialDuration == "7 days")
        #expect(
            store.product(id: SubscriptionStore.monthlyProductID)?.subscription?.introductoryOffer
                == nil)
        let annualPlan = try #require(store.plan(id: SubscriptionStore.yearlyProductID))
        #expect(annualPlan.freeTrial == .days(7) && annualPlan.price == annual.price)
        #expect(annualPlan.monthlyEquivalent == "$6.67")
        #expect(store.plan(id: SubscriptionStore.monthlyProductID)?.freeTrial == nil)
        #expect(store.annualSavingsPercent == 33)
        #expect(store.canPresentOffer)
        #expect(await store.purchase(annual))
        await expectTrial(true, store: store)
        #expect(activity.count(.verifiedTrialObserved) >= 1)
        #expect(activity.count(.purchaseVerified) == 1)
        #expect(!store.canPresentOffer, "An active trial is never offered Pro again")
        #expect(store.renewalDate != nil)
        try session.forceRenewalOfSubscription(productIdentifier: annual.id)
        await expectTrial(false, store: store)
        #expect(store.isPro)
        #expect(activity.count(.verifiedPaidObserved) >= 1)
        let observed = activity.count(.verifiedPaidObserved)
        await store.refreshEntitlements()
        #expect(activity.count(.verifiedPaidObserved) == observed)
        await store.load()
        #expect(store.annualTrialDuration == nil)
        #expect(
            store.plan(id: SubscriptionStore.yearlyProductID)?.freeTrial == nil,
            "A used introductory offer must not be advertised again")
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
