import Foundation
import LinePayDomain

enum RepeatWorkReviewError: LocalizedError {
    case incompleteManualReview

    var errorDescription: String? {
        switch self {
        case .incompleteManualReview:
            "Review every unresolved copied clock time before confirming manual times."
        }
    }
}

enum RepeatWorkDraft {
    private static let manualPrefix = "manual:"

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
        // A new date changes the wall-time question. Previous fold choices and manual review
        // decisions do not carry forward to a different local date.
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

    /// Records that the worker deliberately changed, added, or removed the copied fact identified
    /// by `key`. Manual markers share the persisted decision dictionary with fold choices but use a
    /// namespace that `WorkTemplate` never interprets as a wall-time choice.
    static func markManualReview(_ key: String, draft: inout WorkDraft) {
        var choices = draft.repeatedTimeChoices ?? [:]
        choices[manualMarker(key)] = .first
        draft.repeatedTimeChoices = choices
    }

    static func canConfirmManualReview(
        _ draft: WorkDraft,
        timeZoneIdentifier: String,
        window: PayPeriodWindow?
    ) -> Bool {
        guard draft.templateUnresolved == true,
            let source = draft.templateSource,
            let day = draft.templateDay,
            let proposal = try? WorkTemplate.propose(
                source,
                on: day,
                timeZoneIdentifier: timeZoneIdentifier,
                choices: draft.repeatedTimeChoices ?? [:])
        else { return false }

        if let window, !window.contains(start: draft.start, end: draft.end) {
            return false
        }
        guard draft.end > draft.start else { return false }

        // A manual repair for a nonexistent wall time must never waive a separate fold decision.
        // Every repeated clock time still needs an explicit first/last occurrence.
        let ambiguous = proposal.points.filter { $0.candidates.count > 1 }
        guard ambiguous.allSatisfy({ $0.chosen != nil }) else { return false }

        let decisions = draft.repeatedTimeChoices ?? [:]
        let nonexistent = proposal.points.filter { $0.candidates.isEmpty }
        if !nonexistent.isEmpty {
            return nonexistent.allSatisfy { decisions[manualMarker($0.key)] != nil }
        }

        // The pure proposal is resolved, so the app-level unresolved state is containment-related.
        // Require a deliberate manual fact edit before accepting a different in-period record.
        guard proposal.isResolved else { return false }
        return decisions.keys.contains { $0.hasPrefix(manualPrefix) }
    }

    static func confirmManualReview(
        _ draft: inout WorkDraft,
        timeZoneIdentifier: String,
        window: PayPeriodWindow?
    ) throws {
        guard
            canConfirmManualReview(
                draft, timeZoneIdentifier: timeZoneIdentifier, window: window)
        else { throw RepeatWorkReviewError.incompleteManualReview }
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
        let decisions = draft.repeatedTimeChoices ?? [:]
        let preservesManualFacts = decisions.keys.contains { $0.hasPrefix(manualPrefix) }
        let proposal = try WorkTemplate.propose(
            source,
            on: day,
            timeZoneIdentifier: timeZoneIdentifier,
            choices: decisions)

        let previousStart = draft.start
        let previousEnd = draft.end
        let previousFirstBreakEnabled = draft.hasUnpaidBreak
        let previousBreakStart = draft.breakStart
        let previousBreakEnd = draft.breakEnd
        let previousAdditional = draft.additionalBreaks

        draft.start =
            isManuallyReviewed("start", decisions: decisions)
            ? previousStart
            : date(
                for: "start", proposal: proposal, source: source, targetDay: day,
                targetZone: zone)
        draft.end =
            isManuallyReviewed("end", decisions: decisions)
            ? previousEnd
            : date(
                for: "end", proposal: proposal, source: source, targetDay: day,
                targetZone: zone)

        if source.unpaidBreaks.first != nil {
            let firstStartReviewed = isManuallyReviewed("break.0.start", decisions: decisions)
            let firstEndReviewed = isManuallyReviewed("break.0.end", decisions: decisions)
            let firstRemoved =
                !previousFirstBreakEnabled && firstStartReviewed && firstEndReviewed
            draft.hasUnpaidBreak = !firstRemoved
            if !firstRemoved {
                draft.breakStart =
                    firstStartReviewed
                    ? previousBreakStart
                    : date(
                        for: "break.0.start", proposal: proposal, source: source,
                        targetDay: day, targetZone: zone)
                draft.breakEnd =
                    firstEndReviewed
                    ? previousBreakEnd
                    : date(
                        for: "break.0.end", proposal: proposal, source: source,
                        targetDay: day, targetZone: zone)
            }

            var rebuilt: [BreakDraft] = []
            for (offset, pause) in source.unpaidBreaks.dropFirst().enumerated() {
                let index = offset + 1
                let startKey = "break.\(index).start"
                let endKey = "break.\(index).end"
                let startReviewed = isManuallyReviewed(startKey, decisions: decisions)
                let endReviewed = isManuallyReviewed(endKey, decisions: decisions)
                let previous = previousAdditional.first { $0.id == pause.id }
                if previous == nil && startReviewed && endReviewed {
                    // The worker explicitly removed this copied break.
                    continue
                }
                rebuilt.append(
                    BreakDraft(
                        id: pause.id,
                        start: startReviewed
                            ? (previous?.start
                                ?? date(
                                    for: startKey, proposal: proposal, source: source,
                                    targetDay: day, targetZone: zone))
                            : date(
                                for: startKey, proposal: proposal, source: source,
                                targetDay: day, targetZone: zone),
                        end: endReviewed
                            ? (previous?.end
                                ?? date(
                                    for: endKey, proposal: proposal, source: source,
                                    targetDay: day, targetZone: zone))
                            : date(
                                for: endKey, proposal: proposal, source: source,
                                targetDay: day, targetZone: zone)))
            }

            if preservesManualFacts {
                let sourceIDs = Set(source.unpaidBreaks.map(\.id))
                rebuilt.append(contentsOf: previousAdditional.filter { !sourceIDs.contains($0.id) })
            }
            draft.additionalBreaks = rebuilt
        } else {
            draft.hasUnpaidBreak = false
            draft.additionalBreaks = preservesManualFacts ? previousAdditional : []
        }

        draft.templateUnresolved = !proposal.isResolved
        if proposal.isResolved, let window,
            !window.contains(start: draft.start, end: draft.end)
        {
            draft.templateUnresolved = true
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
        let expectedDay =
            targetCalendar.date(byAdding: .day, value: offset, to: targetDay) ?? targetDay
        let clock = sourceCalendar.dateComponents([.hour, .minute, .second], from: sourceInstant)
        return targetCalendar.nextDate(
            after: targetCalendar.startOfDay(for: expectedDay).addingTimeInterval(-1),
            matching: clock,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward) ?? expectedDay
    }

    private static func isManuallyReviewed(
        _ key: String,
        decisions: [String: RepeatedTimeChoice]
    ) -> Bool {
        decisions[manualMarker(key)] != nil
    }

    private static func manualMarker(_ key: String) -> String {
        manualPrefix + key
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
