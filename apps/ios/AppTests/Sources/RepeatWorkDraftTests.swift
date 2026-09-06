import Foundation
import LinePayDomain
import SwiftUI
import Testing
import ViewInspector

@testable import LinePay

@Suite("Repeat shift app mapping")
@MainActor
struct RepeatWorkDraftTests {
    private let zoneID = "America/New_York"

    @Test func springForwardPreservesEveryBreakWallTime() throws {
        let source = try entry(
            start: instant(2026, 3, 7, 0, 0),
            end: instant(2026, 3, 7, 8, 0),
            breaks: [
                (instant(2026, 3, 7, 4, 0), instant(2026, 3, 7, 4, 30)),
                (instant(2026, 3, 7, 6, 0), instant(2026, 3, 7, 6, 15)),
            ])
        let draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 3, 8, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)

        #expect(draft.templateUnresolved == false)
        #expect(clock(draft.start) == (0, 0))
        #expect(clock(draft.end) == (8, 0))
        #expect(clock(draft.breakStart) == (4, 0))
        #expect(clock(draft.breakEnd) == (4, 30))
        #expect(draft.additionalBreaks.count == 1)
        #expect(clock(try #require(draft.additionalBreaks.first).start) == (6, 0))
        #expect(clock(try #require(draft.additionalBreaks.first).end) == (6, 15))
        #expect(draft.end.timeIntervalSince(draft.start) == 7 * 3_600)
    }

    @Test func nonexistentCopiedTimeStaysUnresolvedUntilExplicitManualReview() throws {
        let source = try entry(
            start: instant(2026, 3, 7, 2, 30),
            end: instant(2026, 3, 7, 8, 0))
        var draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 3, 8, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        let proposal = try #require(
            RepeatWorkDraft.proposal(for: draft, timeZoneIdentifier: zoneID))
        let start = try #require(proposal.points.first { $0.key == "start" })

        #expect(draft.templateUnresolved == true)
        #expect(start.candidates.isEmpty)
        #expect(start.chosen == nil)

        RepeatWorkDraft.confirmManualReview(&draft)
        #expect(draft.templateUnresolved == false)
        #expect(draft.templateSource == nil)
        #expect(draft.repeatedTimeChoices == nil)
    }

    @Test func fallFoldRequiresAnOccurrenceAndKeepsChoicesDistinct() throws {
        let source = try entry(
            start: instant(2026, 10, 31, 1, 30),
            end: instant(2026, 10, 31, 4, 0))
        var firstDraft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 11, 1, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        let unresolved = try #require(
            RepeatWorkDraft.proposal(for: firstDraft, timeZoneIdentifier: zoneID))
        #expect(firstDraft.templateUnresolved == true)
        #expect(unresolved.points.first { $0.key == "start" }?.candidates.count == 2)

        _ = try RepeatWorkDraft.choose(
            .first,
            for: "start",
            draft: &firstDraft,
            timeZoneIdentifier: zoneID,
            window: nil)
        #expect(firstDraft.templateUnresolved == false)

        var secondDraft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 11, 1, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        _ = try RepeatWorkDraft.choose(
            .last,
            for: "start",
            draft: &secondDraft,
            timeZoneIdentifier: zoneID,
            window: nil)
        #expect(secondDraft.templateUnresolved == false)
        #expect(secondDraft.start.timeIntervalSince(firstDraft.start) == 3_600)
    }

    @Test func resolvedTemplateStillBlocksWhenItLeavesTheCurrentPeriod() throws {
        let source = try entry(
            start: instant(2026, 3, 7, 22, 0),
            end: instant(2026, 3, 8, 2, 0))
        let start = instant(2026, 3, 8, 0, 0)
        let end = instant(2026, 3, 9, 0, 0)
        let window = PayPeriodWindow(
            startEpochSeconds: Int64(start.timeIntervalSince1970),
            endEpochSeconds: Int64(end.timeIntervalSince1970),
            cadence: .manual)
        let draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: start,
            timeZoneIdentifier: zoneID,
            window: window)
        let proposal = try #require(
            RepeatWorkDraft.proposal(for: draft, timeZoneIdentifier: zoneID))

        #expect(proposal.isResolved)
        #expect(draft.templateUnresolved == true)
        #expect(!window.contains(start: draft.start, end: draft.end))
    }

    @Test func interruptedRepeatDraftRoundTripsItsReviewState() throws {
        let source = try entry(
            start: instant(2026, 10, 31, 1, 30),
            end: instant(2026, 10, 31, 4, 0))
        let draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 11, 1, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        let restored = try JSONDecoder().decode(
            WorkDraft.self, from: JSONEncoder().encode(draft))
        let proposal = try #require(
            RepeatWorkDraft.proposal(for: restored, timeZoneIdentifier: zoneID))

        #expect(restored.templateUnresolved == true)
        #expect(restored.templateSource == draft.templateSource)
        #expect(proposal.points.first { $0.key == "start" }?.candidates.count == 2)
    }

    @Test func nativeRepeatScreenExplainsGapAndDisablesSave() throws {
        let model = AppModel()
        var profile = PayProfileDraft()
        profile.hourlyRate = "50"
        profile.timeZoneIdentifier = zoneID
        profile.preferredCadence = .manual
        profile.periodStartDate = instant(2026, 3, 8, 0, 0)
        profile.manualPeriodEndDate = instant(2026, 3, 8, 12, 0)
        try model.saveProfile(profile)

        let source = try entry(
            start: instant(2026, 3, 7, 2, 30),
            end: instant(2026, 3, 7, 8, 0))
        let view = RepeatWorkView(model: model, source: source)
        let text = try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }.joined(
            separator: "\n")

        #expect(text.contains("Repeated shift needs your review"))
        #expect(text.contains("does not exist"))
        #expect(
            try view.inspect().find(viewWithAccessibilityIdentifier: "repeat.save").button()
                .isDisabled())
    }

    private func entry(
        start: Date,
        end: Date,
        breaks: [(Date, Date)] = []
    ) throws -> WorkEntry {
        let pauses = try breaks.map {
            try WorkBreak(
                startEpochSeconds: Int64($0.0.timeIntervalSince1970.rounded()),
                endEpochSeconds: Int64($0.1.timeIntervalSince1970.rounded()))
        }
        return WorkEntry(
            interval: try WorkInterval(
                startEpochSeconds: Int64(start.timeIntervalSince1970.rounded()),
                endEpochSeconds: Int64(end.timeIntervalSince1970.rounded()),
                timeZoneIdentifier: zoneID,
                kind: .regular,
                unpaidBreaks: pauses),
            note: "Synthetic repeat")
    }

    private func instant(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zoneID)!
        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute))!
    }

    private func clock(_ date: Date) -> (Int, Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zoneID)!
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? -1, components.minute ?? -1)
    }
}
