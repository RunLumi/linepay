import Foundation
import LinePayDomain

struct AuditHourFinding: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let expected: Decimal
    let paid: Decimal
    var differs: Bool { expected != paid }
}

/// One verdict contract for live screens, frozen history, and exported reports.
/// Blank fields are unverified, never implicit zero. A matching total is not a full audit.
struct AuditAssessment: Sendable {
    let status: AuditDisplayStatus
    let explanation: String
    let hours: [AuditHourFinding]

    static func evaluate(
        calculation: CalculationResult?, paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?
    ) -> AuditAssessment {
        guard let paystub else {
            return Self(
                status: .notAudited, explanation: "No paycheck has been confirmed.", hours: [])
        }
        guard let calculation, let reconciliation,
            reconciliation.expectedGross == calculation.total,
            reconciliation.actualGross == paystub.grossPay,
            !calculation.components.isEmpty
        else {
            return Self(
                status: .needsReview,
                explanation:
                    "Confirm the recorded work and re-run the audit. A missing or outdated calculation is not zero pay.",
                hours: [])
        }
        let paidAmounts = [
            paystub.grossPay, paystub.regularPay, paystub.overtimePay,
            paystub.doubleTimePay, paystub.calloutPay, paystub.perDiemPay,
        ].compactMap { $0 }
        guard paidAmounts.allSatisfy({ $0.currencyCode == calculation.total.currencyCode }) else {
            return Self(
                status: .needsReview,
                explanation:
                    "The confirmed amounts use different currencies and cannot be compared.",
                hours: [])
        }
        let hours = hourFindings(calculation: calculation, paystub: paystub)
        let findings = moneyFindings(calculation: calculation, paystub: paystub)
        let details = findings.filter { $0.id != "gross" }
        let conflicts =
            details.filter { $0.difference.amount != 0 }.count
            + hours.filter(\.differs).count
        if conflicts > 0 {
            let grossNote =
                reconciliation.direction == .matches
                ? "The gross total matches, but " : "The gross total and "
            return Self(
                status: .needsReview,
                explanation: grossNote
                    + "confirmed pay or hour details differ. Review the items below; offsetting differences do not cancel an audit finding.",
                hours: hours)
        }
        let scope =
            "Only entered pay and hour details were checked. Blank fields, deductions, and unsupported agreement rules are not verified."
        switch reconciliation.direction {
        case .matches:
            let grossOnly = details.isEmpty && hours.isEmpty
            return Self(
                status: grossOnly ? .grossMatches : .matches,
                explanation: grossOnly
                    ? "Only the gross total was compared. Pay components and hours have not been verified."
                    : scope,
                hours: hours)
        case .possibleUnderpayment:
            return Self(status: .possibleShortfall, explanation: scope, hours: hours)
        case .possibleOverpayment:
            return Self(status: .possibleOverpayment, explanation: scope, hours: hours)
        }
    }

    private static func hourFindings(
        calculation: CalculationResult, paystub: ConfirmedPaystub
    ) -> [AuditHourFinding] {
        let worked = calculation.components.filter { $0.category == .workedHours }
        let buckets: [(String, String, Decimal?, (Decimal) -> Bool)] = [
            ("regular-hours", "Regular worked hours", paystub.regularHours, { $0 == 1 }),
            (
                "overtime-hours", "Overtime worked hours", paystub.overtimeHours,
                { $0 > 1 && $0 < 2 }
            ),
            ("double-time-hours", "Double-time worked hours", paystub.doubleTimeHours, { $0 >= 2 }),
        ]
        return buckets.compactMap { id, title, paid, accepts in
            guard let paid else { return nil }
            let expected = worked.filter { accepts($0.multiplier ?? 1) }
                .reduce(Decimal(0)) { $0 + ($1.hours ?? 0) }
            return AuditHourFinding(id: id, title: title, expected: expected, paid: paid)
        }
    }
    static func moneyFindings(
        calculation: CalculationResult,
        paystub: ConfirmedPaystub
    ) -> [AuditFinding] {
        var findings: [AuditFinding] = []
        appendFinding(
            id: "gross",
            title: "Gross pay",
            expected: calculation.total,
            paid: paystub.grossPay,
            explanation:
                "Expected gross from your confirmed work and rules compared with confirmed paystub gross.",
            to: &findings
        )

        let expectedRegular = aggregate(
            calculation: calculation,
            where: {
                $0.category == .workedHours && ($0.multiplier ?? 1) <= 1
            }
        )
        let expectedOvertime = aggregate(
            calculation: calculation,
            where: {
                let multiplier = $0.multiplier ?? 1
                return $0.category == .workedHours && multiplier > 1 && multiplier < 2
            }
        )
        let expectedDoubleTime = aggregate(
            calculation: calculation,
            where: {
                $0.category == .workedHours && ($0.multiplier ?? 1) >= 2
            }
        )
        let expectedCallout = aggregate(
            calculation: calculation,
            where: { $0.category == .calloutGuarantee }
        )
        let expectedPerDiem = aggregate(
            calculation: calculation,
            where: { $0.category == .perDiem }
        )

        if let paid = paystub.regularPay {
            appendFinding(
                id: "regular",
                title: "Regular pay",
                expected: expectedRegular,
                paid: paid,
                explanation:
                    "Worked-hour components at 1× compared with the confirmed regular-pay line.",
                to: &findings
            )
        }
        if let paid = paystub.overtimePay {
            appendFinding(
                id: "overtime",
                title: "Overtime pay",
                expected: expectedOvertime,
                paid: paid,
                explanation:
                    "Worked-hour components above 1× and below 2× compared with confirmed overtime pay.",
                to: &findings
            )
        }
        if let paid = paystub.doubleTimePay {
            appendFinding(
                id: "double-time",
                title: "Double-time pay",
                expected: expectedDoubleTime,
                paid: paid,
                explanation:
                    "Worked-hour components at 2× or higher compared with confirmed double-time pay.",
                to: &findings
            )
        }
        if let paid = paystub.calloutPay {
            appendFinding(
                id: "callout",
                title: "Callout guarantee",
                expected: expectedCallout,
                paid: paid,
                explanation:
                    "Derived callout-minimum entitlement compared with the confirmed paystub line.",
                to: &findings
            )
        }
        if let paid = paystub.perDiemPay {
            appendFinding(
                id: "per-diem",
                title: "Per diem",
                expected: expectedPerDiem,
                paid: paid,
                explanation:
                    "Expected flat per-diem components compared with the confirmed paystub amount.",
                to: &findings
            )
        }

        return findings
    }

    private static func aggregate(
        calculation: CalculationResult,
        where predicate: (PayComponent) -> Bool
    ) -> Money {
        let amount = calculation.components
            .filter(predicate)
            .reduce(Decimal.zero) { $0 + $1.amount.amount }
        return Money(amount: amount, currencyCode: calculation.total.currencyCode)
    }

    private static func appendFinding(
        id: String,
        title: String,
        expected: Money,
        paid: Money,
        explanation: String,
        to findings: inout [AuditFinding]
    ) {
        guard let difference = try? expected.subtracting(paid) else { return }
        findings.append(
            AuditFinding(
                id: id,
                title: title,
                expected: expected,
                paid: paid,
                difference: difference,
                explanation: explanation
            )
        )
    }

}
