import Foundation
import Testing

@testable import LinePayDomain

@Suite("Shared configured earnings and hours")
struct SharedLineAssessmentTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let cases: [Fixture]
    }
    private struct Fixture: Decodable {
        let id: String
        let arithmetic: String
        let agreement: Rules
        let changes: [Change]
        let work: [Work]
        let facts: Facts
        let lines: Lines
        let expected: Expected
    }
    private struct Rules: Decodable {
        let id: String
        let version: String
        let currency: String
        let hourlyRate: String
        let outsideScheduleMultiplier: String
        let regularSchedule: [String]
        let weekdayPremiums: [String]
        let datePremiums: [String]
        let dailyOvertimeTiers: [Tier]
        let calloutMinimumHours: String?
        let perDiemPerWorkDate: String?
        let rounding: MoneyRoundingRule
    }
    private struct Tier: Decodable {
        let afterHours: String
        let multiplier: String
    }
    private struct Change: Decodable {
        let effectiveDate: String
        let agreement: Rules
    }
    private struct Work: Decodable {
        let id: UUID
        let startUTC: String
        let endUTC: String
        let timeZone: String
        let kind: WorkKind
        let calloutEventID: UUID?
        let unpaidBreaks: [Pause]
    }
    private struct Pause: Decodable {
        let id: UUID
        let startUTC: String
        let endUTC: String
    }
    private struct Facts: Decodable {
        let completeWork: Bool
        let grossBasis: PaystubGrossBasis
        let paidGross: String
        let paidPerDiem: String?
        let unreviewedFields: Bool
        let unsupportedRules: Bool
        let weeklyReviewPending: Bool
    }
    private struct Lines: Decodable {
        let layout: PaystubLineLayout
        let hoursBasis: PaystubHoursBasis
        let guaranteeLayout: PaystubGuaranteeLayout
        let completeEarnings: Bool
        let amounts: [String: String]
        let hours: [String: String]
    }
    private struct Expected: Decodable {
        let verdict: PaycheckVerdict
        let gross: String
        let difference: String
        let comparisons: [Row]
    }
    private struct Row: Decodable {
        let field: PaystubField
        let unit: ComparisonUnit
        let expected: String
        let paid: String
        let difference: String
        let source: String
    }

    private func localDate(_ value: String) -> LocalDate {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { preconditionFailure("Invalid local date fixture: \(value)") }
        return LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }

    private func epoch(_ value: String) throws -> Int64 {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            throw DomainValidationError.invalidWorkInterval
        }
        return Int64(date.timeIntervalSince1970.rounded())
    }

    @Test func sharedIndependentPricesAndSourceComponents() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let corpus = try JSONDecoder().decode(
            Corpus.self,
            from: Data(
                contentsOf:
                    root.appendingPathComponent(
                        "shared/contracts/reconciliation/configured-lines-v1.json")))
        try #require(corpus.format == "com.streamentry.linepay.configured-line-fixtures")
        try #require(corpus.version == 1 && corpus.cases.count == 29)
        try #require(Set(corpus.cases.map(\.id)).count == 29)
        for fixture in corpus.cases {
            func money(_ value: String) -> Money {
                Money(amount: decimal(value), currencyCode: fixture.agreement.currency)
            }
            func rules(_ input: Rules) throws -> AgreementSnapshot {
                try #require(
                    input.regularSchedule.isEmpty && input.weekdayPremiums.isEmpty
                        && input.datePremiums.isEmpty)
                return try AgreementSnapshot(
                    id: input.id, version: input.version, displayName: "SYNTHETIC line fixture",
                    hourlyRate: Money(
                        amount: decimal(input.hourlyRate), currencyCode: input.currency),
                    regularSchedule: [],
                    outsideScheduleMultiplier: decimal(input.outsideScheduleMultiplier),
                    dailyOvertimeTiers: input.dailyOvertimeTiers.map {
                        try DailyOvertimeTier(
                            afterHours: decimal($0.afterHours), multiplier: decimal($0.multiplier))
                    },
                    calloutMinimum: input.calloutMinimumHours.map {
                        try CalloutMinimumRule(minimumHours: decimal($0))
                    },
                    flatPerDiem: input.perDiemPerWorkDate.map {
                        FlatPerDiemRule(amountPerWorkDate: money($0))
                    },
                    weeklyOvertime: fixture.facts.weeklyReviewPending
                        ? WeeklyOvertimeRule(
                            workweekStart: .monday, applicability: .coveredNonexemptHourly) : nil,
                    rounding: input.rounding)
            }
            let agreement = try rules(fixture.agreement)
            let work = try fixture.work.map { row in
                try WorkInterval(
                    id: row.id, startEpochSeconds: epoch(row.startUTC),
                    endEpochSeconds: epoch(row.endUTC),
                    timeZoneIdentifier: row.timeZone, kind: row.kind,
                    unpaidBreaks: row.unpaidBreaks.map {
                        try WorkBreak(
                            id: $0.id, startEpochSeconds: epoch($0.startUTC),
                            endEpochSeconds: epoch($0.endUTC))
                    },
                    calloutEventID: row.calloutEventID)
            }
            let changes = try fixture.changes.map {
                AgreementChange(
                    effectiveDate: localDate($0.effectiveDate),
                    agreement: try rules($0.agreement))
            }
            let calculation = try PayCalculator().calculate(
                work: work, agreement: agreement, changes: changes, policy: .highestApplicable)
            var amounts: [PaystubField: Money] = [:]
            for (key, value) in fixture.lines.amounts {
                amounts[try #require(PaystubField(rawValue: key))] = money(value)
            }
            if let paid = fixture.facts.paidPerDiem { amounts[.perDiemPay] = money(paid) }
            var hours: [PaystubField: Decimal] = [:]
            for (key, value) in fixture.lines.hours {
                hours[try #require(PaystubField(rawValue: key))] = decimal(value)
            }
            let facts = PaycheckFacts(
                hasCompleteWork: fixture.facts.completeWork,
                grossPay: money(fixture.facts.paidGross),
                amounts: amounts, hours: hours, grossBasis: fixture.facts.grossBasis,
                lineLayout: fixture.lines.layout,
                hoursBasis: fixture.lines.hoursBasis,
                guaranteeLayout: fixture.lines.guaranteeLayout,
                hasUnreviewedFields: fixture.facts.unreviewedFields,
                hasUnsupportedRules: fixture.facts.unsupportedRules,
                hasCompleteEarningsLines: fixture.lines.completeEarnings)
            let result = try PaycheckAssessor().assess(
                calculation: calculation, agreement: agreement, facts: facts)
            #expect(
                result.verdict == fixture.expected.verdict, "\(fixture.id): \(fixture.arithmetic)")
            #expect(
                result.expectedGross?.amount == decimal(fixture.expected.gross),
                "\(fixture.id)")
            #expect(
                result.difference?.amount == decimal(fixture.expected.difference),
                "\(fixture.id)")
            #expect(
                result.comparisons.count == fixture.expected.comparisons.count, "\(fixture.id)")
            for (actual, expected) in zip(result.comparisons, fixture.expected.comparisons) {
                #expect(actual.field == expected.field, "\(fixture.id) field")
                #expect(actual.unit == expected.unit, "\(fixture.id) unit")
                let displayed: Decimal
                if actual.unit == .hours {
                    displayed =
                        Money(
                            amount: actual.expected, currencyCode: fixture.agreement.currency
                        ).rounded(using: MoneyRoundingRule(scale: 4)).amount
                } else {
                    displayed = actual.expected
                }
                #expect(
                    displayed == decimal(expected.expected),
                    "\(fixture.id) \(expected.field.rawValue)")
                #expect(actual.paid == decimal(expected.paid), "\(fixture.id)")
                #expect(actual.difference == decimal(expected.difference), "\(fixture.id)")
                let wages = calculation.components.filter {
                    $0.category != PayComponentCategory.perDiem
                }
                let included = wages.filter {
                    $0.category == PayComponentCategory.workedHours
                        || fixture.lines.guaranteeLayout == .includedInHourlyLines
                }
                let hourParts =
                    fixture.lines.hoursBasis == .actualWork
                    ? wages.filter { $0.category == PayComponentCategory.workedHours } : included
                let hourly = expected.unit == .hours ? hourParts : included
                let selected: [PayComponent]
                switch expected.source {
                case "allCash": selected = calculation.components
                case "allWages": selected = wages
                case "allowance":
                    selected = calculation.components.filter {
                        $0.category == PayComponentCategory.perDiem
                    }
                case "guarantees":
                    selected = wages.filter { $0.category == PayComponentCategory.calloutGuarantee }
                case "allHourly": selected = included
                case "allWorked": selected = hourParts
                default:
                    let multiplier = try #require(
                        [
                            "regular": Decimal(1), "overtime": Decimal(string: "1.5")!,
                            "doubleTime": Decimal(2),
                        ][expected.source])
                    selected = hourly.filter { ($0.multiplier ?? 1) == multiplier }
                }
                #expect(actual.componentIDs == selected.map(\.id), "\(fixture.id) source trace")
            }
            if result.verdict == PaycheckVerdict.needsReview {
                #expect(!result.reviewReasons.isEmpty)
            }
        }
    }
}
