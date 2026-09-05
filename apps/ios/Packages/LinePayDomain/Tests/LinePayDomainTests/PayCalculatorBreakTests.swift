import Foundation
import Testing
@testable import LinePayDomain

@Suite("Unpaid break calculation")
struct PayCalculatorBreakTests {
    @Test("An exact unpaid break is removed without changing the shift clock span")
    func unpaidBreakIsExcludedFromWorkedPay() throws {
        let start: Int64 = 1_800_000_000
        let workBreak = try WorkBreak(
            startEpochSeconds: start + 4 * 3_600,
            endEpochSeconds: start + 4 * 3_600 + 30 * 60
        )
        let interval = try WorkInterval(
            startEpochSeconds: start,
            endEpochSeconds: start + 8 * 3_600,
            timeZoneIdentifier: "America/Los_Angeles",
            unpaidBreaks: [workBreak]
        )
        let agreement = try AgreementSnapshot(
            id: "break-test",
            version: "1",
            displayName: "Break test",
            hourlyRate: Money(amount: 40, currencyCode: "USD"),
            regularSchedule: []
        )

        let result = try PayCalculator().calculate(
            work: [interval],
            agreement: agreement,
            policy: .highestApplicable
        )

        #expect(interval.elapsedHours == Decimal(8))
        #expect(interval.durationHours == Decimal(string: "7.5"))
        #expect(result.total.amount == Decimal(300))
        #expect(result.components.compactMap(\.hours).reduce(0, +) == Decimal(string: "7.5"))
    }

    @Test("Break boundaries preserve overtime semantics")
    func breakDoesNotCreateFakeOvertime() throws {
        let start: Int64 = 1_800_000_000
        let workBreak = try WorkBreak(
            startEpochSeconds: start + 4 * 3_600,
            endEpochSeconds: start + 5 * 3_600
        )
        let interval = try WorkInterval(
            startEpochSeconds: start,
            endEpochSeconds: start + 10 * 3_600,
            timeZoneIdentifier: "America/Los_Angeles",
            unpaidBreaks: [workBreak]
        )
        let agreement = try AgreementSnapshot(
            id: "ot-break-test",
            version: "1",
            displayName: "OT break test",
            hourlyRate: Money(amount: 50, currencyCode: "USD"),
            regularSchedule: [],
            dailyOvertimeTiers: [
                try DailyOvertimeTier(afterHours: 8, multiplier: Decimal(string: "1.5")!)
            ]
        )

        let result = try PayCalculator().calculate(
            work: [interval],
            agreement: agreement,
            policy: .highestApplicable
        )

        let regularHours = result.components
            .filter { $0.multiplier == 1 }
            .compactMap(\.hours)
            .reduce(0, +)
        let overtimeHours = result.components
            .filter { $0.multiplier == Decimal(string: "1.5") }
            .compactMap(\.hours)
            .reduce(0, +)

        #expect(regularHours == Decimal(8))
        #expect(overtimeHours == Decimal(1))
        #expect(result.total.amount == Decimal(475))
    }

    @Test("A break cannot live outside the work interval")
    func invalidBreakIsRejected() throws {
        let start: Int64 = 1_800_000_000
        let workBreak = try WorkBreak(
            startEpochSeconds: start - 600,
            endEpochSeconds: start + 600
        )

        #expect(throws: DomainValidationError.workBreakOutsideInterval) {
            _ = try WorkInterval(
                startEpochSeconds: start,
                endEpochSeconds: start + 3_600,
                timeZoneIdentifier: "America/Los_Angeles",
                unpaidBreaks: [workBreak]
            )
        }
    }
}
