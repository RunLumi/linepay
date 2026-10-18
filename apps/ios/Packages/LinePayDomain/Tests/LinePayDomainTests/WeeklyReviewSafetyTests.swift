import Foundation
import Testing

@testable import LinePayDomain

@Suite("Weekly premium classification and input admission")
struct WeeklyReviewSafetyTests {
    private func input(credit: WeeklyPremiumCredit = .ineligible) throws -> WeeklyRegularRateInput {
        try WeeklyRegularRateInput(
            weekStart: LocalDate(year: 2026, month: 9, day: 7), workweekStart: .monday,
            completeWorkweek: true, applicability: .coveredNonexemptHourly,
            work: [WeeklyWorkFact(hours: 48, straightRate: Money(amount: 50, currencyCode: "USD"))],
            remuneration: [
                WeeklyRemunerationFact(
                    amount: Money(amount: 2400, currencyCode: "USD"), kind: .straightTime),
                WeeklyRemunerationFact(
                    amount: Money(amount: 240, currencyCode: "USD"), kind: .extraPremium,
                    premiumCredit: credit),
            ])
    }
    @Test func aNoncreditableWorkPremiumIsIncludableRatherThanSilentlyExcluded() throws {
        let result = try WeeklyRegularRateCalculator().calculate(input())
        #expect(result.includableRemuneration.amount == 2640)
        #expect(result.regularRate?.amount == 55)
        #expect(result.statutoryAdditionalPremium.amount == 220)
        #expect(result.eligibleExtraPremiumCredit.amount == 0)
        #expect(result.expectedCash.amount == 2860)
    }
    @Test func unknownPremiumTreatmentCannotProduceAnAdditionalPayConclusion() throws {
        #expect(throws: (any Error).self) {
            try WeeklyRegularRateCalculator().calculate(input(credit: .unknown))
        }
    }
    @Test func decodedInputMustNotBypassDateThresholdAndAmountAdmission() throws {
        let valid = try input()
        let original = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        for defect in [
            "weekday", "date", "threshold", "rounding", "negative", "credit", "duplicate",
            "seconds",
        ] {
            var raw = original
            switch defect {
            case "weekday": raw["weekStart"] = ["year": 2026, "month": 9, "day": 8]
            case "date": raw["weekStart"] = ["year": 2026, "month": 2, "day": 30]
            case "threshold": raw["thresholdHours"] = 80
            case "rounding":
                raw["rounding"] = ["scale": 9, "mode": "halfUp", "scope": "payCategory"]
            case "duplicate":
                let rows = try #require(raw["work"] as? [[String: Any]])
                raw["work"] = rows + rows
            case "seconds":
                var rows = try #require(raw["work"] as? [[String: Any]])
                rows[0]["workedSeconds"] = 1
                raw["work"] = rows
            default:
                var rows = try #require(raw["remuneration"] as? [[String: Any]])
                if defect == "negative" {
                    rows[0]["amount"] = ["amount": -2400, "currencyCode": "USD"]
                } else {
                    rows[0]["premiumCredit"] = "eligibleExtraPremium"
                }
                raw["remuneration"] = rows
            }
            let decoded = try JSONDecoder().decode(
                WeeklyRegularRateInput.self, from: JSONSerialization.data(withJSONObject: raw))
            #expect(throws: (any Error).self, "\(defect)") {
                try WeeklyRegularRateCalculator().calculate(decoded)
            }
        }
    }
    @Test func identicalInputsHaveDeterministicAllocationIDsAndExactSecondTotals() throws {
        let first = try WeeklyWorkFact(
            hours: Decimal(144001) / 3600,
            straightRate: Money(amount: 50, currencyCode: "USD"), workedSeconds: 144001)
        let second = try WeeklyWorkFact(
            hours: Decimal(28799) / 3600,
            straightRate: Money(amount: 50, currencyCode: "USD"), workedSeconds: 28799)
        let source = try WeeklyRegularRateInput(
            weekStart: LocalDate(year: 2026, month: 9, day: 7),
            workweekStart: .monday, completeWorkweek: true, applicability: .coveredNonexemptHourly,
            work: [first, second],
            remuneration: [
                WeeklyRemunerationFact(
                    amount: Money(amount: 2400, currencyCode: "USD"), kind: .straightTime)
            ])
        let result = try WeeklyRegularRateCalculator().calculate(source)
        #expect(result.qualifyingHours == 48 && result.remainingAdditionalPremium.amount == 200)
        #expect(result == (try WeeklyRegularRateCalculator().calculate(source)))
        #expect(result.engineVersion == "linepay.weekly-regular-rate/2")
    }
    @Test func originalV1ReceiptKeepsItsOldValuesWhileExplicitNewCalculationUsesV2() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let data = try Data(
            contentsOf: root.appendingPathComponent("shared/contracts/weekly/legacy-result-v1.json")
        )
        struct Fixture: Decodable {
            let format: String
            let sourceCommit: String
            let input: WeeklyRegularRateInput
            let result: WeeklyRegularRateResult
        }
        let original = try JSONDecoder().decode(Fixture.self, from: data)
        #expect(
            original.format == "com.streamentry.linepay.weekly-legacy-result"
                && original.sourceCommit == "f4dd8e1")
        #expect(original.result.engineVersion == "linepay.weekly-regular-rate/1")
        #expect(
            original.result.expectedCash.amount == 2840
                && original.result.includableRemuneration.amount == 2400)
        let roundTrip = try JSONDecoder().decode(
            WeeklyRegularRateResult.self, from: JSONEncoder().encode(original.result))
        #expect(roundTrip == original.result)
        let reviewed = try WeeklyRegularRateCalculator().calculate(original.input)
        #expect(
            reviewed.engineVersion == "linepay.weekly-regular-rate/2"
                && reviewed.expectedCash.amount == 2860)
        #expect(original.result.expectedCash.amount == 2840)
    }
    @Test func explicitBoundaryContextIsRetainedAndMismatchedContextsRefuse() throws {
        let source = try input()
        func context(_ epoch: Int64?, _ zone: String?) throws -> WeeklyRegularRateInput {
            try WeeklyRegularRateInput(
                workweekID: source.workweekID, weekStart: source.weekStart,
                workweekStart: source.workweekStart, completeWorkweek: true,
                applicability: source.applicability,
                work: source.work, remuneration: source.remuneration,
                startEpochSeconds: epoch, timeZoneIdentifier: zone)
        }
        let result = try WeeklyRegularRateCalculator().calculate(context(1_788_739_200, "UTC"))
        #expect(
            result.startEpochSeconds == 1_788_739_200 && result.endEpochSeconds == 1_789_344_000)
        #expect(result.timeZoneIdentifier == "UTC")
        #expect(
            try JSONDecoder().decode(
                WeeklyRegularRateResult.self, from: JSONEncoder().encode(result)) == result)
        for (epoch, zone): (Int64?, String?) in [
            (nil, "UTC"), (1_788_739_200, nil), (0, "UTC"), (1_788_739_200, "No/Zone"),
        ] {
            #expect(throws: WeeklyRegularRateError.invalidWorkweek) {
                try WeeklyRegularRateCalculator().calculate(context(epoch, zone))
            }
        }
    }
}
