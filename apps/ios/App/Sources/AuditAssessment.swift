import LinePayDomain

/// Presentation validity around the saved pure-domain assessment. This does not calculate pay
/// or infer paycheck mappings; stale/legacy facts must be reviewed through the normal intake.
struct AuditAssessment {
    let status: AuditDisplayStatus
    let explanation: String
    let hours: [PaycheckComparison]
    let isCurrent: Bool
    var legacyScopeNote: String? = nil

    static func evaluate(
        calculation: CalculationResult?, paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?, requiresCalculationReview: Bool = false,
        requiresAssessmentReview: Bool = false, agreement: AgreementSnapshot? = nil
    ) -> AuditAssessment {
        guard let paystub else {
            return AuditAssessment(
                status: .notAudited, explanation: "No paycheck confirmed.", hours: [],
                isCurrent: false)
        }
        if requiresCalculationReview {
            return review(
                "Calculation precision changed. Re-run this check; earlier audit revisions are retained."
            )
        }
        if requiresAssessmentReview {
            return review(
                "Weekly comparison safeguards changed. Review this paycheck again; the earlier comparison and its amounts remain recorded."
            )
        }
        let amounts = [
            paystub.regularPay, paystub.overtimePay, paystub.doubleTimePay,
            paystub.calloutPay, paystub.perDiemPay,
        ].compactMap { $0 }
        guard amounts.allSatisfy({ $0.currencyCode == paystub.grossPay.currencyCode }) else {
            return review(
                "Confirmed lines use different currencies. Review the original before comparing.")
        }
        guard let calculation, let assessment = paystub.assessment,
            let confirmation = paystub.confirmation
        else {
            return review(
                "This audit needs an evidence-aware review with its recorded work and original facts."
            )
        }
        if assessment.verdict == .notComparable {
            return AuditAssessment(
                status: .notComparable,
                explanation: (assessment.reviewReasons + assessment.scopeNotes).joined(
                    separator: "\n"),
                hours: assessment.comparisons.filter { $0.unit == .hours }, isCurrent: true)
        }
        let expected =
            confirmation.grossBasis == .wagesOnly ? calculation.expectedWages : calculation.total
        guard let reconciliation, reconciliation.expectedGross == expected,
            reconciliation.actualGross == paystub.grossPay,
            assessment.expectedGross == expected, assessment.paidGross == paystub.grossPay,
            assessment.difference == reconciliation.difference
        else {
            return review(
                "Work, rules or calculation changed. Re-run the audit before relying on this comparison."
            )
        }
        let legacy = legacyWeeklyScopeNote(
            calculation: calculation, paystub: paystub, agreement: agreement)
        return AuditAssessment(
            status: .assessment(assessment),
            explanation: (assessment.reviewReasons + assessment.scopeNotes
                + [legacy].compactMap { $0 }).joined(separator: "\n"),
            hours: assessment.comparisons.filter { $0.unit == .hours }, isCurrent: true,
            legacyScopeNote: legacy)
    }

    static func legacyWeeklyScopeNote(
        calculation: CalculationResult?, paystub: ConfirmedPaystub?,
        agreement: AgreementSnapshot? = nil
    ) -> String? {
        guard let saved = paystub?.assessment,
            saved.engineVersion < PaycheckAssessor.currentEngineVersion,
            saved.expectedGross != nil,
            PaycheckAssessor.requiresWeeklyMappingReview(
                agreement: agreement, calculation: calculation)
        else { return nil }
        return
            "Earlier weekly comparison: values remain as recorded. That comparison did not record verified workweek-to-paycheck mapping. An explicit new review uses current safeguards and keeps the earlier check."
    }

    private static func review(_ reason: String) -> AuditAssessment {
        AuditAssessment(status: .needsReview, explanation: reason, hours: [], isCurrent: false)
    }
}
