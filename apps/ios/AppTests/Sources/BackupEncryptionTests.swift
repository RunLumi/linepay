import Foundation
import Testing

@testable import LinePay

private final class BackupCryptoResourceAnchor: NSObject {}

@Suite("Password-protected manual backup interoperability", .serialized)
@MainActor
struct BackupEncryptionTests {
    private struct Vector: Decodable {
        let password: String
        let normalizedPassword: String
        let saltHex: String
        let nonceHex: String
        let plaintextUTF8: String
        let encodedHex: String
    }
    private func fixtureVector() throws -> Vector {
        let url = try #require(
            Bundle(for: BackupCryptoResourceAnchor.self).url(
                forResource: "encryption-v1", withExtension: "json"))
        return try JSONDecoder().decode(Vector.self, from: Data(contentsOf: url))
    }

    private func bytes(_ hex: String) throws -> Data {
        guard hex.count.isMultiple(of: 2) else { throw BackupError.invalidArchive }
        var result = Data()
        var start = hex.startIndex
        while start < hex.endIndex {
            let end = hex.index(start, offsetBy: 2)
            result.append(try #require(UInt8(hex[start..<end], radix: 16)))
            start = end
        }
        return result
    }

    @Test func independentlyGeneratedNodeVectorMatchesNativeAndCanonicalUnicode() throws {
        let vector = try fixtureVector()
        let plain = Data(vector.plaintextUTF8.utf8)
        let expected = try bytes(vector.encodedHex)
        let actual = try BackupEncryption.seal(
            plain, password: vector.password,
            salt: bytes(vector.saltHex), nonce: bytes(vector.nonceHex))
        #expect(actual == expected)
        #expect(try BackupEncryption.open(expected, password: vector.normalizedPassword) == plain)
        var prefixed = Data([0, 1, 2])
        prefixed.append(expected)
        #expect(
            try BackupEncryption.open(prefixed.dropFirst(3), password: vector.password) == plain)
    }

    @Test func wrongPasswordsAndEveryAuthenticatedRegionRefusePlaintext() throws {
        let password = try fixtureVector().password
        let encoded = try BackupEncryption.seal(
            Data("SYNTHETIC PRIVATE PAY FACTS".utf8), password: password)
        #expect(throws: BackupError.passwordRequired) {
            try BackupEncryption.open(encoded, password: nil)
        }
        #expect(throws: BackupError.passwordRejected) {
            try BackupEncryption.open(encoded, password: password + " wrong")
        }
        for offset in [12, 28, 44, encoded.count - 1] {
            var damaged = encoded
            damaged[offset] ^= 1
            #expect(throws: BackupError.passwordRejected) {
                try BackupEncryption.open(damaged, password: password)
            }
        }
        #expect(throws: BackupError.invalidArchive) {
            try BackupEncryption.open(encoded.dropLast(), password: password)
        }
        var unsupported = encoded
        unsupported[8] ^= 1
        #expect(throws: BackupError.newerVersion) {
            try BackupEncryption.open(unsupported, password: password)
        }
        var invalidLength = encoded
        invalidLength[43] ^= 1
        #expect(throws: BackupError.invalidArchive) {
            try BackupEncryption.open(invalidLength, password: password)
        }
    }

    @Test func freshRandomnessAndPasswordPolicyDoNotAllowAccidentalWeakOrSilentChanges() throws {
        let password = try fixtureVector().password
        let plain = Data("SYNTHETIC COPY".utf8)
        let a = try BackupEncryption.seal(plain, password: password)
        let b = try BackupEncryption.seal(plain, password: password)
        #expect(a != b)
        #expect(a.range(of: plain) == nil)
        #expect(throws: BackupError.passwordPolicy) {
            try BackupEncryption.seal(plain, password: "short")
        }
        #expect(throws: BackupError.passwordPolicy) {
            try BackupEncryption.seal(plain, password: String(repeating: "x", count: 1_025))
        }
        let spaced = try BackupEncryption.seal(plain, password: " " + password + " ")
        #expect(throws: BackupError.passwordRejected) {
            try BackupEncryption.open(spaced, password: password)
        }
    }

    @Test func futurePortableVersionIsRejectedBeforeDecodingUnknownState() {
        let future = Data(
            #"{"format":"com.streamentry.linepay.snapshot","version":2,"state":{"unknown":true}}"#
                .utf8)
        #expect(throws: BackupError.newerVersion) { try BackupArchive.decodePortable(future) }
    }

    @Test func portableDatesKeepSubsecondsAndLegacyArchivesRemainReadable() throws {
        for value in [Double.pi, 0, -0.1234567, 0.0000001, 802_000_000.1234567] {
            let date = Date(timeIntervalSinceReferenceDate: value)
            let archive = BackupArchive(createdAt: date, state: AppPersistentState(), files: [])
            let portable = try archive.portableEncoded()
            #expect(try BackupArchive.decodePortable(portable).createdAt == date)
            #expect(try BackupArchive.decode(archive.encoded()).createdAt == date)
            let object = try #require(
                JSONSerialization.jsonObject(with: portable) as? [String: Any])
            #expect(object["createdAt"] is String)
        }
    }

    @Test func encryptedInspectionNeverMutatesCurrentRecordsAndRestoreKeepsOriginalBytes()
        async throws
    {
        let password = try fixtureVector().password
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceStore = UnitStateStore()
        let sourceEvidence = LocalEvidenceStore(
            baseDirectory: root.appendingPathComponent("originals"))
        let source = AppSession(store: sourceStore, evidenceStore: sourceEvidence)
        try UnitFixture.populate(source.model, evidence: true)
        try source.model.archiveCurrentPeriod()
        let before = try #require(try sourceStore.load())
        let encoded = try await source.prepareBackup(password: password)
        let url = root.appendingPathComponent("synthetic.linepaybackup")
        try encoded.write(to: url)
        let destinationStore = UnitStateStore()
        let destinationEvidence = LocalEvidenceStore(
            baseDirectory: root.appendingPathComponent("destination-originals"))
        let destination = AppSession(store: destinationStore, evidenceStore: destinationEvidence)
        try UnitFixture.populate(destination.model)
        let destinationBefore = try destinationStore.load()
        let oldRevision = destination.revision
        await #expect(throws: BackupError.passwordRequired) {
            try await destination.inspectBackup(at: url)
        }
        await #expect(throws: BackupError.passwordRejected) {
            try await destination.inspectBackup(at: url, password: password + " wrong")
        }
        #expect(
            try destinationStore.load() == destinationBefore && destination.revision == oldRevision)
        let reviewed = try await destination.inspectBackup(at: url, password: password)
        #expect(reviewed.wasPasswordProtected && reviewed.state == before)
        #expect(
            try destinationStore.load() == destinationBefore && destination.revision == oldRevision)
        try destination.restore(reviewed)
        let after = try #require(try destinationStore.load())
        #expect(after.history.first?.workEntries == before.history.first?.workEntries)
        #expect(after.history.first?.calculation == before.history.first?.calculation)
        let original = try #require(after.history.first?.paystub?.evidence)
        #expect(
            try Data(contentsOf: #require(destinationEvidence.url(for: original)))
                == Data("SYNTHETIC ORIGINAL".utf8))
        #expect(try Data(contentsOf: url) == encoded)
        #expect(!destination.isBusy)
    }
}
