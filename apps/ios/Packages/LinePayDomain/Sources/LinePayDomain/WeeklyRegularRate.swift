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
    public let workedSeconds: Int64?

    public init(
        id: UUID = UUID(), payPeriodID: UUID? = nil, hours: Decimal, straightRate: Money,
        qualifiesForWeeklyOvertime: Bool = true, workedSeconds: Int64? = nil
    ) throws {
        guard hours >= 0, !hours.isNaN, !straightRate.amount.isNaN,
            straightRate.amount >= 0
        else { throw WeeklyRegularRateError.invalidWorkFact(id) }
        self.id = id
        self.payPeriodID = payPeriodID
        self.hours = hours
        self.straightRate = straightRate
        self.qualifiesForWeeklyOvertime = qualifiesForWeeklyOvertime
        if let workedSeconds {
            guard workedSeconds >= 0, hours == Decimal(workedSeconds) / 3_600 else {
                throw WeeklyRegularRateError.invalidWorkFact(id)
            }
        }
        self.workedSeconds = workedSeconds
    }

    public var straightTimeAmount: Money {
        Money(amount: straightNumerator / 3_600, currencyCode: straightRate.currencyCode)
    }
    var seconds: Decimal { workedSeconds.map(Decimal.init) ?? hours * 3_600 }
    var straightNumerator: Decimal { straightRate.amount * seconds }
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
            || (kind == .extraPremium && premiumCredit == .ineligible)
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
    public let startEpochSeconds: Int64?
    public let timeZoneIdentifier: String?

    public init(
        workweekID: UUID = UUID(), weekStart: LocalDate, workweekStart: Weekday,
        completeWorkweek: Bool, applicability: WeeklyOvertimeApplicability,
        thresholdHours: Decimal = 40, work: [WeeklyWorkFact],
        remuneration: [WeeklyRemunerationFact], rounding: MoneyRoundingRule = MoneyRoundingRule(),
        startEpochSeconds: Int64? = nil, timeZoneIdentifier: String? = nil
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
        self.startEpochSeconds = startEpochSeconds
        self.timeZoneIdentifier = timeZoneIdentifier
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
    public let startEpochSeconds: Int64?
    public let endEpochSeconds: Int64?
    public let timeZoneIdentifier: String?

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
        // Codable bypasses validating initializers. Re-admit every fact at this public boundary.
        _ = try WeeklyRegularRateInput(
            workweekID: input.workweekID, weekStart: input.weekStart,
            workweekStart: input.workweekStart, completeWorkweek: input.completeWorkweek,
            applicability: input.applicability, thresholdHours: input.thresholdHours,
            work: input.work, remuneration: input.remuneration, rounding: input.rounding,
            startEpochSeconds: input.startEpochSeconds, timeZoneIdentifier: input.timeZoneIdentifier
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let day = input.weekStart
        guard (1...9999).contains(day.year),
            let date = calendar.date(
                from: DateComponents(year: day.year, month: day.month, day: day.day)),
            calendar.component(.year, from: date) == day.year,
            calendar.component(.month, from: date) == day.month,
            calendar.component(.day, from: date) == day.day,
            calendar.component(.weekday, from: date) == input.workweekStart.rawValue
        else { throw WeeklyRegularRateError.invalidWorkweek }
        if input.startEpochSeconds != nil || input.timeZoneIdentifier != nil {
            guard let epoch = input.startEpochSeconds,
                (-62_135_596_800...(253_402_300_799 - 604_800)).contains(epoch),
                let identifier = input.timeZoneIdentifier,
                let zone = TimeZone(identifier: identifier)
            else { throw WeeklyRegularRateError.invalidWorkweek }
            var local = Calendar(identifier: .gregorian)
            local.timeZone = zone
            let instant = Date(timeIntervalSince1970: TimeInterval(epoch))
            guard local.component(.year, from: instant) == day.year,
                local.component(.month, from: instant) == day.month,
                local.component(.day, from: instant) == day.day
            else { throw WeeklyRegularRateError.invalidWorkweek }
        }
        guard (0...8).contains(input.rounding.scale), input.rounding.scope == .payCategory else {
            throw WeeklyRegularRateError.invalidRounding
        }
        var recordedSeconds = Decimal.zero
        for fact in input.work {
            _ = try WeeklyWorkFact(
                id: fact.id, payPeriodID: fact.payPeriodID, hours: fact.hours,
                straightRate: fact.straightRate,
                qualifiesForWeeklyOvertime: fact.qualifiesForWeeklyOvertime,
                workedSeconds: fact.workedSeconds)
            guard fact.hours <= 168 else { throw WeeklyRegularRateError.workExceedsFixedWindow }
            var duration = fact.workedSeconds.map(Decimal.init) ?? .zero
            if fact.workedSeconds == nil {
                var hours = fact.hours
                var secondsPerHour = Decimal(3_600)
                guard NSDecimalMultiply(&duration, &hours, &secondsPerHour, .plain) == .noError
                else { throw WeeklyRegularRateError.arithmeticNotExact }
            }
            var previous = recordedSeconds
            guard NSDecimalAdd(&recordedSeconds, &previous, &duration, .plain) == .noError else {
                throw WeeklyRegularRateError.arithmeticNotExact
            }
            // Eligibility changes overtime counting, not actual time available in this window.
            guard duration <= 604_800, recordedSeconds <= 604_800
            else { throw WeeklyRegularRateError.workExceedsFixedWindow }
        }
        for fact in input.remuneration {
            _ = try WeeklyRemunerationFact(
                id: fact.id, amount: fact.amount, kind: fact.kind, premiumCredit: fact.premiumCredit
            )
            guard fact.premiumCredit != .unknown else {
                throw WeeklyRegularRateError.unknownPremiumCredit
            }
        }

        let currencies = Set(
            input.work.map(\.straightRate.currencyCode)
                + input.remuneration.map(\.amount.currencyCode)
        )
        guard currencies.count == 1, let currency = currencies.first else {
            throw WeeklyRegularRateError.currencyMismatch
        }
        guard currency.utf8.count == 3, currency.utf8.allSatisfy({ (65...90).contains($0) }) else {
            throw WeeklyRegularRateError.currencyMismatch
        }

        let qualifyingSeconds = input.work.reduce(Decimal.zero) {
            $0 + ($1.qualifiesForWeeklyOvertime ? $1.seconds : 0)
        }
        let qualifyingHours = qualifyingSeconds / 3_600
        let includable = input.remuneration.filter(\.isIncludable).reduce(Decimal.zero) {
            $0 + $1.amount.amount
        }
        let cash = input.remuneration.reduce(Decimal.zero) { $0 + $1.amount.amount }
        let eligibleCredit = input.remuneration.filter {
            $0.premiumCredit == .eligibleExtraPremium
        }.reduce(Decimal.zero) { $0 + $1.amount.amount }
        guard !qualifyingHours.isNaN, !includable.isNaN, !cash.isNaN, !eligibleCredit.isNaN else {
            throw WeeklyRegularRateError.arithmeticNotExact
        }
        guard qualifyingHours > 0 || includable == 0 else {
            throw WeeklyRegularRateError.remunerationWithoutQualifyingHours
        }

        let overtimeSeconds = max(Decimal.zero, qualifyingSeconds - input.thresholdHours * 3_600)
        let overtimeHours = overtimeSeconds / 3_600
        let regularRate = qualifyingHours > 0 ? includable / qualifyingHours : nil
        // Multiply before division: a rounded repeating rate must not decide a half-cent tie.
        let statutory =
            qualifyingSeconds > 0 ? includable * overtimeSeconds / (2 * qualifyingSeconds) : 0
        let remaining = max(Decimal.zero, statutory - eligibleCredit)
        guard !statutory.isNaN, !remaining.isNaN, regularRate.map({ !$0.isNaN }) ?? true else {
            throw WeeklyRegularRateError.arithmeticNotExact
        }
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
        let allocations = try allocate(
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
            engineVersion: "linepay.weekly-regular-rate/3",
            startEpochSeconds: input.startEpochSeconds,
            endEpochSeconds: input.startEpochSeconds.map { $0 + 604_800 },
            timeZoneIdentifier: input.timeZoneIdentifier)
    }

    private func allocate(
        remaining: Money, work: [WeeklyWorkFact], currency: String,
        rounding: MoneyRoundingRule
    ) throws -> [WeeklyPremiumAllocation] {
        guard remaining.amount > 0 else { return [] }
        var bases: [UUID?: Decimal] = [:]
        var identities: [UUID?: UUID] = [:]
        for fact in work where fact.qualifiesForWeeklyOvertime && fact.hours > 0 {
            bases[fact.payPeriodID, default: 0] += fact.straightNumerator
            if identities[fact.payPeriodID].map({ fact.id.uuidString < $0.uuidString }) ?? true {
                identities[fact.payPeriodID] = fact.id
            }
        }
        let total = bases.values.reduce(Decimal.zero, +)
        guard total > 0, !total.isNaN else { throw WeeklyRegularRateError.allocationUnavailable }
        let floorRule = MoneyRoundingRule(scale: rounding.scale, mode: .down, scope: .payCategory)
        var allocations = try bases.map { key, basis in
            guard let identity = identities[key] else {
                throw WeeklyRegularRateError.allocationUnavailable
            }
            return WeeklyPremiumAllocation(
                id: identity,
                payPeriodID: key,
                amount: Money(
                    amount: remaining.amount * basis / total, currencyCode: currency
                )
                .rounded(using: floorRule),
                basis: Money(amount: basis / 3_600, currencyCode: currency))
        }
        let target = remaining.rounded(using: rounding).amount
        var residual = target - allocations.reduce(Decimal.zero) { $0 + $1.amount.amount }
        let unit = Decimal(sign: .plus, exponent: -rounding.scale, significand: 1)
        allocations.sort { ($0.payPeriodID?.uuidString ?? "") < ($1.payPeriodID?.uuidString ?? "") }
        for index in allocations.indices where residual >= unit {
            let item = allocations[index]
            // A zero-weight group must stay zero, including when its identity sorts first.
            guard bases[item.payPeriodID, default: 0] > 0 else { continue }
            allocations[index] = WeeklyPremiumAllocation(
                id: item.id, payPeriodID: item.payPeriodID,
                amount: Money(amount: item.amount.amount + unit, currencyCode: currency),
                basis: item.basis)
            residual -= unit
        }
        guard residual == 0 else { throw WeeklyRegularRateError.arithmeticNotExact }
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
    case invalidWorkweek, invalidRounding, unknownPremiumCredit, arithmeticNotExact,
        allocationUnavailable
    case remunerationIncomplete
    case workExceedsFixedWindow
    case workweekBoundaryUnconfirmed

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
        case .invalidWorkweek:
            "Review the exact workweek start instant, local date and declared weekday. A calendar paycycle is not a workweek."
        case .invalidRounding:
            "Review the weekly rounding scale and pay-category policy."
        case .unknownPremiumCredit:
            "A premium's regular-rate and credit treatment is unknown. Classify it before calculating."
        case .arithmeticNotExact:
            "The weekly arithmetic cannot be represented safely. No approximate result was produced."
        case .allocationUnavailable:
            "The additional premium cannot be allocated from the confirmed straight-time basis. Review the work facts."
        case .remunerationIncomplete:
            "Confirm the whole week's straight-time remuneration and every other cash payment and classification before calculating."
        case .workweekBoundaryUnconfirmed:
            "Confirm the employer's exact recurring 168-hour workweek boundary before calculating."
        case .workExceedsFixedWindow:
            "Actual work cannot exceed the reviewed 168-hour window. Review all recorded work, including work that does not qualify for weekly overtime."
        }
    }
}
