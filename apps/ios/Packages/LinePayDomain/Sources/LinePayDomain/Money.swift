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

/// The aggregation boundary is part of the saved rule, not an incidental engine partition.
public enum PayRoundingScope: String, Codable, Hashable, Sendable {
    case legacySegments
    case payCategory
}

public struct MoneyRoundingRule: Codable, Hashable, Sendable {
    public let scale: Int
    public let mode: MoneyRoundingMode
    public let scope: PayRoundingScope

    public init(
        scale: Int = 2, mode: MoneyRoundingMode = .halfUp,
        scope: PayRoundingScope = .payCategory
    ) {
        self.scale = scale
        self.mode = mode
        self.scope = scope
    }

    private enum CodingKeys: String, CodingKey { case scale, mode, scope }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        scale = try values.decode(Int.self, forKey: .scale)
        mode = try values.decode(MoneyRoundingMode.self, forKey: .mode)
        // Old records retain their actual policy; decoding is not a new calculation.
        scope = try values.decodeIfPresent(PayRoundingScope.self, forKey: .scope) ?? .legacySegments
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
