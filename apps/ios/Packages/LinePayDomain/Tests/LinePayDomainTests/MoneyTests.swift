import Foundation
import Testing

@testable import LinePayDomain

@Test("Money addition uses Decimal, not binary floating point")
func addsMoneyExactly() throws {
    let locale = Locale(identifier: "en_US_POSIX")
    let tenCents = try #require(Decimal(string: "0.10", locale: locale))
    let twentyCents = try #require(Decimal(string: "0.20", locale: locale))
    let thirtyCents = try #require(Decimal(string: "0.30", locale: locale))

    let lhs = Money(amount: tenCents, currencyCode: "usd")
    let rhs = Money(amount: twentyCents, currencyCode: "USD")

    let result = try lhs.adding(rhs)

    #expect(result == Money(amount: thirtyCents, currencyCode: "USD"))
}

@Test("Money from different currencies cannot be combined")
func rejectsCurrencyMismatch() {
    let usd = Money(amount: 10, currencyCode: "USD")
    let cad = Money(amount: 10, currencyCode: "CAD")

    #expect(throws: MoneyError.currencyMismatch(lhs: "USD", rhs: "CAD")) {
        try usd.adding(cad)
    }
}
