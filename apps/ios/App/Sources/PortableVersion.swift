import Foundation

/// Numeric and text producer versions are distinct source facts.
enum PortableVersion: Codable, Hashable, Sendable {
    case number(Int64)
    case text(String)
    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Int64.self) {
            self = .number(number)
        } else {
            self = .text(try value.decode(String.self))
        }
    }
    func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .number(let number): try value.encode(number)
        case .text(let text): try value.encode(text)
        }
    }
}
