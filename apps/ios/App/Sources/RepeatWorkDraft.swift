import Foundation
import LinePayDomain

enum RepeatWorkDraft {
    static func make(
        source: WorkEntry,
        periodID: UUID,
        day: Date,
        timeZoneIdentifier: String,
        window: PayPeriodWindow?
    ) throws -> WorkDraft {
        let zone = try timeZone(timeZoneIdentifier)
        let targetDay = clampedDay(day, zone: zone, window: window)
        let sourceStart = Date(
            timeIntervalSince1970: TimeInterval(source.interval.startEpochSeconds))
        let sourceEnd = Date(
            timeIntervalSince1970: TimeInterval(source.interval.endEpochSeconds))
        let firstBreak = source.interval.unpaidBreaks.first
        var draft = WorkDraft(
            periodID: periodID,
            editingEntryID: nil,
            start: sourceStart,
            end: sourceEnd,
            kind: source.interval.kind,
            note: source.note,
            hasUnpaidBreak: firstBreak != nil,
            breakStart: firstBreak.map {
                Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds))
            } ?? sourceStart.addingTimeInterval(4 * 3_600),
            breakEnd: firstBreak.map {
                Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds))
            } ?? sourceStart.addingTimeInterval(4.5 * 3_600),
            copiedFrom: sourceStart,
            templateSource: source.interval,
            templateDay: targetDay,
            repeatedTimeChoices: [:],
            templateUnresolved: true,
            additionalBreaks: source.interval.unpaidBreaks.dropFirst().map {
                BreakDraft(
                    id: $0.id,
                    start: Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds)),
                    end: Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds)))
            })
        _ = try refresh(
            &draft, timeZoneIdentifier: timeZoneIdentifier, window: window)
        return draft
    }

    static func proposal(
        for draft: WorkDraft,
        timeZoneIdentifier: String
    ) throws -> WorkTemplateProposal? {
        guard let source = draft.templateSource, let day = draft.templateDay else { return nil }
        return try WorkTemplate.propose(
            source,
            on: day,
            timeZoneIdentifier: timeZoneIdentifier,
            choices: draft.repeatedTimeChoices ?? [:])
    }

    @discardableResult
    static func move(
        _ draft: inout WorkDraft,
        to day: Date,
        timeZoneIdentifier: String,
        window: PayPeriodWindow?
    ) throws -> WorkTemplateProposal {
        let zone = try timeZone(timeZoneIdentifier)
        draft.templateDay = clampedDay(day, zone: zone, window: window)
        draft.repeatedTimeChoices = [:]
        return try refresh(
            &draft, timeZoneIdentifier: timeZoneIdentifier, window: window)
    }

    @discardableResult
    static func choose(
        _ choice: RepeatedTimeChoice?,
        for key: String,
        draft: inout WorkDraft,
        timeZoneIdentifier: String,
        window: PayPeriodWindow?
    ) throws -> WorkTemplateProposal {
        var choices = draft.repeatedTimeChoices ?? [:]
        if let choice {
            choices[key] = choice
        } else {
            choices.removeValue(forKey: key)
        }
        draft.repeatedTimeChoices = choices
        return try refresh(
            &draft, timeZoneIdentifier: timeZoneIdentifier, window: window)
    }

    static func confirmManualReview(_ draft: inout WorkDraft) {
        draft.templateSource = nil
        draft.templateDay = nil
        draft.repeatedTimeChoices = nil
        draft.templateUnresolved = false
    }

    @discardableResult
    private static func refresh(
        _ draft: inout WorkDraft,
        timeZoneIdentifier: String,
        window: PayPeriodWindow?
    ) throws -> WorkTemplateProposal {
        guard let source = draft.templateSource, let day = draft.templateDay else {
            throw DomainValidationError.invalidWorkInterval
        }
        let zone = try timeZone(timeZoneIdentifier)
        let proposal = try WorkTemplate.propose(
            source,
            on: day,
            timeZoneIdentifier: timeZoneIdentifier,
            choices: draft.repeatedTimeChoices ?? [:])

        draft.start = date(
            for: "start", proposal: proposal, source: source, targetDay: day, targetZone: zone)
        draft.end = date(
            for: "end", proposal: proposal, source: source, targetDay: day, targetZone: zone)

        if let first = source.unpaidBreaks.first {
            draft.hasUnpaidBreak = true
            draft.breakStart = date(
                for: "break.0.start", proposal: proposal, source: source,
                targetDay: day, targetZone: zone)
            draft.breakEnd = date(
                for: "break.0.end", proposal: proposal, source: source,
                targetDay: day, targetZone: zone)
            draft.additionalBreaks = source.unpaidBreaks.dropFirst().enumerated().map { offset, pause in
                let index = offset + 1
                return BreakDraft(
                    id: pause.id,
                    start: date(
                        for: "break.\(index).start", proposal: proposal, source: source,
                        targetDay: day, targetZone: zone),
                    end: date(
                        for: "break.\(index).end", proposal: proposal, source: source,
                        targetDay: day, targetZone: zone))
            }
        } else {
            draft.hasUnpaidBreak = false
            draft.additionalBreaks = []
        }

        draft.templateUnresolved = !proposal.isResolved
        if proposal.isResolved, let window {
            guard window.contains(start: draft.start, end: draft.end) else {
                draft.templateUnresolved = true
                return proposal
            }
        }
        return proposal
    }

    private static func date(
        for key: String,
        proposal: WorkTemplateProposal,
        source: WorkInterval,
        targetDay: Date,
        targetZone: TimeZone
    ) -> Date {
        if let chosen = proposal.date(key) { return chosen }
        if let candidate = proposal.points.first(where: { $0.key == key })?.candidates.first {
            return candidate
        }
        guard let sourceInstant = sourceInstant(for: key, source: source) else { return targetDay }
        return placeholder(
            sourceInstant: sourceInstant,
            source: source,
            targetDay: targetDay,
            targetZone: targetZone)
    }

    private static func sourceInstant(for key: String, source: WorkInterval) -> Date? {
        if key == "start" {
            return Date(timeIntervalSince1970: TimeInterval(source.startEpochSeconds))
        }
        if key == "end" {
            return Date(timeIntervalSince1970: TimeInterval(source.endEpochSeconds))
        }
        let pieces = key.split(separator: ".")
        guard pieces.count == 3, pieces[0] == "break", let index = Int(pieces[1]),
            source.unpaidBreaks.indices.contains(index)
        else { return nil }
        let pause = source.unpaidBreaks[index]
        switch pieces[2] {
        case "start":
            return Date(timeIntervalSince1970: TimeInterval(pause.startEpochSeconds))
        case "end":
            return Date(timeIntervalSince1970: TimeInterval(pause.endEpochSeconds))
        default:
            return nil
        }
    }

    /// Only a visible editing placeholder for an unresolved wall time. It never clears
    /// `templateUnresolved`; saving stays blocked until the worker chooses an occurrence or
    /// explicitly confirms manually reviewed times.
    private static func placeholder(
        sourceInstant: Date,
        source: WorkInterval,
        targetDay: Date,
        targetZone: TimeZone
    ) -> Date {
        let sourceZone = TimeZone(identifier: source.timeZoneIdentifier) ?? targetZone
        var sourceCalendar = Calendar(identifier: .gregorian)
        sourceCalendar.timeZone = sourceZone
        var targetCalendar = Calendar(identifier: .gregorian)
        targetCalendar.timeZone = targetZone

        let sourceStart = Date(timeIntervalSince1970: TimeInterval(source.startEpochSeconds))
        let sourceDay = sourceCalendar.startOfDay(for: sourceStart)
        let pointDay = sourceCalendar.startOfDay(for: sourceInstant)
        let offset = sourceCalendar.dateComponents([.day], from: sourceDay, to: pointDay).day ?? 0
        let expectedDay = targetCalendar.date(byAdding: .day, value: offset, to: targetDay) ?? targetDay
        let clock = sourceCalendar.dateComponents([.hour, .minute, .second], from: sourceInstant)
        return targetCalendar.nextDate(
            after: targetCalendar.startOfDay(for: expectedDay).addingTimeInterval(-1),
            matching: clock,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward) ?? expectedDay
    }

    private static func clampedDay(
        _ requested: Date,
        zone: TimeZone,
        window: PayPeriodWindow?
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.startOfDay(for: requested)
        guard let window else { return day }
        let first = calendar.startOfDay(for: window.startDate)
        let last = calendar.startOfDay(for: window.displayEndDate)
        return min(max(day, first), last)
    }

    private static func timeZone(_ identifier: String) throws -> TimeZone {
        guard let zone = TimeZone(identifier: identifier) else {
            throw DomainValidationError.invalidTimeZone(identifier)
        }
        return zone
    }
}
