import CryptoKit
import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Backup validation and evidence remapping")
@MainActor
struct BackupValidationTests {
    @Test(arguments: ["schema", "profile-zone", "period-zone", "duplicate-work", "duplicate-period", "window", "rate", "rounding", "missing-profile"])
    func invalidSnapshotCannotReachCommit(_ defect: String) throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.archiveCurrentPeriod()
        let state = try #require(store.state)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var profile = try #require(object["profile"] as? [String: Any])
        var active = try #require(object["activePeriod"] as? [String: Any])
        var history = try #require(object["history"] as? [[String: Any]])
        var agreement = try #require(profile["agreement"] as? [String: Any])
        switch defect {
        case "schema": object["schemaVersion"] = 99
        case "profile-zone": profile["timeZoneIdentifier"] = "No/Zone"
        case "period-zone": active["timeZoneIdentifier"] = "No/Zone"
        case "duplicate-work":
            let entries = try #require(history[0]["workEntries"] as? [[String: Any]])
            history[0]["workEntries"] = entries + entries
        case "duplicate-period": history.append(history[0])
        case "window":
            var window = try #require(active["window"] as? [String: Any])
            window["endEpochSeconds"] = window["startEpochSeconds"]
            active["window"] = window
        case "rate":
            var rate = try #require(agreement["hourlyRate"] as? [String: Any])
            rate["currencyCode"] = "us!"
            agreement["hourlyRate"] = rate
        case "rounding": agreement["rounding"] = ["scale": 500, "mode": "halfUp"]
        default: break
        }
        profile["agreement"] = agreement
        object["profile"] = defect == "missing-profile" ? nil : profile
        object["activePeriod"] = active
        object["history"] = history
        let stateData = try JSONSerialization.data(withJSONObject: object)
        let bytes = try wrap(stateJSON: stateData)
        let before = store.state
        #expect(throws: (any Error).self) { try BackupArchive.decode(bytes) }
        #expect(store.state == before)
    }

    @Test func wrongFormatAndMalformedPayloadAreRejected() throws {
        let bytes = try wrap(stateJSON: Data("invalid state JSON".utf8))
        #expect(throws: BackupError.invalidArchive) { try BackupArchive.decode(bytes) }
        let envelope = BackupArchive.Envelope(format: "not-linepay", version: 1, payload: Data(), sha256: Data())
        #expect(throws: BackupError.invalidArchive) {
            try BackupArchive.decode(PropertyListEncoder().encode(envelope))
        }
        #expect(throws: BackupError.newerVersion) {
            var future = AppPersistentState(); future.schemaVersion = 2
            try BackupArchive(createdAt: Date(), state: future, files: []).validate()
        }
    }

    @Test func evidenceMappingOnlyChangesPhysicalLocation() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model, evidence: true)
        try model.archiveCurrentPeriod()
        let state = try #require(store.state)
        let source = try #require(state.history.first?.paystub?.evidence)
        let replacement = PaystubEvidence(id: source.id, storedFilename: "new-physical.pdf",
            originalFilename: source.originalFilename, mediaType: source.mediaType,
            sourceKind: source.sourceKind, createdEpochSeconds: source.createdEpochSeconds,
            recognizedText: source.recognizedText)
        let updated = state.replacingEvidence([source.id: replacement])
        #expect(updated.history.first?.paystub?.evidence == replacement)
        #expect(updated.history.first?.calculation == state.history.first?.calculation)
        #expect(updated.history.first?.reconciliation == state.history.first?.reconciliation)
        #expect(updated.history.first?.archivedEpochSeconds == state.history.first?.archivedEpochSeconds)
        #expect(updated.activePeriod == state.activePeriod && updated.profile == state.profile)
        #expect(updated.history.first?.paystub?.confirmedEpochSeconds == state.history.first?.paystub?.confirmedEpochSeconds)
    }

    @Test func emptyAndOversizedOriginalsAreNotSilentlyOmitted() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model, evidence: true)
        let state = try #require(store.state)
        let source = try #require(model.currentPaystub?.evidence)
        for count in [0, BackupArchive.maximumEvidenceBytes + 1] {
            let archive = BackupArchive(createdAt: UnitFixture.start, state: state,
                files: [.init(id: source.id, bytes: Data(count: count))])
            #expect(throws: BackupError.tooLarge) { try archive.validate() }
        }
    }

    @Test func unreadableAndRemoteURLNeverCreateBackups() async throws {
        let store = UnitStateStore(); store.failLoad = true
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        await #expect(throws: BackupError.currentDataUnreadable) { try await session.prepareBackup() }
        let remote = try #require(URL(string: "https://example.invalid/private-paystub"))
        await #expect(throws: BackupError.unavailableFile) { try await session.inspectBackup(at: remote) }
        #expect(!session.isBusy && store.saveCount == 0)
    }

    @Test func missingSourceReadIsRecoverable() async {
        let io = BackupIO()
        let source = BackupSource(id: UUID(), url: UnitFixture.temporaryDirectory())
        await #expect(throws: BackupError.unavailableFile) {
            try await io.create(state: AppPersistentState(), sources: [source])
        }
    }

    @Test func emptySnapshotHasZeroCountsAndStableRoundTrip() throws {
        let archive = BackupArchive(createdAt: UnitFixture.start, state: AppPersistentState(), files: [])
        let decoded = try BackupArchive.decode(archive.encoded())
        #expect(decoded.createdAt == archive.createdAt)
        #expect(decoded.workCount == 0 && decoded.periodCount == 0 && decoded.files.isEmpty)
        #expect(decoded.state == archive.state)
    }

    private func wrap(stateJSON: Data) throws -> Data {
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let payload = try encoder.encode(BackupArchive.Payload(createdAt: UnitFixture.start, stateJSON: stateJSON, files: []))
        return try encoder.encode(BackupArchive.Envelope(format: "com.streamentry.linepay.backup", version: 1,
            payload: payload, sha256: Data(SHA256.hash(data: payload))))
    }
}
