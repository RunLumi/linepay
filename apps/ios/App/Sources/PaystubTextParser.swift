import Foundation
import LinePayDomain

struct RecognizedPaystubLine: Sendable {
    let text: String
    let region: SourceRegion
    let confidence: Double
}

/// Conservative suggestions only. Ambiguous columns abstain instead of choosing the last number.
enum PaystubTextParser {
    static func parse(_ lines: [RecognizedPaystubLine]) -> [PaystubField: OCRFieldSuggestion] {
        var result: [PaystubField: OCRFieldSuggestion] = [:]
        let hasYearToDateHeader = lines.contains {
            $0.text.range(
                of: #"\b(?:ytd|year[ -]to[ -]date)\b"#,
                options: [.regularExpression, .caseInsensitive]) != nil
        }
        for field in PaystubField.allCases {
            let candidates = lines.filter { matches($0.text, field: field) }
            guard let source = candidates.first else { continue }
            if candidates.count > 1 {
                result[field] = suggestion(
                    nil, source, "Several rows match this field. Confirm the current-period value.")
                continue
            }
            let lower = source.text.lowercased()
            if field.isDate {
                let dates = matches(
                    in: source.text,
                    pattern: #"\b(?:\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{4})\b"#)
                let selected: String?
                let starts = periodLabel(in: lower, start: true)
                let ends = periodLabel(in: lower, start: false)
                if dates.count == 1 && (field == .periodStart ? starts != nil : ends != nil) {
                    selected = normalizedDate(dates[0])
                } else if dates.count == 2, lower.contains("pay period"),
                    (starts == nil && ends == nil) || (starts != nil && ends != nil)
                {
                    let reversed =
                        starts != nil && ends != nil && ends!.lowerBound < starts!.lowerBound
                    let first = (field == .periodStart) != reversed
                    selected = normalizedDate(first ? dates[0] : dates[1])
                } else {
                    selected = nil
                }
                result[field] = suggestion(
                    selected, source, selected == nil ? "Confirm the exact period dates." : nil)
                continue
            }
            if lower.contains("ytd") || lower.contains("year to date")
                || lower.contains("year-to-date")
            {
                guard let current = source.text.range(of: "current", options: .caseInsensitive),
                    let year = source.text.range(of: "ytd", options: .caseInsensitive) ?? source
                        .text.range(of: "year to date", options: .caseInsensitive)
                        ?? source.text.range(of: "year-to-date", options: .caseInsensitive),
                    current.upperBound < year.lowerBound
                else {
                    result[field] = suggestion(
                        nil, source, "This row may be year-to-date, not current pay.")
                    continue
                }
                let piece = String(source.text[current.upperBound..<year.lowerBound])
                result[field] = valueSuggestion(piece, field: field, source: source)
            } else if hasYearToDateHeader && !lower.contains("current") {
                result[field] = suggestion(
                    nil, source,
                    "Year-to-date columns appear elsewhere on this document. Confirm which amount is current pay."
                )
            } else {
                result[field] = valueSuggestion(source.text, field: field, source: source)
            }
        }
        return result
    }

    private static func valueSuggestion(
        _ text: String, field: PaystubField,
        source: RecognizedPaystubLine
    ) -> OCRFieldSuggestion {
        if text.range(
            of: #"(?:[-−(]\s*\$?\s*\d)|(?:\d\s*[-−)])"#,
            options: .regularExpression) != nil
        {
            return suggestion(
                nil, source, "Possible adjustment or negative amount. Review this row manually.")
        }
        let values = matches(
            in: text, pattern: #"(?<![\w.,])\$?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,4})?(?![\w.,])"#)
        guard values.count == 1, let raw = values.first,
            let number = try? StrictDecimal.parse(
                raw, maximum: field.isHours ? 10_000 : 10_000_000,
                fractionDigits: field.isHours ? 4 : 2, allowDollarSign: !field.isHours)
        else {
            return suggestion(
                nil, source,
                "The hours, rate, current and year-to-date columns cannot be distinguished safely.")
        }
        return suggestion(
            LinePayFormat.decimal(number), source,
            source.confidence < 0.85
                ? "Text is unclear. Check the original before confirming." : nil)
    }

    private static func suggestion(
        _ value: String?, _ source: RecognizedPaystubLine,
        _ reason: String?
    ) -> OCRFieldSuggestion {
        OCRFieldSuggestion(
            value: value, sourceText: source.text, region: source.region,
            confidence: source.confidence, reason: reason)
    }

    private static func matches(_ text: String, field: PaystubField) -> Bool {
        let lower = text.lowercased().replacingOccurrences(of: "-", with: " ")
        switch field {
        case .periodStart:
            return periodLabel(in: lower, start: true) != nil
                || (lower.contains("pay period") && periodLabel(in: lower, start: false) == nil)
        case .periodEnd:
            return periodLabel(in: lower, start: false) != nil
                || (lower.contains("pay period") && periodLabel(in: lower, start: true) == nil)
        case .grossPay:
            return lower.range(of: #"\bgross\b"#, options: .regularExpression) != nil
                && lower.range(of: #"\bnet\b"#, options: .regularExpression) == nil
        case .regularHours: return lower.contains("regular") && lower.contains("hours")
        case .overtimeHours:
            return (lower.contains("overtime") || lower.contains("ot hours"))
                && lower.contains("hours")
        case .doubleTimeHours:
            return (lower.contains("double time") || lower.contains("dt hours"))
                && lower.contains("hours")
        case .regularPay: return lower.contains("regular") && !lower.contains("hours")
        case .overtimePay:
            return (lower.contains("overtime") || lower.contains("ot pay"))
                && !lower.contains("hours")
        case .doubleTimePay:
            return (lower.contains("double time") || lower.contains("dt pay"))
                && !lower.contains("hours")
        case .calloutPay: return lower.contains("callout") && !lower.contains("hours")
        case .perDiemPay: return lower.contains("per diem")
        }
    }

    private static func periodLabel(in text: String, start: Bool) -> Range<String.Index>? {
        let word =
            start ? "(?:start(?:s|ing)?|begin(?:s|ning)?|from)" : "(?:end(?:s|ing)?|through|to)"
        return text.range(
            of: "\\b(?:pay\\s+)?period\\s+" + word + "\\b",
            options: [.regularExpression, .caseInsensitive])
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
            .compactMap {
                guard let range = Range($0.range, in: text) else { return nil }
                return String(text[range])
            }
    }

    static func normalizedDate(_ value: String) -> String? {
        let separator: Character = value.contains("/") ? "/" : "-"
        let parts = value.split(separator: separator).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let year = separator == "/" ? parts[2] : parts[0]
        let month = separator == "/" ? parts[0] : parts[1]
        let day = separator == "/" ? parts[1] : parts[2]
        guard (1900...2200).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
            calendar.component(.day, from: date) == day
        else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
