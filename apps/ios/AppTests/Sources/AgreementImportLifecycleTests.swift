import Foundation
import LinePayDomain
import PDFKit
import Testing

@testable import LinePay

@Suite("Agreement originals and migration", .serialized)
@MainActor
struct AgreementImportLifecycleTests {
    @Test func backupRestoreKeepsDocumentIdentityQuotesAndExactOriginalBytes() async throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UnitStateStore()
        let model = AppModel(
            store: store,
            evidenceStore: LocalEvidenceStore(baseDirectory: root.appendingPathComponent("source")))
        try UnitFixture.populate(model)
        let bytes = AgreementImportTests().pdf([
            "Base hourly rate: USD 60.00 per hour", "Effective from: 2026-08-14",
        ])
        let id = try await retained(model, bytes: bytes)
        try model.saveAgreementReview(
            id: id,
            review: AgreementImportTests().reviewed(try #require(model.agreementDocument(id: id))))
        try await model.prepareImportedAgreement(id: id)
        try model.saveProfile(try #require(model.setupDraft), scope: .prospective)
        let document = try #require(model.agreementDocument(id: id))
        let evidence = try #require(document.evidence)
        let state = try #require(store.state)
        let archive = BackupArchive(
            createdAt: UnitFixture.start, state: state,
            files: [BackupArchive.EvidenceFile(id: evidence.id, bytes: bytes)])
        let decoded = try BackupArchive.decode(archive.encoded())
        let session = AppSession(
            store: VersionedLocalStateStore(
                baseDirectory: root.appendingPathComponent("restored-state")),
            evidenceStore: LocalEvidenceStore(
                baseDirectory: root.appendingPathComponent("restored-originals")))
        try session.restore(decoded)
        let restored = try #require(session.model.agreementDocument(id: id))
        let restoredEvidence = try #require(restored.evidence)
        #expect(restored.id == document.id && restored.sha256 == document.sha256)
        #expect(restored.candidates == document.candidates)
        #expect(restoredEvidence.storedFilename != evidence.storedFilename)
        #expect(session.model.profile?.agreement.sources == model.profile?.agreement.sources)
        let url = try #require(session.model.evidenceURL(for: restoredEvidence))
        #expect(try Data(contentsOf: url) == bytes)
        _ = try await AgreementDocumentService.verifiedURL(url, sha256: restored.sha256, page: 0)
    }

    @Test func originalRemovalKeepsCitationsAndOnlyTheExactPDFCanBeReattached() async throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            store: UnitStateStore(), evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        let bytes = AgreementImportTests().pdf([
            "Base hourly rate: USD 60.00 per hour", "Effective from: 2026-08-14",
        ])
        let id = try await retained(model, bytes: bytes)
        try model.saveAgreementReview(
            id: id,
            review: AgreementImportTests().reviewed(try #require(model.agreementDocument(id: id))))
        try await model.prepareImportedAgreement(id: id)
        try model.saveProfile(try #require(model.setupDraft), scope: .prospective)
        let sources = model.profile?.agreement.sources
        let original = try #require(model.agreementDocument(id: id)?.evidence)
        try model.removeEvidence(id: original.id)
        #expect(model.agreementDocument(id: id)?.evidence == nil)
        #expect(model.profile?.agreement.sources == sources)
        #expect(!model.canDeleteAgreementImport(id: id))
        #expect(throws: (any Error).self) {
            try model.reattachAgreementOriginal(id: id, data: Data("WRONG".utf8))
        }
        try model.reattachAgreementOriginal(id: id, data: bytes)
        let replacement = try #require(model.agreementDocument(id: id)?.evidence)
        #expect(replacement.storedFilename != original.storedFilename)
        #expect(model.profile?.agreement.sources == sources)
    }

    @Test func changedOriginalCannotPrepareRulesAndFailedSaveKeepsPriorState() async throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UnitStateStore()
        let model = AppModel(store: store, evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        let bytes = AgreementImportTests().pdf([
            "Base hourly rate: USD 60.00 per hour", "Effective from: 2026-08-14",
        ])
        let id = try await retained(model, bytes: bytes)
        try model.saveAgreementReview(
            id: id,
            review: AgreementImportTests().reviewed(try #require(model.agreementDocument(id: id))))
        let before = store.state
        store.failSave = true
        await #expect(throws: AppModelError.persistenceFailed) {
            try await model.prepareImportedAgreement(id: id)
        }
        #expect(model.setupDraft == nil && store.state == before)
        store.failSave = false
        let evidence = try #require(model.agreementDocument(id: id)?.evidence)
        let url = try #require(model.evidenceURL(for: evidence))
        try Data("CHANGED SYNTHETIC ORIGINAL".utf8).write(to: url)
        await #expect(throws: (any Error).self) { try await model.prepareImportedAgreement(id: id) }
        #expect(model.setupDraft == nil)
        #expect(model.calculation?.expectedWages.amount == 400)
    }

    @Test func existingRuleDraftNeedsExplicitReplacementAndUsedImportsCannotBeDeleted() async throws
    {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            store: UnitStateStore(), evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        let bytes = AgreementImportTests().pdf([
            "Base hourly rate: USD 60.00 per hour", "Effective from: 2026-08-14",
        ])
        let id = try await retained(model, bytes: bytes)
        try model.saveAgreementReview(
            id: id,
            review: AgreementImportTests().reviewed(try #require(model.agreementDocument(id: id))))
        var previous = UnitFixture.profile(rate: "75")
        previous.setupStep = 2
        try model.saveSetupDraft(previous)
        await #expect(throws: (any Error).self) { try await model.prepareImportedAgreement(id: id) }
        #expect(model.setupDraft == previous)
        try await model.prepareImportedAgreement(id: id, replaceExistingDraft: true)
        #expect(model.setupDraft?.hourlyRate == "60.00")
        #expect(!model.canDeleteAgreementImport(id: id))
        #expect(throws: (any Error).self) { try model.deleteUnusedAgreementImport(id: id) }
    }

    @Test func schemaFiveDiskMigrationRetainsResolutionAndHistoricalMoney() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let period = try #require(model.activePeriod)
        try model.recordResolution(
            periodID: period.id, status: .explained, note: "Synthetic migration follow-up")
        try model.archiveCurrentPeriod()
        let state = try #require(store.state)
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["schemaVersion"] = 5
        json.removeValue(forKey: "agreementDocuments")
        let bytes = try JSONSerialization.data(withJSONObject: json)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("state-v1.json")
        try bytes.write(to: url)
        let loaded = try VersionedLocalStateStore(baseDirectory: root).load()
        let restored = try #require(loaded)
        #expect(restored.schemaVersion == AppPersistentState.currentSchemaVersion)
        #expect(
            restored.history == state.history && restored.resolutionEvents == state.resolutionEvents
        )
        #expect(restored.agreementDocuments == nil)
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func evidenceMappingPreservesClosedUnresolvedWorkAndCorrectionHistory() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        let active = try #require(model.activePeriod)
        let prior = ClosedWorkRevision(
            workEntries: [], reason: "Synthetic corrected facts", correctedEpochSeconds: 0)
        let closed = CompletedPayPeriod(
            id: active.id, window: active.window, agreement: active.agreement,
            timeZoneIdentifier: "UTC", workEntries: active.workEntries, calculation: nil,
            paystub: nil, reconciliation: nil, calculationIssue: "Synthetic unresolved rule",
            workCorrections: [prior])
        var state = AppPersistentState()
        state.profile = model.profile
        state.history = [closed]
        let mapped = state.replacingEvidence([:])
        #expect(mapped.history == state.history)
        try AppStateValidation.validate(mapped)
    }

    @Test func printedCurrencyAndConflictingSelectionsCannotBeIgnoredByPreparation() throws {
        var document = AgreementImportTests().fixtureDocument()
        var review = AgreementImportTests().reviewed(document)
        review.currencyCode = "CAD"
        #expect(throws: (any Error).self) {
            try AgreementImportDraftBuilder.build(
                document: document, review: review, profile: nil, activePeriod: nil)
        }
        document.candidates = AgreementClauseParser.parse([
            AgreementTextLine(
                text: "Base hourly rate: USD 50.00 per hour", page: 0, confidence: nil),
            AgreementTextLine(
                text: "Base hourly rate: USD 60.00 per hour", page: 0, confidence: nil),
        ])
        review = AgreementImportTests().reviewed(document)
        #expect(throws: (any Error).self) {
            try AgreementImportDraftBuilder.build(
                document: document, review: review, profile: nil, activePeriod: nil)
        }
    }

    @Test func failedRetentionLeavesNoActiveDocumentAndOrphanCleanupIsRetryable() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UnitStateStore()
        let model = AppModel(store: store, evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        let before = model.calculation
        let bytes = AgreementImportTests().pdf(["Base hourly rate: USD 60.00 per hour"])
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.retainAgreement(data: bytes, filename: "synthetic-agreement.pdf")
        }
        #expect(model.agreementDocuments.isEmpty && model.calculation == before)
        store.failSave = false
        try model.retryEvidenceDeletion()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func finishingACancelledOrDeletedImportCannotResurrectIt() async throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            store: UnitStateStore(), evidenceStore: LocalEvidenceStore(baseDirectory: root))
        let bytes = AgreementImportTests().pdf(["Base hourly rate: USD 60.00 per hour"])
        let id = try model.retainAgreement(data: bytes, filename: "synthetic-agreement.pdf")
        let extracted = try await AgreementDocumentService().extract(bytes)
        try model.deleteUnusedAgreementImport(id: id)
        #expect(throws: (any Error).self) {
            try model.finishAgreementExtraction(id: id, result: extracted)
        }
        #expect(model.agreementDocuments.isEmpty && model.profile == nil)
    }

    @Test func reportAgreementQuotesAndFingerprintsRequireSourceDetailConsent() async throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            store: UnitStateStore(), evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        let quote = "Base hourly rate: USD 60.00 per hour"
        let bytes = AgreementImportTests().pdf([quote, "Effective from: 2026-08-14"])
        let id = try await retained(model, bytes: bytes)
        try model.saveAgreementReview(
            id: id,
            review: AgreementImportTests().reviewed(try #require(model.agreementDocument(id: id))))
        try await model.prepareImportedAgreement(id: id)
        try model.saveProfile(try #require(model.setupDraft), scope: .prospective)
        try model.archiveCurrentPeriod()
        let next = try #require(model.activePeriod)
        try model.addWork(
            start: next.window.startDate, end: next.window.startDate.addingTimeInterval(8 * 3_600),
            kind: .regular, note: "Synthetic source report")
        let context = try #require(model.periodContext())
        let calculation = try #require(context.calculation)
        for include in [false, true] {
            let url = try ReconciliationReportExporter().export(
                window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
                agreement: context.agreement, calculation: calculation,
                paystub: nil, reconciliation: nil, findings: [],
                privacy: ReportPrivacyOptions(includeSourceDetails: include))
            defer { try? TemporaryExports.removeReport(url) }
            let text = try #require(PDFDocument(url: url)?.string)
            #expect(text.contains(quote) == include)
            #expect(text.contains(AgreementDocumentService.digest(bytes)) == include)
        }
    }

    private func retained(_ model: AppModel, bytes: Data) async throws -> UUID {
        let id = try model.retainAgreement(data: bytes, filename: "synthetic-agreement.pdf")
        let extraction = try await AgreementDocumentService().extract(bytes)
        try model.finishAgreementExtraction(id: id, result: extraction)
        return id
    }
}
