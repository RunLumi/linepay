import Foundation
import Testing

@testable import LinePayDomain

@Suite("Product repair: facts, rounding and historical identity")
struct ProductBoundaryTests {
    private func call(_ start: Int, _ end: Int, event: UUID?) throws -> WorkInterval {
        try WorkInterval(
            startEpochSeconds: epoch(year: 2026, month: 9, day: 1, hour: start),
            endEpochSeconds: epoch(year: 2026, month: 9, day: 1, hour: end),
            timeZoneIdentifier: "America/Los_Angeles", kind: .callout, calloutEventID: event)
    }
    @Test func oneCalloutIsInvariantToRecordPartitionButTwoRealCallsAreNot() throws {
        let rules = try agreement(
            hourlyRate: "50", calloutMinimum: CalloutMinimumRule(minimumHours: 4))
        let event = UUID()
        let one = try call(0, 2, event: event)
        let parts = try [call(0, 1, event: event), call(1, 2, event: event)]
        let a = try PayCalculator().calculate(
            work: [one], agreement: rules, policy: .highestApplicable)
        let b = try PayCalculator().calculate(
            work: parts, agreement: rules, policy: .highestApplicable)
        #expect(a.total.amount == 200 && b.total == a.total)
        #expect(b.components.filter { $0.category == .calloutGuarantee }.count == 1)
        #expect(
            b.components.filter { $0.category == .workedHours }.reduce(0) { $0 + ($1.hours ?? 0) }
                == 2)
        let separate = try PayCalculator().calculate(
            work: [call(0, 1, event: UUID()), call(1, 2, event: UUID())],
            agreement: rules, policy: .highestApplicable)
        #expect(separate.total.amount == 400)
    }
    @Test func unconfirmedAndDiscontinuousCalloutsRequireReview() throws {
        let rules = try agreement(calloutMinimum: CalloutMinimumRule(minimumHours: 4))
        let missing = try call(0, 2, event: nil)
        #expect(throws: CalloutReviewError.eventIdentityRequired(missing.id)) {
            try PayCalculator().calculate(
                work: [missing], agreement: rules, policy: .highestApplicable)
        }
        let event = UUID()
        #expect(throws: CalloutReviewError.unsupportedInteraction(event)) {
            try PayCalculator().calculate(
                work: [call(0, 1, event: event), call(2, 3, event: event)],
                agreement: rules, policy: .highestApplicable)
        }
    }
    @Test func legacySnapshotPolicyAndUnknownResultIdentityAreNotRelabeled() throws {
        let encodedRule = Data(#"{"scale":2,"mode":"halfUp"}"#.utf8)
        let legacy = try JSONDecoder().decode(MoneyRoundingRule.self, from: encodedRule)
        #expect(legacy.scope == .legacySegments)
        let rules = try AgreementSnapshot(
            id: "legacy", version: "1", displayName: "Legacy",
            hourlyRate: Money(amount: 50, currencyCode: "USD"), regularSchedule: [],
            rounding: legacy)
        let parts = try [
            work((2026, 9, 1, 8, 0), (2026, 9, 1, 8, 1)),
            work((2026, 9, 1, 8, 1), (2026, 9, 1, 8, 2)),
        ]
        let calculated = try PayCalculator().calculate(
            work: parts, agreement: rules, policy: .highestApplicable)
        #expect(calculated.total.amount == decimal("1.66"))
        #expect(calculated.provenance?.engine == "linepay.configured-pay/2")
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(calculated)) as? [String: Any])
        json.removeValue(forKey: "provenance")
        let old = try JSONDecoder().decode(
            CalculationResult.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.provenance == nil && old.total == calculated.total)
        #expect(
            try JSONDecoder().decode(CalculationResult.self, from: JSONEncoder().encode(old))
                .provenance == nil)
    }
    @Test(arguments: [MoneyRoundingMode.halfUp, .bankers, .down, .up])
    func allocatedComponentsConserveTotalAndPartitionIndependence(_ mode: MoneyRoundingMode) throws
    {
        let rules = try AgreementSnapshot(
            id: "round", version: "1", displayName: "Synthetic",
            hourlyRate: Money(amount: decimal("17.23"), currencyCode: "USD"), regularSchedule: [],
            rounding: MoneyRoundingRule(mode: mode))
        let start = epoch(year: 2026, month: 9, day: 1, hour: 8)
        let whole = try WorkInterval(
            startEpochSeconds: start, endEpochSeconds: start + 121, timeZoneIdentifier: "UTC")
        let split = try (0..<121).map { offset in
            try WorkInterval(
                startEpochSeconds: start + Int64(offset),
                endEpochSeconds: start + Int64(offset + 1), timeZoneIdentifier: "UTC")
        }
        let a = try PayCalculator().calculate(
            work: [whole], agreement: rules, policy: .highestApplicable)
        let b = try PayCalculator().calculate(
            work: split.reversed(), agreement: rules, policy: .highestApplicable)
        #expect(a.total == b.total)
        #expect(b.components.reduce(0) { $0 + $1.amount.amount } == b.total.amount)
        #expect(b.components.allSatisfy { $0.unroundedAmount != nil })
    }
    @Test func partialPaidLinesAreNotAssumedComplete() throws {
        let (rules, result) = try PaycheckAssessmentTests().example()
        let partial = PaycheckFacts(
            hasCompleteWork: true, grossPay: Money(amount: 550, currencyCode: "USD"),
            amounts: [.regularPay: Money(amount: 400, currencyCode: "USD")], grossBasis: .wagesOnly,
            lineLayout: .fullRateBuckets)
        let a = try PaycheckAssessor().assess(calculation: result, agreement: rules, facts: partial)
        #expect(a.verdict == .matches)
        var complete = partial
        complete.hasCompleteEarningsLines = true
        #expect(
            try PaycheckAssessor().assess(calculation: result, agreement: rules, facts: complete)
                .verdict == .needsReview)
    }
}

@Suite("Repeat preserves local facts and resolves clock ambiguities")
struct WorkTemplateTests {
    private func date(_ day: Int, month: Int = 3, hour: Int = 0) -> Date {
        Date(
            timeIntervalSince1970: TimeInterval(
                epoch(
                    year: 2026, month: month, day: day, hour: hour,
                    timeZoneIdentifier: "America/New_York")))
    }
    @Test func breakStaysAtFourAcrossSpringForward() throws {
        let start = date(7)
        let pause = try WorkBreak(
            startEpochSeconds: Int64(date(7, hour: 4).timeIntervalSince1970),
            endEpochSeconds: Int64(date(7, hour: 5).timeIntervalSince1970))
        let original = try WorkInterval(
            startEpochSeconds: Int64(start.timeIntervalSince1970),
            endEpochSeconds: Int64(date(7, hour: 8).timeIntervalSince1970),
            timeZoneIdentifier: "America/New_York", unpaidBreaks: [pause])
        let proposal = try WorkTemplate.propose(
            original, on: date(8), timeZoneIdentifier: "America/New_York")
        #expect(proposal.isResolved)
        #expect(proposal.date("break.0.start") == date(8, hour: 4))
        #expect(
            proposal.date("end")?.timeIntervalSince(try #require(proposal.date("start"))) == 7
                * 3600)
    }
    @Test func nonexistentTimeDoesNotNormalize() throws {
        let start = date(7, hour: 2).addingTimeInterval(1800)
        let original = try WorkInterval(
            startEpochSeconds: Int64(start.timeIntervalSince1970),
            endEpochSeconds: Int64(date(7, hour: 8).timeIntervalSince1970),
            timeZoneIdentifier: "America/New_York")
        let proposal = try WorkTemplate.propose(
            original, on: date(8), timeZoneIdentifier: "America/New_York")
        #expect(!proposal.isResolved && proposal.date("start") == nil)
        #expect(proposal.points.first?.candidates.isEmpty == true)
    }
    @Test func fallFoldRequiresExplicitOccurrence() throws {
        let start = date(31, month: 10, hour: 1).addingTimeInterval(1800)
        let original = try WorkInterval(
            startEpochSeconds: Int64(start.timeIntervalSince1970),
            endEpochSeconds: Int64(date(31, month: 10, hour: 4).timeIntervalSince1970),
            timeZoneIdentifier: "America/New_York")
        let unresolved = try WorkTemplate.propose(
            original, on: date(1, month: 11), timeZoneIdentifier: "America/New_York")
        #expect(!unresolved.isResolved && unresolved.points.first?.candidates.count == 2)
        let first = try WorkTemplate.propose(
            original, on: date(1, month: 11), timeZoneIdentifier: "America/New_York",
            choices: ["start": .first])
        let last = try WorkTemplate.propose(
            original, on: date(1, month: 11), timeZoneIdentifier: "America/New_York",
            choices: ["start": .last])
        #expect(first.isResolved && last.isResolved)
        #expect(
            try #require(last.date("start")).timeIntervalSince(try #require(first.date("start")))
                == 3600)
    }
}

@Suite("Policy version transitions retain old cents")
struct PolicyTransitionTests {
    @Test func datedRoundingUpgradeDoesNotRepriceEarlierSegments() throws {
        let old = try AgreementSnapshot(
            id: "policy", version: "1", displayName: "Legacy",
            hourlyRate: Money(amount: 50, currencyCode: "USD"), regularSchedule: [],
            rounding: MoneyRoundingRule(scope: .legacySegments))
        let updated = try AgreementSnapshot(
            id: "policy", version: "2", displayName: "Reviewed",
            hourlyRate: old.hourlyRate, regularSchedule: [])
        let shifts = try [
            work((2026, 9, 1, 8, 0), (2026, 9, 1, 8, 1)),
            work((2026, 9, 1, 8, 1), (2026, 9, 1, 8, 2)),
            work((2026, 9, 2, 8, 0), (2026, 9, 2, 8, 1)),
            work((2026, 9, 2, 8, 1), (2026, 9, 2, 8, 2)),
        ]
        let result = try PayCalculator().calculate(
            work: shifts, agreement: old,
            changes: [
                AgreementChange(
                    effectiveDate: LocalDate(year: 2026, month: 9, day: 2), agreement: updated)
            ], policy: .highestApplicable)
        #expect(result.total.amount == decimal("3.33"))
        #expect(
            result.components.filter { $0.localDate.day == 1 }.reduce(0) { $0 + $1.amount.amount }
                == decimal("1.66"))
        #expect(
            result.components.filter { $0.localDate.day == 2 }.reduce(0) { $0 + $1.amount.amount }
                == decimal("1.67"))
        let audit = try PaycheckAssessor().assess(
            calculation: result, agreement: old,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: result.total, grossBasis: .wagesOnly))
        #expect(audit.verdict == .needsReview)
        #expect(audit.reviewReasons.contains { $0.contains("legacy segment rounding") })
    }
    @Test func premiumOnlyCentsReconstructTheSameRoundedGross() throws {
        let rules = try agreement(
            hourlyRate: "50",
            dailyOvertimeTiers: [
                DailyOvertimeTier(
                    afterHours: decimal("0.01666666666666666666666666666666666667"),
                    multiplier: decimal("1.5"))
            ])
        let result = try PayCalculator().calculate(
            work: [work((2026, 9, 1, 8, 0), (2026, 9, 1, 8, 3))], agreement: rules,
            policy: .highestApplicable)
        let audit = try PaycheckAssessor().assess(
            calculation: result, agreement: rules,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: result.total,
                amounts: [
                    .regularPay: .zero(currencyCode: "USD"),
                    .overtimePay: .zero(currencyCode: "USD"),
                    .doubleTimePay: .zero(currencyCode: "USD"),
                ],
                grossBasis: .wagesOnly, lineLayout: .basePlusPremium))
        #expect(
            audit.comparisons.filter { $0.field != .grossPay }.reduce(0) { $0 + $1.expected }
                == result.total.amount)
    }
}

@Suite("Callout unsupported interactions do not invent pay")
struct CalloutInteractionTests {
    @Test func regularWorkStartingInsideTheMinimumRequiresReview() throws {
        let event = UUID()
        let call = try WorkInterval(
            startEpochSeconds: 0, endEpochSeconds: 3600, timeZoneIdentifier: "UTC", kind: .callout,
            calloutEventID: event)
        let regular = try WorkInterval(
            startEpochSeconds: 3 * 3600, endEpochSeconds: 11 * 3600, timeZoneIdentifier: "UTC")
        #expect(throws: CalloutReviewError.unsupportedInteraction(event)) {
            try PayCalculator().calculate(
                work: [call, regular],
                agreement: agreement(calloutMinimum: CalloutMinimumRule(minimumHours: 4)),
                policy: .highestApplicable)
        }
    }
    @Test func newMinimumIntroducedDuringCalloutCannotBeSilentlyIgnored() throws {
        let baseline = try agreement()
        let changed = try AgreementSnapshot(
            id: baseline.id, version: "2", displayName: "Changed", hourlyRate: baseline.hourlyRate,
            regularSchedule: [], calloutMinimum: CalloutMinimumRule(minimumHours: 4))
        let call = try work((2026, 9, 1, 23, 0), (2026, 9, 2, 1, 0), kind: .callout)
        #expect(throws: AgreementTimelineError.calloutGuaranteeNeedsReview(call.id)) {
            try PayCalculator().calculate(
                work: [call], agreement: baseline,
                changes: [
                    AgreementChange(
                        effectiveDate: LocalDate(year: 2026, month: 9, day: 2), agreement: changed)
                ], policy: .highestApplicable)
        }
    }
}
