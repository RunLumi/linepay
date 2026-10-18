import Foundation
import LinePayDomain
import PDFKit
import Testing

@testable import LinePay

private final class BaseAssessmentResourceAnchor: NSObject {}

@Suite("Versioned premium-only paycheck precision", .serialized)
@MainActor
struct BaseAssessmentRevisionTests {
    private struct Fixtures: Decodable {
        struct Row: Decodable {
            let id: String
            let agreement: AgreementSnapshot
            let calculation: CalculationResult
            let assessment: PaycheckAssessment
        }
        let cases: [Row]
    }
    private func legacyStore(id: String = "straight-half-cent") throws -> UnitStateStore {
        let url = try #require(
            Bundle(for: BaseAssessmentResourceAnchor.self)
                .url(forResource: "native-assessment-v4", withExtension: "json"))
        let row = try #require(
            JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url)).cases.first {
                $0.id == id
            })
        let workID = try #require(row.calculation.components.first?.workIntervalID)
        let work = WorkEntry(
            interval: try WorkInterval(
                id: workID,
                startEpochSeconds: 1_788_739_200, endEpochSeconds: 1_788_739_260,
                timeZoneIdentifier: "UTC"),
            note: "SYNTHETIC legacy work")
        let window = PayPeriodWindow(
            startEpochSeconds: 1_788_739_200,
            endEpochSeconds: 1_789_344_000, cadence: .weekly)
        let stub = ConfirmedPaystub(
            payPeriodStart: LocalDate(year: 2026, month: 9, day: 7),
            payPeriodEnd: LocalDate(year: 2026, month: 9, day: 13),
            grossPay: row.assessment.paidGross,
            regularPay: Money(amount: Decimal(string: "0.98")!, currencyCode: "USD"),
            confirmedEpochSeconds: 1_788_768_001,
            confirmation: PaystubConfirmation(
                grossBasis: .wagesOnly, lineLayout: .basePlusPremium,
                hoursBasis: .unconfirmed, guaranteeLayout: .unconfirmed,
                reviewedFields: [.periodStart, .periodEnd, .grossPay, .regularPay],
                suggestions: [:],
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
        state.schemaVersion = 9
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

    @Test func oldBaseCheckRequiresExplicitReviewWithoutWritingThenPreservesItsReceipt() throws {
        let store = try legacyStore()
        let original = store.state
        let saves = store.saveCount
        let model = AppModel(store: store)
        let context = try #require(model.periodContext())
        #expect(context.requiresAssessmentReview && !context.requiresCalculationReview)
        #expect(store.state == original && store.saveCount == saves)
        let before = try #require(context.revisions.first)
        #expect(before.paystub.assessment?.engineVersion == 4)
        let historical = AuditAssessment.evaluate(
            calculation: before.calculation, paystub: before.paystub,
            reconciliation: before.reconciliation, agreement: before.agreement)
        #expect(historical.legacyScopeNote?.contains("premium-only") == true)
        var draft = UnitFixture.paystub(model, gross: "0.98")
        draft.regularPay = "0.98"
        draft.lineLayout = .basePlusPremium
        draft.reviewedFields.insert(.regularPay)
        try model.confirmPaystub(draft)
        let current = try #require(model.periodContext())
        #expect(current.revisions.count == 2 && current.revisions.first == before)
        #expect(current.paystub?.assessment?.engineVersion == 5)
        #expect(
            current.paystub?.assessment?.verdict == .matches && !current.requiresAssessmentReview)
        try model.archiveCurrentPeriod()
        let state = try #require(store.state)
        let restored = try BackupArchive.decode(
            BackupArchive(createdAt: UnitFixture.start, state: state, files: []).encoded())
        #expect(restored.state == state)
        #expect(state.history.first?.auditRevisions?.first == before)
    }

    @Test func currentCalculationCannotLoseItsExactBaseTraceDuringRestore() throws {
        let store = try legacyStore()
        let model = AppModel(store: store)
        var draft = UnitFixture.paystub(model, gross: "0.98")
        draft.regularPay = "0.98"
        draft.lineLayout = .basePlusPremium
        draft.reviewedFields.insert(.regularPay)
        try model.confirmPaystub(draft)
        let state = try #require(store.state)
        let bytes = try JSONEncoder().encode(state)
        let original = String(decoding: bytes, as: UTF8.self)
        // Remove only the new trace key, retaining every other source and recorded amount.
        let pattern = #""baseTimeNumerator":(?:[0-9.]+),?"#
        let corrupted = original.replacingOccurrences(
            of: pattern, with: "", options: .regularExpression
        )
        .replacingOccurrences(of: ",}", with: "}")
        let decoded = try JSONDecoder().decode(AppPersistentState.self, from: Data(corrupted.utf8))
        #expect(throws: (any Error).self) { try AppStateValidation.validate(decoded) }
    }
}
