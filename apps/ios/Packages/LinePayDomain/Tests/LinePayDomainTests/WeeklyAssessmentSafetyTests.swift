import Foundation
import Testing

@testable import LinePayDomain

@Suite("Weekly evidence cannot bypass paycheck scope")
struct WeeklyAssessmentSafetyTests {
    private func source(hours: Int, configured: Bool, attached: Bool) throws -> (
        AgreementSnapshot, CalculationResult
    ) {
        let rule = try WeeklyOvertimeRule(
            workweekStart: .monday, applicability: .coveredNonexemptHourly)
        let agreement = try AgreementSnapshot(
            id: "synthetic-weekly-scope", version: "1", displayName: "Synthetic",
            hourlyRate: Money(amount: 50, currencyCode: "USD"), regularSchedule: [],
            weeklyOvertime: configured ? rule : nil)
        let work = try WorkInterval(
            startEpochSeconds: 1_788_739_200,
            endEpochSeconds: 1_788_739_200 + Int64(hours * 3600), timeZoneIdentifier: "UTC")
        let weekly =
            try attached
            ? WeeklyRegularRateInput(
                weekStart: LocalDate(year: 2026, month: 9, day: 7), workweekStart: .monday,
                completeWorkweek: true, applicability: .coveredNonexemptHourly,
                work: [
                    WeeklyWorkFact(
                        payPeriodID: UUID(), hours: 48, straightRate: agreement.hourlyRate)
                ],
                remuneration: [
                    WeeklyRemunerationFact(
                        amount: Money(amount: 2400, currencyCode: "USD"), kind: .straightTime)
                ]) : nil
        let calculation = try PayCalculator().calculate(
            work: [work], agreement: agreement,
            policy: .highestApplicable, weekly: weekly)
        return (agreement, calculation)
    }
    @Test(arguments: [
        (8, true, false), (40, true, false), (60, true, false), (8, true, true), (8, false, true),
    ])
    func aPeriodTotalOrUnmappedWeeklyResultCannotAuthorizeADirectionalVerdict(
        _ hours: Int, _ configured: Bool, _ attached: Bool
    ) throws {
        let (agreement, calculation) = try source(
            hours: hours, configured: configured, attached: attached)
        for paid in [
            calculation.total.amount, calculation.total.amount - 1, calculation.total.amount + 1,
        ] {
            let result = try PaycheckAssessor().assess(
                calculation: calculation, agreement: agreement,
                facts: PaycheckFacts(
                    hasCompleteWork: true, grossPay: Money(amount: paid, currencyCode: "USD"),
                    grossBasis: .wagesOnly))
            #expect(result.verdict == .needsReview)
            #expect(result.engineVersion == 5)
            #expect(result.expectedGross == calculation.expectedWages)
            #expect(result.reviewReasons.contains { $0.lowercased().contains("workweek") })
        }
    }
    @Test func nonweeklyConfiguredScopeStillComparesItsKnownFacts() throws {
        let (agreement, calculation) = try source(hours: 8, configured: false, attached: false)
        let result = try PaycheckAssessor().assess(
            calculation: calculation, agreement: agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: calculation.total, grossBasis: .wagesOnly))
        #expect(result.verdict == .matches && result.reviewReasons.isEmpty)
        #expect(result.engineVersion == 5)
    }
    @Test func originalAssessmentV3ReceiptsRemainRecordedWhileExplicitV4ReviewUsesNewScope() throws
    {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let bytes = try Data(
            contentsOf: root.appendingPathComponent(
                "shared/contracts/reconciliation/native-assessment-v3.json"))
        struct Fixture: Decodable {
            struct Row: Decodable {
                let id: String
                let agreement: AgreementSnapshot
                let calculation: CalculationResult
                let assessment: PaycheckAssessment
            }
            let sourceCommit: String
            let cases: [Row]
        }
        let fixture = try JSONDecoder().decode(Fixture.self, from: bytes)
        #expect(fixture.sourceCommit == "614d360" && fixture.cases.count == 5)
        for row in fixture.cases {
            #expect(row.assessment.engineVersion == 3)
            #expect(
                row.assessment.verdict
                    == (row.id == "configured-sixty-hours" ? .needsReview : .matches))
            let original = try JSONDecoder().decode(
                PaycheckAssessment.self, from: JSONEncoder().encode(row.assessment))
            #expect(original == row.assessment)
            let facts = PaycheckFacts(
                hasCompleteWork: true, grossPay: original.paidGross, grossBasis: .wagesOnly)
            let replayed = try PaycheckAssessor().reproduceRecorded(
                original, calculation: row.calculation,
                agreement: row.agreement, facts: facts)
            #expect(replayed == original)
            let changedFacts = PaycheckFacts(
                hasCompleteWork: true,
                grossPay: Money(amount: original.paidGross.amount + 1, currencyCode: "USD"),
                grossBasis: .wagesOnly)
            #expect(throws: PaycheckAssessmentError.recordedComparisonMismatch) {
                try PaycheckAssessor().reproduceRecorded(
                    original, calculation: row.calculation,
                    agreement: row.agreement, facts: changedFacts)
            }
            let reviewed = try PaycheckAssessor().assess(
                calculation: row.calculation, agreement: row.agreement,
                facts: PaycheckFacts(
                    hasCompleteWork: true, grossPay: original.paidGross, grossBasis: .wagesOnly))
            #expect(reviewed.engineVersion == 5)
            #expect(reviewed.verdict == (row.id == "no-weekly-scope" ? .matches : .needsReview))
            #expect(
                reviewed.comparisons == original.comparisons
                    && reviewed.expectedGross == original.expectedGross)
            #expect(original.verdict == row.assessment.verdict && original.engineVersion == 3)
        }
    }
    @Test func missingOrEmptyCalculationSnapshotsCannotConcealTheSuppliedWeeklyRule() throws {
        let (agreement, calculation) = try source(hours: 8, configured: true, attached: false)
        let original = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(calculation)) as? [String: Any])
        for empty in [false, true] {
            var raw = original
            if empty {
                raw["agreementSnapshots"] = [Any]()
            } else {
                raw["agreementSnapshots"] = NSNull()
            }
            let supplied = try JSONDecoder().decode(
                CalculationResult.self, from: JSONSerialization.data(withJSONObject: raw))
            let result = try PaycheckAssessor().assess(
                calculation: supplied, agreement: agreement,
                facts: PaycheckFacts(
                    hasCompleteWork: true, grossPay: calculation.total, grossBasis: .wagesOnly))
            #expect(
                result.verdict == .needsReview
                    && result.reviewReasons.contains(PaycheckAssessor.weeklyMappingReviewReason))
        }
    }

}
