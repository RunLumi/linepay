import Testing

@testable import LinePayDomain

@Test("Reconciliation reports exact match")
func reconciliationMatch() throws {
    let expected = CalculationResult(
        agreementID: "a",
        agreementVersion: "1",
        components: [],
        total: Money(amount: 100, currencyCode: "USD")
    )

    let result = try PayReconciler().reconcile(
        expected: expected,
        paystub: PaystubSummary(grossPay: Money(amount: 100, currencyCode: "USD"))
    )

    #expect(result.direction == .matches)
    #expect(result.difference.amount == 0)
}

@Test("Expected greater than actual is a possible underpayment")
func reconciliationUnderpayment() throws {
    let expected = CalculationResult(
        agreementID: "a",
        agreementVersion: "1",
        components: [],
        total: Money(amount: 427.40, currencyCode: "USD")
    )

    let result = try PayReconciler().reconcile(
        expected: expected,
        paystub: PaystubSummary(grossPay: Money(amount: 400, currencyCode: "USD"))
    )

    #expect(result.direction == .possibleUnderpayment)
    #expect(result.difference.amount == decimal("27.40"))
}

@Test("Actual greater than expected is a possible overpayment")
func reconciliationOverpayment() throws {
    let expected = CalculationResult(
        agreementID: "a",
        agreementVersion: "1",
        components: [],
        total: Money(amount: 400, currencyCode: "USD")
    )

    let result = try PayReconciler().reconcile(
        expected: expected,
        paystub: PaystubSummary(grossPay: Money(amount: 425, currencyCode: "USD"))
    )

    #expect(result.direction == .possibleOverpayment)
    #expect(result.difference.amount == decimal("-25.00"))
}

@Test("Reconciliation rejects different currencies")
func reconciliationCurrencyMismatch() throws {
    let expected = CalculationResult(
        agreementID: "a",
        agreementVersion: "1",
        components: [],
        total: Money(amount: 100, currencyCode: "USD")
    )

    #expect(throws: MoneyError.currencyMismatch(lhs: "USD", rhs: "CAD")) {
        try PayReconciler().reconcile(
            expected: expected,
            paystub: PaystubSummary(grossPay: Money(amount: 100, currencyCode: "CAD"))
        )
    }
}
