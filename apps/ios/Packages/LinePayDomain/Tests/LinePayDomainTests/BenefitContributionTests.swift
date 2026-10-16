import Foundation
import Testing

@testable import LinePayDomain

@Suite("Confirmed employer benefits stay separate from wages")
struct BenefitContributionTests {
    private let fundID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    @Test func missingStatementIsUnverifiedWithoutInventingZeroOrADebt() throws {
        let result = try calculate([try segment(rate: "8.75", units: "40")])
        #expect(result.expectedEmployerContribution.amount == decimal("350"))
        #expect(result.status == .notVerified)
        #expect(result.confirmedEmployerContribution == nil && result.contributionDifference == nil)
        #expect(result.quantityDifference == nil)
    }

    @Test func separateMoneyAndHoursExplainTheSameConfirmedFundDifference() throws {
        // Independently: 40 × 8.75 = 350; 35.5 × 8.75 = 310.625, rounded 310.63.
        let statement = BenefitStatementObservation(
            fundID: fundID, currencyCode: "USD", period: try period(),
            employerContribution: Money(amount: decimal("310.63"), currencyCode: "USD"),
            quantity: decimal("35.5"), quantityBasis: .eligibleHour, confirmed: true)
        let result = try calculate([try segment(rate: "8.75", units: "40")], statement: statement)
        #expect(result.contributionDifference?.amount == decimal("39.37"))
        #expect(result.quantityDifference == decimal("4.5"))
        #expect(result.status == .possibleDifference)
        #expect(result.segments[0].rule.rate == decimal("8.75"))
    }

    @Test(arguments: [
        (BenefitContributionBasis.eligibleHour, "8.75", "40", "350"),
        (.eligibleDay, "12.50", "5", "62.50"),
        (.percentOfEligibleEarnings, "6", "4088", "245.28"),
        (.fixedPeriod, "125", "1", "125"),
    ])
    func explicitBasesUseExactEligibleUnits(
        _ sample: (BenefitContributionBasis, String, String, String)
    ) throws {
        let result = try calculate([try segment(rate: sample.1, units: sample.2, basis: sample.0)])
        #expect(result.expectedEmployerContribution.amount == decimal(sample.3))
        #expect(result.quantityBasis == sample.0)
        #expect(result.status == .notVerified)
    }

    @Test func changedRatesKeepTheirOwnSnapshotAndRoundOncePerFund() throws {
        let first = try period(endDay: 4)
        let second = try period(startDay: 4)
        let a = try segment(rate: "0.005", units: "1", scope: first)
        let b = try segment(rate: "0.005", units: "1", scope: second)
        let result = try calculate([b, a])
        #expect(result.expectedEmployerContribution.amount == decimal("0.01"))
        #expect(result.segments.map(\.id) == [a.id, b.id])
        #expect(result.segments.map(\.rule.id) == [a.rule.id, b.rule.id])
        let restored = try JSONDecoder().decode(
            BenefitContributionResult.self,
            from: JSONEncoder().encode(result))
        #expect(restored == result)
    }

    @Test func wrongPeriodCurrencyOrTimezoneCannotBecomeAMatch() throws {
        let expected = [try segment(rate: "10", units: "40")]
        for (scope, currency) in [
            (try period(endDay: 7), "USD"),
            (try period(zone: "America/Chicago"), "USD"), (try period(), "CAD"),
        ] {
            let statement = BenefitStatementObservation(
                fundID: fundID, currencyCode: "USD", period: scope,
                employerContribution: Money(amount: 400, currencyCode: currency), confirmed: true)
            let result = try calculate(expected, statement: statement)
            #expect(result.status == .notComparable && result.contributionDifference == nil)
        }
    }

    @Test func unitOnlyOrDifferentUnitsDoNotClaimAnAmountAndQuantityMatch() throws {
        let expected = [try segment(rate: "10", units: "40")]
        let units = BenefitStatementObservation(
            fundID: fundID, currencyCode: "USD", period: try period(), employerContribution: nil,
            quantity: 40, quantityBasis: .eligibleHour, confirmed: true)
        let unitResult = try calculate(expected, statement: units)
        #expect(
            unitResult.status == .comparedValuesMatch && unitResult.contributionDifference == nil)
        #expect(unitResult.limitation?.contains("Units only") == true)
        let wrongUnits = BenefitStatementObservation(
            fundID: fundID, currencyCode: "USD", period: try period(),
            employerContribution: Money(amount: 400, currencyCode: "USD"),
            quantity: 5, quantityBasis: .eligibleDay, confirmed: true)
        let amountResult = try calculate(expected, statement: wrongUnits)
        #expect(
            amountResult.status == .comparedValuesMatch && amountResult.quantityDifference == nil)
        #expect(amountResult.limitation?.contains("different basis") == true)
    }

    @Test func unconfirmedIncompleteOverlappingOrIneffectiveFactsAreRejected() throws {
        let line = try segment(rate: "10", units: "40")
        #expect(throws: BenefitContributionError.incompleteCoverage) {
            try BenefitContributionCalculator().calculate(
                period: period(), segments: [line],
                completeEligibilityConfirmed: false, statement: nil, rounding: MoneyRoundingRule())
        }
        #expect(throws: BenefitContributionError.overlappingSegments) {
            try calculate([line, line])
        }
        let unconfirmed = BenefitEligibilitySegment(
            period: try period(), rule: line.rule,
            quantity: 40, eligibilityConfirmed: false)
        #expect(throws: BenefitContributionError.eligibilityNotConfirmed) {
            try calculate([unconfirmed])
        }
        let narrowRule = try segment(rate: "10", units: "4", scope: period(endDay: 4)).rule
        let outOfDates = BenefitEligibilitySegment(
            period: try period(), rule: narrowRule,
            quantity: 40, eligibilityConfirmed: true)
        #expect(throws: BenefitContributionError.ruleNotEffective) { try calculate([outOfDates]) }
    }

    @Test func fixedPeriodCannotBeDuplicatedBySplittingTheSameStatement() throws {
        let a = try segment(rate: "125", units: "1", basis: .fixedPeriod, scope: period(endDay: 4))
        let b = try segment(
            rate: "125", units: "1", basis: .fixedPeriod, scope: period(startDay: 4))
        #expect(throws: BenefitContributionError.invalidQuantity) { try calculate([a, b]) }
    }

    @Test func corruptDecodedValuesAreValidatedAtCalculationBoundary() throws {
        let line = try segment(rate: "10", units: "40")
        let valid = try JSONEncoder().encode(line)
        var json = try #require(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        json["quantity"] = -1
        let corrupt = try JSONDecoder().decode(
            BenefitEligibilitySegment.self,
            from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: BenefitContributionError.invalidQuantity) { try calculate([corrupt]) }
        #expect(throws: BenefitContributionError.invalidPeriod) {
            try BenefitPeriod(
                start: LocalDate(year: 2026, month: 2, day: 30),
                end: LocalDate(year: 2026, month: 3, day: 2), timeZoneIdentifier: "UTC")
        }
        let enormous = try segment(rate: "1e127", units: "10")
        #expect(throws: BenefitContributionError.arithmeticNotExact) { try calculate([enormous]) }
    }

    @Test func differentFundsAndUnitOnlyCurrencyCannotCreateFalseMatches() throws {
        let expected = [try segment(rate: "10", units: "40")]
        let expectedPeriod = try period()
        for (id, currency) in [(UUID(), "USD"), (fundID, "CAD")] {
            let statement = BenefitStatementObservation(
                fundID: id, currencyCode: currency,
                period: try period(), employerContribution: nil, quantity: 40,
                quantityBasis: .eligibleHour, confirmed: true)
            let result = try calculate(expected, statement: statement)
            #expect(result.status == .notComparable && result.quantityDifference == nil)
            #expect(result.statement == statement && result.period == expectedPeriod)
        }
    }

    @Test(arguments: [(2, 4, false), (3, 4, true), (7, 8, true), (8, 9, false)])
    func effectiveDateBoundariesAreExclusiveAtTheEnd(_ sample: (Int, Int, Bool)) throws {
        let applicable = try period(startDay: 3, endDay: 8)
        let rule = try segment(rate: "10", units: "1", scope: applicable).rule
        let line = BenefitEligibilitySegment(
            period: try period(startDay: sample.0, endDay: sample.1),
            rule: rule, quantity: 1, eligibilityConfirmed: true)
        let run = {
            try BenefitContributionCalculator().calculate(
                period: period(endDay: 9),
                segments: [line], completeEligibilityConfirmed: true, statement: nil,
                rounding: MoneyRoundingRule())
        }
        if sample.2 {
            #expect(try run().expectedEmployerContribution.amount == 10)
        } else {
            #expect(throws: BenefitContributionError.ruleNotEffective) { try run() }
        }
    }

    @Test func oneExpectationCannotSilentlyCombineDifferentFunds() throws {
        let first = try segment(rate: "10", units: "8", scope: period(endDay: 4))
        let laterPeriod = try period(startDay: 4)
        let other = try BenefitRuleSnapshot(
            fundID: UUID(), version: "Another fund", basis: .eligibleHour,
            rate: 10, currencyCode: "USD", effectivePeriod: laterPeriod)
        let later = BenefitEligibilitySegment(
            period: laterPeriod, rule: other, quantity: 8,
            eligibilityConfirmed: true)
        #expect(throws: BenefitContributionError.fundMismatch) { try calculate([first, later]) }
    }

    @Test func zeroExpectedIsStillUnverifiedAndExcessIsOnlyAPossibleDifference() throws {
        #expect(try calculate([segment(rate: "0", units: "40")]).status == .notVerified)
        let statement = BenefitStatementObservation(
            fundID: fundID, currencyCode: "USD", period: try period(),
            employerContribution: Money(amount: 500, currencyCode: "USD"), confirmed: true)
        let result = try calculate([segment(rate: "10", units: "40")], statement: statement)
        #expect(
            result.contributionDifference?.amount == -100 && result.status == .possibleDifference)
        let invalid = BenefitStatementObservation(
            fundID: fundID, currencyCode: "USD", period: try period(),
            employerContribution: Money(amount: .nan, currencyCode: "USD"), confirmed: false)
        #expect(throws: BenefitContributionError.invalidStatement) {
            try calculate([segment(rate: "10", units: "40")], statement: invalid)
        }
    }

    private func period(startDay: Int = 1, endDay: Int = 8, zone: String = "UTC") throws
        -> BenefitPeriod
    {
        try BenefitPeriod(
            start: LocalDate(year: 2026, month: 8, day: startDay),
            end: LocalDate(year: 2026, month: 8, day: endDay), timeZoneIdentifier: zone)
    }

    private func segment(
        rate: String, units: String, basis: BenefitContributionBasis = .eligibleHour,
        scope: BenefitPeriod? = nil
    ) throws -> BenefitEligibilitySegment {
        let window = try scope ?? period()
        let rule = try BenefitRuleSnapshot(
            fundID: fundID, version: "Synthetic v1", basis: basis, rate: decimal(rate),
            currencyCode: "USD", effectivePeriod: window,
            sources: [
                AgreementSource(title: "Synthetic benefit clause", url: "", section: "Example only")
            ])
        return BenefitEligibilitySegment(
            period: window, rule: rule, quantity: decimal(units), eligibilityConfirmed: true)
    }

    private func calculate(
        _ segments: [BenefitEligibilitySegment], statement: BenefitStatementObservation? = nil
    ) throws -> BenefitContributionResult {
        try BenefitContributionCalculator().calculate(
            period: period(), segments: segments,
            completeEligibilityConfirmed: true, statement: statement, rounding: MoneyRoundingRule())
    }
}
