import Foundation
import Testing

@testable import LinePayDomain

@Suite("Effective-dated rules preserve real work")
struct AgreementTimelineTests {
    @Test func ratesApplyByWorkDateAndKeepSourceVersions() throws {
        let original = try rules("1", rate: 50)
        let updated = try rules("2", rate: 60)
        let shifts = try [
            work((2026, 8, 3, 8, 0), (2026, 8, 3, 16, 0)),
            work((2026, 8, 4, 8, 0), (2026, 8, 4, 16, 0)),
        ]
        let change = AgreementChange(
            effectiveDate: .init(year: 2026, month: 8, day: 4), agreement: updated)
        let result = try PayCalculator().calculate(
            work: shifts, agreement: original,
            changes: [change], policy: .highestApplicable)
        #expect(result.total.amount == 880)
        #expect(result.components.map(\.amount.amount) == [400, 480])
        #expect(result.components.map(\.appliedAgreement?.version) == ["1", "2"])
        #expect(result.agreementSnapshots == [original, updated])
        #expect(result.components.reduce(Decimal(0)) { $0 + ($1.hours ?? 0) } == 16)
        #expect(
            try JSONDecoder().decode(CalculationResult.self, from: JSONEncoder().encode(result))
                == result)
    }

    @Test func overnightShiftSplitsAtPayrollMidnightNotUTC() throws {
        let shift = try work((2026, 8, 3, 22, 0), (2026, 8, 4, 2, 0))
        let result = try PayCalculator().calculate(
            work: [shift], agreement: rules("1", rate: 50),
            changes: [
                .init(
                    effectiveDate: .init(year: 2026, month: 8, day: 4),
                    agreement: rules("2", rate: 60))
            ],
            policy: .highestApplicable)
        #expect(result.total.amount == 220)
        #expect(result.components.map(\.hours) == [2, 2])
        #expect(Set(result.components.compactMap(\.workIntervalID)) == [shift.id])
    }

    @Test func changedTiersAndPerDiemAreResolvedIndependentlyPerDate() throws {
        let initial = try rules("1", rate: 50, diem: 100, overtime: 2)
        let later = try rules("2", rate: 60, diem: 125, overtime: 3)
        let result = try PayCalculator().calculate(
            work: [
                work((2026, 8, 3, 8, 0), (2026, 8, 3, 18, 0)),
                work((2026, 8, 4, 8, 0), (2026, 8, 4, 18, 0)),
            ], agreement: initial,
            changes: [.init(effectiveDate: .init(year: 2026, month: 8, day: 4), agreement: later)],
            policy: .highestApplicable)
        // Day 1: 8*50 + 2*100 + 100. Day 2: 8*60 + 2*180 + 125.
        #expect(result.total.amount == 1_665)
        #expect(
            result.components.filter { $0.category == .perDiem }.map(\.amount.amount) == [100, 125])
    }

    @Test func multipleScheduledChangesAreOrderedAndEarlierAmountsStayFixed() throws {
        let original = try rules("1", rate: 50)
        let early = AgreementChange(
            effectiveDate: .init(year: 2026, month: 8, day: 4), agreement: try rules("3", rate: 60))
        let late = AgreementChange(
            effectiveDate: .init(year: 2026, month: 8, day: 5), agreement: try rules("2", rate: 70))
        let timeline = try AgreementTimeline(baseline: original, changes: [late, early])
        #expect(timeline.changes == [early, late])
        #expect(timeline.agreement(on: .init(year: 2026, month: 8, day: 3)) == original)
        #expect(timeline.agreement(on: early.effectiveDate) == early.agreement)
        #expect(timeline.agreement(on: .init(year: 2026, month: 8, day: 9)) == late.agreement)
    }

    @Test(arguments: [true, false])
    func spanningCalloutNeverGuessesAGuaranteeRate(_ needsGuarantee: Bool) throws {
        let shift = try work((2026, 8, 3, 23, 0), (2026, 8, 4, 1, 0), kind: .callout)
        let minimum: Decimal = needsGuarantee ? 4 : 2
        let initial = try rules("1", rate: 50, minimum: minimum)
        let changes = [
            AgreementChange(
                effectiveDate: .init(year: 2026, month: 8, day: 4),
                agreement: try rules("2", rate: 60, minimum: minimum))
        ]
        if needsGuarantee {
            #expect(throws: AgreementTimelineError.calloutGuaranteeNeedsReview(shift.id)) {
                try PayCalculator().calculate(
                    work: [shift], agreement: initial, changes: changes, policy: .highestApplicable)
            }
        } else {
            let result = try PayCalculator().calculate(
                work: [shift], agreement: initial, changes: changes, policy: .highestApplicable)
            #expect(result.total.amount == 110)
            #expect(result.components.allSatisfy { $0.category == .workedHours })
        }
        #expect(shift.durationHours == 2)
    }

    @Test func withinDateCalloutKeepsItsOwnVersionAndGuarantee() throws {
        let shift = try work((2026, 8, 4, 8, 0), (2026, 8, 4, 9, 0), kind: .callout)
        let result = try PayCalculator().calculate(
            work: [shift], agreement: rules("1", rate: 50, minimum: 2),
            changes: [
                .init(
                    effectiveDate: .init(year: 2026, month: 8, day: 4),
                    agreement: rules("2", rate: 60, minimum: 4))
            ],
            policy: .highestApplicable)
        #expect(result.total.amount == 240)
        #expect(result.components.first { $0.category == .calloutGuarantee }?.hours == 3)
        #expect(result.components.allSatisfy { $0.appliedAgreement?.version == "2" })
    }

    @Test(arguments: [(2026, 3, 8, 3), (2026, 11, 1, 5)])
    func ruleDateRespectsDSTElapsedTime(_ year: Int, _ month: Int, _ day: Int, _ hours: Int) throws
    {
        let shift = try work((year, month, day, 0, 0), (year, month, day, 4, 0))
        let result = try PayCalculator().calculate(
            work: [shift], agreement: rules("1", rate: 50),
            changes: [
                .init(
                    effectiveDate: .init(year: year, month: month, day: day),
                    agreement: rules("2", rate: 60))
            ],
            policy: .highestApplicable)
        #expect(result.total.amount == Decimal(hours * 60))
    }

    @Test func invalidTimelineIsRejectedBeforeCalculation() throws {
        let base = try rules("1", rate: 50)
        let date = LocalDate(year: 2026, month: 8, day: 4)
        let change = AgreementChange(effectiveDate: date, agreement: try rules("2", rate: 60))
        #expect(throws: AgreementTimelineError.duplicateOrExcessiveChanges) {
            try AgreementTimeline(baseline: base, changes: [change, change])
        }
        #expect(throws: AgreementTimelineError.duplicateOrExcessiveChanges) {
            try AgreementTimeline(
                baseline: base, changes: [.init(effectiveDate: date, agreement: base)])
        }
        #expect(throws: AgreementTimelineError.invalidEffectiveDate) {
            try AgreementTimeline(
                baseline: base,
                changes: [
                    .init(
                        effectiveDate: .init(year: 2026, month: 2, day: 30),
                        agreement: rules("2", rate: 60))
                ])
        }
        #expect(throws: AgreementTimelineError.incompatibleAgreement) {
            try AgreementTimeline(
                baseline: base,
                changes: [
                    .init(effectiveDate: date, agreement: rules("2", rate: 60, currency: "CAD"))
                ])
        }
    }

    private func rules(
        _ version: String, rate: Decimal, minimum: Decimal? = nil,
        diem: Decimal? = nil, overtime: Decimal? = nil, currency: String = "USD"
    ) throws -> AgreementSnapshot {
        try AgreementSnapshot(
            id: "synthetic", version: version, displayName: "Synthetic agreement",
            hourlyRate: Money(amount: rate, currencyCode: currency), regularSchedule: [],
            dailyOvertimeTiers: overtime.map {
                [try DailyOvertimeTier(afterHours: 8, multiplier: $0)]
            } ?? [],
            calloutMinimum: minimum.map { try CalloutMinimumRule(minimumHours: $0) },
            flatPerDiem: diem.map {
                FlatPerDiemRule(amountPerWorkDate: Money(amount: $0, currencyCode: currency))
            })
    }
}
