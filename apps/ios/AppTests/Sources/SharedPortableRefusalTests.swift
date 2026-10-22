import Foundation
import Testing

@testable import LinePay

@Suite("Shared portable refusal vectors through the real iOS boundary")
@MainActor
struct SharedPortableRefusalTests {
    @Test func everyApplicableVectorProtectsDestinationStateOriginalsAndActivity() async throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateDirectory = directory.appendingPathComponent("destination")
        let store = VersionedLocalStateStore(baseDirectory: stateDirectory)
        let evidence = LocalEvidenceStore(
            baseDirectory: directory.appendingPathComponent("originals"))
        let activity = LocalActivityLedger()
        let session = AppSession(store: store, evidenceStore: evidence, activity: activity)
        try UnitFixture.populate(session.model, evidence: true)
        let loaded = try store.load()
        let baseline = try #require(loaded)
        let stateURL = stateDirectory.appendingPathComponent("state-v1.json")
        let stateBytes = try Data(contentsOf: stateURL)
        let original = try #require(baseline.allEvidence.first)
        let originalURL = try #require(evidence.url(for: original))
        let originalBytes = try Data(contentsOf: originalURL)
        let counts = activity.snapshot
        let revision = session.revision
        let model = session.model
        let data = try resource("portable-refusal-cases-v1")
        let manifest = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try #require(manifest["cases"] as? [[String: Any]])
        #expect(cases.count == 21)
        var refused = 0
        var acceptedIOSNotices = 0
        var excludedOtherOriginalStores = 0
        for vector in cases {
            let id = try #require(vector["id"] as? String)
            if vector["expectedCode"] as? String == "target.attachmentsUnsupported",
                ["web", "android"].contains(vector["target"] as? String ?? "")
            {
                excludedOtherOriginalStores += 1
                continue
            }
            let filename = vector["baseFixture"] as? String ?? "common-weekly-pending.json"
            var object = try JSONSerialization.jsonObject(
                with: resource("portable-" + filename.replacingOccurrences(of: ".json", with: "")))
            for operation in vector["operations"] as? [[String: Any]] ?? [] {
                let path = try #require(operation["path"] as? String)
                let action = try #require(operation["op"] as? String)
                let keys = path.split(separator: "/").map {
                    String($0).replacingOccurrences(of: "~1", with: "/").replacingOccurrences(
                        of: "~0", with: "~")
                }
                object = try changed(
                    object, path: ArraySlice(keys), action: action, value: operation["value"])
            }
            let plaintext = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
            let protected = try BackupEncryption.seal(
                plaintext, password: "synthetic refusal vector 2026")
            let url = directory.appendingPathComponent(id + ".linepaybackup")
            try protected.write(to: url)
            if vector["activationReview"] as? Bool == true {
                // These two vectors ask Android/Web for activation review. iOS supports their
                // modeled facts, and still retains this materially incomplete source read-only.
                let decoded = try PortableStateCodec.decode(plaintext)
                let preview = try await session.inspectBackup(
                    at: url, password: "synthetic refusal vector 2026")
                #expect(
                    preview.state.profile == nil,
                    "Other-client activation notice \(id) must not invent missing native rules")
                #expect(
                    preview.state.portableFinancialState?.paycheckReceipts
                        == decoded.paycheckReceipts)
                acceptedIOSNotices += 1
            } else {
                #expect(throws: (any Error).self, "Real codec must refuse shared vector \(id)") {
                    try PortableStateCodec.decode(plaintext)
                }
                await #expect(
                    throws: (any Error).self,
                    "Protected Files inspection must refuse shared vector \(id)"
                ) {
                    try await session.inspectBackup(
                        at: url, password: "synthetic refusal vector 2026")
                }
                refused += 1
            }
            #expect(try Data(contentsOf: stateURL) == stateBytes, "State bytes changed for \(id)")
            #expect(
                try Data(contentsOf: originalURL) == originalBytes,
                "Original bytes changed for \(id)")
            #expect(try store.load() == baseline)
            #expect(activity.snapshot == counts, "Destination activity changed for \(id)")
            #expect(session.revision == revision && session.model === model && !session.isBusy)
        }
        #expect(refused == 17)
        #expect(acceptedIOSNotices == 2)
        #expect(excludedOtherOriginalStores == 2)
    }

    private func resource(_ name: String) throws -> Data {
        let url = try #require(
            Bundle(for: PortableRefusalResources.self).url(forResource: name, withExtension: "json")
        )
        return try Data(contentsOf: url)
    }
    private func changed(_ node: Any, path: ArraySlice<String>, action: String, value: Any?) throws
        -> Any
    {
        guard let key = path.first else {
            guard let value, action != "remove" else { throw UnitFailure.injected }
            return value
        }
        let tail = path.dropFirst()
        if var object = node as? [String: Any] {
            if tail.isEmpty {
                if action == "remove" {
                    guard object.removeValue(forKey: key) != nil else { throw UnitFailure.injected }
                } else {
                    guard let value else { throw UnitFailure.injected }
                    object[key] = value
                }
            } else {
                object[key] = try changed(
                    #require(object[key]), path: tail, action: action, value: value)
            }
            return object
        }
        guard var array = node as? [Any] else { throw UnitFailure.injected }
        if key == "-", tail.isEmpty, action == "add" {
            guard let value else { throw UnitFailure.injected }
            array.append(value)
            return array
        }
        guard let index = Int(key), array.indices.contains(index) else {
            throw UnitFailure.injected
        }
        if tail.isEmpty && action == "remove" {
            array.remove(at: index)
        } else if tail.isEmpty && action == "add" {
            array.insert(try #require(value), at: index)
        } else {
            array[index] = try changed(array[index], path: tail, action: action, value: value)
        }
        return array
    }
}
private final class PortableRefusalResources {}
