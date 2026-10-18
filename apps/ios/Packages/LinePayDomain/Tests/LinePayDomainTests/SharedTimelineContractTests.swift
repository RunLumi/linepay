import Foundation
import Testing

@testable import LinePayDomain

@Suite("Shared effective-date configured-pay boundaries")
struct SharedTimelineContractTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let cases: [Fixture]
        let refusals: [Fixture]
    }
    private struct Fixture: Decodable {
        let id: String
        let timeZone: String
        let baseline: Rule
        let changes: [Change]
        let work: [Work]
        let expected: Expected?
    }
    private struct Rule: Decodable {
        let id: String
        let version: String
        let currency: String
        let hourlyRate: String
        let regularSchedule: [String]
        let datePremiums: [String]
        let outsideScheduleMultiplier: String
        let dailyOvertimeTiers: [Tier]
        let weekdayPremiums: [Week]
        let calloutMinimumHours: String?
        let perDiemPerWorkDate: String?
        let rounding: MoneyRoundingRule
    }
    private struct Tier: Decodable {
        let afterHours: String
        let multiplier: String
    }
    private struct Week: Decodable {
        let weekday: String
        let multiplier: String
    }
    private struct Change: Decodable {
        let effectiveDate: String
        let agreement: Rule
    }
    private struct Work: Decodable {
        let id: UUID
        let startUTC: String
        let endUTC: String
        let kind: WorkKind
        let calloutEventID: UUID?
        let unpaidBreaks: [Pause]
    }
    private struct Pause: Decodable {
        let id: UUID
        let startUTC: String
        let endUTC: String
    }
    private struct Expected: Decodable {
        let wages: String
        let allowances: String
        let total: String
        let workedSeconds: String
        let appliedVersions: [String]
    }
    private func corpus() throws -> Corpus {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let result = try JSONDecoder().decode(
            Corpus.self,
            from: Data(
                contentsOf: root.appendingPathComponent(
                    "shared/contracts/payroll/effective-date-v1.json")))
        try #require(
            result.format == "com.streamentry.linepay.effective-pay-fixtures" && result.version == 1
                && result.cases.count == 8 && result.refusals.count == 5)
        return result
    }
    private func money(_ value: String, _ currency: String) throws -> Money {
        try Money(amount: StrictDecimal.parse(value, fractionDigits: 8), currencyCode: currency)
    }
    private func agreement(_ rule: Rule) throws -> AgreementSnapshot {
        try #require(
            rule.regularSchedule.isEmpty && rule.datePremiums.isEmpty
                && rule.outsideScheduleMultiplier == "1")
        let weekdays: [String: Weekday] = [
            "sunday": .sunday, "monday": .monday, "tuesday": .tuesday, "wednesday": .wednesday,
            "thursday": .thursday, "friday": .friday, "saturday": .saturday,
        ]
        return try AgreementSnapshot(
            id: rule.id, version: rule.version, displayName: "SYNTHETIC timeline",
            hourlyRate: money(rule.hourlyRate, rule.currency), regularSchedule: [],
            weekdayPremiums: rule.weekdayPremiums.map {
                try WeekdayPremium(
                    weekday: #require(weekdays[$0.weekday]),
                    multiplier: StrictDecimal.parse($0.multiplier, fractionDigits: 8))
            },
            dailyOvertimeTiers: rule.dailyOvertimeTiers.map {
                try DailyOvertimeTier(
                    afterHours: StrictDecimal.parse($0.afterHours, fractionDigits: 8),
                    multiplier: StrictDecimal.parse($0.multiplier, fractionDigits: 8))
            },
            calloutMinimum: rule.calloutMinimumHours.map {
                try CalloutMinimumRule(minimumHours: StrictDecimal.parse($0, fractionDigits: 8))
            },
            flatPerDiem: rule.perDiemPerWorkDate.map {
                try FlatPerDiemRule(amountPerWorkDate: money($0, rule.currency))
            }, rounding: rule.rounding)
    }
    private func date(_ value: String) throws -> LocalDate {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        try #require(parts.count == 3)
        return LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }
    private func epoch(_ value: String) throws -> Int64 {
        try Int64(#require(ISO8601DateFormatter().date(from: value)).timeIntervalSince1970)
    }
    private func calculate(_ fixture: Fixture) throws -> CalculationResult {
        let work = try fixture.work.map { item in
            try WorkInterval(
                id: item.id, startEpochSeconds: epoch(item.startUTC),
                endEpochSeconds: epoch(item.endUTC), timeZoneIdentifier: fixture.timeZone,
                kind: item.kind,
                unpaidBreaks: item.unpaidBreaks.map {
                    try WorkBreak(
                        id: $0.id, startEpochSeconds: epoch($0.startUTC),
                        endEpochSeconds: epoch($0.endUTC))
                }, calloutEventID: item.calloutEventID)
        }
        return try PayCalculator().calculate(
            work: work, agreement: agreement(fixture.baseline),
            changes: fixture.changes.map {
                try AgreementChange(
                    effectiveDate: date($0.effectiveDate), agreement: agreement($0.agreement))
            }, policy: .highestApplicable)
    }
    @Test func eightIndependentEffectiveDatePricesPreserveUnitsAndRuleReferences() throws {
        for fixture in try corpus().cases {
            let result = try calculate(fixture)
            let expected = try #require(fixture.expected)
            let wages = try money(expected.wages, fixture.baseline.currency)
            let allowances = try money(expected.allowances, fixture.baseline.currency)
            let total = try money(expected.total, fixture.baseline.currency)
            #expect(result.expectedWages == wages, "\(fixture.id)")
            #expect(result.expectedAllowances == allowances, "\(fixture.id)")
            #expect(result.total == total, "\(fixture.id)")
            #expect(
                Set(result.components.compactMap(\.appliedAgreement?.version))
                    == Set(expected.appliedVersions), "\(fixture.id)")
            var seconds =
                result.components.filter { $0.category == .workedHours }.compactMap(\.hours).reduce(
                    0, +) * 3_600
            var rounded = Decimal()
            NSDecimalRound(&rounded, &seconds, 0, .plain)
            let expectedSeconds = try StrictDecimal.parse(expected.workedSeconds)
            #expect(rounded == expectedSeconds, "\(fixture.id)")
            #expect(
                result.components.allSatisfy {
                    $0.appliedAgreement?.id == fixture.baseline.id && !$0.explanation.isEmpty
                })
        }
    }
    @Test func ambiguousEffectiveInputsRefuseRatherThanChooseAPrice() throws {
        for fixture in try corpus().refusals {
            #expect(throws: (any Error).self, "\(fixture.id)") { try calculate(fixture) }
        }
    }
}
