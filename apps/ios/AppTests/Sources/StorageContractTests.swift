import Foundation
import Testing

@testable import LinePay

@Suite("Local state and evidence adapters")
@MainActor
struct StorageContractTests {
    @Test func memoryStoreHasIndependentValueSemantics() throws {
        let a = MemoryStateStore()
        let b = MemoryStateStore()
        #expect(try a.load() == nil && b.load() == nil)
        var value = AppPersistentState()
        value.hasUsedFreeAudit = true
        try a.save(value)
        value.hasUsedFreeAudit = false
        #expect(try a.load()?.hasUsedFreeAudit == true && b.load() == nil)
        #expect(a.recoveryFileURL == nil)
        try a.reset()
        try a.reset()
        #expect(try a.load() == nil)
    }

    @Test func missingAndCorruptStateAreDifferentAndRecoveryNeverDeletes() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = VersionedLocalStateStore(baseDirectory: root)
        #expect(try store.load() == nil && store.recoveryFileURL == nil)
        try store.reset()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("state-v1.json")
        let bytes = Data("not json".utf8)
        try bytes.write(to: file)
        #expect(throws: (any Error).self) { try store.load() }
        let model = AppModel(store: store)
        #expect(model.persistenceIssue != nil && store.recoveryFileURL == file)
        #expect(try Data(contentsOf: file) == bytes)
        try model.resetAfterPersistenceFailure()
        #expect(try store.load()?.profile == nil && model.persistenceIssue == nil)
        #expect(try store.load()?.hasUsedFreeAudit == true)
    }

    @Test func futureSchemaIsRejectedWithoutOverwritingValidFile() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = VersionedLocalStateStore(baseDirectory: root)
        var existing = AppPersistentState()
        existing.hasUsedFreeAudit = true
        try store.save(existing)
        let file = try #require(store.recoveryFileURL)
        let oldBytes = try Data(contentsOf: file)
        var future = existing
        future.schemaVersion = 99
        #expect(throws: LocalStateStoreError.unsupportedSchema(99)) { try store.save(future) }
        #expect(try Data(contentsOf: file) == oldBytes)
        try JSONEncoder().encode(future).write(to: file)
        #expect(throws: LocalStateStoreError.unsupportedSchema(99)) { try store.load() }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func stateSaveCreatesParentsAndSurvivesRelaunch() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let location = root.appendingPathComponent("nested/state")
        let store = VersionedLocalStateStore(baseDirectory: location)
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let state = try #require(try store.load())
        #expect(try VersionedLocalStateStore(baseDirectory: location).load() == state)
        #expect(
            try JSONDecoder().decode(AppPersistentState.self, from: JSONEncoder().encode(state))
                == state)
        try store.reset()
        #expect(store.recoveryFileURL == nil)
    }

    @Test(arguments: [false, true])
    func oversizedSavePreservesReloadableState(escapedText: Bool) throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = VersionedLocalStateStore(baseDirectory: root)
        var existing = AppPersistentState()
        existing.hasUsedFreeAudit = true
        try store.save(existing)
        let file = try #require(store.recoveryFileURL)
        let originalBytes = try Data(contentsOf: file)

        var candidate = existing
        var draft = PayProfileDraft()
        draft.unsupportedRuleNotes = String(
            repeating: escapedText ? "\n" : "x",
            count: (escapedText ? 4 : 8) * 1024 * 1024)
        candidate.setupDraft = draft
        #expect(try JSONEncoder().encode(candidate).count > 8 * 1024 * 1024)

        #expect(throws: LocalStateStoreError.invalidState) { try store.save(candidate) }
        #expect(try Data(contentsOf: file) == originalBytes)
        #expect(try VersionedLocalStateStore(baseDirectory: root).load() == existing)
    }

    @Test func invalidDirectoryFailsWithoutPretendingToSave() throws {
        let root = UnitFixture.temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocked = root.appendingPathComponent("file-not-directory")
        try Data([1]).write(to: blocked)
        let store = VersionedLocalStateStore(baseDirectory: blocked)
        #expect(throws: (any Error).self) { try store.save(AppPersistentState()) }
        #expect(try Data(contentsOf: blocked) == Data([1]))
    }

    @Test(arguments: ["grossPay", "regularPay"])
    func inconsistentSavedComparisonsAreRejected(field: String) throws {
        let store = MemoryStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        var draft = UnitFixture.paystub(model)
        draft.regularPay = "400"
        draft.lineLayout = .fullRateBuckets
        draft.reviewedFields.insert(.regularPay)
        try model.confirmPaystub(draft)
        let state = try #require(try store.load())
        try AppStateValidation.validate(state)

        var document = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var active = try #require(document["activePeriod"] as? [String: Any])
        var paystub = try #require(active["paystub"] as? [String: Any])
        var assessment = try #require(paystub["assessment"] as? [String: Any])
        var comparisons = try #require(assessment["comparisons"] as? [[String: Any]])
        let index = try #require(comparisons.firstIndex { $0["field"] as? String == field })
        comparisons[index]["expected"] = 401
        if field == "grossPay" {
            // An internally balanced line must also agree with its saved gross summary.
            comparisons[index]["paid"] = 401
        }
        assessment["comparisons"] = comparisons
        paystub["assessment"] = assessment
        active["paystub"] = paystub
        document["activePeriod"] = active
        let invalid = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: document))
        #expect(throws: LocalStateStoreError.invalidState) {
            try AppStateValidation.validate(invalid)
        }
    }

    @Test(arguments: ["same.PDF", "no-extension", "../../outside.pdf"])
    func originalsUseUniqueGeneratedLocalPaths(_ filename: String) throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalEvidenceStore(baseDirectory: root)
        let data = Data("SYNTHETIC BYTES".utf8)
        let first = try store.save(
            data: data, originalFilename: filename,
            mediaType: "application/pdf", sourceKind: .file, recognizedText: "Synthetic text")
        let second = try store.save(
            data: data, originalFilename: filename,
            mediaType: "application/pdf", sourceKind: .scan, recognizedText: nil)
        #expect(first.id != second.id && first.storedFilename != second.storedFilename)
        #expect(first.originalFilename == filename && first.recognizedText == "Synthetic text")
        let url = try #require(store.url(for: first))
        #expect(url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
        #expect(try Data(contentsOf: url) == data)
        #expect(
            try JSONDecoder().decode(PaystubEvidence.self, from: JSONEncoder().encode(first))
                == first)
        try store.delete(first)
        try store.delete(first)
        #expect(store.url(for: first) == nil && store.url(for: second) != nil)
        try store.deleteAll()
        try store.deleteAll()
        #expect(store.url(for: second) == nil)
    }

    @Test func memoryOriginalsHaveIndependentLifecycle() throws {
        let store = MemoryEvidenceStore()
        let other = MemoryEvidenceStore()
        let item = try store.save(
            data: Data([1]), originalFilename: "a.PNG",
            mediaType: "image/png", sourceKind: .photo, recognizedText: nil)
        #expect(item.storedFilename.hasSuffix(".png"))
        #expect(store.url(for: item) != nil && other.url(for: item) == nil)
        try store.delete(item)
        try store.delete(item)
        #expect(store.url(for: item) == nil)
        try store.deleteAll()
    }
}
