import Foundation

/// A worker-confirmed benefit expectation, never part of cash gross or a statutory fringe audit.
public enum BenefitKind: String, Codable, CaseIterable, Hashable, Sendable {
    case pension, annuity, healthAndWelfare, other
}

public enum BenefitContributionBasis: String, Codable, CaseIterable, Hashable, Sendable {
    case eligibleHour, eligibleDay, percentOfEligibleEarnings, fixedPeriod
}

/// End is exclusive. Dates and timezone describe the statement/work scope, not its deposit date.
public struct BenefitPeriod: Codable, Hashable, Sendable {
    public let start: LocalDate
    public let end: LocalDate
    public let timeZoneIdentifier: String

    public init(start: LocalDate, end: LocalDate, timeZoneIdentifier: String) throws {
        self.start = start
        self.end = end
        self.timeZoneIdentifier = timeZoneIdentifier
        try validate()
    }

    public func validate() throws {
        guard Self.valid(start), Self.valid(end), start < end,
            TimeZone(identifier: timeZoneIdentifier) != nil
        else { throw BenefitContributionError.invalidPeriod }
    }

    func contains(_ other: Self) -> Bool {
        timeZoneIdentifier == other.timeZoneIdentifier && start <= other.start && end >= other.end
    }

    private static func valid(_ date: LocalDate) -> Bool {
        guard (1...9999).contains(date.year) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard
            let instant = calendar.date(
                from: DateComponents(year: date.year, month: date.month, day: date.day))
        else { return false }
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        return parts.year == date.year && parts.month == date.month && parts.day == date.day
    }
}

/// Currency is explicit even for a percentage; no currency conversion or wage mapping is inferred.
public struct BenefitRuleSnapshot: Codable, Hashable, Sendable {
    public let id: UUID
    public let fundID: UUID
    public let version: String
    public let basis: BenefitContributionBasis
    public let rate: Decimal
    public let currencyCode: String
    public let effectivePeriod: BenefitPeriod
    public let sources: [AgreementSource]

    public init(
        id: UUID = UUID(), fundID: UUID, version: String, basis: BenefitContributionBasis,
        rate: Decimal,
        currencyCode: String, effectivePeriod: BenefitPeriod, sources: [AgreementSource] = []
    ) throws {
        self.id = id
        self.fundID = fundID
        self.version = version
        self.basis = basis
        self.rate = rate
        self.currencyCode = currencyCode.uppercased()
        self.effectivePeriod = effectivePeriod
        self.sources = sources
        try validate()
    }

    public func validate() throws {
        try effectivePeriod.validate()
        guard !version.isEmpty, version.count <= 128, !rate.isNaN, rate >= 0,
            currencyCode.count == 3, currencyCode.utf8.allSatisfy({ (65...90).contains($0) })
        else { throw BenefitContributionError.invalidRule }
    }
}

/// Quantities are explicitly reviewed eligibility facts, not automatically multiplied OT hours.
public struct BenefitEligibilitySegment: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let period: BenefitPeriod
    public let rule: BenefitRuleSnapshot
    public let quantity: Decimal
    public let eligibilityConfirmed: Bool

    public init(
        id: UUID = UUID(), period: BenefitPeriod, rule: BenefitRuleSnapshot,
        quantity: Decimal, eligibilityConfirmed: Bool
    ) {
        self.id = id
        self.period = period
        self.rule = rule
        self.quantity = quantity
        self.eligibilityConfirmed = eligibilityConfirmed
    }
}

/// A confirmed statement value. Nil amount/quantity means missing, and must never become zero.
public struct BenefitStatementObservation: Codable, Hashable, Sendable {
    public let fundID: UUID
    public let currencyCode: String
    public let period: BenefitPeriod
    public let employerContribution: Money?
    public let quantity: Decimal?
    public let quantityBasis: BenefitContributionBasis?
    public let confirmed: Bool

    public init(
        fundID: UUID, currencyCode: String, period: BenefitPeriod, employerContribution: Money?,
        quantity: Decimal? = nil,
        quantityBasis: BenefitContributionBasis? = nil, confirmed: Bool
    ) {
        self.period = period
        self.fundID = fundID
        self.currencyCode = currencyCode.uppercased()
        self.employerContribution = employerContribution
        self.quantity = quantity
        self.quantityBasis = quantityBasis
        self.confirmed = confirmed
    }
}

public enum BenefitComparisonStatus: String, Codable, Hashable, Sendable {
    case notVerified, notComparable, comparedValuesMatch, possibleDifference
}

public struct BenefitContributionResult: Codable, Hashable, Sendable {
    public let fundID: UUID
    public let engineVersion: String
    public let period: BenefitPeriod
    public let statement: BenefitStatementObservation?
    public let expectedEmployerContribution: Money
    public let confirmedEmployerContribution: Money?
    /// Expected minus confirmed; does not establish a debt or a recovery amount.
    public let contributionDifference: Money?
    public let eligibleQuantity: Decimal?
    public let quantityBasis: BenefitContributionBasis?
    public let quantityDifference: Decimal?
    public let status: BenefitComparisonStatus
    public let limitation: String?
    public let segments: [BenefitEligibilitySegment]
    public let rounding: MoneyRoundingRule
}

public enum BenefitContributionError: Error, Equatable, Sendable {
    case invalidPeriod, invalidRule, invalidQuantity, eligibilityNotConfirmed
    case incompleteCoverage, overlappingSegments, ruleNotEffective, currencyMismatch
    case invalidStatement, arithmeticNotExact, invalidRounding, fundMismatch
}

/// One fund, one explicitly complete statement period. Funds and cash pay are never combined.
public struct BenefitContributionCalculator: Sendable {
    public static let version = "confirmed-benefit-fund-v1"
    public init() {}

    public func calculate(
        period: BenefitPeriod, segments: [BenefitEligibilitySegment],
        completeEligibilityConfirmed: Bool, statement: BenefitStatementObservation?,
        rounding: MoneyRoundingRule
    ) throws -> BenefitContributionResult {
        try period.validate()
        guard completeEligibilityConfirmed, !segments.isEmpty, segments.count <= 1_000 else {
            throw BenefitContributionError.incompleteCoverage
        }
        guard (0...8).contains(rounding.scale), rounding.scope == .payCategory else {
            throw BenefitContributionError.invalidRounding
        }
        let sorted = segments.sorted { $0.period.start < $1.period.start }
        guard Set(sorted.map(\.id)).count == sorted.count else {
            throw BenefitContributionError.overlappingSegments
        }
        let currency = sorted[0].rule.currencyCode
        let fundID = sorted[0].rule.fundID
        let bases = Set(sorted.map { $0.rule.basis })
        var raw: Decimal = 0
        var units: Decimal = 0
        var previousEnd = period.start
        var snapshots: [UUID: BenefitRuleSnapshot] = [:]
        for segment in sorted {
            try segment.period.validate()
            try segment.rule.validate()
            if let saved = snapshots[segment.rule.id], saved != segment.rule {
                throw BenefitContributionError.invalidRule
            }
            snapshots[segment.rule.id] = segment.rule
            guard segment.eligibilityConfirmed else {
                throw BenefitContributionError.eligibilityNotConfirmed
            }
            guard !segment.quantity.isNaN, segment.quantity >= 0,
                segment.rule.basis != .fixedPeriod
                    || (segment.quantity == 1 && sorted.count == 1 && segment.period == period
                        && segment.rule.effectivePeriod == period)
            else { throw BenefitContributionError.invalidQuantity }
            guard segment.rule.fundID == fundID else { throw BenefitContributionError.fundMismatch }
            guard segment.rule.currencyCode == currency else {
                throw BenefitContributionError.currencyMismatch
            }
            guard period.contains(segment.period),
                segment.rule.effectivePeriod.contains(segment.period)
            else {
                throw BenefitContributionError.ruleNotEffective
            }
            guard segment.period.start >= previousEnd else {
                throw BenefitContributionError.overlappingSegments
            }
            previousEnd = segment.period.end
            var value = try exact(segment.rule.rate, segment.quantity, multiply: true)
            if segment.rule.basis == .percentOfEligibleEarnings {
                var hundred: Decimal = 100
                var divided: Decimal = 0
                guard NSDecimalDivide(&divided, &value, &hundred, .plain) == .noError else {
                    throw BenefitContributionError.arithmeticNotExact
                }
                value = divided
            }
            raw = try exact(raw, value, multiply: false)
            if bases.count == 1 { units = try exact(units, segment.quantity, multiply: false) }
        }
        let expected = Money(amount: raw, currencyCode: currency).rounded(using: rounding)
        let basis = bases.count == 1 ? sorted[0].rule.basis : nil
        let eligibleUnits = basis == nil ? nil : units
        func result(
            _ status: BenefitComparisonStatus, _ limitation: String?,
            paid: Money? = nil, difference: Money? = nil, unitDifference: Decimal? = nil
        ) -> BenefitContributionResult {
            BenefitContributionResult(
                fundID: fundID, engineVersion: Self.version, period: period, statement: statement,
                expectedEmployerContribution: expected,
                confirmedEmployerContribution: paid, contributionDifference: difference,
                eligibleQuantity: eligibleUnits, quantityBasis: basis,
                quantityDifference: unitDifference,
                status: status, limitation: limitation, segments: sorted, rounding: rounding)
        }
        guard let statement else {
            return result(
                .notVerified, "Employer contribution statement is missing or unconfirmed.")
        }
        try statement.period.validate()
        if let amount = statement.employerContribution {
            guard !amount.amount.isNaN, amount.amount >= 0 else {
                throw BenefitContributionError.invalidStatement
            }
        }
        if let quantity = statement.quantity {
            guard !quantity.isNaN, quantity >= 0, statement.quantityBasis != nil else {
                throw BenefitContributionError.invalidStatement
            }
        } else if statement.quantityBasis != nil {
            throw BenefitContributionError.invalidStatement
        }
        guard statement.confirmed else {
            return result(.notVerified, "Employer contribution statement is unconfirmed.")
        }
        guard statement.period == period, statement.fundID == fundID,
            statement.currencyCode == currency,
            statement.employerContribution.map({ $0.currencyCode == currency }) ?? true
        else {
            return result(
                .notComparable,
                "Statement fund, dates, timezone or currency differ from the reviewed expectation.")
        }
        let difference = try statement.employerContribution.map {
            try expected.subtracting($0).rounded(using: rounding)
        }
        let unitDifference: Decimal?
        if let quantity = statement.quantity, let eligibleUnits, statement.quantityBasis == basis {
            unitDifference = try exact(eligibleUnits, -quantity, multiply: false)
        } else {
            unitDifference = nil
        }
        guard difference != nil || unitDifference != nil else {
            return result(
                .notVerified, "No comparable confirmed amount or unit count is available.")
        }
        let differs =
            difference.map { $0.amount != 0 } == true || unitDifference.map { $0 != 0 } == true
        let limitation =
            difference == nil
            ? "Units only; employer contribution amount is unverified."
            : statement.quantity != nil && unitDifference == nil
                ? "Contribution amount only; reported units use a different basis."
                : "Only these confirmed employer contribution values were compared."
        return result(
            differs ? .possibleDifference : .comparedValuesMatch, limitation,
            paid: statement.employerContribution, difference: difference,
            unitDifference: unitDifference)
    }

    private func exact(_ lhs: Decimal, _ rhs: Decimal, multiply: Bool) throws -> Decimal {
        var left = lhs
        var right = rhs
        var value: Decimal = 0
        let error =
            multiply
            ? NSDecimalMultiply(&value, &left, &right, .plain)
            : NSDecimalAdd(&value, &left, &right, .plain)
        guard error == .noError, !value.isNaN else {
            throw BenefitContributionError.arithmeticNotExact
        }
        return value
    }
}
