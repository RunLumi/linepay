import Foundation
import Testing

@testable import LinePayDomain

@Suite("Weekly premium allocation boundaries")
struct WeeklyAllocationTests {
    private func input(zeroAt: Int, nilZeroPeriod: Bool = false) throws -> WeeklyRegularRateInput {
        let work = try (0..<3).map { index in
            let periodID: UUID = try #require(
                UUID(uuidString: "62000000-0000-0000-0000-00000000000\(index)"))
            return try WeeklyWorkFact(
                id: #require(UUID(uuidString: "62000000-0000-0000-0000-00000000001\(index)")),
                payPeriodID: nilZeroPeriod && index == zeroAt ? nil : periodID,
                hours: Decimal(60_000) / 3_600,
                straightRate: Money(amount: index == zeroAt ? 0 : 1, currencyCode: "USD"),
                workedSeconds: 60_000)
        }
        return try WeeklyRegularRateInput(
            workweekID: #require(UUID(uuidString: "62000000-0000-0000-0000-000000000100")),
            weekStart: LocalDate(year: 2026, month: 9, day: 7), workweekStart: .monday,
            completeWorkweek: true, applicability: .coveredNonexemptHourly, work: work,
            remuneration: [
                WeeklyRemunerationFact(
                    id: #require(UUID(uuidString: "62000000-0000-0000-0000-000000000200")),
                    amount: Money(amount: decimal("0.10"), currencyCode: "USD"),
                    kind: .straightTime)
            ])
    }

    @Test(
        "BR-096: zero basis stays zero for explicit and unassigned periods",
        arguments: [false, true])
    func residualSkipsZeroBasis(nilZeroPeriod: Bool) throws {
        let source = try input(zeroAt: 0, nilZeroPeriod: nilZeroPeriod)
        let result = try WeeklyRegularRateCalculator().calculate(source)
        // 50 hours and $0.10 remuneration: $0.10 × 10 / (2 × 50) = $0.01.
        #expect(result.qualifyingHours == 50)
        #expect(result.remainingAdditionalPremium.amount == decimal("0.01"))
        #expect(result.allocations.count == 3)
        #expect(result.allocations[0].basis.amount == 0)
        #expect(result.allocations[0].amount.amount == 0)
        #expect(result.allocations[1].amount.amount == decimal("0.01"))
        #expect(
            result.allocations.reduce(Decimal.zero) { $0 + $1.amount.amount } == decimal("0.01"))
        let reordered = try WeeklyRegularRateInput(
            workweekID: source.workweekID, weekStart: source.weekStart,
            workweekStart: source.workweekStart, completeWorkweek: true,
            applicability: source.applicability, work: Array(source.work.reversed()),
            remuneration: source.remuneration)
        #expect(try WeeklyRegularRateCalculator().calculate(reordered) == result)
    }

    @Test("BR-096: frozen v2 allocation survives decoding while a new review uses v3")
    func savedV2ReceiptIsNotSilentlyReallocated() throws {
        // Emitted from the unmodified 1da1059 v2 calculator before this correction.
        let data = Data(
            #"""
            {
              "includableRemuneration": {"amount": 0.1, "currencyCode": "USD"},
              "overtimeHours": 10,
              "eligibleExtraPremiumCredit": {"amount": 0, "currencyCode": "USD"},
              "workweekStart": 2,
              "regularRate": {"amount": 0, "currencyCode": "USD"},
              "workweekID": "62000000-0000-0000-0000-000000000100",
              "allocations": [
                {
                  "amount": {"currencyCode": "USD", "amount": 0.01},
                  "payPeriodID": "62000000-0000-0000-0000-000000000000",
                  "basis": {"currencyCode": "USD", "amount": 0},
                  "id": "62000000-0000-0000-0000-000000000010"
                },
                {
                  "amount": {"currencyCode": "USD", "amount": 0},
                  "payPeriodID": "62000000-0000-0000-0000-000000000001",
                  "basis": {"currencyCode": "USD", "amount": 16.666666666666666666666666666666666666},
                  "id": "62000000-0000-0000-0000-000000000011"
                },
                {
                  "amount": {"currencyCode": "USD", "amount": 0},
                  "payPeriodID": "62000000-0000-0000-0000-000000000002",
                  "basis": {"currencyCode": "USD", "amount": 16.666666666666666666666666666666666666},
                  "id": "62000000-0000-0000-0000-000000000012"
                }
              ],
              "qualifyingHours": 50,
              "remainingAdditionalPremium": {"amount": 0.01, "currencyCode": "USD"},
              "expectedCash": {"amount": 0.11, "currencyCode": "USD"},
              "cashRemuneration": {"amount": 0.1, "currencyCode": "USD"},
              "engineVersion": "linepay.weekly-regular-rate/2",
              "statutoryAdditionalPremium": {"amount": 0.01, "currencyCode": "USD"},
              "weekStart": {"month": 9, "year": 2026, "day": 7}
            }
            """#.utf8)
        let original = try JSONDecoder().decode(WeeklyRegularRateResult.self, from: data)
        let roundTrip = try JSONDecoder().decode(
            WeeklyRegularRateResult.self, from: JSONEncoder().encode(original))
        #expect(roundTrip == original)
        #expect(original.engineVersion == "linepay.weekly-regular-rate/2")
        #expect(original.allocations.map(\.amount.amount) == [decimal("0.01"), 0, 0])
        let reviewed = try WeeklyRegularRateCalculator().calculate(input(zeroAt: 0))
        #expect(reviewed.engineVersion == "linepay.weekly-regular-rate/3")
        #expect(reviewed.allocations.map(\.amount.amount) == [0, decimal("0.01"), 0])
        #expect(reviewed.expectedCash == original.expectedCash)
        #expect(original.allocations[0].amount.amount == decimal("0.01"))
    }
}
