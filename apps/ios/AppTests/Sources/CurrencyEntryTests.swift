import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Pay currency follows the storefronts LinePaycheck is sold in")
@MainActor
struct CurrencyEntryTests {
    @Test func minorUnitsComeFromTheCurrency() {
        #expect(LinePayFormat.fractionDigits(currencyCode: "USD") == 2)
        #expect(LinePayFormat.fractionDigits(currencyCode: "CAD") == 2)
        #expect(LinePayFormat.fractionDigits(currencyCode: "VND") == 0)
        // No decimal separator at all: grouping marks differ by region ("2,499,000" or
        // "2.499.000"), but a whole-đồng amount never shows minor units.
        let dong = LinePayFormat.money(Money(amount: 2_499_000, currencyCode: "VND"))
        let separator = Locale.current.decimalSeparator ?? "."
        #expect(dong.contains("499") && !dong.contains(separator))
    }

    @Test func zeroDecimalCurrenciesAcceptOrdinaryPaychecks() throws {
        // A normal Vietnamese paycheck is tens of millions of đồng.
        #expect(NumberEntry.amountMaximum(currencyCode: "VND") > 15_000_000)
        #expect(NumberEntry.amountMaximum(currencyCode: "USD") == 10_000_000)
        #expect(try NumberEntry.amount("15000000", currencyCode: "VND") == 15_000_000)
        #expect(throws: (any Error).self) {
            try NumberEntry.amount("15000000", currencyCode: "USD")
        }
    }

    @Test func wholeDongAmountsRejectDecimalsInsteadOfMisreadingThem() throws {
        #expect(NumberEntry.amountFractionDigits(currencyCode: "VND") == 0)
        #expect(NumberEntry.amountFractionDigits(currencyCode: "CAD") == 2)
        // "45.00" or "45,5" đồng is a typo for a whole amount; it must not become 45 đồng.
        for typo in ["45.00", "45.5", "15000000.50"] {
            #expect(throws: (any Error).self) { try NumberEntry.amount(typo, currencyCode: "VND") }
        }
        #expect(try NumberEntry.amount("45000", currencyCode: "VND") == 45_000)
        #expect(try NumberEntry.amount("45.50", currencyCode: "USD") == Decimal(string: "45.50"))

        let model = AppModel()
        var draft = PayProfileDraft()
        draft.currencyCode = "VND"
        draft.hourlyRate = "45.00"
        #expect(throws: (any Error).self) { try model.saveProfile(draft) }
        #expect(model.profile == nil)
    }

    @Test func newProfileUsesTheChosenCurrencyEverywhere() throws {
        let model = AppModel()
        var draft = PayProfileDraft()
        draft.currencyCode = "CAD"
        draft.hourlyRate = "61.25"
        draft.usePerDiem = true
        draft.perDiemAmount = "100"
        draft.timeZoneIdentifier = "America/Toronto"
        try model.saveProfile(draft)
        let agreement = try #require(model.profile?.agreement)
        let rate = try #require(Decimal(string: "61.25"))
        #expect(agreement.hourlyRate == Money(amount: rate, currencyCode: "CAD"))
        #expect(agreement.flatPerDiem?.amountPerWorkDate.currencyCode == "CAD")
        #expect(agreement.rounding.scale == 2)
    }

    @Test func dongProfileRoundsToWholeDong() throws {
        let model = AppModel()
        var draft = PayProfileDraft()
        draft.currencyCode = "VND"
        draft.hourlyRate = "45000"
        draft.timeZoneIdentifier = "Asia/Ho_Chi_Minh"
        try model.saveProfile(draft)
        let agreement = try #require(model.profile?.agreement)
        #expect(agreement.hourlyRate.currencyCode == "VND")
        #expect(agreement.rounding.scale == 0)
    }

    @Test func savedProfileKeepsItsCurrencyWhenRulesChange() throws {
        let model = AppModel()
        var draft = PayProfileDraft()
        draft.currencyCode = "CAD"
        draft.hourlyRate = "50"
        try model.saveProfile(draft)
        let profile = try #require(model.profile)
        var edit = PayProfileDraft(profile: profile)
        #expect(edit.resolvedCurrencyCode == "CAD")
        edit.currencyCode = "USD"
        edit.hourlyRate = "55"
        try model.saveProfile(edit)
        // Every saved calculation is denominated in the original currency.
        #expect(model.profile?.agreement.hourlyRate.currencyCode == "CAD")
    }

    @Test func draftsSavedBeforeCurrenciesVariedStillDecode() throws {
        var draft = PayProfileDraft()
        draft.hourlyRate = "40"
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft))
        var json = try #require(encoded as? [String: Any])
        json.removeValue(forKey: "currencyCode")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(PayProfileDraft.self, from: old)
        #expect(decoded.currencyCode == nil && decoded.hourlyRate == "40")
        #expect(PayProfileDraft.supportedCurrencyCodes.contains(decoded.resolvedCurrencyCode))
    }
}
