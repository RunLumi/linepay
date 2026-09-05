import Foundation
import Testing
@testable import LinePayDomain

@Test("Money addition uses Decimal, not binary floating point")
func addsMoneyExactly() throws {
    let lhs = Money(amount: Decimal(string: "0.10")!, currencyCode: "usd")
    let rhs = Money(amount: Decimal(string: "0.20")!, currencyCode: "USD")

    let result = try lhs.adding(rhs)

    #expect(result == Money(amount: Decimal(string: "0.30")!, currencyCode: "USD"))
}

@Test("Money from different currencies cannot be combined")
func rejectsCurrencyMismatch() {
    let usd = Money(amount: 10, currencyCode: "USD")
    let cad = Money(amount: 10, currencyCode: "CAD")

    #expect(throws: MoneyError.currencyMismatch(lhs: "USD", rhs: "CAD")) {
        try usd.adding(cad)
    }
}
