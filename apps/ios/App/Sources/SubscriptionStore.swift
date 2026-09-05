import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    static let monthlyProductID = "linepay.pro.monthly"
    static let yearlyProductID = "linepay.pro.yearly"

    /// Keep purchases off until the recurring paycheck-audit value promised by Pro is shipping.
    /// The onboarding paywall can still render as a product preview without trapping Free users.
    static let commerceEnabled = false

    private static let productIDs = [monthlyProductID, yearlyProductID]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var transactionUpdatesTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    /// Starts StoreKit observation when the app is ready for it.
    ///
    /// Keeping asynchronous work out of `init` makes object construction deterministic for previews and
    /// tests, and gives the SwiftUI lifecycle explicit ownership of long-lived tasks.
    func start() async {
        guard Self.commerceEnabled else { return }

        startTransactionUpdatesIfNeeded()
        await load()
    }

    func load() async {
        guard Self.commerceEnabled else {
            products = []
            isPro = false
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { lhs, rhs in
                    rank(lhs.id) < rank(rhs.id)
                }
            errorMessage = nil
            await refreshEntitlements()
        } catch {
            products = []
            errorMessage = "Pro isn't available right now. You can keep using LinePay Free."
            LinePayLog.storeKit.error("Failed to load StoreKit products")
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func purchase(_ product: Product) async -> Bool {
        guard Self.commerceEnabled else {
            errorMessage = "Pro purchasing isn't enabled in this build yet."
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "The App Store couldn't verify this purchase."
                    LinePayLog.storeKit.error("StoreKit returned an unverified purchase")
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPro

            case .pending:
                errorMessage = "This purchase is waiting for App Store approval."
                return false

            case .userCancelled:
                errorMessage = nil
                return false

            @unknown default:
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
        guard Self.commerceEnabled else {
            errorMessage = "Pro purchasing isn't enabled in this build yet."
            return
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            errorMessage = isPro ? nil : "No active LinePay Pro purchase was found."
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
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID) {
                hasPro = true
                break
            }
        }

        isPro = hasPro
    }

    private func rank(_ productID: String) -> Int {
        switch productID {
        case Self.yearlyProductID: 0
        case Self.monthlyProductID: 1
        default: 2
        }
    }
}
