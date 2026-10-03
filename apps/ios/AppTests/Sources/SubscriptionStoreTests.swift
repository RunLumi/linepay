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

    private func plan(
        _ period: ProPlan.Period, price: String, currency: String = "USD",
        trial: ProPlan.FreeTrial? = nil
    ) throws -> ProPlan {
        ProPlan(
            id: period == .year
                ? SubscriptionStore.yearlyProductID : SubscriptionStore.monthlyProductID,
            period: period, price: try UnitFixture.decimal(price), currencyCode: currency,
            displayPrice: "$" + price, monthlyEquivalent: nil, freeTrial: trial)
    }

    @Test("Annual savings use exact Decimal math and are never rounded up")
    func annualSavingsAreExactAndConservative() throws {
        let monthly = try plan(.month, price: "9.99")
        #expect(
            ProPlan.annualSavingsPercent(annual: try plan(.year, price: "79.99"), monthly: monthly)
                == 33)
        // 1 - 80.00 / 119.88 = 33.26…% still claims only 33%.
        #expect(
            ProPlan.annualSavingsPercent(annual: try plan(.year, price: "80.00"), monthly: monthly)
                == 33)
        #expect(
            ProPlan.annualSavingsPercent(annual: try plan(.year, price: "119.88"), monthly: monthly)
                == nil)
        #expect(
            ProPlan.annualSavingsPercent(annual: try plan(.year, price: "129.99"), monthly: monthly)
                == nil)
        #expect(
            ProPlan.annualSavingsPercent(
                annual: try plan(.year, price: "79.99", currency: "EUR"), monthly: monthly) == nil,
            "Prices in different currencies are not comparable")
    }

    @Test("Trial labels follow the configured offer instead of a hard-coded week")
    func trialLabelsFollowTheOffer() {
        #expect(ProPlan.FreeTrial.days(7) == .days(7))
        #expect(ProPlan.FreeTrial.days(7).duration == "7 days")
        #expect(ProPlan.FreeTrial.days(7).length == "7-day")
        #expect(ProPlan.FreeTrial.days(1).duration == "1 day")
        #expect(ProPlan.FreeTrial.months(1).duration == "1 month")
        #expect(ProPlan.FreeTrial.months(1).days == nil)
    }

    @Test("The onboarding offer appears only when Pro is sellable and not already owned")
    func onboardingOfferRequiresSellableUnownedPro() async {
        let disabled = SubscriptionStore(commerceEnabled: false)
        await disabled.load()
        #expect(!disabled.canPresentOffer)

        let unavailable = SubscriptionStore.fixture(plans: [])
        await unavailable.load()
        #expect(!unavailable.canPresentOffer, "An offer without App Store prices is skipped")

        let sellable = SubscriptionStore.fixture(plans: UITestFixtures.samplePlans(trial: true))
        #expect(!sellable.canPresentOffer, "Nothing is offered before entitlements are checked")
        await sellable.load()
        #expect(sellable.canPresentOffer)
        #expect(sellable.annualTrialDuration == "7 days")
        #expect(sellable.annualSavingsPercent == 33)

        let owned = SubscriptionStore.fixture(
            plans: UITestFixtures.samplePlans(trial: true), entitled: true)
        await owned.load()
        #expect(owned.isPro && !owned.canPresentOffer, "Never sell Pro to an existing subscriber")
    }

    @Test("A fixture offer can never be bought or grant Pro")
    func fixturePurchaseFailsClosed() async {
        let store = SubscriptionStore.fixture(plans: UITestFixtures.samplePlans(trial: true))
        await store.load()
        #expect(!(await store.purchase(productID: SubscriptionStore.yearlyProductID)))
        #expect(!store.isPro && store.errorMessage != nil)
    }
}
