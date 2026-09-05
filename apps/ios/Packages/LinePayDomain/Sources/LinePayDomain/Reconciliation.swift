import Foundation

public struct PaystubSummary: Codable, Hashable, Sendable {
    public let grossPay: Money

    public init(grossPay: Money) {
        self.grossPay = grossPay
    }
}

public enum ReconciliationDirection: String, Codable, Hashable, Sendable {
    case matches
    case possibleUnderpayment
    case possibleOverpayment
}

public struct ReconciliationResult: Codable, Hashable, Sendable {
    public let expectedGross: Money
    public let actualGross: Money
    public let difference: Money
    public let direction: ReconciliationDirection

    public init(
        expectedGross: Money,
        actualGross: Money,
        difference: Money,
        direction: ReconciliationDirection
    ) {
        self.expectedGross = expectedGross
        self.actualGross = actualGross
        self.difference = difference
        self.direction = direction
    }
}

public struct PayReconciler: Sendable {
    public init() {}

    public func reconcile(
        expected: CalculationResult,
        paystub: PaystubSummary,
        rounding: MoneyRoundingRule = MoneyRoundingRule()
    ) throws -> ReconciliationResult {
        let difference = try expected.total
            .subtracting(paystub.grossPay)
            .rounded(using: rounding)

        let direction: ReconciliationDirection
        if difference.amount == 0 {
            direction = .matches
        } else if difference.amount > 0 {
            direction = .possibleUnderpayment
        } else {
            direction = .possibleOverpayment
        }

        return ReconciliationResult(
            expectedGross: expected.total,
            actualGross: paystub.grossPay,
            difference: difference,
            direction: direction
        )
    }
}
