import Foundation

/// The deliberately narrow applicability envelope admitted by the weekly reference layer.
public enum WeeklyOvertimeApplicability: String, Codable, Hashable, Sendable {
    case coveredNonexemptHourly
    case unknown
}

public enum WeeklyRemunerationKind: String, Codable, Hashable, Sendable {
    case straightTime
    case includableBonus
    case excludedCash
    case extraPremium
}

public enum WeeklyPremiumCredit: String, Codable, Hashable, Sendable {
    case notApplicable
    case eligibleExtraPremium
    case ineligible
    case unknown
}

public struct WeeklyOvertimeRule: Codable, Hashable, Sendable {
    public let workweekStart: Weekday
    public let applicability: WeeklyOvertimeApplicability
    public let thresholdHours: Decimal

    public init(
        workweekStart: Weekday,
        applicability: WeeklyOvertimeApplicability,
        thresholdHours: Decimal = 40
    ) throws {
        guard thresholdHours == 40 else {
            throw WeeklyRegularRateError.unsupportedThreshold(thresholdHours)
        }
        self.workweekStart = workweekStart
        self.applicability = applicability
        self.thresholdHours = thresholdHours
    }
}

public struct WeeklyWorkFact: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let payPeriodID: UUID?
    public let hours: Decimal
    public let straightRate: Money
    public let qualifiesForWeeklyOvertime: Bool

    public init(
        id: UUID = UUID(), payPeriodID: UUID? = nil, hours: Decimal, straightRate: Money,
        qualifiesForWeeklyOvertime: Bool = true
    ) throws {
        guard hours >= 0, !hours.isNaN, !straightRate.amount.isNaN,
            straightRate.amount >= 0
        else { throw WeeklyRegularRateError.invalidWorkFact(id) }
        self.id = id
        self.payPeriodID = payPeriodID
        self.hours = hours
        self.straightRate = straightRate
        self.qualifiesForWeeklyOvertime = qualifiesForWeeklyOvertime
    }

    public var straightTimeAmount: Money {
        straightRate.multiplied(by: hours)
    }
}

public struct WeeklyRemunerationFact: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let amount: Money
    public let kind: WeeklyRemunerationKind
    public let premiumCredit: WeeklyPremiumCredit

    public init(
        id: UUID = UUID(), amount: Money, kind: WeeklyRemunerationKind,
        premiumCredit: WeeklyPremiumCredit = .notApplicable
    ) throws {
        guard !amount.amount.isNaN, amount.amount >= 0 else {
            throw WeeklyRegularRateError.invalidRemunerationFact(id)
        }
        if kind == .extraPremium {
            guard premiumCredit != .notApplicable else {
                throw WeeklyRegularRateError.invalidCreditClassification(id)
            }
        } else if premiumCredit != .notApplicable {
            throw WeeklyRegularRateError.invalidCreditClassification(id)
        }
        self.id = id
        self.amount = amount
        self.kind = kind
        self.premiumCredit = premiumCredit
    }

    var isIncludable: Bool {
        kind == .straightTime || kind == .includableBonus
    }
}

public struct WeeklyRegularRateInput: Codable, Hashable, Sendable {
    public let workweekID: UUID
    public let weekStart: LocalDate
    public let workweekStart: Weekday
    public let completeWorkweek: Bool
    public let applicability: WeeklyOvertimeApplicability
    public let thresholdHours: Decimal
    public let work: [WeeklyWorkFact]
    public let remuneration: [WeeklyRemunerationFact]
    public let rounding: MoneyRoundingRule

    public init(
        workweekID: UUID = UUID(), weekStart: LocalDate, workweekStart: Weekday,
        completeWorkweek: Bool, applicability: WeeklyOvertimeApplicability,
        thresholdHours: Decimal = 40, work: [WeeklyWorkFact],
        remuneration: [WeeklyRemunerationFact], rounding: MoneyRoundingRule = MoneyRoundingRule()
    ) throws {
        guard thresholdHours == 40 else {
            throw WeeklyRegularRateError.unsupportedThreshold(thresholdHours)
        }
        guard Set(work.map(\.id)).count == work.count,
            Set(remuneration.map(\.id)).count == remuneration.count
        else { throw WeeklyRegularRateError.duplicateFactID }
        self.workweekID = workweekID
        self.weekStart = weekStart
        self.workweekStart = workweekStart
        self.completeWorkweek = completeWorkweek
        self.applicability = applicability
        self.thresholdHours = thresholdHours
        self.work = work
        self.remuneration = remuneration
        self.rounding = rounding
    }
}

public struct WeeklyPremiumAllocation: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let payPeriodID: UUID?
    public let amount: Money
    public let basis: Money

    public init(id: UUID = UUID(), payPeriodID: UUID?, amount: Money, basis: Money) {
        self.id = id
        self.payPeriodID = payPeriodID
        self.amount = amount
        self.basis = basis
    }
}

public struct WeeklyRegularRateResult: Codable, Hashable, Sendable {
    public let workweekID: UUID
    public let weekStart: LocalDate
    public let workweekStart: Weekday
    public let qualifyingHours: Decimal
    public let includableRemuneration: Money
    public let regularRate: Money?
    public let overtimeHours: Decimal
    public let statutoryAdditionalPremium: Money
    public let eligibleExtraPremiumCredit: Money
    public let remainingAdditionalPremium: Money
    public let cashRemuneration: Money
    public let expectedCash: Money
    public let allocations: [WeeklyPremiumAllocation]
    public let engineVersion: String

    public var explanation: String {
        "Restricted weekly regular-rate calculation for a complete covered/nonexempt hourly workweek; applicability and source scope remain explicit."
    }
}

public struct WeeklyRegularRateCalculator: Sendable {
    public init() {}

    public func calculate(_ input: WeeklyRegularRateInput) throws -> WeeklyRegularRateResult {
        guard input.completeWorkweek else { throw WeeklyRegularRateError.incompleteWorkweek }
        guard input.applicability == .coveredNonexemptHourly else {
            throw WeeklyRegularRateError.applicabilityUnknown
        }

        let currencies = Set(
            input.work.map(\.straightRate.currencyCode)
                + input.remuneration.map(\.amount.currencyCode)
        )
        guard currencies.count == 1, let currency = currencies.first else {
            throw WeeklyRegularRateError.currencyMismatch
        }

        let qualifyingHours = input.work.reduce(Decimal.zero) {
            $0 + ($1.qualifiesForWeeklyOvertime ? $1.hours : 0)
        }
        let includable = input.remuneration.filter(\.isIncludable).reduce(Decimal.zero) {
            $0 + $1.amount.amount
        }
        let cash = input.remuneration.reduce(Decimal.zero) { $0 + $1.amount.amount }
        let eligibleCredit = input.remuneration.filter {
            $0.premiumCredit == .eligibleExtraPremium
        }.reduce(Decimal.zero) { $0 + $1.amount.amount }
        guard qualifyingHours > 0 || includable == 0 else {
            throw WeeklyRegularRateError.remunerationWithoutQualifyingHours
        }

        let overtimeHours = max(Decimal.zero, qualifyingHours - input.thresholdHours)
        let regularRate = qualifyingHours > 0 ? includable / qualifyingHours : nil
        let statutory = (regularRate ?? 0) * Decimal(string: "0.5")! * overtimeHours
        let remaining = max(Decimal.zero, statutory - eligibleCredit)
        let rounding = input.rounding
        let statutoryMoney = Money(amount: statutory, currencyCode: currency).rounded(
            using: rounding)
        let creditMoney = Money(amount: eligibleCredit, currencyCode: currency).rounded(
            using: rounding)
        let remainingMoney = Money(amount: remaining, currencyCode: currency).rounded(
            using: rounding)
        let cashMoney = Money(amount: cash, currencyCode: currency).rounded(using: rounding)
        let rateMoney = regularRate.map {
            Money(amount: $0, currencyCode: currency).rounded(using: rounding)
        }
        let allocations = allocate(
            remaining: remainingMoney, work: input.work, currency: currency, rounding: rounding)
        let expectedCash = Money(
            amount: cashMoney.amount + remainingMoney.amount, currencyCode: currency)

        return WeeklyRegularRateResult(
            workweekID: input.workweekID, weekStart: input.weekStart,
            workweekStart: input.workweekStart, qualifyingHours: qualifyingHours,
            includableRemuneration: Money(amount: includable, currencyCode: currency),
            regularRate: rateMoney, overtimeHours: overtimeHours,
            statutoryAdditionalPremium: statutoryMoney,
            eligibleExtraPremiumCredit: creditMoney,
            remainingAdditionalPremium: remainingMoney, cashRemuneration: cashMoney,
            expectedCash: expectedCash, allocations: allocations,
            engineVersion: "linepay.weekly-regular-rate/1")
    }

    private func allocate(
        remaining: Money, work: [WeeklyWorkFact], currency: String,
        rounding: MoneyRoundingRule
    ) -> [WeeklyPremiumAllocation] {
        guard remaining.amount > 0 else { return [] }
        var bases: [UUID?: Decimal] = [:]
        for fact in work where fact.qualifiesForWeeklyOvertime && fact.hours > 0 {
            bases[fact.payPeriodID, default: 0] += fact.straightTimeAmount.amount
        }
        if bases.values.reduce(Decimal.zero, +) == 0 { return [] }
        let total = bases.values.reduce(Decimal.zero, +)
        let floorRule = MoneyRoundingRule(scale: rounding.scale, mode: .down, scope: .payCategory)
        var allocations = bases.map { key, basis in
            WeeklyPremiumAllocation(
                payPeriodID: key,
                amount: Money(
                    amount: remaining.amount * basis / total, currencyCode: currency
                )
                .rounded(using: floorRule),
                basis: Money(amount: basis, currencyCode: currency))
        }
        let target = remaining.rounded(using: rounding).amount
        var residual = target - allocations.reduce(Decimal.zero) { $0 + $1.amount.amount }
        let unit = Decimal(sign: .plus, exponent: -rounding.scale, significand: 1)
        allocations.sort { ($0.payPeriodID?.uuidString ?? "") < ($1.payPeriodID?.uuidString ?? "") }
        for index in allocations.indices where residual >= unit {
            let item = allocations[index]
            allocations[index] = WeeklyPremiumAllocation(
                id: item.id, payPeriodID: item.payPeriodID,
                amount: Money(amount: item.amount.amount + unit, currencyCode: currency),
                basis: item.basis)
            residual -= unit
        }
        return allocations
    }
}

public enum WeeklyRegularRateError: Error, Equatable, LocalizedError, Sendable {
    case incompleteWorkweek
    case applicabilityUnknown
    case unsupportedThreshold(Decimal)
    case duplicateFactID
    case invalidWorkFact(UUID)
    case invalidRemunerationFact(UUID)
    case invalidCreditClassification(UUID)
    case currencyMismatch
    case remunerationWithoutQualifyingHours

    public var errorDescription: String? {
        switch self {
        case .incompleteWorkweek:
            "The selected workweek is not complete. Confirm all work in this week before calculating."
        case .applicabilityUnknown:
            "Weekly overtime applicability or historical rule scope is unknown. Review the pay profile and stored periods."
        case .unsupportedThreshold:
            "Only a 40-hour weekly threshold is supported."
        case .duplicateFactID:
            "The weekly work or remuneration facts contain a duplicate identity."
        case .invalidWorkFact:
            "A weekly work fact is invalid. Review the recorded hours and rate."
        case .invalidRemunerationFact:
            "A weekly remuneration fact is invalid. Review the recorded amount."
        case .invalidCreditClassification:
            "An extra-premium credit classification is invalid. Review the payment type and credit status."
        case .currencyMismatch:
            "The weekly work and remuneration use different currencies."
        case .remunerationWithoutQualifyingHours:
            "Remuneration was provided without qualifying work hours. Review the workweek inputs."
        }
    }
}
