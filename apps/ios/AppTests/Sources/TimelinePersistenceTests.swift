import CryptoKit
import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Rule timelines survive migration, archive, and backup")
@MainActor
struct TimelinePersistenceTests {
    @Test func legacySchemaLoadsWithoutRewritingTheOriginalFile() throws {
        let memory = UnitStateStore()
        let model = AppModel(store: memory)
        try UnitFixture.populate(model)
        try model.archiveCurrentPeriod()
        let state = try #require(memory.state)
        let legacy = try legacyJSON(state)
        let decoded = try JSONDecoder().decode(AppPersistentState.self, from: legacy)
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("state-v1.json")
        try legacy.write(to: url)
        let store = VersionedLocalStateStore(baseDirectory: directory)
        let loaded = AppModel(store: store)
        #expect(loaded.persistenceIssue == nil)
        #expect(loaded.history.first?.calculation == decoded.history.first?.calculation)
        #expect(loaded.history.first?.agreementChanges == nil)
        #expect(try store.load()?.schemaVersion == 2)
        #expect(try Data(contentsOf: url) == legacy)
    }

    @Test func oldBackupRestoresAsSchemaTwoWithoutRecalculatingHistory() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.archiveCurrentPeriod()
        let bytes = try legacyJSON(#require(store.state))
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let payload = try encoder.encode(
            BackupArchive.Payload(
                createdAt: UnitFixture.start,
                stateJSON: bytes, files: []))
        let envelope = BackupArchive.Envelope(
            format: "com.streamentry.linepay.backup", version: 1,
            payload: payload, sha256: Data(SHA256.hash(data: payload)))
        let archive = try BackupArchive.decode(encoder.encode(envelope))
        let restoredStore = UnitStateStore()
        let session = AppSession(store: restoredStore, evidenceStore: MemoryEvidenceStore())
        try session.restore(archive)
        let old = try JSONDecoder().decode(AppPersistentState.self, from: bytes)
        #expect(restoredStore.state?.schemaVersion == 2)
        #expect(session.model.history.first?.calculation == old.history.first?.calculation)
    }

    @Test func backupRoundTripPreservesVersionsAndOriginalBytes() async throws {
        let originalDirectory = UnitFixture.temporaryDirectory()
        let restoredDirectory = UnitFixture.temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: originalDirectory)
            try? FileManager.default.removeItem(at: restoredDirectory)
        }
        let source = AppSession(
            store: UnitStateStore(),
            evidenceStore: LocalEvidenceStore(baseDirectory: originalDirectory))
        try UnitFixture.populate(source.model, evidence: true)
        var draft = UnitFixture.profile(rate: "60")
        draft.changeEffectiveDate = UnitFixture.start.addingTimeInterval(86_400)
        try source.model.saveProfile(draft)
        let tomorrow = UnitFixture.start.addingTimeInterval(86_400)
        try source.model.addWork(
            start: tomorrow, end: tomorrow.addingTimeInterval(8 * 3_600), kind: .regular)
        try source.model.confirmPaystub(UnitFixture.paystub(source.model, gross: "880"))
        try source.model.archiveCurrentPeriod()
        let before = try #require(source.model.history.first)
        let archive = try BackupArchive.decode(await source.prepareBackup())
        let restored = AppSession(
            store: UnitStateStore(),
            evidenceStore: LocalEvidenceStore(baseDirectory: restoredDirectory))
        try restored.restore(archive)
        let after = try #require(restored.model.history.first)
        #expect(
            after.calculation == before.calculation
                && after.agreementChanges == before.agreementChanges)
        #expect(after.calculation.total.amount == 880)
        #expect(after.calculation.components.map(\.appliedAgreement?.version) == ["1", "2"])
        let evidence = try #require(after.paystub?.evidence)
        let original = try #require(restored.model.evidenceURL(for: evidence))
        #expect(try Data(contentsOf: original) == Data("SYNTHETIC ORIGINAL".utf8))
        #expect(restored.model.auditStatus(for: after) == .grossMatches)
    }

    private func legacyJSON(_ state: AppPersistentState) throws -> Data {
        let addedFields: Set<String> = [
            "baselineAgreement", "agreementChanges", "agreementSnapshots", "appliedAgreement",
        ]
        func strip(_ object: Any) -> Any {
            if let dictionary = object as? [String: Any] {
                return dictionary.filter { !addedFields.contains($0.key) }.mapValues(strip)
            }
            if let array = object as? [Any] { return array.map(strip) }
            return object
        }
        var object = try #require(
            strip(JSONSerialization.jsonObject(with: JSONEncoder().encode(state))) as? [String: Any]
        )
        object["schemaVersion"] = 1
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
