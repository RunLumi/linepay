import Foundation

extension AppPersistentState {
    /// Restoring uses fresh physical filenames, without changing evidence identity or payroll facts.
    func replacingEvidence(_ replacements: [UUID: PaystubEvidence]) -> AppPersistentState {
        var result = self
        if var active = result.activePeriod {
            active.paystub = active.paystub?.replacingEvidence(replacements)
            result.activePeriod = active
        }
        result.history = history.map { period in
            CompletedPayPeriod(
                id: period.id, window: period.window, agreement: period.agreement,
                timeZoneIdentifier: period.timeZoneIdentifier, workEntries: period.workEntries,
                calculation: period.calculation,
                paystub: period.paystub?.replacingEvidence(replacements),
                reconciliation: period.reconciliation,
                archivedEpochSeconds: period.archivedEpochSeconds
            )
        }
        return result
    }
}

extension ConfirmedPaystub {
    fileprivate func replacingEvidence(_ replacements: [UUID: PaystubEvidence]) -> ConfirmedPaystub
    {
        ConfirmedPaystub(
            id: id, payPeriodStart: payPeriodStart, payPeriodEnd: payPeriodEnd,
            grossPay: grossPay, regularHours: regularHours, regularPay: regularPay,
            overtimeHours: overtimeHours, overtimePay: overtimePay,
            doubleTimeHours: doubleTimeHours, doubleTimePay: doubleTimePay,
            calloutPay: calloutPay, perDiemPay: perDiemPay, notes: notes,
            evidence: evidence.flatMap { replacements[$0.id] },
            confirmedEpochSeconds: confirmedEpochSeconds
        )
    }
}
