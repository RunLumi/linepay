import Foundation

public struct Money: Codable, Hashable, Sendable {
    public let amount: Decimal
    public let currencyCode: String

    public init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode.uppercased()
    }

    public static func zero(currencyCode: String) -> Money {
        Money(amount: 0, currencyCode: currencyCode)
    }

    public func adding(_ other: Money) throws -> Money {
        try requireSameCurrency(as: other)
        return Money(amount: amount + other.amount, currencyCode: currencyCode)
    }

    public func subtracting(_ other: Money) throws -> Money {
        try requireSameCurrency(as: other)
        return Money(amount: amount - other.amount, currencyCode: currencyCode)
    }

    public func multiplied(by multiplier: Decimal) -> Money {
        Money(amount: amount * multiplier, currencyCode: currencyCode)
    }

    public func rounded(using rule: MoneyRoundingRule) -> Money {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, rule.scale, rule.mode.foundationMode)
        return Money(amount: output, currencyCode: currencyCode)
    }

    private func requireSameCurrency(as other: Money) throws {
        guard currencyCode == other.currencyCode else {
            throw MoneyError.currencyMismatch(lhs: currencyCode, rhs: other.currencyCode)
        }
    }
}

public struct MoneyRoundingRule: Codable, Hashable, Sendable {
    public let scale: Int
    public let mode: MoneyRoundingMode

    public init(scale: Int = 2, mode: MoneyRoundingMode = .halfUp) {
        self.scale = scale
        self.mode = mode
    }
}

public enum MoneyRoundingMode: String, Codable, Hashable, Sendable {
    case halfUp
    case bankers
    case down
    case up

    fileprivate var foundationMode: Decimal.RoundingMode {
        switch self {
        case .halfUp:
            .plain
        case .bankers:
            .bankers
        case .down:
            .down
        case .up:
            .up
        }
    }
}

public enum MoneyError: Error, Equatable, Sendable {
    case currencyMismatch(lhs: String, rhs: String)
}
