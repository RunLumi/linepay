import CryptoKit
import Foundation

/// Portable identities survive replacement and later exports; native UUIDs never replace them.
struct PortableLocalIdentity: Codable, Hashable, Sendable {
    let entityType: String
    let portableID: String
    let localID: UUID

    static func make(entityType: String, portableID: String) -> Self {
        // Domain-separated deterministic local adapter identity. This is not an authenticity hash.
        let hash = Array(
            SHA256.hash(data: Data(("linepay.portable.v1:" + entityType + ":" + portableID).utf8)))
        let id = UUID(
            uuid: (
                hash[0], hash[1], hash[2], hash[3], hash[4], hash[5],
                (hash[6] & 15) | 80, hash[7], (hash[8] & 63) | 128,
                hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]
            ))
        return Self(entityType: entityType, portableID: portableID, localID: id)
    }
}
