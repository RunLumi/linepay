import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Versioned portable envelope. Only bounded, authenticated plaintext reaches archive decoding.
enum BackupEncryption {
    static let magic = Data("LPBENC01".utf8)
    static let iterations: UInt32 = 600_000
    static let headerBytes = 44
    static let overheadBytes = 60

    static func isEncrypted(_ data: Data) -> Bool { data.starts(with: Data("LPBENC".utf8)) }

    static func validateNewPassword(_ password: String) throws {
        let normalized = password.precomposedStringWithCanonicalMapping
        guard normalized.unicodeScalars.count >= 12, normalized.utf8.count <= 1_024 else {
            throw BackupError.passwordPolicy
        }
    }

    static func seal(_ plaintext: Data, password: String) throws -> Data {
        try validateNewPassword(password)
        return try seal(
            plaintext, password: password, salt: random(count: 16), nonce: random(count: 12))
    }

    /// Deterministic parameters are internal for cross-implementation vectors; production uses fresh randomness.
    static func seal(_ plaintext: Data, password: String, salt: Data, nonce: Data) throws -> Data {
        try validateNewPassword(password)
        guard salt.count == 16, nonce.count == 12 else { throw BackupError.invalidArchive }
        guard plaintext.count > 0, plaintext.count <= BackupArchive.maximumBytes - overheadBytes
        else {
            throw BackupError.tooLarge
        }
        try Task.checkCancellation()
        let header = magic + integer(iterations) + salt + nonce + integer(UInt32(plaintext.count))
        let key = try derive(password: password, salt: salt)
        try Task.checkCancellation()
        let box = try AES.GCM.seal(
            plaintext, using: key, nonce: AES.GCM.Nonce(data: nonce),
            authenticating: header)
        return header + box.ciphertext + box.tag
    }

    static func open(_ encoded: Data, password: String?) throws -> Data {
        guard encoded.count <= BackupArchive.maximumBytes else { throw BackupError.tooLarge }
        let data = Data(encoded)
        guard data.count <= BackupArchive.maximumBytes else { throw BackupError.tooLarge }
        guard data.count >= overheadBytes, isEncrypted(data) else {
            throw BackupError.invalidArchive
        }
        guard data.starts(with: magic), number(data, at: 8) == iterations else {
            throw BackupError.newerVersion
        }
        let length = Int(number(data, at: 40))
        guard length > 0, length == data.count - overheadBytes else {
            throw BackupError.invalidArchive
        }
        guard let password, !password.isEmpty else { throw BackupError.passwordRequired }
        let header = Data(data.prefix(headerBytes))
        let salt = Data(data[12..<28])
        let nonce = Data(data[28..<40])
        try Task.checkCancellation()
        let key = try derive(password: password, salt: salt)
        try Task.checkCancellation()
        do {
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: data[headerBytes..<(data.count - 16)], tag: data.suffix(16))
            return try AES.GCM.open(box, using: key, authenticating: header)
        } catch { throw BackupError.passwordRejected }
    }

    private static func derive(password: String, salt: Data) throws -> SymmetricKey {
        var passwordBytes = Array(password.precomposedStringWithCanonicalMapping.utf8)
        guard !passwordBytes.isEmpty, passwordBytes.count <= 1_024 else {
            throw BackupError.passwordPolicy
        }
        var key = [UInt8](repeating: 0, count: 32)
        defer {
            passwordBytes.withUnsafeMutableBytes {
                _ = $0.initializeMemory(as: UInt8.self, repeating: 0)
            }
            key.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) }
        }
        let result = passwordBytes.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                key.withUnsafeMutableBytes { keyBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                        passwordBuffer.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltBuffer.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                        keyBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self), keyBuffer.count)
                }
            }
        }
        guard result == kCCSuccess else { throw BackupError.encryptionFailed }
        return SymmetricKey(data: key)
    }

    private static func random(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw BackupError.encryptionFailed
        }
        return Data(bytes)
    }

    private static func integer(_ value: UInt32) -> Data {
        Data([
            UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value),
        ])
    }
    private static func number(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

extension BackupArchive {
    private struct PortableHeader: Decodable {
        let format: String
        let version: Int
    }

    private struct PortablePayload: Codable {
        let format: String
        let version: Int
        let createdAt: Date
        let state: AppPersistentState
        let files: [EvidenceFile]
    }

    func portableEncoded() throws -> Data {
        try validate()
        let encoder = Self.portableEncoder()
        guard try encoder.encode(state).count <= Self.maximumStateBytes else {
            throw BackupError.tooLarge
        }
        let bytes = try encoder.encode(
            PortablePayload(
                format: "com.streamentry.linepay.snapshot",
                version: 1, createdAt: createdAt, state: state, files: files))
        guard bytes.count <= Self.maximumBytes - BackupEncryption.overheadBytes else {
            throw BackupError.tooLarge
        }
        return bytes
    }

    static func decodePortable(_ bytes: Data) throws -> BackupArchive {
        guard bytes.count <= maximumBytes - BackupEncryption.overheadBytes else {
            throw BackupError.tooLarge
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let raw = try decoder.singleValueContainer().decode(String.self)
                guard raw.count <= 80,
                    raw.range(of: #"^-?\d+(?:\.\d+)?$"#, options: .regularExpression) != nil,
                    let unix = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")),
                    unix >= -62_135_596_800, unix <= 253_402_300_799,
                    let seconds = Double(NSDecimalNumber(decimal: unix - 978_307_200).stringValue),
                    seconds.isFinite
                else { throw BackupError.invalidArchive }
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            let header = try decoder.decode(PortableHeader.self, from: bytes)
            guard header.format == "com.streamentry.linepay.snapshot" else {
                throw BackupError.invalidArchive
            }
            guard header.version == 1 else { throw BackupError.newerVersion }
            let payload = try decoder.decode(PortablePayload.self, from: bytes)
            guard payload.format == "com.streamentry.linepay.snapshot" else {
                throw BackupError.invalidArchive
            }
            guard payload.version == 1 else { throw BackupError.newerVersion }
            let archive = BackupArchive(
                createdAt: payload.createdAt, state: try payload.state.upgraded(),
                files: payload.files)
            try archive.validate()
            guard try portableEncoder().encode(archive.state).count <= maximumStateBytes else {
                throw BackupError.tooLarge
            }
            return archive
        } catch let error as BackupError { throw error } catch { throw BackupError.invalidArchive }
    }

    private static func portableEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Decimal Unix-second strings preserve draft/subsecond dates without binary epoch-shift loss.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let reference = date.timeIntervalSinceReferenceDate
            guard reference.isFinite,
                let decimal = Decimal(
                    string: String(reference), locale: Locale(identifier: "en_US_POSIX"))
            else { throw BackupError.invalidArchive }
            let unix = decimal + 978_307_200
            guard unix >= -62_135_596_800, unix <= 253_402_300_799 else {
                throw BackupError.invalidArchive
            }
            guard let recovered = Double(NSDecimalNumber(decimal: unix - 978_307_200).stringValue),
                recovered == reference
            else { throw BackupError.invalidArchive }
            var container = encoder.singleValueContainer()
            try container.encode(NSDecimalNumber(decimal: unix).stringValue)
        }
        return encoder
    }
}
