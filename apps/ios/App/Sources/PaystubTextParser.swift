import Foundation

struct OCRPaystubResult: Sendable {
    let recognizedText: String
    let grossPay: String?
    let regularPay: String?
    let overtimePay: String?
    let doubleTimePay: String?
    let perDiemPay: String?
}

/// Suggestions only. Ambiguous columns, signed adjustments, and YTD rows require manual entry.
/// Recognition and financial field mapping are separate operations and separate test boundaries.
enum PaystubTextParser {
    static func parse(lines: [String]) -> OCRPaystubResult {
        OCRPaystubResult(
            recognizedText: lines.joined(separator: "\n"),
            grossPay: amount(in: lines, labels: ["gross pay", "gross earnings", "gross"]),
            regularPay: amount(in: lines, labels: ["regular pay", "regular"]),
            overtimePay: amount(in: lines, labels: ["overtime", "ot pay"]),
            doubleTimePay: amount(in: lines, labels: ["double time", "double-time", "dt pay"]),
            perDiemPay: amount(in: lines, labels: ["per diem", "per-diem"])
        )
    }

    private static func amount(in lines: [String], labels: [String]) -> String? {
        let matching = lines.filter { line in
            labels.contains { label in
                line.range(of: "\\b" + NSRegularExpression.escapedPattern(for: label) + "\\b",
                           options: [.regularExpression, .caseInsensitive]) != nil
            }
        }
        // Do not choose one of two matching payroll rows just because it appeared first.
        guard matching.count == 1, let line = matching.first,
            line.range(of: #"\b(?:ytd|year[ -]to[ -]date)\b"#,
                       options: [.regularExpression, .caseInsensitive]) == nil,
            line.range(of: #"(?:[-−(]\s*\$?\s*\d)|(?:\d[.,]\d{2}\s*[-−)])"#,
                       options: .regularExpression) == nil
        else { return nil }
        let pattern = #"(?<![\p{L}\p{N}.,])\$?(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)\.[0-9]{2}(?![0-9.,])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line))
        guard matches.count == 1, let match = matches.first,
            let range = Range(match.range, in: line)
        else { return nil }
        return line[range].replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
}
