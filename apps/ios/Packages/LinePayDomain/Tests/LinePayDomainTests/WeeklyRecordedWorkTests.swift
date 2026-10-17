import Foundation
import Testing

@testable import LinePayDomain

@Suite("Exact recorded workweek boundaries")
struct WeeklyRecordedWorkTests {
    private let monday = LocalDate(year: 2026, month: 9, day: 7)
    private func epoch(_ text: String) throws -> Int64 {
        try Int64(#require(ISO8601DateFormatter().date(from: text)).timeIntervalSince1970)
    }
    private func rule(_ day: Weekday = .monday) throws -> WeeklyOvertimeRule {
        try WeeklyOvertimeRule(workweekStart: day, applicability: .coveredNonexemptHourly)
    }
    private func agreement(_ version: String = "1", rate: Decimal = 50, weekly: Bool = true) throws
        -> AgreementSnapshot
    {
        try AgreementSnapshot(
            id: "synthetic", version: version, displayName: "Synthetic",
            hourlyRate: Money(amount: rate, currencyCode: "USD"), regularSchedule: [],
            weeklyOvertime: weekly ? rule() : nil)
    }
    private func entry(
        _ start: String, _ end: String, breaks: [(String, String)] = [], zone: String = "UTC"
    ) throws -> WorkInterval {
        try WorkInterval(
            startEpochSeconds: epoch(start), endEpochSeconds: epoch(end), timeZoneIdentifier: zone,
            unpaidBreaks: breaks.map {
                try WorkBreak(startEpochSeconds: epoch($0.0), endEpochSeconds: epoch($0.1))
            })
    }
    private func slices(_ work: [WorkInterval], changes: [AgreementChange] = []) throws
        -> [WeeklyRecordedSlice]
    {
        try WeeklyRecordedWork.slices(
            weekStart: monday, startEpochSeconds: 1_788_739_200, rule: rule(),
            timeZoneIdentifier: "UTC",
            periods: [
                WeeklyStoredPeriod(
                    id: UUID(), timeZoneIdentifier: "UTC", agreement: agreement(), changes: changes,
                    work: work)
            ])
    }
    @Test func bothBoundaryTailsAndTheirBreakPortionsAreCountedWithoutChangingTheOriginal() throws {
        let first = try entry(
            "2026-09-06T22:00:00Z", "2026-09-07T04:00:00Z",
            breaks: [("2026-09-06T23:30:00Z", "2026-09-07T00:30:00Z")])
        let last = try entry(
            "2026-09-13T22:00:00Z", "2026-09-14T04:00:00Z",
            breaks: [("2026-09-13T23:30:00Z", "2026-09-14T00:30:00Z")])
        let original = [first, last]
        let result = try slices(original)
        #expect(result.reduce(Int64(0)) { $0 + $1.workedSeconds } == 5 * 3_600)
        let expectedStart = try epoch("2026-09-07T00:30:00Z")
        #expect(result.first?.startEpochSeconds == expectedStart)
        let expectedEnd = try epoch("2026-09-13T23:30:00Z")
        #expect(result.last?.endEpochSeconds == expectedEnd)
        #expect(original == [first, last])
    }
    @Test func rateChangesUseEachWorkedDateAfterBreakRemoval() throws {
        let work = try entry(
            "2026-09-07T22:00:00Z", "2026-09-08T04:00:00Z",
            breaks: [("2026-09-07T23:30:00Z", "2026-09-08T00:30:00Z")])
        let result = try slices(
            [work],
            changes: [
                AgreementChange(
                    effectiveDate: LocalDate(year: 2026, month: 9, day: 8),
                    agreement: agreement("2", rate: 60))
            ])
        #expect(result.map(\.workedSeconds) == [5400, 12600])
        #expect(result.map(\.agreement.version) == ["1", "2"])
        #expect(result.map(\.agreement.hourlyRate.amount) == [50, 60])
    }
    @Test func unrelatedOldRulesDoNotBlockButRelevantMixedScopeAndOverlapDo() throws {
        let relevant = try entry("2026-09-07T08:00:00Z", "2026-09-07T16:00:00Z")
        let period = WeeklyStoredPeriod(
            id: UUID(), timeZoneIdentifier: "UTC", agreement: try agreement(), work: [relevant])
        let old = WeeklyStoredPeriod(
            id: UUID(), timeZoneIdentifier: "UTC", agreement: try agreement(weekly: false),
            work: [try entry("2026-08-01T08:00:00Z", "2026-08-01T16:00:00Z")])
        let result = try WeeklyRecordedWork.slices(
            weekStart: monday, startEpochSeconds: 1_788_739_200, rule: rule(),
            timeZoneIdentifier: "UTC", periods: [old, period])
        #expect(result.reduce(Int64(0)) { $0 + $1.workedSeconds } == 28_800)
        let mixed = WeeklyStoredPeriod(
            id: UUID(), timeZoneIdentifier: "UTC", agreement: try agreement(weekly: false),
            work: [relevant])
        #expect(throws: (any Error).self) {
            try WeeklyRecordedWork.slices(
                weekStart: monday, startEpochSeconds: 1_788_739_200, rule: rule(),
                timeZoneIdentifier: "UTC", periods: [mixed])
        }
        let overlap = try entry("2026-09-07T15:00:00Z", "2026-09-07T17:00:00Z")
        #expect(throws: (any Error).self) { try slices([relevant, overlap]) }
        #expect(throws: (any Error).self) { try slices([relevant, relevant]) }
        var raw = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(relevant)) as? [String: Any])
        raw["unpaidBreaks"] = [
            [
                "id": UUID().uuidString,
                "startEpochSeconds": relevant.startEpochSeconds + 3600,
                "endEpochSeconds": relevant.startEpochSeconds + 1800,
            ]
        ]
        let invalid = try JSONDecoder().decode(
            WorkInterval.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(throws: (any Error).self) { try slices([invalid]) }
    }
    @Test func aDSTWeekUsesElapsedSecondsAndWrongStartDatesRefuse() throws {
        let work = try entry(
            "2026-03-08T06:00:00Z", "2026-03-08T08:00:00Z", zone: "America/New_York")
        let nextMonday = try entry(
            "2026-03-09T04:00:00Z", "2026-03-09T06:00:00Z", zone: "America/New_York")
        let result = try WeeklyRecordedWork.slices(
            weekStart: LocalDate(year: 2026, month: 3, day: 2),
            startEpochSeconds: epoch("2026-03-02T05:00:00Z"), rule: rule(),
            timeZoneIdentifier: "America/New_York",
            periods: [
                WeeklyStoredPeriod(
                    id: UUID(), timeZoneIdentifier: "America/New_York", agreement: agreement(),
                    work: [work, nextMonday])
            ])
        #expect(result.reduce(Int64(0)) { $0 + $1.workedSeconds } == 10800)
        let expectedEnd = try epoch("2026-03-09T05:00:00Z")
        #expect(result.last?.endEpochSeconds == expectedEnd)
        #expect(throws: WeeklyRegularRateError.invalidWorkweek) {
            try WeeklyRecordedWork.slices(
                weekStart: LocalDate(year: 2026, month: 9, day: 8),
                startEpochSeconds: 1_788_739_200, rule: rule(),
                timeZoneIdentifier: "UTC", periods: [])
        }
    }
    @Test func fixedFallWeekExcludesTheExtraCalendarHourAndNonMidnightStartsAreExplicit() throws {
        let work = try entry(
            "2026-11-02T03:00:00Z", "2026-11-02T05:00:00Z", zone: "America/New_York")
        let fall = try WeeklyRecordedWork.slices(
            weekStart: LocalDate(year: 2026, month: 10, day: 26),
            startEpochSeconds: epoch("2026-10-26T04:00:00Z"), rule: rule(),
            timeZoneIdentifier: "America/New_York",
            periods: [
                WeeklyStoredPeriod(
                    id: UUID(), timeZoneIdentifier: "America/New_York", agreement: agreement(),
                    work: [work])
            ])
        #expect(fall.reduce(Int64(0)) { $0 + $1.workedSeconds } == 3600)
        let expectedFallEnd = try epoch("2026-11-02T04:00:00Z")
        #expect(fall.last?.endEpochSeconds == expectedFallEnd)
        let afternoon = try entry("2026-09-08T17:00:00Z", "2026-09-08T19:00:00Z")
        let actual = try WeeklyRecordedWork.slices(
            weekStart: LocalDate(year: 2026, month: 9, day: 8),
            startEpochSeconds: epoch("2026-09-08T18:00:00Z"), rule: rule(),
            timeZoneIdentifier: "UTC",
            periods: [
                WeeklyStoredPeriod(
                    id: UUID(), timeZoneIdentifier: "UTC", agreement: agreement(), work: [afternoon]
                )
            ])
        #expect(actual.reduce(Int64(0)) { $0 + $1.workedSeconds } == 3600)
    }
}
