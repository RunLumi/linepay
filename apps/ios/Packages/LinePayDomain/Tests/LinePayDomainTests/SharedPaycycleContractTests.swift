import Foundation
import Testing

@testable import LinePayDomain

@Suite("Shared local-calendar paycycle boundaries")
struct SharedPaycycleContractTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let cases: [Fixture]
        let refusals: [Fixture]
    }
    private struct Fixture: Decodable {
        let id: String
        let input: Input
        let expected: Expected?
    }
    private struct Input: Decodable {
        let cadence: CalendarPaycycleCadence
        let startDate: String
        let manualEndDate: String
        let timeZone: String
    }
    private struct Expected: Decodable {
        let startDate: String
        let endDate: String
        let endExclusiveDate: String
        let startUTC: String
        let endExclusiveUTC: String
        let elapsedSeconds: Int64
    }
    private func corpus() throws -> Corpus {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let result = try JSONDecoder().decode(
            Corpus.self,
            from: Data(
                contentsOf: root.appendingPathComponent(
                    "shared/contracts/paycycles/calendar-v1.json")))
        try #require(
            result.format == "com.streamentry.linepay.calendar-paycycle-fixtures"
                && result.version == 1 && result.cases.count == 14 && result.refusals.count == 7)
        return result
    }
    private func local(_ text: String) throws -> LocalDate {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        try #require(parts.count == 3)
        return LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }
    private func instant(_ text: String) throws -> Int64 {
        try Int64(#require(ISO8601DateFormatter().date(from: text)).timeIntervalSince1970)
    }
    private func calculate(_ input: Input) throws -> CalendarPaycycleWindow {
        try CalendarPaycycle.window(
            cadence: input.cadence, start: local(input.startDate),
            manualEnd: local(input.manualEndDate), timeZoneIdentifier: input.timeZone)
    }
    @Test func allFourCadencesUseIndependentLocalDateAndInstantBoundaries() throws {
        for fixture in try corpus().cases {
            let actual = try calculate(fixture.input)
            let expected = try #require(fixture.expected)
            let start = try local(expected.startDate)
            let end = try local(expected.endDate)
            let exclusive = try local(expected.endExclusiveDate)
            let firstInstant = try instant(expected.startUTC)
            let finalInstant = try instant(expected.endExclusiveUTC)
            #expect(
                actual.start == start && actual.lastDate == end && actual.endExclusive == exclusive,
                "\(fixture.id)")
            #expect(
                actual.startEpochSeconds == firstInstant && actual.endEpochSeconds == finalInstant,
                "\(fixture.id)")
            #expect(
                actual.endEpochSeconds - actual.startEpochSeconds == expected.elapsedSeconds,
                "\(fixture.id)")
            #expect(actual.timeZoneIdentifier == fixture.input.timeZone)
        }
    }
    @Test func invalidDatesCutoffsAndZonesRefuseInsteadOfNormalizing() throws {
        for fixture in try corpus().refusals {
            #expect(throws: (any Error).self, "\(fixture.id)") { try calculate(fixture.input) }
        }
    }
}
