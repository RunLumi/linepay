import Foundation
import Testing

@testable import LinePayDomain

@Suite("Premium-only base precision")
struct PremiumOnlyPrecisionTests {
    @Test(arguments: [false, true])
    func aOneMinuteHalfCentKeepsItsExactBase(_ premium: Bool) throws {
        let agreement = try AgreementSnapshot(
            id: "synthetic-base-precision", version: "1", displayName: "Synthetic",
            hourlyRate: Money(amount: Decimal(string: "58.50")!, currencyCode: "USD"),
            regularSchedule: [],
            dailyOvertimeTiers: premium
                ? [DailyOvertimeTier(afterHours: 0, multiplier: Decimal(string: "1.5")!)] : [])
        let work = try WorkInterval(
            startEpochSeconds: 1_788_739_200,
            endEpochSeconds: 1_788_739_260, timeZoneIdentifier: "UTC")
        let calculation = try PayCalculator().calculate(
            work: [work], agreement: agreement, policy: .highestApplicable)
        let base = Money(amount: Decimal(string: "0.98")!, currencyCode: "USD")
        var amounts: [PaystubField: Money] = [.regularPay: base]
        if premium {
            amounts[.overtimePay] = Money(amount: Decimal(string: "0.48")!, currencyCode: "USD")
        }
        let assessment = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: calculation.total, amounts: amounts,
                grossBasis: .wagesOnly, lineLayout: .basePlusPremium, hasCompleteEarningsLines: true
            ))
        #expect(assessment.comparisons.first { $0.field == .regularPay }?.expected == base.amount)
        #expect(assessment.verdict == .matches)
    }

    private struct Legacy: Decodable {
        struct Row: Decodable {
            let id: String
            let agreement: AgreementSnapshot
            let calculation: CalculationResult
            let assessment: PaycheckAssessment
        }
        let sourceCommit: String
        let cases: [Row]
    }
    @Test func originalProducerFourReplaysWhileNewReviewRefusesMissingTrace() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let legacy = try JSONDecoder().decode(
            Legacy.self,
            from: Data(
                contentsOf:
                    root.appendingPathComponent(
                        "shared/contracts/reconciliation/native-assessment-v4.json")))
        #expect(legacy.sourceCommit == "3836154" && legacy.cases.count == 2)
        for row in legacy.cases {
            var amounts: [PaystubField: Money] = [
                .regularPay: Money(amount: Decimal(string: "0.98")!, currencyCode: "USD")
            ]
            if row.id == "premium-half-cent" {
                amounts[.overtimePay] = Money(amount: Decimal(string: "0.48")!, currencyCode: "USD")
            }
            let facts = PaycheckFacts(
                hasCompleteWork: true, grossPay: row.calculation.total,
                amounts: amounts, grossBasis: .wagesOnly, lineLayout: .basePlusPremium,
                hasCompleteEarningsLines: true)
            #expect(row.assessment.engineVersion == 4)
            #expect(
                row.assessment.comparisons.first { $0.field == .regularPay }?.expected
                    == Decimal(string: "0.97"))
            let replay = try PaycheckAssessor().reproduceRecorded(
                row.assessment,
                calculation: row.calculation, agreement: row.agreement, facts: facts)
            #expect(replay == row.assessment)
            let review = try PaycheckAssessor().assess(
                calculation: row.calculation, agreement: row.agreement, facts: facts)
            #expect(
                review.verdict == .needsReview
                    && review.reviewReasons.contains(PaycheckAssessor.exactBaseReviewReason))
            #expect(
                !review.comparisons.contains { $0.field == .regularPay || $0.field == .overtimePay }
            )
            #expect(review.comparisons.first { $0.field == .grossPay }?.difference == 0)
        }
    }

    @Test(arguments: [false, true])
    func aHalfCentAcrossDifferentRateSnapshotsRoundsOnlyAfterSumming(_ premium: Bool) throws {
        func rules(_ version: String, rate: Int) throws -> AgreementSnapshot {
            try AgreementSnapshot(
                id: "synthetic-cross-rate", version: version, displayName: "Synthetic",
                hourlyRate: Money(amount: Decimal(rate), currencyCode: "USD"), regularSchedule: [],
                dailyOvertimeTiers: premium
                    ? [DailyOvertimeTier(afterHours: 0, multiplier: Decimal(string: "1.5")!)] : [])
        }
        let original = try rules("1", rate: 1)
        let later = try rules("2", rate: 17)
        let work = try [
            WorkInterval(
                startEpochSeconds: 1_788_739_200, endEpochSeconds: 1_788_739_201,
                timeZoneIdentifier: "UTC"),
            WorkInterval(
                startEpochSeconds: 1_788_825_600, endEpochSeconds: 1_788_825_601,
                timeZoneIdentifier: "UTC"),
        ]
        let calculation = try PayCalculator().calculate(
            work: work, agreement: original,
            changes: [
                AgreementChange(
                    effectiveDate: LocalDate(year: 2026, month: 9, day: 8), agreement: later)
            ],
            policy: .highestApplicable)
        // (1 + 17) / 3600 = 0.005 base; premium gross 0.0075. Both round to 0.01.
        #expect(calculation.total.amount == Decimal(string: "0.01"))
        #expect(calculation.components.compactMap(\.baseTimeNumerator).reduce(0, +) == 18)
        var amounts: [PaystubField: Money] = [
            .regularPay: Money(amount: Decimal(string: "0.01")!, currencyCode: "USD")
        ]
        if premium { amounts[.overtimePay] = .zero(currencyCode: "USD") }
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: original,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: calculation.total, amounts: amounts,
                grossBasis: .wagesOnly, lineLayout: .basePlusPremium, hasCompleteEarningsLines: true
            ))
        #expect(result.verdict == .matches)
        #expect(
            result.comparisons.first { $0.field == .regularPay }?.expected
                == Decimal(string: "0.01"))
    }

    @Test(arguments: [PaystubGuaranteeLayout.includedInHourlyLines, .separateLine])
    func calloutMinimumRetainsTheSameExactBaseEvidence(_ layout: PaystubGuaranteeLayout) throws {
        let agreement = try AgreementSnapshot(
            id: "synthetic-guarantee", version: "1", displayName: "Synthetic",
            hourlyRate: Money(amount: Decimal(string: "58.50")!, currencyCode: "USD"),
            regularSchedule: [],
            calloutMinimum: CalloutMinimumRule(minimumHours: 1))
        let work = try WorkInterval(
            startEpochSeconds: 1_788_739_200, endEpochSeconds: 1_788_739_201,
            timeZoneIdentifier: "UTC", kind: .callout, calloutEventID: UUID())
        let calculation = try PayCalculator().calculate(
            work: [work], agreement: agreement, policy: .highestApplicable)
        #expect(calculation.components.compactMap(\.baseTimeNumerator).reduce(0, +) == 210_600)
        let worked = calculation.components.filter { $0.category == .workedHours }.reduce(
            Decimal.zero
        ) { $0 + $1.amount.amount }
        let guarantee = calculation.components.filter { $0.category == .calloutGuarantee }.reduce(
            Decimal.zero
        ) { $0 + $1.amount.amount }
        // The separate category buckets round 58.5/3600 to0.02 and210541.5/3600 to58.48.
        #expect(worked == Decimal(string: "0.02") && guarantee == Decimal(string: "58.48"))
        var amounts: [PaystubField: Money] = [
            .regularPay: Money(
                amount: layout == .separateLine ? worked : worked + guarantee, currencyCode: "USD")
        ]
        if layout == .separateLine {
            amounts[.calloutPay] = Money(amount: guarantee, currencyCode: "USD")
        }
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: calculation.total, amounts: amounts,
                grossBasis: .wagesOnly, lineLayout: .basePlusPremium, guaranteeLayout: layout,
                hasCompleteEarningsLines: true))
        #expect(result.verdict == .matches)
    }
}
