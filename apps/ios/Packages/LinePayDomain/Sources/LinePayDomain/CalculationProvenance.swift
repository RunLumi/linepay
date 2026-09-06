import Foundation

/// Nil on decoded legacy results means unknown, never implicitly the current engine.
public struct CalculationProvenance: Codable, Hashable, Sendable {
    public let engine: String
    public let rounding: String
    public let callout: String

    public init(engine: String, rounding: String, callout: String) {
        self.engine = engine
        self.rounding = rounding
        self.callout = callout
    }
}

public enum CalloutReviewError: Error, Equatable, Sendable {
    case eventIdentityRequired(UUID)
    case unsupportedInteraction(UUID)
}

/// Round once per category, multiplier and explicit policy. Allocate cents to ledger rows by
/// largest remainder, with chronological input order as tie-breaker. Never use random UUID order.
enum PayComponentRounding {
    struct Key: Hashable {
        let category: PayComponentCategory
        let multiplier: Decimal?
        let rule: MoneyRoundingRule
        let currency: String
    }

    static func apply(_ source: [PayComponent], snapshots: [AgreementSnapshot]) throws
        -> [PayComponent]
    {
        var result = source
        var groups: [Key: [Int]] = [:]
        for index in source.indices {
            let part = source[index]
            guard
                let snapshot = snapshots.first(where: {
                    AgreementReference($0) == part.appliedAgreement
                }), (0...8).contains(snapshot.rounding.scale), !part.amount.amount.isNaN,
                part.amount.amount >= 0
            else { throw PayCalculationError.invalidRoundingInput }
            let rule = snapshot.rounding
            if rule.scope == .legacySegments {
                result[index] = replacing(part, amount: part.amount.rounded(using: rule))
            } else {
                groups[
                    Key(
                        category: part.category, multiplier: part.multiplier,
                        rule: rule, currency: part.amount.currencyCode), default: []
                ].append(index)
            }
        }
        for (key, indices) in groups {
            let sum = Money(
                amount: indices.reduce(0) { $0 + source[$1].amount.amount },
                currencyCode: key.currency)
            let target = sum.rounded(using: key.rule)
            let floorRule = MoneyRoundingRule(scale: key.rule.scale, mode: .down)
            let floors = indices.map { source[$0].amount.rounded(using: floorRule) }
            var residual = target.amount - floors.reduce(0) { $0 + $1.amount }
            var unit = Decimal(1)
            for _ in 0..<key.rule.scale { unit /= 10 }
            let ranked = indices.indices.sorted {
                let a = source[indices[$0]].amount.amount - floors[$0].amount
                let b = source[indices[$1]].amount.amount - floors[$1].amount
                return a == b ? indices[$0] < indices[$1] : a > b
            }
            var allocated = floors
            for position in ranked where residual >= unit {
                allocated[position] = Money(
                    amount: floors[position].amount + unit,
                    currencyCode: key.currency)
                residual -= unit
            }
            guard residual == 0 else { throw PayCalculationError.invalidRoundingInput }
            for position in indices.indices {
                result[indices[position]] = replacing(
                    source[indices[position]], amount: allocated[position])
            }
        }
        return result
    }

    private static func replacing(_ part: PayComponent, amount: Money) -> PayComponent {
        PayComponent(
            id: part.id, category: part.category, workIntervalID: part.workIntervalID,
            localDate: part.localDate, hours: part.hours, multiplier: part.multiplier,
            amount: amount, explanation: part.explanation, ruleKeys: part.ruleKeys,
            baseRate: part.baseRate, appliedAgreement: part.appliedAgreement,
            unroundedAmount: part.amount)
    }
}
