import Foundation
import LinePayDomain

/// A speech reading is only a proposal. No clock, locale or pay-rule inference belongs here.
struct VoiceWorkProposal: Equatable, Sendable {
    let start: Date
    let end: Date
    let kind: WorkKind
    let breaks: [VoiceWorkBreak]

    static func parse(_ text: String, day: Date, timeZoneIdentifier: String) throws -> Self {
        guard text.count <= 2_000, let zone = TimeZone(identifier: timeZoneIdentifier) else {
            throw VoiceWorkError.unsupportedReading
        }
        let clauses = normalized(text).split(separator: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        guard (2...6).contains(clauses.count),
            let shift = captures(
                #"^(?:i worked |worked )?(regular|callout|other)(?: work)? from (.+?) (?:to|until) (.+)$"#,
                in: clauses[0]), let kind = WorkKind(rawValue: shift[0])
        else { throw VoiceWorkError.unsupportedReading }
        let start = try instant(shift[1], on: day, zone: zone, allowsNextDay: false)
        let end = try instant(shift[2], on: day, zone: zone)
        guard end > start else { throw VoiceWorkError.endBeforeStart }
        var breaks: [VoiceWorkBreak] = []
        if clauses.count == 2, clauses[1] == "no unpaid breaks" || clauses[1] == "no unpaid break" {
            // Absence of a break is a spoken/reviewed fact, never the parser's default.
        } else {
            for clause in clauses.dropFirst() {
                guard
                    let values = captures(
                        #"^unpaid break from (.+?) (?:to|until) (.+)$"#, in: clause)
                else { throw VoiceWorkError.unsupportedReading }
                let pause = VoiceWorkBreak(
                    start: try instant(values[0], on: day, zone: zone),
                    end: try instant(values[1], on: day, zone: zone))
                guard pause.start >= start, pause.end <= end, pause.end > pause.start,
                    breaks.allSatisfy({ pause.end <= $0.start || pause.start >= $0.end })
                else { throw VoiceWorkError.invalidBreak }
                breaks.append(pause)
            }
        }
        return Self(
            start: start, end: end, kind: kind, breaks: breaks.sorted { $0.start < $1.start })
    }

    /// This replaces only explicitly reviewed work facts. Notes and entry identity stay intact.
    func applying(to draft: WorkDraft) -> WorkDraft {
        var value = draft
        value.start = start
        value.end = end
        value.kind = kind
        value.hasUnpaidBreak = !breaks.isEmpty
        value.breakStart = breaks.first?.start ?? start
        value.breakEnd = breaks.first?.end ?? start
        value.additionalBreaks = breaks.dropFirst().map { BreakDraft(start: $0.start, end: $0.end) }
        // A changed callout's event membership is decided by the existing work editor.
        if draft.kind != kind { value.calloutEventID = nil }
        return value
    }

    private static func normalized(_ text: String) -> String {
        var value = text.lowercased().replacingOccurrences(of: "a.m.", with: "am")
            .replacingOccurrences(of: "p.m.", with: "pm")
            .replacingOccurrences(of: "a.m", with: "am")
            .replacingOccurrences(of: "p.m", with: "pm")
            .replacingOccurrences(of: "o’clock", with: "")
            .replacingOccurrences(of: "o'clock", with: "")
            .replacingOccurrences(of: #"[.,;]+"#, with: ";", options: .regularExpression)
            .replacingOccurrences(
                of: #"\s+(?:(?:and|with an?)\s+)?(no unpaid breaks?|unpaid break)"#,
                with: ";$1", options: .regularExpression)
        let numbers = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10", "eleven": "11",
            "twelve": "12", "fifteen": "15", "thirty": "30", "forty five": "45",
        ]
        for word in numbers.keys.sorted(by: { $0.count > $1.count }) {
            value = value.replacingOccurrences(
                of: "\\b\(word)\\b", with: numbers[word] ?? word, options: .regularExpression)
        }
        return value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func instant(
        _ text: String, on day: Date, zone: TimeZone, allowsNextDay: Bool = true
    ) throws -> Date {
        var value = text.trimmingCharacters(in: .whitespaces)
        let nextDay = value.hasSuffix(" next day")
        if nextDay {
            guard allowsNextDay else { throw VoiceWorkError.unsupportedReading }
            value.removeLast(" next day".count)
        }
        let hour: Int
        let minute: Int
        if value == "noon" {
            hour = 12
            minute = 0
        } else if value == "midnight" {
            hour = 0
            minute = 0
        } else if let clock = captures(#"^(\d{1,2})(?:[: ](\d{2}))?\s*(am|pm)$"#, in: value),
            let rawHour = Int(clock[0]), (1...12).contains(rawHour)
        {
            hour = rawHour % 12 + (clock[2] == "pm" ? 12 : 0)
            minute = clock[1].isEmpty ? 0 : Int(clock[1]) ?? -1
        } else if let clock = captures(#"^(\d{2}):(\d{2})$"#, in: value),
            let h = Int(clock[0]), let m = Int(clock[1]), (0...23).contains(h)
        {
            hour = h
            minute = m
        } else {
            throw VoiceWorkError.ambiguousClock
        }
        guard (0...59).contains(minute) else { throw VoiceWorkError.ambiguousClock }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let target = calendar.date(byAdding: .day, value: nextDay ? 1 : 0, to: day) else {
            throw VoiceWorkError.ambiguousClock
        }
        let midnight = calendar.startOfDay(for: target)
        let components = DateComponents(hour: hour, minute: minute, second: 0)
        let candidates = Set(
            [Calendar.RepeatedTimePolicy.first, .last].compactMap { policy in
                calendar.nextDate(
                    after: midnight.addingTimeInterval(-1), matching: components,
                    matchingPolicy: .strict, repeatedTimePolicy: policy)
            }.filter {
                calendar.isDate($0, inSameDayAs: target)
                    && calendar.dateComponents([.hour, .minute, .second], from: $0) == components
            })
        guard candidates.count == 1, let result = candidates.first else {
            throw VoiceWorkError.daylightSavingClock
        }
        return result
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}

struct VoiceWorkBreak: Equatable, Sendable {
    let start: Date
    let end: Date
}

enum VoiceWorkError: LocalizedError {
    case unsupportedReading, ambiguousClock, endBeforeStart, invalidBreak, daylightSavingClock
    var errorDescription: String? {
        switch self {
        case .unsupportedReading:
            "Use the example format, including work type, both clock times and either each unpaid break or ‘no unpaid breaks’. Extra or conflicting instructions need manual entry."
        case .ambiguousClock:
            "A clock time is unclear. Use AM/PM, noon, midnight or a 24-hour time such as 19:30."
        case .endBeforeStart:
            "End must be after start. For overnight work, say or type ‘next day’ after the end time."
        case .invalidBreak:
            "Each unpaid break must be inside the shift, end after it starts and not overlap another break."
        case .daylightSavingClock:
            "A clock time is missing or repeated at a daylight-saving change. Enter and review these dates manually in the work editor."
        }
    }
}
