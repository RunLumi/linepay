import Foundation
import PDFKit
import Testing

@testable import LinePay

@Suite("Paycheck follow-up history")
@MainActor
struct PaycheckResolutionTests {
    @Test func followUpNeverChangesCalculationOrVerdictAndSurvivesRelaunch() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "375"))
        let before = try #require(model.periodContext())
        try model.recordResolution(
            periodID: before.id, status: .explained, note: "Synthetic explanation")
        let after = try #require(model.periodContext())
        #expect(after.calculation == before.calculation)
        #expect(after.paystub == before.paystub)
        #expect(after.reconciliation == before.reconciliation)
        #expect(after.resolutionEvents.count == 1)
        #expect(after.resolutionEvents.first?.paystubID == before.paystub?.id)
        let restored = AppModel(store: store)
        #expect(restored.periodContext()?.resolutionEvents == after.resolutionEvents)
    }

    @Test func correctionKeepsNotesBoundToOriginalPaycheckRevision() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "375"))
        let original = try #require(model.periodContext())
        try model.recordResolution(
            periodID: original.id, status: .shared, note: "Sent synthetic question")
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "400"))
        let corrected = try #require(model.periodContext())
        #expect(corrected.resolutionEvents.first?.paystubID == original.paystub?.id)
        #expect(corrected.resolutionEvents.first?.paystubID != corrected.paystub?.id)
        #expect(corrected.revisions.contains { $0.paystub.id == original.paystub?.id })
        try model.recordResolution(
            periodID: original.id, status: .corrected, note: "Reviewed corrected statement")
        #expect(model.periodContext()?.resolutionEvents.last?.paystubID == corrected.paystub?.id)
    }

    @Test func openingAnOlderAuditCanRecordAndExportOnlyThatRevisionsFollowUps() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "375"))
        let original = try #require(model.periodContext())
        let oldID = try #require(original.paystub?.id)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "400"))
        try model.recordResolution(
            periodID: original.id, paystubID: oldID, status: .explained,
            note: "Explanation for original statement")
        let current = try #require(model.periodContext())
        #expect(current.resolutionEvents.first?.paystubID == oldID)
        let revision = try #require(current.revisions.first { $0.paystub.id == oldID })
        let context = revision.context(
            periodID: original.id,
            resolutionEvents: current.resolutionEvents.filter { $0.paystubID == oldID })
        #expect(context.paystub?.id == oldID)
        #expect(context.resolutionEvents == current.resolutionEvents)
        #expect(throws: AppModelError.unconfirmedPaystub) {
            try model.recordResolution(
                periodID: original.id, paystubID: UUID(), status: .shared, note: "Unknown revision")
        }
    }

    @Test func historyAndBackupPreserveFollowUpsAndDeleteRemovesOnlyTheirPeriod() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let period = try #require(model.periodContext())
        try model.recordResolution(
            periodID: period.id, status: .awaitingResponse, note: "Synthetic question")
        try model.archiveCurrentPeriod()
        try model.recordResolution(periodID: period.id, status: .unresolved, note: "Still waiting")
        let state = try #require(store.state)
        let archive = BackupArchive(createdAt: UnitFixture.start, state: state, files: [])
        let restored = try BackupArchive.decode(archive.encoded())
        #expect(restored.state.resolutionEvents == state.resolutionEvents)
        #expect(model.periodContext()?.resolutionEvents.isEmpty == true)
        #expect(model.periodContext(id: period.id)?.resolutionEvents.count == 2)
        let next = model.activePeriod
        try model.deleteHistoryPeriod(id: period.id)
        #expect(store.state?.resolutionEvents?.isEmpty == true)
        #expect(model.activePeriod == next)
    }

    @Test func failedSaveDoesNotAppendOrChangeThePreviousRecord() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let period = try #require(model.periodContext())
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.recordResolution(periodID: period.id, status: .shared, note: "Synthetic note")
        }
        #expect(model.periodContext()?.resolutionEvents.isEmpty == true)
        #expect(model.periodContext()?.paystub == period.paystub)
    }

    @Test func missingPaycheckAndInvalidNotesCannotCreateFollowUps() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        let period = try #require(model.periodContext())
        #expect(throws: AppModelError.unconfirmedPaystub) {
            try model.recordResolution(periodID: period.id, status: .shared, note: "Synthetic")
        }
        try model.confirmPaystub(UnitFixture.paystub(model))
        for note in [" \n ", String(repeating: "x", count: 4_001)] {
            #expect(throws: (any Error).self) {
                try model.recordResolution(periodID: period.id, status: .shared, note: note)
            }
        }
        #expect(model.periodContext()?.resolutionEvents.isEmpty == true)
    }

    @Test func schemaFourMigratesWithoutInventingFollowUpsOrRepricing() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let state = try #require(store.state)
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["schemaVersion"] = 4
        json.removeValue(forKey: "resolutionEvents")
        let migrated = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(migrated.schemaVersion == AppPersistentState.currentSchemaVersion)
        #expect(migrated.resolutionEvents == nil)
        #expect(migrated.activePeriod == state.activePeriod)
        #expect(migrated.profile == state.profile)
        try AppStateValidation.validate(migrated)
    }

    @Test func schemaFourDiskFileOpensWithoutLosingHistoricalPaycheckFacts() throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = UnitStateStore()
        let original = AppModel(store: source)
        try UnitFixture.populate(original)
        try original.confirmPaystub(UnitFixture.paystub(original, gross: "375"))
        try original.archiveCurrentPeriod()
        let state = try #require(source.state)
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["schemaVersion"] = 4
        json.removeValue(forKey: "resolutionEvents")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(
            to: directory.appendingPathComponent("state-v1.json"))
        let store = VersionedLocalStateStore(baseDirectory: directory)
        let restored = AppModel(store: store)
        #expect(restored.persistenceIssue == nil)
        #expect(restored.history == original.history)
        let period = try #require(restored.history.first)
        try restored.recordResolution(
            periodID: period.id, status: .reviewing, note: "Reviewing old paycheck")
        let relaunched = AppModel(store: store)
        #expect(relaunched.history == original.history)
        #expect(relaunched.periodContext(id: period.id)?.resolutionEvents.count == 1)
    }

    @Test func importedFollowUpsMustReferToAnActualPaycheckRevision() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let period = try #require(model.periodContext())
        var state = try #require(store.state)
        state.resolutionEvents = [
            ResolutionEvent(
                id: UUID(), periodID: period.id, paystubID: UUID(), status: .explained,
                note: "Synthetic orphan", recordedEpochSeconds: 0)
        ]
        #expect(throws: LocalStateStoreError.invalidState) {
            try AppStateValidation.validate(state)
        }
    }

    @Test func reportNotesRequireExplicitOptIn() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let period = try #require(model.periodContext())
        let sentinel = "PRIVATE-RESOLUTION-SENTINEL"
        try model.recordResolution(periodID: period.id, status: .shared, note: sentinel)
        let context = try #require(model.periodContext())
        let calculation = try #require(context.calculation)
        for (includeSource, include) in [
            (false, false), (true, false), (false, true), (true, true),
        ] {
            let url = try ReconciliationReportExporter().export(
                window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
                agreement: context.agreement, calculation: calculation, paystub: context.paystub,
                reconciliation: context.reconciliation, findings: [],
                resolutionEvents: context.resolutionEvents,
                privacy: ReportPrivacyOptions(
                    includeSourceDetails: includeSource, includeResolutionHistory: include))
            defer { try? TemporaryExports.removeReport(url) }
            let text = try #require(PDFDocument(url: url)?.string)
            #expect(text.contains(sentinel) == include)
        }
    }
}
