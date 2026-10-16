import Foundation
import Testing

@testable import LinePayDomain

@Suite("Platform-neutral configured-pay fixtures")
struct SharedPayrollContractTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let premiumCombination: String
        let cases: [Fixture]
    }
    private struct Fixture: Decodable {
        let id: String
        let timeZone: String
        let agreement: Rules
        let work: [Work]
        let expected: Expected
    }
    private struct Rules: Decodable {
        let id: String
        let version: String
        let currency: String
        let hourlyRate: String
        let outsideScheduleMultiplier: String
        let regularSchedule: [String]
        let dailyOvertimeTiers: [Tier]
        let weekdayPremiums: [WeekPremium]
        let datePremiums: [String]
        let calloutMinimumHours: String?
        let perDiemPerWorkDate: String?
        let rounding: MoneyRoundingRule
    }
    private struct Tier: Decodable {
        let afterHours: String
        let multiplier: String
    }
    private struct WeekPremium: Decodable {
        let weekday: String
        let multiplier: String
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
        let currency: String
        let wages: String
        let allowances: String
        let workedAmount: String
        let calloutGuarantee: String
        let actualWorkedSeconds: Int64
        let multipliers: [String]
        let workDates: [String]
        let reference: Reference
    }
    private struct Reference: Decodable {
        let id: String
        let version: String
    }

    @Test func everySharedFixtureMatchesIndependentAmountsTimeAndReferences() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("shared/contracts/payroll/configured-pay-v1.json")
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        try #require(corpus.format == "com.streamentry.linepay.configured-pay-fixtures")
        try #require(corpus.version == 1 && corpus.premiumCombination == "highestApplicable")
        try #require(corpus.cases.count == 14)
        try #require(Set(corpus.cases.map(\.id)).count == corpus.cases.count)
        let weekdays: [String: Weekday] = [
            "sunday": .sunday, "monday": .monday,
            "tuesday": .tuesday, "wednesday": .wednesday, "thursday": .thursday,
            "friday": .friday, "saturday": .saturday,
        ]
        for fixture in corpus.cases {
            let rules = fixture.agreement
            // v1 intentionally has no schedule/date-premium cases. Never silently ignore new data.
            try #require(rules.regularSchedule.isEmpty && rules.datePremiums.isEmpty)
            let agreement = try AgreementSnapshot(
                id: rules.id, version: rules.version,
                displayName: "SYNTHETIC shared fixture",
                hourlyRate: Money(
                    amount: decimal(rules.hourlyRate), currencyCode: rules.currency),
                regularSchedule: [],
                outsideScheduleMultiplier: decimal(rules.outsideScheduleMultiplier),
                weekdayPremiums: rules.weekdayPremiums.map {
                    try WeekdayPremium(
                        weekday: #require(weekdays[$0.weekday]), multiplier: decimal($0.multiplier))
                },
                dailyOvertimeTiers: rules.dailyOvertimeTiers.map {
                    try DailyOvertimeTier(
                        afterHours: decimal($0.afterHours), multiplier: decimal($0.multiplier))
                },
                calloutMinimum: rules.calloutMinimumHours.map {
                    try CalloutMinimumRule(minimumHours: decimal($0))
                },
                flatPerDiem: rules.perDiemPerWorkDate.map {
                    try FlatPerDiemRule(
                        amountPerWorkDate: Money(amount: decimal($0), currencyCode: rules.currency))
                }, rounding: rules.rounding)
            let work = try fixture.work.map { item in
                try WorkInterval(
                    id: item.id, startEpochSeconds: epoch(item.startUTC),
                    endEpochSeconds: epoch(item.endUTC), timeZoneIdentifier: fixture.timeZone,
                    kind: item.kind,
                    unpaidBreaks: item.unpaidBreaks.map { pause in
                        try WorkBreak(
                            id: pause.id, startEpochSeconds: epoch(pause.startUTC),
                            endEpochSeconds: epoch(pause.endUTC))
                    }, calloutEventID: item.calloutEventID)
            }
            let result = try PayCalculator().calculate(
                work: work, agreement: agreement, policy: .highestApplicable)
            let expected = fixture.expected
            let wages = try decimal(expected.wages)
            let allowances = try decimal(expected.allowances)
            let workedAmount = try decimal(expected.workedAmount)
            let guarantee = try decimal(expected.calloutGuarantee)
            let multipliers = Set(try expected.multipliers.map(decimal))
            #expect(result.expectedWages.currencyCode == expected.currency, "\(fixture.id)")
            #expect(result.expectedWages.amount == wages, "\(fixture.id)")
            #expect(
                result.expectedAllowances.amount == allowances, "\(fixture.id)")
            #expect(
                result.total.amount == wages + allowances,
                "\(fixture.id)")
            let worked = result.components.filter { $0.category == .workedHours }
            #expect(
                Set(worked.compactMap(\.workIntervalID)) == Set(work.map(\.id)), "\(fixture.id)")
            #expect(
                worked.reduce(Decimal(0)) { $0 + $1.amount.amount }
                    == workedAmount, "\(fixture.id)")
            #expect(
                result.components.filter { $0.category == .calloutGuarantee }.reduce(Decimal(0)) {
                    $0 + $1.amount.amount
                } == guarantee, "\(fixture.id)")
            var seconds = worked.compactMap(\.hours).reduce(0, +) * 3_600
            var rounded = Decimal()
            NSDecimalRound(&rounded, &seconds, 0, .plain)
            #expect(rounded == Decimal(expected.actualWorkedSeconds), "\(fixture.id)")
            #expect(
                Set(worked.compactMap(\.multiplier)) == multipliers,
                "\(fixture.id)")
            let dates = Set(
                worked.map {
                    String(
                        format: "%04d-%02d-%02d", $0.localDate.year,
                        $0.localDate.month, $0.localDate.day)
                })
            #expect(dates == Set(expected.workDates), "\(fixture.id)")
            #expect(
                result.components.allSatisfy {
                    $0.appliedAgreement?.id == expected.reference.id
                        && $0.appliedAgreement?.version == expected.reference.version
                        && !$0.explanation.isEmpty && !($0.ruleKeys ?? []).isEmpty
                }, "\(fixture.id)")
        }
    }

    private func decimal(_ text: String) throws -> Decimal {
        try #require(text.range(of: #"^\d+(?:\.\d+)?$"#, options: .regularExpression) != nil)
        return try StrictDecimal.parse(text, fractionDigits: 8)
    }
    private func epoch(_ text: String) throws -> Int64 {
        try #require(text.hasSuffix("Z"))
        let date = try #require(ISO8601DateFormatter().date(from: text))
        let value = date.timeIntervalSince1970
        try #require(value.isFinite && value.rounded() == value)
        return Int64(value)
    }
}
