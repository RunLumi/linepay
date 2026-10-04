import Foundation

/// An explicit entry grammar that never accepts a numeric prefix. The caller states which
/// decimal separator the worker uses; the parser itself never reads the device locale.
///
/// - `"."` (default): `1,234.56`. Commas group thousands.
/// - `","`: `1.234,56` or `1 234,56`. Dots, spaces and no-break spaces group thousands. A lone
///   dot followed by one or two digits (`58.40`) is unambiguous, because a thousands group always
///   has three digits, so it is read as the decimal point a worker typed out of habit.
public enum StrictDecimal {
    public static func parse(
        _ input: String,
        maximum: Decimal = 10_000_000,
        fractionDigits: Int = 2,
        allowZero: Bool = true,
        allowDollarSign: Bool = false,
        decimalSeparator: Character = "."
    ) throws -> Decimal {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if allowDollarSign {
            if text.hasPrefix("$") {
                text.removeFirst()
            } else if let last = text.last, last == "₫" || last == "đ" {
                text.removeLast()
                text = text.trimmingCharacters(in: .whitespaces)
            }
        }
        guard !text.isEmpty, text.utf8.count <= 48, (0...8).contains(fractionDigits) else {
            throw DecimalInputError.invalidNumber
        }
        let decimal: Character
        let grouping: Set<Character>
        if decimalSeparator == "," {
            decimal = ","
            grouping = [".", " ", "\u{00A0}", "\u{202F}"]
            if !text.contains(","), text.filter({ $0 == "." }).count == 1,
                let tail = text.split(separator: ".", omittingEmptySubsequences: false).last,
                (1...2).contains(tail.count)
            {
                text = text.replacingOccurrences(of: ".", with: ",")
            }
        } else {
            decimal = "."
            grouping = [","]
        }
        let parts = text.split(separator: decimal, omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].isEmpty else { throw DecimalInputError.invalidNumber }
        let groups = parts[0].split(
            omittingEmptySubsequences: false, whereSeparator: { grouping.contains($0) })
        guard !groups.isEmpty else { throw DecimalInputError.invalidNumber }
        if groups.count > 1 {
            guard Set(parts[0].filter { grouping.contains($0) }).count == 1,
                (1...3).contains(groups[0].utf8.count),
                groups.dropFirst().allSatisfy({ $0.utf8.count == 3 })
            else { throw DecimalInputError.invalidNumber }
        }
        let integer = groups.joined()
        let fractional = parts.count == 2 ? String(parts[1]) : ""
        guard parts.count == 1 || (!fractional.isEmpty && fractional.utf8.count <= fractionDigits),
            (integer + fractional).utf8.allSatisfy({ (48...57).contains($0) })
        else { throw DecimalInputError.invalidNumber }
        var value: Decimal = 0
        for digit in integer.utf8 {
            value = value * 10 + Decimal(Int(digit - 48))
            guard !value.isNaN, value <= maximum else { throw DecimalInputError.outOfRange }
        }
        var denominator: Decimal = 1
        for digit in fractional.utf8 {
            denominator *= 10
            value += Decimal(Int(digit - 48)) / denominator
        }
        guard !value.isNaN, value <= maximum, allowZero ? value >= 0 : value > 0 else {
            throw DecimalInputError.outOfRange
        }
        return value
    }
}

public enum DecimalInputError: Error, Equatable, Sendable {
    case invalidNumber
    case outOfRange
}
