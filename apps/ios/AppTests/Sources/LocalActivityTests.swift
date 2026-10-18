import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Device-local milestones never collect pay content", .serialized)
@MainActor
struct LocalActivityTests {
    @Test func financialSuccessAndVisibleValueHaveDistinctHonestMilestones() throws {
        let ledger = LocalActivityLedger()
        let model = AppModel(store: UnitStateStore(), activity: ledger)
        model.observedExpectedPay()
        #expect(ledger.count(.expectedPaySeen) == 0)
        var profile = UnitFixture.profile()
        profile.name = "SYNTHETIC PRIVATE EMPLOYER"
        try model.saveSetupDraft(profile)
        try model.saveSetupDraft(profile)
        #expect(ledger.count(.profileStarted) == 1 && ledger.count(.profileReady) == 0)
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(8 * 3_600),
            kind: .regular, note: "SYNTHETIC PRIVATE UNION NOTE")
        #expect(ledger.count(.profileReady) == 1 && ledger.count(.workLogged) == 1)
        #expect(ledger.count(.expectedPaySeen) == 0)
        model.observedExpectedPay()
        model.observedExpectedPay()
        #expect(ledger.count(.expectedPaySeen) == 1)
        try model.confirmPaystub(UnitFixture.paystub(model))
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "375"))
        #expect(ledger.count(.paycheckImported) == 1 && ledger.count(.auditCompleted) == 1)
        #expect(ledger.count(.secondAudit) == 0)
        try model.archiveCurrentPeriod()
        let next = try #require(model.activePeriod)
        try model.addWork(
            start: next.window.startDate, end: next.window.startDate.addingTimeInterval(8 * 3_600),
            kind: .regular)
        try model.confirmPaystub(UnitFixture.paystub(model), hasProAccess: true)
        #expect(ledger.count(.auditCompleted) == 2 && ledger.count(.secondAudit) == 1)
        #expect(ledger.count(.verifiedPaidObserved) == 0)
        let text = String(decoding: try ledger.diagnosticData(), as: UTF8.self)
        #expect(!text.contains(profile.name) && !text.contains("PRIVATE UNION"))
        #expect(!text.contains(next.id.uuidString))
    }

    @Test func financialFailureCannotRecordSuccessAndDiagnosticFailureCannotUndoWork() throws {
        let activityStore = FailingActivityStore()
        let ledger = LocalActivityLedger(store: activityStore)
        let store = UnitStateStore()
        let model = AppModel(store: store, activity: ledger)
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.saveProfile(UnitFixture.profile())
        }
        #expect(ledger.count(.profileReady) == 0)
        store.failSave = false
        activityStore.failSave = true
        try UnitFixture.populate(model)
        #expect(model.calculation?.expectedWages.amount == 400 && model.workEntries.count == 1)
        #expect(ledger.issue != nil && ledger.count(.workLogged) == 0)
        activityStore.failSave = false
        ledger.record(.appOpened)
        let export = try JSONDecoder().decode(
            LocalDiagnosticExport.self, from: ledger.diagnosticData())
        #expect(export.failedObservationCount >= 2 && export.recordingIssue)
        #expect(ledger.count(.profileReady) == 0 && ledger.count(.workLogged) == 0)
    }

    @Test func exportContainsOnlyClosedCountsAndUsageDaysNotDeduplicationOrIdentifiers() throws {
        let store = MemoryLocalActivityStore()
        let ledger = LocalActivityLedger(store: store, now: { UnitFixture.start })
        let id = UUID()
        ledger.record(.workLogged, once: .work(id))
        ledger.record(.workLogged, once: .work(id))
        ledger.record(.verifiedTrialObserved, once: .transaction(123_456))
        let bytes = try ledger.diagnosticData()
        let text = String(decoding: bytes, as: UTF8.self)
        let state = try #require(store.value)
        #expect(ledger.count(.workLogged) == 1)
        #expect(!text.contains(id.uuidString) && !text.contains("123456"))
        #expect(!text.contains("deduplicationDigests"))
        for digest in state.deduplicationDigests { #expect(!text.contains(digest)) }
        let json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let days = try #require(json["days"] as? [[String: Any]])
        #expect(Set(days[0].keys) == ["dayUTC", "tallies"])
        let tallies = try #require(days[0]["tallies"] as? [[String: Any]])
        #expect(tallies.allSatisfy { Set($0.keys) == ["milestone", "count"] })
    }

    @Test func payBackupRestoreDoesNotBackfillObservedFunnelHistory() throws {
        let sourceStore = UnitStateStore()
        let source = AppModel(store: sourceStore)
        try UnitFixture.populate(source)
        try source.confirmPaystub(UnitFixture.paystub(source))
        let archive = BackupArchive(
            createdAt: UnitFixture.start, state: try #require(sourceStore.state), files: [])
        let ledger = LocalActivityLedger()
        ledger.record(.appOpened)
        let destination = AppSession(
            store: UnitStateStore(), evidenceStore: MemoryEvidenceStore(), activity: ledger)
        try destination.restore(archive)
        #expect(destination.model.calculation?.expectedWages.amount == 400)
        #expect(ledger.count(.backupRestored) == 1 && ledger.count(.appOpened) == 1)
        #expect(
            ledger.count(.profileReady) == 0 && ledger.count(.workLogged) == 0
                && ledger.count(.auditCompleted) == 0)
        destination.model.observedExpectedPay()
        #expect(ledger.count(.expectedPaySeen) == 1)
        let backupJSON = String(decoding: try JSONEncoder().encode(archive.state), as: UTF8.self)
        #expect(
            !backupJSON.contains("deduplicationDigests") && !backupJSON.contains("profile_ready"))
    }

    @Test func optOutAndExplicitResetPreserveChoiceWithoutAffectingMoney() throws {
        let activityStore = FailingActivityStore()
        let ledger = LocalActivityLedger(store: activityStore)
        let store = UnitStateStore()
        let model = AppModel(store: store, activity: ledger)
        try UnitFixture.populate(model)
        try ledger.setRecordingEnabled(false)
        ledger.record(.appOpened)
        #expect(ledger.count(.appOpened) == 0)
        try ledger.clear()
        #expect(!ledger.snapshot.recordingEnabled && ledger.snapshot.days.isEmpty)
        #expect(model.calculation?.expectedWages.amount == 400)
        activityStore.failSave = true
        #expect(throws: (any Error).self) { try model.resetAllData() }
        #expect(model.calculation?.expectedWages.amount == 400 && model.profile != nil)
        activityStore.failSave = false
        try model.resetAllData()
        #expect(model.profile == nil && !ledger.snapshot.recordingEnabled)
    }

    @Test func dailyRetentionDoesNotTurnLifetimeCountsIntoACohortClaim() throws {
        var clock = UnitFixture.start
        let ledger = LocalActivityLedger(now: { clock })
        for _ in 0..<401 {
            ledger.record(.appOpened)
            clock = clock.addingTimeInterval(86_400)
        }
        #expect(ledger.snapshot.days.count == 400 && ledger.count(.appOpened) == 401)
        #expect(ledger.snapshot.prunedDayCount == 1)
        try ledger.setRecordingEnabled(false)
        try ledger.setRecordingEnabled(true)
        #expect(ledger.snapshot.recordingPauseCount == 1)
        let export = try JSONDecoder().decode(
            LocalDiagnosticExport.self, from: ledger.diagnosticData())
        #expect(
            export.scope.contains("Not App Store installs")
                && export.scope.contains("not anonymous"))
    }

    @Test func unreadableActivityIsPreservedAndDoesNotBlockThePayModel() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = FileLocalActivityStore(directory: root)
        let corrupt = Data("SYNTHETIC UNREADABLE LOCAL ACTIVITY".utf8)
        try corrupt.write(to: store.url)
        let ledger = LocalActivityLedger(store: store)
        let model = AppModel(store: UnitStateStore(), activity: ledger)
        try UnitFixture.populate(model)
        #expect(model.calculation?.expectedWages.amount == 400 && ledger.issue != nil)
        #expect(try Data(contentsOf: store.url) == corrupt)
        #expect(!ledger.snapshot.recordingEnabled)
        try ledger.clear()
        #expect(try store.load()?.days.isEmpty == true && !ledger.snapshot.recordingEnabled)
    }

    @Test func onceMilestonesDoNotRepeatWhenOldDeduplicationDigestsArePruned() throws {
        let store = MemoryLocalActivityStore()
        let first = LocalActivityLedger(store: store)
        first.record(.firstObservedOpen, once: .once)
        var retained = try #require(store.value)
        retained.deduplicationDigests = []
        store.value = retained
        let reloaded = LocalActivityLedger(store: store)
        reloaded.record(.firstObservedOpen, once: .once)
        #expect(reloaded.count(.firstObservedOpen) == 1)
    }

    @Test func realLocalFileReloadAndInvalidCounterRefusal() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileLocalActivityStore(directory: root)
        let ledger = LocalActivityLedger(store: store)
        ledger.record(.firstObservedOpen, once: .once)
        let reloaded = LocalActivityLedger(store: store)
        reloaded.record(.firstObservedOpen, once: .once)
        #expect(reloaded.count(.firstObservedOpen) == 1)
        var bad = reloaded.snapshot
        bad.totals[0].count = -1
        #expect(throws: (any Error).self) { try LocalActivityLedger.validate(bad) }
    }
}

@MainActor
private final class FailingActivityStore: LocalActivityStoring {
    var value: LocalActivitySnapshot?
    var failSave = false
    func load() throws -> LocalActivitySnapshot? { value }
    func save(_ value: LocalActivitySnapshot) throws {
        if failSave { throw UnitFailure.injected }
        self.value = value
    }
}
