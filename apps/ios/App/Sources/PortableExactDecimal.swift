import Foundation

/// Exact decimal-string comparisons for frozen traces, including precision beyond a native editor.
/// This validates interchange; the native payroll engine continues to use Foundation Decimal.
struct PortableExactDecimal: Equatable {
    let negative: Bool
    let coefficient: [UInt8]
    let scale: Int

    init?(_ text: String) {
        var body = text
        let signed = body.first == "-"
        if signed { body.removeFirst() }
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty,
            parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } })
        else { return nil }
        var digits = Array(parts.joined().utf8).map { $0 - 48 }
        var places = parts.count == 2 ? parts[1].utf8.count : 0
        while digits.count > 1 && digits.first == 0 { digits.removeFirst() }
        while places > 0 && digits.last == 0 {
            digits.removeLast()
            places -= 1
        }
        if digits.isEmpty || digits.allSatisfy({ $0 == 0 }) {
            digits = [0]
            places = 0
        }
        negative = signed && digits != [0]
        coefficient = digits
        scale = places
    }

    private init(negative: Bool, coefficient: [UInt8], scale: Int) {
        var digits = coefficient
        var places = scale
        while digits.count > 1 && digits.first == 0 { digits.removeFirst() }
        while places > 0 && digits.last == 0 {
            digits.removeLast()
            places -= 1
        }
        if digits.isEmpty || digits.allSatisfy({ $0 == 0 }) {
            digits = [0]
            places = 0
        }
        self.negative = negative && digits != [0]
        self.coefficient = digits
        self.scale = places
    }

    var nativeValue: Decimal? {
        let text = string
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
            !value.isNaN,
            PortableExactDecimal(NSDecimalNumber(decimal: value).stringValue) == self
        else { return nil }
        return value
    }
    var string: String {
        var digits = coefficient.map(String.init).joined()
        if scale > 0 {
            if digits.count <= scale {
                digits = String(repeating: "0", count: scale - digits.count + 1) + digits
            }
            let split = digits.index(digits.endIndex, offsetBy: -scale)
            digits.insert(".", at: split)
        }
        return (negative ? "-" : "") + digits
    }

    static func difference(expected: String, paid: String, equals recorded: String) -> Bool {
        guard let left = Self(expected), let right = Self(paid), let difference = Self(recorded),
            !left.negative, !right.negative
        else { return false }
        let scale = max(left.scale, right.scale)
        var a = left.coefficient + Array(repeating: UInt8(0), count: scale - left.scale)
        var b = right.coefficient + Array(repeating: UInt8(0), count: scale - right.scale)
        let length = max(a.count, b.count)
        a = Array(repeating: UInt8(0), count: length - a.count) + a
        b = Array(repeating: UInt8(0), count: length - b.count) + b
        let negative = a.lexicographicallyPrecedes(b)
        let top = negative ? b : a
        let bottom = negative ? a : b
        var result = top
        var borrow = 0
        for index in result.indices.reversed() {
            var digit = Int(top[index]) - Int(bottom[index]) - borrow
            borrow = digit < 0 ? 1 : 0
            if digit < 0 { digit += 10 }
            result[index] = UInt8(digit)
        }
        return Self(negative: negative, coefficient: result, scale: scale) == difference
    }
}
