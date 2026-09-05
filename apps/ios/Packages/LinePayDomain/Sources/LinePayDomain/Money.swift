import Foundation

public struct Money: Codable, Hashable, Sendable {
    public let amount: Decimal
    public let currencyCode: String

    public init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode.uppercased()
    }

    public func adding(_ other: Money) throws -> Money {
        guard currencyCode == other.currencyCode else {
            throw MoneyError.currencyMismatch(lhs: currencyCode, rhs: other.currencyCode)
        }

        return Money(amount: amount + other.amount, currencyCode: currencyCode)
    }
}

public enum MoneyError: Error, Equatable, Sendable {
    case currencyMismatch(lhs: String, rhs: String)
}
