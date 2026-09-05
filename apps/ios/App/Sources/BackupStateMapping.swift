import Foundation

extension AppPersistentState {
    var allEvidence: [PaystubEvidence] {
        let originals =
            [activePeriod?.paystub?.evidence, paystubDraft?.sourceEvidence]
            + history.map { $0.paystub?.evidence }
            + (activePeriod?.auditRevisions ?? []).map { $0.paystub.evidence }
            + history.flatMap { ($0.auditRevisions ?? []).map { $0.paystub.evidence } }
        return originals.compactMap { $0 }
    }

    /// Restore uses fresh physical filenames, without changing logical evidence or payroll facts.
    func replacingEvidence(_ replacements: [UUID: PaystubEvidence]) -> AppPersistentState {
        mappingEvidence { evidence in replacements[evidence.id] ?? evidence }
    }

    func removingEvidence(id: UUID) -> AppPersistentState {
        mappingEvidence { $0.id == id ? nil : $0 }
    }

    private func mappingEvidence(_ transform: (PaystubEvidence) -> PaystubEvidence?)
        -> AppPersistentState
    {
        var result = self
        if var active = result.activePeriod {
            active.paystub = active.paystub?.mappingEvidence(transform)
            active.auditRevisions = active.auditRevisions?.map { $0.mappingEvidence(transform) }
            result.activePeriod = active
        }
        if var draft = result.paystubDraft {
            let hadSource = draft.sourceEvidence != nil
            draft.sourceEvidence = draft.sourceEvidence.flatMap(transform)
            if hadSource && draft.sourceEvidence == nil {
                draft.suggestions = [:]
                draft.recognizedText = nil
            }
            result.paystubDraft = draft
        }
        result.history = history.map { period in
            CompletedPayPeriod(
                id: period.id, window: period.window, agreement: period.agreement,
                timeZoneIdentifier: period.timeZoneIdentifier, workEntries: period.workEntries,
                calculation: period.calculation,
                paystub: period.paystub?.mappingEvidence(transform),
                reconciliation: period.reconciliation,
                archivedEpochSeconds: period.archivedEpochSeconds,
                auditRevisions: period.auditRevisions?.map { $0.mappingEvidence(transform) },
                hasConsumedAuditAccess: period.hasConsumedAuditAccess
            )
        }
        return result
    }
}

extension AuditRevision {
    fileprivate func mappingEvidence(_ transform: (PaystubEvidence) -> PaystubEvidence?)
        -> AuditRevision
    {
        AuditRevision(
            id: id, window: window, agreement: agreement,
            timeZoneIdentifier: timeZoneIdentifier, workEntries: workEntries,
            calculation: calculation, paystub: paystub.mappingEvidence(transform),
            reconciliation: reconciliation)
    }
}

extension ConfirmedPaystub {
    fileprivate func mappingEvidence(_ transform: (PaystubEvidence) -> PaystubEvidence?)
        -> ConfirmedPaystub
    {
        let mapped = evidence.flatMap(transform)
        let reviewed = confirmation.map {
            PaystubConfirmation(
                grossBasis: $0.grossBasis, lineLayout: $0.lineLayout,
                hoursBasis: $0.hoursBasis, guaranteeLayout: $0.guaranteeLayout,
                reviewedFields: $0.reviewedFields,
                suggestions: evidence != nil && mapped == nil ? [:] : $0.suggestions,
                hasAdditionalUnmappedPay: $0.hasAdditionalUnmappedPay)
        }
        return ConfirmedPaystub(
            id: id, payPeriodStart: payPeriodStart, payPeriodEnd: payPeriodEnd,
            grossPay: grossPay, regularHours: regularHours, regularPay: regularPay,
            overtimeHours: overtimeHours, overtimePay: overtimePay,
            doubleTimeHours: doubleTimeHours, doubleTimePay: doubleTimePay,
            calloutPay: calloutPay, perDiemPay: perDiemPay, notes: notes,
            evidence: mapped, confirmedEpochSeconds: confirmedEpochSeconds,
            confirmation: reviewed, assessment: assessment
        )
    }
}
