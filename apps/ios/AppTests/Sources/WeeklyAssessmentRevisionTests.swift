import Foundation
import LinePayDomain
import PDFKit
import Testing

@testable import LinePay

private final class WeeklyAssessmentResourceAnchor: NSObject {}

@Suite("Versioned weekly paycheck safeguards", .serialized)
@MainActor
struct WeeklyAssessmentRevisionTests {
    private struct Fixtures: Decodable {
        struct Row: Decodable {
            let id: String
            let agreement: AgreementSnapshot
            let calculation: CalculationResult
            let assessment: PaycheckAssessment
        }
        let cases: [Row]
    }
    private func legacyStore(id: String = "configured-eight-hours") throws -> UnitStateStore {
        let url = try #require(
            Bundle(for: WeeklyAssessmentResourceAnchor.self)
                .url(forResource: "native-assessment-v3", withExtension: "json"))
        let row = try #require(
            JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url)).cases.first {
                $0.id == id
            })
        let workID = try #require(row.calculation.components.first?.workIntervalID)
        let work = WorkEntry(
            interval: try WorkInterval(
                id: workID,
                startEpochSeconds: 1_788_739_200, endEpochSeconds: 1_788_768_000,
                timeZoneIdentifier: "UTC"),
            note: "SYNTHETIC legacy work")
        let window = PayPeriodWindow(
            startEpochSeconds: 1_788_739_200,
            endEpochSeconds: 1_789_344_000, cadence: .weekly)
        let stub = ConfirmedPaystub(
            payPeriodStart: LocalDate(year: 2026, month: 9, day: 7),
            payPeriodEnd: LocalDate(year: 2026, month: 9, day: 13),
            grossPay: row.assessment.paidGross,
            confirmedEpochSeconds: 1_788_768_001,
            confirmation: PaystubConfirmation(
                grossBasis: .wagesOnly, lineLayout: .unconfirmed,
                hoursBasis: .unconfirmed, guaranteeLayout: .unconfirmed,
                reviewedFields: [.periodStart, .periodEnd, .grossPay], suggestions: [:],
                hasAdditionalUnmappedPay: false, workComplete: true), assessment: row.assessment)
        let reconciliation = ReconciliationResult(
            expectedGross: row.calculation.expectedWages,
            actualGross: row.assessment.paidGross, difference: .zero(currencyCode: "USD"),
            direction: .matches)
        let revision = AuditRevision(
            id: stub.id, window: window, agreement: row.agreement,
            timeZoneIdentifier: "UTC", workEntries: [work], calculation: row.calculation,
            paystub: stub, reconciliation: reconciliation)
        var state = AppPersistentState()
        state.schemaVersion = 8
        state.profile = PayProfile(
            name: "SYNTHETIC legacy profile", timeZoneIdentifier: "UTC", agreement: row.agreement)
        state.activePeriod = ActivePayPeriod(
            window: window, agreement: row.agreement,
            timeZoneIdentifier: "UTC", workEntries: [work], paystub: stub,
            reconciliation: reconciliation,
            auditCompletedEpochSeconds: stub.confirmedEpochSeconds, hasConsumedAuditAccess: true,
            auditRevisions: [revision])
        state.hasUsedFreeAudit = true
        let oldBytes = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AppPersistentState.self, from: oldBytes)
        #expect(
            decoded.schemaVersion == AppPersistentState.currentSchemaVersion
                && decoded.activePeriod == state.activePeriod)
        try AppStateValidation.validate(decoded)
        let store = UnitStateStore()
        try store.save(decoded)
        return store
    }

    @Test func loadingAnActiveOldWeeklyCheckRequiresReviewWithoutWritingOrChangingItsReceipt()
        throws
    {
        let store = try legacyStore()
        let original = store.state
        let saves = store.saveCount
        let model = AppModel(store: store)
        let context = try #require(model.periodContext())
        #expect(context.requiresAssessmentReview && !context.requiresCalculationReview)
        #expect(model.currentAuditStatus == .needsReview)
        #expect(
            model.currentPaystub?.assessment?.engineVersion == 3
                && model.currentPaystub?.assessment?.verdict == .matches)
        #expect(store.state == original && store.saveCount == saves)
        let presentation = AuditAssessment.evaluate(
            calculation: context.calculation, paystub: context.paystub,
            reconciliation: context.reconciliation,
            requiresAssessmentReview: context.requiresAssessmentReview,
            agreement: context.agreement)
        #expect(!presentation.isCurrent && presentation.explanation.contains("safeguards changed"))
        let frozen = try #require(context.revisions.last).context(periodID: context.id)
        let recorded = AuditAssessment.evaluate(
            calculation: frozen.calculation, paystub: frozen.paystub,
            reconciliation: frozen.reconciliation, agreement: frozen.agreement)
        #expect(frozen.isClosed && recorded.isCurrent && recorded.legacyScopeNote != nil)
        #expect(frozen.paystub?.assessment == context.paystub?.assessment)
    }

    @Test func anExplicitCorrectionAppendsCurrentAndPreservesV3AcrossArchiveAndBackup() throws {
        let store = try legacyStore()
        let before = try #require(store.state?.activePeriod?.auditRevisions?.first)
        let model = AppModel(store: store)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let context = try #require(model.periodContext())
        #expect(!context.requiresAssessmentReview && model.currentAuditStatus == .needsReview)
        #expect(context.revisions.count == 2 && context.revisions.first == before)
        #expect(context.paystub?.assessment?.engineVersion == PaycheckAssessor.currentEngineVersion)
        #expect(
            context.paystub?.assessment?.expectedGross == before.paystub.assessment?.expectedGross)
        try model.archiveCurrentPeriod()
        let period = try #require(model.history.first)
        #expect(period.auditRevisions?.first == before)
        let state = try #require(store.state)
        let restored = try BackupArchive.decode(
            BackupArchive(createdAt: UnitFixture.start, state: state, files: []).encoded())
        #expect(
            restored.state.history == state.history
                && restored.state.schemaVersion == AppPersistentState.currentSchemaVersion)
        #expect(AppModel(store: store).history == state.history)
    }

    @Test func anArchivedOriginalRetainsItsVerdictAndThePDFLabelsItsEarlierScope() throws {
        let store = try legacyStore()
        let model = AppModel(store: store)
        let original = try #require(model.currentPaystub?.assessment)
        try model.archiveCurrentPeriod()
        let period = try #require(model.history.first)
        let context = try #require(model.periodContext(id: period.id))
        #expect(context.isClosed && !context.requiresAssessmentReview)
        #expect(
            model.status(for: context) == .grossMatches && context.paystub?.assessment == original)
        let presentation = AuditAssessment.evaluate(
            calculation: context.calculation, paystub: context.paystub,
            reconciliation: context.reconciliation, agreement: context.agreement)
        #expect(presentation.legacyScopeNote != nil && presentation.isCurrent)
        let url = try ReconciliationReportExporter().export(
            window: context.window, timeZoneIdentifier: "UTC",
            agreement: context.agreement, calculation: #require(context.calculation),
            paystub: context.paystub,
            reconciliation: context.reconciliation, findings: [])
        defer { try? TemporaryExports.removeReport(url) }
        let text = try #require(PDFDocument(url: url)?.string)
        #expect(text.contains("Earlier weekly comparison") && text.contains("Recorded verdict"))
        #expect(text.contains("Gross total matches") && context.paystub?.assessment == original)
    }

    @Test func unrelatedLegacyScopeStaysUsableButForgedV4WeeklyMatchIsRejected() throws {
        let unaffected = AppModel(store: try legacyStore(id: "no-weekly-scope"))
        #expect(unaffected.currentAuditStatus == .grossMatches)
        #expect(unaffected.periodContext()?.requiresAssessmentReview == false)
        let store = try legacyStore()
        let model = AppModel(store: store)
        try model.confirmPaystub(UnitFixture.paystub(model))
        var raw = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(store.state)) as? [String: Any])
        var active = try #require(raw["activePeriod"] as? [String: Any])
        var stub = try #require(active["paystub"] as? [String: Any])
        var assessment = try #require(stub["assessment"] as? [String: Any])
        assessment["verdict"] = "matches"
        assessment["reviewReasons"] = []
        stub["assessment"] = assessment
        active["paystub"] = stub
        raw["activePeriod"] = active
        let invalid = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(throws: (any Error).self) { try AppStateValidation.validate(invalid) }
    }
    @Test func failedNewReviewKeepsTheOriginalComparisonAndPendingReviewFlag() throws {
        let store = try legacyStore()
        let model = AppModel(store: store)
        let before = store.state
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.confirmPaystub(UnitFixture.paystub(model))
        }
        #expect(store.state == before && model.currentPaystub?.assessment?.engineVersion == 3)
        #expect(model.periodContext()?.requiresAssessmentReview == true)
        #expect(model.activePeriod?.auditRevisions?.count == 1)
    }

}
