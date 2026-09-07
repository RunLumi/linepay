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
        let additionalBreak = try #require(draft.additionalBreaks.first)
        #expect(clock(additionalBreak.start) == (6, 0))
        #expect(clock(additionalBreak.end) == (6, 15))
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
        let maybeProposal = try RepeatWorkDraft.proposal(
            for: draft, timeZoneIdentifier: zoneID)
        let proposal = try #require(maybeProposal)
        let start = try #require(proposal.points.first { $0.key == "start" })

        #expect(draft.templateUnresolved == true)
        #expect(start.candidates.isEmpty)
        #expect(start.chosen == nil)
        #expect(
            !RepeatWorkDraft.canConfirmManualReview(
                draft, timeZoneIdentifier: zoneID, window: nil))

        draft.start = instant(2026, 3, 8, 3, 30)
        RepeatWorkDraft.markManualReview("start", draft: &draft)
        #expect(
            RepeatWorkDraft.canConfirmManualReview(
                draft, timeZoneIdentifier: zoneID, window: nil))
        try RepeatWorkDraft.confirmManualReview(
            &draft, timeZoneIdentifier: zoneID, window: nil)
        #expect(draft.templateUnresolved == false)
        #expect(draft.templateSource == nil)
        #expect(draft.repeatedTimeChoices == nil)
    }

    @Test func everyNonexistentCopiedFactMustBeReviewedBeforeManualConfirmation() throws {
        let source = try entry(
            start: instant(2026, 3, 7, 1, 0),
            end: instant(2026, 3, 7, 4, 0),
            breaks: [
                (instant(2026, 3, 7, 2, 15), instant(2026, 3, 7, 2, 45))
            ])
        var draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 3, 8, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        let maybeProposal = try RepeatWorkDraft.proposal(
            for: draft, timeZoneIdentifier: zoneID)
        let proposal = try #require(maybeProposal)
        #expect(proposal.points.filter { $0.candidates.isEmpty }.count == 2)

        // Choosing the same normalized-looking 03:15 value still counts only because the user
        // action is explicitly recorded, never because it happens to differ from a placeholder.
        draft.breakStart = instant(2026, 3, 8, 3, 15)
        RepeatWorkDraft.markManualReview("break.0.start", draft: &draft)
        #expect(
            !RepeatWorkDraft.canConfirmManualReview(
                draft, timeZoneIdentifier: zoneID, window: nil))
        #expect(throws: RepeatWorkReviewError.self) {
            try RepeatWorkDraft.confirmManualReview(
                &draft, timeZoneIdentifier: zoneID, window: nil)
        }

        let restored = try JSONDecoder().decode(
            WorkDraft.self, from: JSONEncoder().encode(draft))
        #expect(
            !RepeatWorkDraft.canConfirmManualReview(
                restored, timeZoneIdentifier: zoneID, window: nil))
        draft = restored
        draft.breakEnd = instant(2026, 3, 8, 3, 45)
        RepeatWorkDraft.markManualReview("break.0.end", draft: &draft)
        #expect(
            RepeatWorkDraft.canConfirmManualReview(
                draft, timeZoneIdentifier: zoneID, window: nil))
        try RepeatWorkDraft.confirmManualReview(
            &draft, timeZoneIdentifier: zoneID, window: nil)
        #expect(draft.templateUnresolved == false)
    }

    @Test func changingTheRepeatDateClearsEarlierReviewDecisions() throws {
        let source = try entry(
            start: instant(2026, 3, 7, 2, 30),
            end: instant(2026, 3, 7, 8, 0))
        var draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: instant(2026, 3, 8, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        RepeatWorkDraft.markManualReview("start", draft: &draft)
        #expect(draft.repeatedTimeChoices?.keys.contains("manual:start") == true)

        _ = try RepeatWorkDraft.move(
            &draft,
            to: instant(2026, 3, 9, 0, 0),
            timeZoneIdentifier: zoneID,
            window: nil)
        #expect(draft.repeatedTimeChoices?.isEmpty == true)
        #expect(draft.templateUnresolved == false)
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
        let maybeProposal = try RepeatWorkDraft.proposal(
            for: firstDraft, timeZoneIdentifier: zoneID)
        let unresolved = try #require(maybeProposal)
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
        let maybeProposal = try RepeatWorkDraft.proposal(
            for: draft, timeZoneIdentifier: zoneID)
        let proposal = try #require(maybeProposal)

        #expect(proposal.isResolved)
        #expect(draft.templateUnresolved == true)
        #expect(!window.contains(start: draft.start, end: draft.end))
        #expect(
            !RepeatWorkDraft.canConfirmManualReview(
                draft, timeZoneIdentifier: zoneID, window: window))
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
        let maybeProposal = try RepeatWorkDraft.proposal(
            for: restored, timeZoneIdentifier: zoneID)
        let proposal = try #require(maybeProposal)

        #expect(restored.templateUnresolved == true)
        #expect(restored.templateSource == draft.templateSource)
        #expect(proposal.points.first { $0.key == "start" }?.candidates.count == 2)
    }

    @Test func explicitPayrollZoneDoesNotDependOnHowTheSelectedDayWasConstructed() throws {
        let source = try entry(
            start: instant(2026, 3, 7, 7, 0),
            end: instant(2026, 3, 7, 15, 0),
            breaks: [(instant(2026, 3, 7, 12, 0), instant(2026, 3, 7, 12, 30))])
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let sameNewYorkMidnight = try #require(
            utc.date(
                from: DateComponents(
                    timeZone: utc.timeZone,
                    year: 2026,
                    month: 3,
                    day: 8,
                    hour: 5)))
        let draft = try RepeatWorkDraft.make(
            source: source,
            periodID: UUID(),
            day: sameNewYorkMidnight,
            timeZoneIdentifier: zoneID,
            window: nil)

        #expect(clock(draft.start) == (7, 0))
        #expect(clock(draft.end) == (15, 0))
        #expect(clock(draft.breakStart) == (12, 0))
        #expect(clock(draft.breakEnd) == (12, 30))
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
