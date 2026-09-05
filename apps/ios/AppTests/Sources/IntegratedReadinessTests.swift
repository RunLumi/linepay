import Foundation
import LinePayDomain
import Testing

@testable import LinePay

private final class MigrationResourceAnchor: NSObject {}

@Suite("Integrated payday, migration and cleanup contracts")
@MainActor
struct IntegratedReadinessTests {
    @Test func sundayCloseMondayWorkAndThursdayPaycheckKeepSeparateRules() throws {
        let formatter = ISO8601DateFormatter()
        let monday = try #require(formatter.date(from: "2026-09-07T07:00:00Z"))
        let sunday = try #require(formatter.date(from: "2026-09-13T23:00:00Z"))
        let nextMonday = try #require(formatter.date(from: "2026-09-14T07:00:00Z"))
        let thursday = try #require(formatter.date(from: "2026-09-17T12:00:00Z"))
        var clock = monday.addingTimeInterval(28_800)
        let model = AppModel(now: { clock })
        var profile = UnitFixture.profile()
        profile.periodStartDate = monday
        try model.saveProfile(profile)
        try model.addWork(start: monday, end: clock, kind: .regular)
        let a = try #require(model.activePeriod)
        clock = sunday
        profile.hourlyRate = "60"
        try model.saveProfile(profile)
        try model.archiveCurrentPeriod()
        let b = try #require(model.activePeriod)
        #expect(b.window.startDate == nextMonday.addingTimeInterval(-7 * 3600))
        #expect(a.window.displayEndDate == nextMonday.addingTimeInterval(-7 * 3600 - 1))
        clock = nextMonday.addingTimeInterval(28_800)
        try model.addWork(start: nextMonday, end: clock, kind: .regular)
        let bWork = model.workEntries
        clock = thursday
        var paycheck = try model.paycheckDraft(for: a.id)
        paycheck.grossPay = "400"
        paycheck.grossBasis = .wagesOnly
        paycheck.workComplete = true
        paycheck.reviewedFields = [.periodStart, .periodEnd, .grossPay]
        try model.confirmPaystub(paycheck, periodID: a.id)
        #expect(
            model.history.first?.paystub?.confirmedEpochSeconds
                == Int64(thursday.timeIntervalSince1970))
        #expect(model.history.first?.calculation.total.amount == 400)
        #expect(model.history.first?.agreement.hourlyRate.amount == 50)
        #expect(model.activePeriod?.id == b.id && model.workEntries == bWork)
        #expect(model.calculation?.total.amount == 480)
    }
    @Test func partialWorkCannotProduceAFullPaycheckVerdictOrConsumeFreeAccess() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.paystub(model, gross: "3000")
        draft.workComplete = nil
        try model.confirmPaystub(draft)
        #expect(model.currentAuditStatus == .notComparable)
        #expect(model.reconciliation == nil && !model.hasUsedFreeAudit)
        draft.workComplete = true
        try model.confirmPaystub(draft)
        #expect(model.currentAuditStatus == .possibleOverpayment && model.hasUsedFreeAudit)
    }
    @Test func paidAuditsPreserveUnusedFreeAuditAcrossRelaunchAndExpiry() throws {
        let store = MemoryStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model), hasProAccess: true)
        #expect(!model.hasUsedFreeAudit)
        try model.archiveCurrentPeriod()
        let next = try #require(model.activePeriod)
        try model.addWork(
            start: next.window.startDate,
            end: next.window.startDate.addingTimeInterval(28_800), kind: .regular)
        let restored = AppModel(store: store)
        #expect(restored.canRunAudit(hasProAccess: false))
        try restored.confirmPaystub(UnitFixture.paystub(restored), hasProAccess: false)
        #expect(restored.hasUsedFreeAudit)
        try restored.archiveCurrentPeriod()
        #expect(!restored.canRunAudit(hasProAccess: false))
        #expect(restored.canRunAudit(periodID: next.id, hasProAccess: false))
    }

    @Test func firstRealResultSurvivesInterruptionAndOnlyAppearsOnce() throws {
        let store = MemoryStateStore()
        let model = AppModel(store: store)
        try model.saveProfile(UnitFixture.profile())
        #expect(model.onboardingProgress == .firstWork)
        try model.deferFirstWork()
        #expect(AppModel(store: store).onboardingProgress == .waitingForFirstResult)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(28_800),
            kind: .regular)
        #expect(model.onboardingProgress == .proof && model.calculation?.total.amount == 400)
        let restored = AppModel(store: store)
        #expect(restored.onboardingProgress == .proof && restored.calculation?.total.amount == 400)
        try restored.completeFirstResult()
        try restored.addWork(
            start: UnitFixture.start.addingTimeInterval(86_400),
            end: UnitFixture.start.addingTimeInterval(115_200), kind: .regular)
        #expect(restored.onboardingProgress == nil && restored.calculation?.total.amount == 800)
    }

    @Test func groupedMoneyIsExactAndTrailingTextIsRejected() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile(rate: "1,000.00"))
        #expect(model.profile?.agreement.hourlyRate.amount == 1000)
        #expect(throws: (any Error).self) {
            try model.saveProfile(UnitFixture.profile(rate: "58oops"))
        }
        #expect(model.profile?.agreement.hourlyRate.amount == 1000)
    }

    @Test func staticV1FixturePreservesHistoricalMeaningAndOriginal() throws {
        let fixture = try #require(
            Bundle(for: MigrationResourceAnchor.self).url(
                forResource: "schema-v1-synthetic", withExtension: "json"))
        let bytes = try Data(contentsOf: fixture)
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let saved = root.appendingPathComponent("state-v1.json")
        try bytes.write(to: saved)
        let store = VersionedLocalStateStore(baseDirectory: root)
        let decoded = try #require(try store.load())
        let original = try #require(decoded.history.first?.paystub?.evidence)
        let originalURL = root.appendingPathComponent(original.storedFilename)
        let source = Data("SYNTHETIC LEGACY ORIGINAL".utf8)
        try source.write(to: originalURL)
        let model = AppModel(store: store, evidenceStore: LocalEvidenceStore(baseDirectory: root))
        #expect(model.persistenceIssue == nil && model.onboardingProgress == nil)
        let history = try #require(model.history.first)
        #expect(
            history.calculation.total.amount == 400 && history.agreement.hourlyRate.amount == 50)
        #expect(model.profile?.agreement.hourlyRate.amount == 60)
        #expect(
            model.status(for: try #require(model.periodContext(id: history.id))) == .needsReview)
        #expect(try Data(contentsOf: saved) == bytes)
        #expect(try Data(contentsOf: originalURL) == source)
        var draft = try model.paycheckDraft(for: history.id)
        draft.workComplete = true
        draft.grossBasis = .wagesOnly
        draft.reviewedFields = [.periodStart, .periodEnd, .grossPay]
        try model.confirmPaystub(draft, periodID: history.id)
        #expect(model.history.first?.auditRevisions?.count == 2)
        #expect(model.history.first?.calculation == history.calculation)
        #expect(try store.load()?.schemaVersion == AppPersistentState.currentSchemaVersion)
        #expect(try Data(contentsOf: originalURL) == source)
    }

    @Test func interruptedOriginalIsTrackedAfterRelaunchAndUnrelatedFilesSurviveDeleteAll() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let evidence = LocalEvidenceStore(baseDirectory: root)
        let staged = try evidence.save(
            data: Data("SYNTHETIC INTERRUPTED IMPORT".utf8), originalFilename: "source.pdf",
            mediaType: "application/pdf", sourceKind: .file, recognizedText: nil)
        let unrelated = root.appendingPathComponent("keep-user-note.txt")
        try Data("Unrelated file".utf8).write(to: unrelated)
        let state = MemoryStateStore()
        let model = AppModel(store: state, evidenceStore: evidence)
        #expect(model.pendingDeletionCount == 1)
        #expect(
            try state.load()?.pendingEvidenceDeletions.first?.storedFilename
                == staged.storedFilename)
        try model.retryEvidenceDeletion()
        #expect(model.pendingDeletionCount == 0 && evidence.url(for: staged) == nil)
        try model.resetAllData()
        #expect(try Data(contentsOf: unrelated) == Data("Unrelated file".utf8))
    }

    @Test(arguments: [
        "negative-paystub", "wrong-currency", "invalid-date", "mismatched-assessment",
        "wrong-total",
    ])
    func malformedStoredMoneyEntersRecoveryWithoutOverwriting(_ defect: String) throws {
        let memory = MemoryStateStore()
        let sourceModel = AppModel(store: memory)
        try UnitFixture.populate(sourceModel)
        try sourceModel.confirmPaystub(UnitFixture.paystub(sourceModel))
        try sourceModel.archiveCurrentPeriod()
        let state = try #require(try memory.load())
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var history = try #require(object["history"] as? [[String: Any]])
        var stub = try #require(history[0]["paystub"] as? [String: Any])
        switch defect {
        case "negative-paystub": stub["regularPay"] = ["amount": -1, "currencyCode": "USD"]
        case "wrong-currency": stub["grossPay"] = ["amount": 400, "currencyCode": "EUR"]
        case "invalid-date": stub["payPeriodEnd"] = ["year": 2026, "month": 2, "day": 30]
        case "mismatched-assessment":
            var assessment = try #require(stub["assessment"] as? [String: Any])
            assessment["paidGross"] = ["amount": 999, "currencyCode": "USD"]
            stub["assessment"] = assessment
        default:
            var calculation = try #require(history[0]["calculation"] as? [String: Any])
            calculation["total"] = ["amount": 999, "currencyCode": "USD"]
            history[0]["calculation"] = calculation
        }
        history[0]["paystub"] = stub
        object["history"] = history
        let bytes = try JSONSerialization.data(withJSONObject: object)
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("state-v1.json")
        try bytes.write(to: file)
        let model = AppModel(store: VersionedLocalStateStore(baseDirectory: root))
        #expect(model.persistenceIssue != nil)
        #expect(throws: AppModelError.persistenceFailed) {
            try model.saveProfile(UnitFixture.profile())
        }
        #expect(try Data(contentsOf: file) == bytes)
    }
}
