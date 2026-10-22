import Foundation

/// Foundation's decoder accepts duplicate keys. Financial interchange refuses ambiguity first.
struct PortableJSONKeys {
    private let bytes: [UInt8]
    private var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func validate() throws {
        try value(depth: 0)
        whitespace()
        guard offset == bytes.count else { throw BackupError.invalidArchive }
    }
    private mutating func whitespace() {
        while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 }
    }
    private mutating func consume(_ expected: UInt8) throws {
        whitespace()
        guard offset < bytes.count, bytes[offset] == expected else {
            throw BackupError.invalidArchive
        }
        offset += 1
    }
    private mutating func string() throws -> String {
        whitespace()
        let start = offset
        try consume(34)
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            if byte == 34 {
                let fragment = Data(bytes[start..<offset])
                guard
                    let result = try JSONSerialization.jsonObject(
                        with: fragment, options: .fragmentsAllowed) as? String
                else {
                    throw BackupError.invalidArchive
                }
                return result
            }
            if byte == 92 {
                guard offset < bytes.count else { throw BackupError.invalidArchive }
                offset += 1
            }
        }
        throw BackupError.invalidArchive
    }
    private mutating func value(depth: Int) throws {
        guard depth < 64 else { throw BackupError.invalidArchive }
        whitespace()
        guard offset < bytes.count else { throw BackupError.invalidArchive }
        switch bytes[offset] {
        case 123:
            offset += 1
            whitespace()
            var keys = Set<String>()
            if offset < bytes.count && bytes[offset] == 125 {
                offset += 1
                return
            }
            while true {
                let key = try string()
                guard keys.insert(key).inserted else { throw BackupError.invalidArchive }
                try consume(58)
                try value(depth: depth + 1)
                whitespace()
                guard offset < bytes.count else { throw BackupError.invalidArchive }
                if bytes[offset] == 125 {
                    offset += 1
                    return
                }
                try consume(44)
            }
        case 91:
            offset += 1
            whitespace()
            if offset < bytes.count && bytes[offset] == 93 {
                offset += 1
                return
            }
            while true {
                try value(depth: depth + 1)
                whitespace()
                guard offset < bytes.count else { throw BackupError.invalidArchive }
                if bytes[offset] == 93 {
                    offset += 1
                    return
                }
                try consume(44)
            }
        case 34: _ = try string()
        default:
            let start = offset
            while offset < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) {
                offset += 1
            }
            guard offset > start else { throw BackupError.invalidArchive }
            let token = String(decoding: bytes[start..<offset], as: UTF8.self)
            if token.first.map({ "-0123456789".contains($0) }) == true {
                // This format has only integer JSON numbers. Payroll decimals and OCR scalars
                // are strings; rejecting numeric fractions prevents Foundation coercion loss.
                guard
                    token.range(of: #"^-?(?:0|[1-9][0-9]*)$"#, options: .regularExpression) == token
                        .startIndex..<token.endIndex
                else { throw BackupError.invalidArchive }
            }
            _ = try JSONSerialization.jsonObject(
                with: Data(bytes[start..<offset]), options: .fragmentsAllowed)
        }
    }
}
