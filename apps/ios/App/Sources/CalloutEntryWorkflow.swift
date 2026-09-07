import Foundation
import LinePayDomain

struct CalloutMergePlan: Hashable, Sendable {
    let start: Date
    let end: Date
    let note: String
    let breaks: [WorkBreak]
}

enum CalloutEntryWorkflow {
    static func adjacentCallouts(
        start: Date,
        end: Date,
        excluding editingID: UUID?,
        entries: [WorkEntry]
    ) -> [WorkEntry] {
        let startSeconds = Int64(start.timeIntervalSince1970.rounded())
        let endSeconds = Int64(end.timeIntervalSince1970.rounded())
        return entries.filter { entry in
            guard entry.id != editingID, entry.interval.kind == .callout else { return false }
            return entry.interval.endEpochSeconds == startSeconds
                || entry.interval.startEpochSeconds == endSeconds
        }
        .sorted { $0.interval.startEpochSeconds < $1.interval.startEpochSeconds }
    }

    static func merge(
        existing: WorkEntry,
        segmentStart: Date,
        segmentEnd: Date,
        segmentNote: String,
        segmentBreaks: [WorkBreak]
    ) throws -> CalloutMergePlan {
        guard existing.interval.kind == .callout else {
            throw DomainValidationError.invalidWorkInterval
        }
        let segmentStartSeconds = Int64(segmentStart.timeIntervalSince1970.rounded())
        let segmentEndSeconds = Int64(segmentEnd.timeIntervalSince1970.rounded())
        guard existing.interval.endEpochSeconds == segmentStartSeconds
            || segmentEndSeconds == existing.interval.startEpochSeconds
        else { throw DomainValidationError.invalidWorkInterval }

        return CalloutMergePlan(
            start: Date(
                timeIntervalSince1970: TimeInterval(
                    min(existing.interval.startEpochSeconds, segmentStartSeconds))),
            end: Date(
                timeIntervalSince1970: TimeInterval(
                    max(existing.interval.endEpochSeconds, segmentEndSeconds))),
            note: combinedNote(existing.note, segmentNote),
            breaks: sortedBreaks(existing.interval.unpaidBreaks + segmentBreaks))
    }

    static func merge(_ first: WorkEntry, _ second: WorkEntry) throws -> CalloutMergePlan {
        guard first.interval.kind == .callout, second.interval.kind == .callout,
            first.interval.timeZoneIdentifier == second.interval.timeZoneIdentifier
        else { throw DomainValidationError.invalidWorkInterval }
        let secondStart = Date(
            timeIntervalSince1970: TimeInterval(second.interval.startEpochSeconds))
        let secondEnd = Date(
            timeIntervalSince1970: TimeInterval(second.interval.endEpochSeconds))
        return try merge(
            existing: first,
            segmentStart: secondStart,
            segmentEnd: secondEnd,
            segmentNote: second.note,
            segmentBreaks: second.interval.unpaidBreaks)
    }

    private static func sortedBreaks(_ breaks: [WorkBreak]) -> [WorkBreak] {
        breaks.sorted { lhs, rhs in
            if lhs.startEpochSeconds == rhs.startEpochSeconds {
                return lhs.endEpochSeconds < rhs.endEpochSeconds
            }
            return lhs.startEpochSeconds < rhs.startEpochSeconds
        }
    }

    private static func combinedNote(_ first: String, _ second: String) -> String {
        let a = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = second.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }
        if b.isEmpty || a == b { return a }
        return a + "\n" + b
    }
}
