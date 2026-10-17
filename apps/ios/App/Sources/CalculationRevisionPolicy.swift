import Foundation
import LinePayDomain

/// New calculation precision must not relabel a saved check or silently rewrite its ledger rows.
enum CalculationRevisionPolicy {
    private struct PriceKey: Hashable {
        let category: PayComponentCategory
        let workID: UUID?
        let date: LocalDate
        let multiplier: Decimal?
        let baseRate: Money?
        let reference: AgreementReference?
        let currency: String
    }

    static func requiresReview(saved: CalculationResult?, current: CalculationResult?) -> Bool {
        guard let saved, let current, saved.provenance != current.provenance else { return false }
        return prices(saved) != prices(current)
    }

    static func requiresAssessmentReview(
        saved: PaycheckAssessment?, agreement: AgreementSnapshot, calculation: CalculationResult?
    ) -> Bool {
        guard let saved, saved.engineVersion < PaycheckAssessor.currentEngineVersion,
            saved.expectedGross != nil
        else { return false }
        return PaycheckAssessor.requiresWeeklyMappingReview(
            agreement: agreement, calculation: calculation)
    }

    private static func prices(_ result: CalculationResult) -> [PriceKey: Decimal] {
        var values: [PriceKey: Decimal] = [:]
        for component in result.components {
            let key = PriceKey(
                category: component.category, workID: component.workIntervalID,
                date: component.localDate, multiplier: component.multiplier,
                baseRate: component.baseRate,
                reference: component.appliedAgreement, currency: component.amount.currencyCode)
            values[key, default: 0] += component.amount.amount
        }
        return values
    }
}
