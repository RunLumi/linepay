import CryptoKit
import Foundation

/// Conservative local patterns. Unmatched, conditional and low-confidence clauses abstain.
/// No clause or numeric match establishes employer/classification/legal applicability.
enum AgreementClauseParser {
    static let version = "local-clause-patterns-v1"
    static let maximumCandidates = 64

    static func parse(_ lines: [AgreementTextLine]) -> [ImportedRuleCandidate] {
        var candidates: [ImportedRuleCandidate] = []
        var seen = Set<String>()
        for line in lines {
            let quote = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty, let kind = kind(in: quote) else { continue }
            let id = SHA256.hash(data: Data("\(line.page)|\(kind.rawValue)|\(quote)".utf8))
                .map { String(format: "%02x", $0) }.joined()
            guard seen.insert(id).inserted else { continue }
            var candidate = ImportedRuleCandidate(
                id: id, kind: kind, page: line.page, quote: String(quote.prefix(2_000)),
                value: nil, multiplier: nil, currencyCode: currency(in: quote),
                recognitionConfidence: line.confidence, status: .manualReview,
                reason:
                    "No safe structured reading. Review the original and enter supported values yourself."
            )
            if !kind.canPreparePayRule && kind != .effectiveStart && kind != .effectiveEnd {
                candidate.status = .unsupported
                candidate.reason = kind.behavior
            }
            let conditional =
                quote.range(
                    of:
                        #"\b(?:unless|except|provided|subject\s+to|not|only\s+if|in\s+lieu|whichever|consecutive|rest\s+period)\b"#,
                    options: [.regularExpression, .caseInsensitive]) != nil
            if conditional {
                candidate.status = .unsupported
                candidate.reason =
                    "Conditions or interactions need manual rule review; no automatic mapping is made."
            } else if line.confidence.map({ !$0.isFinite || $0 < 0.85 || $0 > 1 }) == true {
                candidate.reason =
                    "Text recognition is uncertain. No value is suggested; check the original."
            } else if quote.count <= 2_000, let values = values(in: quote, kind: kind) {
                candidate.value = values.0
                candidate.multiplier = values.1
                if candidate.status != .unsupported {
                    candidate.status = .suggested
                    candidate.reason = nil
                }
            }
            candidates.append(candidate)
            if candidates.count == maximumCandidates { break }
        }
        for kind in ImportedRuleKind.allCases {
            let group = candidates.filter { $0.kind == kind && $0.value != nil }
            let values = Set(group.map { "\($0.value ?? "")|\($0.multiplier ?? "")" })
            if values.count > 1 {
                for index in candidates.indices
                where candidates[index].kind == kind
                    && candidates[index].status != .unsupported
                {
                    candidates[index].status = .conflicting
                    candidates[index].reason =
                        "Several clauses give different values. Review classification, dates and amendments; no value is selected for you."
                }
            }
        }
        return candidates
    }

    private static func kind(in text: String) -> ImportedRuleKind? {
        let lower = text.lowercased().replacingOccurrences(of: "-", with: " ")
        if lower.contains("effective") || lower.contains("expires") || lower.contains("expiration")
        {
            return lower.contains("end") || lower.contains("expires")
                || lower.contains("expiration")
                ? .effectiveEnd : .effectiveStart
        }
        if lower.contains("daily double time") { return .dailyDoubleTime }
        if lower.contains("daily overtime") { return .dailyOvertime }
        if lower.contains("weekly overtime") { return .weeklyOvertime }
        if lower.contains("sunday") { return .sundayPremium }
        if lower.contains("holiday") { return .holidayPremium }
        if lower.contains("callout") || lower.contains("call out") { return .calloutMinimum }
        if lower.contains("show up") { return .showUpMinimum }
        if lower.contains("per diem") || lower.contains("subsistence") { return .perDiem }
        if ["pension", "annuity", "health", "welfare", "benefit", "contribution"].contains(
            where: lower.contains)
        {
            return .benefitRate
        }
        if lower.contains("differential") { return .shiftDifferential }
        if lower.contains("meal") { return .mealPremium }
        if lower.contains("base hourly") || lower.contains("base wage")
            || lower.contains("hourly rate")
        {
            return .baseRate
        }
        if ["overtime", "premium", "minimum", "wage", "rate"].contains(where: lower.contains) {
            return .unmapped
        }
        return nil
    }

    private static func currency(in text: String) -> String? {
        let codes = ["USD", "CAD", "VND"].filter {
            text.range(of: "\\b\($0)\\b", options: [.regularExpression, .caseInsensitive]) != nil
        }
        return codes.count == 1 ? codes.first : nil
    }

    private static func values(in text: String, kind: ImportedRuleKind) -> (String, String?)? {
        let number = #"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,4})?)"#
        let money = #"(?:(?:USD|CAD|VND)\s*|\$)?"# + number
        let pattern: String
        switch kind {
        case .baseRate:
            pattern =
                #"^\s*(?:base\s+(?:hourly\s+)?(?:rate|wage)|hourly\s+rate)\s*[:=]\s*"# + money
                + #"\s*(?:per\s+hour|/hr|/hour)?\s*[.;]?\s*$"#
        case .dailyOvertime, .dailyDoubleTime, .weeklyOvertime:
            let label =
                kind == .dailyOvertime
                ? "daily overtime"
                : kind == .dailyDoubleTime ? "daily double time" : "weekly overtime"
            pattern =
                "^\\s*" + label.replacingOccurrences(of: " ", with: "\\s+") + #"\s*[:=]\s*after\s+"#
                + number + #"\s+hours?\s+at\s+"# + number + #"\s*[x×]\s*[.;]?\s*$"#
        case .sundayPremium, .holidayPremium:
            pattern =
                #"^\s*(?:sunday|holiday)\s+premium\s*[:=]\s*"# + number + #"\s*[x×]\s*[.;]?\s*$"#
        case .calloutMinimum, .showUpMinimum:
            pattern =
                #"^\s*(?:callout|call out|show.up)\s+minimum\s*[:=]\s*"# + number
                + #"\s+hours?\s*[.;]?\s*$"#
        case .perDiem:
            pattern =
                #"^\s*(?:per diem|subsistence)\s*[:=]\s*"# + money
                + #"\s+per\s+worked\s+(?:day|date)\s*[.;]?\s*$"#
        case .effectiveStart, .effectiveEnd:
            let datePattern = #"\b\d{4}-\d{2}-\d{2}\b"#
            guard let regex = try? NSRegularExpression(pattern: datePattern),
                let match = regex.firstMatch(
                    in: text, range: NSRange(text.startIndex..., in: text)),
                regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) == 1,
                let range = Range(match.range, in: text),
                let date = PaystubTextParser.normalizedDate(String(text[range]))
            else { return nil }
            return (date, nil)
        default: return nil
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let first = Range(match.range(at: 1), in: text)
        else { return nil }
        let second =
            match.numberOfRanges > 2
            ? Range(match.range(at: 2), in: text).map { String(text[$0]) } : nil
        return (String(text[first]), second)
    }
}
