import Foundation

public enum PaystubField: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case periodStart, periodEnd, grossPay
    case regularHours, regularPay, overtimeHours, overtimePay
    case doubleTimeHours, doubleTimePay, calloutPay, perDiemPay
    public var id: String { rawValue }
    public var isHours: Bool {
        [.regularHours, .overtimeHours, .doubleTimeHours].contains(self)
    }
    public var isDate: Bool { self == .periodStart || self == .periodEnd }
}

public enum PaystubGrossBasis: String, CaseIterable, Codable, Hashable, Sendable {
    case unconfirmed, wagesOnly, wagesAndPerDiem
}

public enum PaystubLineLayout: String, CaseIterable, Codable, Hashable, Sendable {
    case unconfirmed, fullRateBuckets, basePlusPremium
}

public enum PaystubHoursBasis: String, CaseIterable, Codable, Hashable, Sendable {
    case unconfirmed, actualWork, paidEquivalents
}

public enum PaystubGuaranteeLayout: String, CaseIterable, Codable, Hashable, Sendable {
    case unconfirmed, separateLine, includedInHourlyLines
}

public enum PaycheckVerdict: String, Codable, Hashable, Sendable {
    case matches, possibleShortfall, possibleOverpayment, needsReview, notComparable
}

public enum ComparisonScope: String, Codable, Hashable, Sendable {
    case grossOnly, confirmedLines
}

public enum ComparisonUnit: String, Codable, Hashable, Sendable {
    case money, hours
}

public struct PaycheckComparison: Codable, Hashable, Sendable, Identifiable {
    public var id: String { field.rawValue }
    public let field: PaystubField
    public let expected: Decimal
    public let paid: Decimal
    public let difference: Decimal
    public let unit: ComparisonUnit
    public let currencyCode: String
    public let componentIDs: [UUID]
    public var differs: Bool { difference != 0 }
}

public struct PaycheckFacts: Hashable, Sendable {
    public let grossPay: Money
    public var hasCompleteWork: Bool
    public var hasCompleteEarningsLines: Bool
    public var amounts: [PaystubField: Money]
    public var hours: [PaystubField: Decimal]
    public var grossBasis: PaystubGrossBasis
    public var lineLayout: PaystubLineLayout
    public var hoursBasis: PaystubHoursBasis
    public var guaranteeLayout: PaystubGuaranteeLayout
    public var hasUnreviewedFields: Bool
    public var hasUnsupportedRules: Bool

    public init(
        hasCompleteWork: Bool = false, grossPay: Money, amounts: [PaystubField: Money] = [:],
        hours: [PaystubField: Decimal] = [:], grossBasis: PaystubGrossBasis,
        lineLayout: PaystubLineLayout = .unconfirmed,
        hoursBasis: PaystubHoursBasis = .unconfirmed,
        guaranteeLayout: PaystubGuaranteeLayout = .unconfirmed,
        hasUnreviewedFields: Bool = false, hasUnsupportedRules: Bool = false,
        hasCompleteEarningsLines: Bool = false
    ) {
        self.grossPay = grossPay
        self.hasCompleteWork = hasCompleteWork
        self.hasCompleteEarningsLines = hasCompleteEarningsLines
        self.amounts = amounts
        self.hours = hours
        self.grossBasis = grossBasis
        self.lineLayout = lineLayout
        self.hoursBasis = hoursBasis
        self.guaranteeLayout = guaranteeLayout
        self.hasUnreviewedFields = hasUnreviewedFields
        self.hasUnsupportedRules = hasUnsupportedRules
    }
}

/// Persist this with the confirmed facts. Reopening an old audit must not recompute its verdict.
public struct PaycheckAssessment: Codable, Hashable, Sendable {
    public let engineVersion: Int
    public let verdict: PaycheckVerdict
    public let scope: ComparisonScope
    public let expectedGross: Money?
    public let paidGross: Money
    public let difference: Money?
    public let comparisons: [PaycheckComparison]
    public let reviewReasons: [String]
    public let scopeNotes: [String]
}

public struct PaycheckAssessor: Sendable {
    public init() {}

    /// Records paycheck facts without inventing an expected amount when the saved work
    /// cannot be calculated safely. The result is intentionally not comparable.
    public func assessWithoutCalculation(
        agreement: AgreementSnapshot, facts: PaycheckFacts, reason: String
    ) throws -> PaycheckAssessment {
        let currency = agreement.hourlyRate.currencyCode
        guard facts.grossPay.currencyCode == currency,
            facts.amounts.values.allSatisfy({ $0.currencyCode == currency })
        else { throw PaycheckAssessmentError.currencyMismatch }
        guard !facts.grossPay.amount.isNaN, facts.grossPay.amount >= 0,
            facts.amounts.values.allSatisfy({ !$0.amount.isNaN && $0.amount >= 0 }),
            facts.hours.values.allSatisfy({ !$0.isNaN && $0 >= 0 })
        else { throw PaycheckAssessmentError.invalidFact }
        return PaycheckAssessment(
            engineVersion: 3, verdict: .notComparable, scope: .grossOnly,
            expectedGross: nil, paidGross: facts.grossPay, difference: nil,
            comparisons: [],
            reviewReasons: [reason],
            scopeNotes: [
                "The saved work and rules could not produce an expected amount. Confirm the missing rule or work fact before comparing this paycheck."
            ])
    }

    public func assess(
        calculation: CalculationResult, agreement: AgreementSnapshot, facts: PaycheckFacts
    ) throws -> PaycheckAssessment {
        let currency = agreement.hourlyRate.currencyCode
        guard facts.grossPay.currencyCode == currency,
            facts.amounts.values.allSatisfy({ $0.currencyCode == currency })
        else { throw PaycheckAssessmentError.currencyMismatch }
        guard !facts.grossPay.amount.isNaN, facts.grossPay.amount >= 0,
            facts.amounts.values.allSatisfy({ !$0.amount.isNaN && $0.amount >= 0 }),
            facts.hours.values.allSatisfy({ !$0.isNaN && $0 >= 0 })
        else { throw PaycheckAssessmentError.invalidFact }
        let wageComponents = calculation.components.filter { $0.category != .perDiem }
        let allowances = calculation.components.filter { $0.category == .perDiem }
        let guarantees = calculation.components.filter { $0.category == .calloutGuarantee }
        let wages = sum(wageComponents, currency: currency)
        var notes = [
            "Only the work and rules you confirmed are covered. This is not a legal finding."
        ]
        var reasons: [String] = []
        var comparisons: [PaycheckComparison] = []
        let expectedGross: Money?
        if !facts.hasCompleteWork {
            expectedGross = nil
            reasons.append(
                "Confirm that all work for this paycheck period is recorded before comparing the full paycheck."
            )
        } else {
            switch facts.grossBasis {
            case .unconfirmed:
                expectedGross = nil
                reasons.append(
                    "Confirm whether the paystub gross includes per diem before comparing totals.")
            case .wagesOnly:
                expectedGross = wages
                if !allowances.isEmpty {
                    notes.append("Per diem is excluded from this gross-wage comparison.")
                }
            case .wagesAndPerDiem:
                expectedGross = calculation.total
                notes.append(
                    "You confirmed that this gross figure includes the per diem shown in the ledger."
                )
            }
        }
        if let expectedGross {
            comparisons.append(
                comparison(
                    .grossPay, expected: expectedGross.amount, paid: facts.grossPay.amount,
                    unit: .money, currency: currency,
                    components: facts.grossBasis == .wagesOnly
                        ? wageComponents : calculation.components, rounding: agreement.rounding
                ))
        }
        if (calculation.agreementSnapshots ?? [agreement]).contains(where: {
            $0.rounding.scope == .legacySegments
        }) {
            reasons.append(
                "This estimate uses legacy segment rounding. Confirm a supported rounding policy before treating a new audit as a clean match. Saved earlier audits are unchanged."
            )
        }
        if facts.hasUnsupportedRules {
            reasons.append(
                "An agreement rule is not represented. The expected amount may be incomplete.")
        }
        if facts.hasUnreviewedFields {
            reasons.append(
                "Some source fields are still unconfirmed; they were not used as paid facts.")
        }

        if let paid = facts.amounts[.perDiemPay] {
            comparisons.append(
                comparison(
                    .perDiemPay, expected: sum(allowances, currency: currency).amount,
                    paid: paid.amount, unit: .money, currency: currency, components: allowances,
                    rounding: agreement.rounding
                ))
        } else if !allowances.isEmpty {
            notes.append("Per diem has not been checked as a separate paystub line.")
        }

        let hasHourlyFacts =
            facts.amounts.keys.contains(where: {
                [.regularPay, .overtimePay, .doubleTimePay, .calloutPay].contains($0)
            }) || !facts.hours.isEmpty
        let guaranteeMappingKnown = guarantees.isEmpty || facts.guaranteeLayout != .unconfirmed
        if hasHourlyFacts && !guaranteeMappingKnown {
            reasons.append(
                "Confirm where the paystub includes guaranteed callout pay before mapping hourly lines."
            )
        }
        let hasUnusualMultiplier = wageComponents.contains {
            ![Decimal(1), Decimal(15) / 10, Decimal(2)].contains($0.multiplier ?? 1)
        }
        if hasHourlyFacts && hasUnusualMultiplier {
            reasons.append(
                "This ledger has a multiplier other than 1x, 1.5x or 2x. Its hourly paystub lines need manual mapping."
            )
        }
        if hasHourlyFacts && facts.lineLayout == .unconfirmed {
            reasons.append(
                "Confirm full-rate versus premium-only paystub lines before comparing components.")
        }
        if hasHourlyFacts && guaranteeMappingKnown && !hasUnusualMultiplier
            && facts.lineLayout != .unconfirmed
        {
            let included = wageComponents.filter {
                $0.category == .workedHours || facts.guaranteeLayout == .includedInHourlyLines
            }
            for (field, multiplier) in [
                (PaystubField.regularPay, Decimal(1)),
                (.overtimePay, Decimal(15) / 10), (.doubleTimePay, Decimal(2)),
            ] {
                let selected = included.filter {
                    (facts.lineLayout == .basePlusPremium && field == .regularPay)
                        || ($0.multiplier ?? 1) == multiplier
                }
                if let paid = facts.amounts[field] {
                    let expected: Decimal
                    if facts.lineLayout == .fullRateBuckets {
                        expected = selected.reduce(0) { $0 + $1.amount.amount }
                    } else {
                        let base = normalizedBase(
                            selected, calculation: calculation, agreement: agreement)
                        expected =
                            field == .regularPay
                            ? base
                            : selected.reduce(0) { $0 + $1.amount.amount } - base
                    }
                    comparisons.append(
                        comparison(
                            field, expected: expected, paid: paid.amount, unit: .money,
                            currency: currency, components: selected, rounding: agreement.rounding
                        ))
                }
            }
            if let paid = facts.amounts[.calloutPay], facts.guaranteeLayout == .separateLine {
                comparisons.append(
                    comparison(
                        .calloutPay, expected: sum(guarantees, currency: currency).amount,
                        paid: paid.amount, unit: .money, currency: currency, components: guarantees,
                        rounding: agreement.rounding
                    ))
            } else if facts.amounts[.calloutPay] != nil {
                reasons.append(
                    "A separate callout amount was entered, but the selected layout includes it in hourly lines."
                )
            }
            if !facts.hours.isEmpty && facts.hoursBasis == .unconfirmed {
                reasons.append(
                    "Confirm whether paystub hours are actual worked hours or include guaranteed hours."
                )
            } else if facts.hoursBasis != .unconfirmed {
                let hourComponents =
                    facts.hoursBasis == .actualWork
                    ? included.filter { $0.category == .workedHours } : included
                for (field, multiplier) in [
                    (PaystubField.regularHours, Decimal(1)),
                    (.overtimeHours, Decimal(15) / 10), (.doubleTimeHours, Decimal(2)),
                ] {
                    guard let paid = facts.hours[field] else { continue }
                    let selected = hourComponents.filter {
                        (facts.lineLayout == .basePlusPremium && field == .regularHours)
                            || ($0.multiplier ?? 1) == multiplier
                    }
                    comparisons.append(
                        comparison(
                            field, expected: selected.reduce(0) { $0 + ($1.hours ?? 0) },
                            paid: paid, unit: .hours, currency: currency, components: selected,
                            rounding: MoneyRoundingRule(scale: 4)
                        ))
                }
            }
        }
        // Validate paid evidence against itself before drawing a directional conclusion.
        // Optional absent lines are unknown, not zero. Only an explicitly exhaustive set
        // requires equality; a known nonnegative subtotal exceeding gross is inconsistent.
        if facts.grossBasis != .unconfirmed && facts.lineLayout != .unconfirmed {
            var fields: [PaystubField] = [.regularPay, .overtimePay, .doubleTimePay]
            if facts.guaranteeLayout == .separateLine { fields.append(.calloutPay) }
            if facts.grossBasis == .wagesAndPerDiem { fields.append(.perDiemPay) }
            let entered = fields.compactMap { field in facts.amounts[field].map { (field, $0) } }
            let subtotal = entered.reduce(Decimal.zero) { $0 + $1.1.amount }
            if !entered.isEmpty
                && (subtotal > facts.grossPay.amount
                    || (facts.hasCompleteEarningsLines && subtotal != facts.grossPay.amount))
            {
                reasons.append(
                    "Confirmed earnings lines conflict with gross pay. Review grossPay and "
                        + entered.map { $0.0.rawValue }.joined(separator: ", ")
                        + ". Missing adjustments or overlapping lines must be resolved before concluding pay is short or overpaid."
                )
            }
            if facts.hasCompleteEarningsLines && entered.isEmpty {
                reasons.append(
                    "No earnings lines were confirmed for the claimed complete breakdown.")
            }
        } else if facts.hasCompleteEarningsLines {
            reasons.append(
                "Confirm the earnings-line layout and gross basis before declaring the breakdown complete."
            )
        }
        if facts.hasCompleteEarningsLines && !guarantees.isEmpty
            && facts.guaranteeLayout == .unconfirmed
        {
            reasons.append("The complete breakdown needs the callout guarantee's line mapping.")
        }
        let scope: ComparisonScope =
            comparisons.contains { $0.field != .grossPay }
            ? .confirmedLines : .grossOnly
        notes.append(
            scope == .grossOnly
                ? "Gross total only. Hours and individual earnings lines were not verified."
                : "Only the listed confirmed lines were compared. A matching total can hide offsetting differences."
        )
        let grossDifference = comparisons.first { $0.field == .grossPay }?.difference
        let componentDifferences = comparisons.filter { $0.field != .grossPay && $0.differs }
        let verdict: PaycheckVerdict
        if expectedGross == nil {
            verdict = .notComparable
        } else if !reasons.isEmpty {
            verdict = .needsReview
        } else if grossDifference == 0 && !componentDifferences.isEmpty {
            verdict = .needsReview
            reasons.append(
                "Gross total matches, but confirmed components differ. Review the listed lines.")
        } else if let grossDifference, grossDifference > 0 {
            verdict = .possibleShortfall
        } else if let grossDifference, grossDifference < 0 {
            verdict = .possibleOverpayment
        } else {
            verdict = .matches
        }
        return PaycheckAssessment(
            engineVersion: 3, verdict: verdict, scope: scope,
            expectedGross: expectedGross, paidGross: facts.grossPay,
            difference: grossDifference.map { Money(amount: $0, currencyCode: currency) },
            comparisons: comparisons, reviewReasons: reasons, scopeNotes: notes
        )
    }

    /// For a premium-only statement, split each rounded gross bucket into base and extra.
    /// Summing those bases and extras reconstructs the same gross, including cent allocation.
    private func normalizedBase(
        _ selected: [PayComponent], calculation: CalculationResult, agreement: AgreementSnapshot
    ) -> Decimal {
        var groups: [PayComponentRounding.Key: Decimal] = [:]
        var result = Decimal.zero
        for part in selected {
            let snapshot =
                (calculation.agreementSnapshots ?? [agreement]).first {
                    AgreementReference($0) == part.appliedAgreement
                } ?? agreement
            let amount = (part.baseRate ?? part.appliedAgreement?.hourlyRate ?? snapshot.hourlyRate)
                .multiplied(by: part.hours ?? 0)
            if calculation.provenance == nil || snapshot.rounding.scope == .legacySegments {
                result += amount.rounded(using: snapshot.rounding).amount
            } else {
                let key = PayComponentRounding.Key(
                    category: part.category,
                    multiplier: part.multiplier, rule: snapshot.rounding,
                    currency: amount.currencyCode)
                groups[key, default: 0] += amount.amount
            }
        }
        for (key, amount) in groups {
            result +=
                Money(amount: amount, currencyCode: key.currency).rounded(using: key.rule).amount
        }
        return result
    }

    private func sum(_ components: [PayComponent], currency: String) -> Money {
        Money(amount: components.reduce(0) { $0 + $1.amount.amount }, currencyCode: currency)
    }

    private func comparison(
        _ field: PaystubField, expected: Decimal, paid: Decimal, unit: ComparisonUnit,
        currency: String, components: [PayComponent], rounding: MoneyRoundingRule
    ) -> PaycheckComparison {
        PaycheckComparison(
            field: field, expected: expected, paid: paid,
            difference: Money(amount: expected - paid, currencyCode: currency)
                .rounded(using: rounding).amount,
            unit: unit, currencyCode: currency, componentIDs: components.map(\.id)
        )
    }
}

public enum PaycheckAssessmentError: Error, Equatable, Sendable {
    case currencyMismatch, invalidFact
}

extension CalculationResult {
    public var expectedWages: Money {
        Money(
            amount: components.filter { $0.category != .perDiem }
                .reduce(0) { $0 + $1.amount.amount }, currencyCode: total.currencyCode)
    }
    public var expectedAllowances: Money {
        Money(
            amount: components.filter { $0.category == .perDiem }
                .reduce(0) { $0 + $1.amount.amount }, currencyCode: total.currencyCode)
    }
}
