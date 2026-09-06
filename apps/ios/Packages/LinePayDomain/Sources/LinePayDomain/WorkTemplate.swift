import Foundation

public enum RepeatedTimeChoice: String, Codable, Hashable, Sendable {
    case first, last
}

public struct WorkTemplatePoint: Hashable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let wallTime: String
    public let candidates: [Date]
    public let chosen: Date?
}

/// A proposal is not a work record. Nonexistent clock times never normalize into new facts.
public struct WorkTemplateProposal: Hashable, Sendable {
    public let points: [WorkTemplatePoint]
    public var isResolved: Bool { !points.isEmpty && points.allSatisfy { $0.chosen != nil } }
    public func date(_ key: String) -> Date? { points.first { $0.key == key }?.chosen }
}

public enum WorkTemplate {
    public static func propose(
        _ original: WorkInterval, on day: Date, timeZoneIdentifier: String,
        choices: [String: RepeatedTimeChoice] = [:]
    ) throws -> WorkTemplateProposal {
        guard let sourceZone = TimeZone(identifier: original.timeZoneIdentifier),
            let zone = TimeZone(identifier: timeZoneIdentifier)
        else { throw DomainValidationError.invalidTimeZone(timeZoneIdentifier) }
        var source = Calendar(identifier: .gregorian)
        source.timeZone = sourceZone
        var target = Calendar(identifier: .gregorian)
        target.timeZone = zone
        let originalDay = source.startOfDay(
            for: Date(timeIntervalSince1970: TimeInterval(original.startEpochSeconds)))
        let targetDay = target.startOfDay(for: day)
        var endpoints: [(String, String, Int64)] = [
            ("start", "Shift start", original.startEpochSeconds),
            ("end", "Shift end", original.endEpochSeconds),
        ]
        for (index, pause) in original.unpaidBreaks.enumerated() {
            endpoints.append(
                ("break.\(index).start", "Break \(index + 1) start", pause.startEpochSeconds))
            endpoints.append(
                ("break.\(index).end", "Break \(index + 1) end", pause.endEpochSeconds))
        }
        let points = try endpoints.map { key, label, seconds in
            let instant = Date(timeIntervalSince1970: TimeInterval(seconds))
            guard
                let offset = source.dateComponents(
                    [.day], from: originalDay,
                    to: source.startOfDay(for: instant)
                ).day,
                let expectedDay = target.date(byAdding: .day, value: offset, to: targetDay)
            else { throw DomainValidationError.invalidWorkInterval }
            let clock = source.dateComponents([.hour, .minute, .second], from: instant)
            let after = target.startOfDay(for: expectedDay).addingTimeInterval(-1)
            let first = target.nextDate(
                after: after, matching: clock, matchingPolicy: .strict,
                repeatedTimePolicy: .first)
            let last = target.nextDate(
                after: after, matching: clock, matchingPolicy: .strict,
                repeatedTimePolicy: .last)
            let candidates = Array(
                Set(
                    [first, last].compactMap { $0 }.filter {
                        target.isDate($0, inSameDayAs: expectedDay)
                            && target.dateComponents([.hour, .minute, .second], from: $0) == clock
                    })
            ).sorted()
            let selected: Date?
            if candidates.count == 1 {
                selected = candidates[0]
            } else if candidates.count > 1, let choice = choices[key] {
                selected = choice == .first ? candidates.first : candidates.last
            } else {
                selected = nil
            }
            let local = target.dateComponents([.year, .month, .day], from: expectedDay)
            return WorkTemplatePoint(
                key: key, label: label,
                wallTime: String(
                    format: "%04d-%02d-%02d %02d:%02d:%02d", local.year ?? 0,
                    local.month ?? 0, local.day ?? 0, clock.hour ?? 0,
                    clock.minute ?? 0, clock.second ?? 0),
                candidates: candidates, chosen: selected)
        }
        return WorkTemplateProposal(points: points)
    }
}
