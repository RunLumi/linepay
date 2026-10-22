import Foundation
import Testing

@testable import LinePay

@Suite("Subscription detail refresh ownership")
@MainActor
struct SubscriptionStoreRefreshTests {
    @Test(arguments: [false, true])
    func overlappingRefreshesPublishOnlyTheLatestCompleteDetails(latestFinishesFirst: Bool) async {
        let client = ControlledSubscriptionRefresh()
        let store = client.makeStore()
        let activity = LocalActivityLedger()
        store.localActivity = activity
        await store.refreshEntitlements()
        #expect(store.notice == "Existing verified grace")

        let first = Task { await store.refreshEntitlements() }
        await client.waitForDetails(call: 2)
        let latest = Task { await store.refreshEntitlements() }
        await client.waitForDetails(call: 3)
        // No provisional nil/trial/renewal snapshot while either resolver is suspended.
        #expect(store.isPro && store.notice == "Existing verified grace")
        #expect(store.renewalDate == client.initial.renewalDate && store.isTrial)

        let stale = SubscriptionStore.SubscriptionDetails(
            notice: "Superseded", renewalDate: Date(timeIntervalSince1970: 200),
            willAutoRenew: false, isTrial: false,
            activity: [(.verifiedPaidObserved, 12)])
        let final = SubscriptionStore.SubscriptionDetails(
            notice: "Latest verified grace", renewalDate: Date(timeIntervalSince1970: 300),
            willAutoRenew: true, isTrial: false,
            activity: [(.verifiedPaidObserved, 13)])
        if latestFinishesFirst {
            client.finishDetails(call: 3, value: final)
            await latest.value
            client.finishDetails(call: 2, value: stale)
            await first.value
        } else {
            client.finishDetails(call: 2, value: stale)
            await first.value
            #expect(store.notice == "Existing verified grace")
            #expect(activity.count(.verifiedPaidObserved) == 0)
            client.finishDetails(call: 3, value: final)
            await latest.value
        }
        #expect(store.notice == final.notice && store.renewalDate == final.renewalDate)
        #expect(store.willAutoRenew == true && !store.isTrial && store.isPro)
        #expect(activity.count(.verifiedPaidObserved) == 1)
    }

    @Test(arguments: [false, true])
    func accessLossOrDifferentProductClearsOldDetailsBeforeStatusReturns(
        changesProduct: Bool
    ) async {
        let client = ControlledSubscriptionRefresh()
        let store = client.makeStore()
        await store.refreshEntitlements()
        #expect(store.isPro && store.isTrial && store.notice != nil)
        client.identifiers = changesProduct ? [SubscriptionStore.yearlyProductID] : []
        let refresh = Task { await store.refreshEntitlements() }
        await client.waitForDetails(call: 2)
        #expect(store.isPro == changesProduct)
        #expect(store.hasAuditAccess == changesProduct)
        #expect(store.notice == nil && store.renewalDate == nil)
        #expect(store.willAutoRenew == nil && !store.isTrial)
        client.finishDetails(call: 2, value: .init())
        await refresh.value
        #expect(store.isPro == changesProduct)
        #expect(store.notice == nil && !store.isTrial)
    }
}

@MainActor
private final class ControlledSubscriptionRefresh {
    var identifiers: Set<String> = [SubscriptionStore.monthlyProductID]
    let initial = SubscriptionStore.SubscriptionDetails(
        notice: "Existing verified grace", renewalDate: Date(timeIntervalSince1970: 100),
        willAutoRenew: true, isTrial: true)
    private var calls = 0
    private var pending: [Int: CheckedContinuation<SubscriptionStore.SubscriptionDetails, Never>] =
        [:]
    private var started: [Int: CheckedContinuation<Void, Never>] = [:]

    func makeStore() -> SubscriptionStore {
        SubscriptionStore(
            commerceEnabled: true,
            operations: SubscriptionOperations(
                loadProducts: { [] }, entitlementIDs: { self.identifiers },
                purchase: { _, _ in .unverified }, synchronize: {}),
            subscriptionDetailsLoader: { _, _ in await self.loadDetails() })
    }

    func waitForDetails(call: Int) async {
        if pending[call] != nil { return }
        await withCheckedContinuation { started[call] = $0 }
    }

    func finishDetails(call: Int, value: SubscriptionStore.SubscriptionDetails) {
        pending.removeValue(forKey: call)?.resume(returning: value)
    }

    private func loadDetails() async -> SubscriptionStore.SubscriptionDetails {
        calls += 1
        let call = calls
        if call == 1 { return initial }
        return await withCheckedContinuation { continuation in
            pending[call] = continuation
            started.removeValue(forKey: call)?.resume()
        }
    }
}
