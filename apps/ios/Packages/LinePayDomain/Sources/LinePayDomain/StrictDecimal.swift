import Foundation

/// An explicit US-entry grammar, independent of the device locale. Never accepts a numeric prefix.
public enum StrictDecimal {
    public static func parse(
        _ input: String,
        maximum: Decimal = 10_000_000,
        fractionDigits: Int = 2,
        allowZero: Bool = true,
        allowDollarSign: Bool = false
    ) throws -> Decimal {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if allowDollarSign, text.hasPrefix("$") { text.removeFirst() }
        guard !text.isEmpty, text.utf8.count <= 48, (0...8).contains(fractionDigits) else {
            throw DecimalInputError.invalidNumber
        }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].isEmpty else { throw DecimalInputError.invalidNumber }
        let groups = parts[0].split(separator: ",", omittingEmptySubsequences: false)
        guard !groups.isEmpty else { throw DecimalInputError.invalidNumber }
        if groups.count > 1 {
            guard (1...3).contains(groups[0].utf8.count),
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
