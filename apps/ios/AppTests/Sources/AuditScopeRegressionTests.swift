import Foundation
import LinePayDomain
import PDFKit
import Testing

@testable import LinePay

@Suite("One truthful audit verdict", .serialized)
@MainActor
struct AuditScopeRegressionTests {
    @Test func offsettingComponentsCannotClaimMatchOnAnySurface() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.regularPay = "350"
        stub.overtimePay = "50"
        stub.reviewedFields = Set(PaystubField.allCases)
        stub.lineLayout = .fullRateBuckets
        stub.hoursBasis = .actualWork
        stub.guaranteeLayout = .separateLine
        try model.confirmPaystub(stub)
        #expect(model.reconciliation?.direction == .matches)
        #expect(model.currentAuditStatus == .needsReview)
        let assessment = evaluate(model)
        #expect(
            assessment.status == .needsReview
                && assessment.explanation.lowercased().contains("gross total matches"))
        let period = try #require(model.activePeriod)
        let url = try ReconciliationReportExporter().export(
            window: period.window, timeZoneIdentifier: "UTC", agreement: period.agreement,
            calculation: #require(model.calculation), paystub: model.currentPaystub,
            reconciliation: model.reconciliation,
            findings: model.auditFindings(
                calculation: #require(model.calculation), paystub: #require(model.currentPaystub)))
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try #require(PDFDocument(url: url)?.string)
        #expect(text.contains("Needs review") && text.contains("offsetting"))
        try model.archiveCurrentPeriod()
        let frozen = try #require(model.history.first)
        #expect(model.auditStatus(for: frozen) == .needsReview)
        let reloaded = AppModel(store: store)
        let reloadedPeriod = try #require(reloaded.history.first)
        #expect(reloaded.auditStatus(for: reloadedPeriod) == .needsReview)
    }

    @Test func grossOnlyAndConfirmedItemsHaveDifferentScope() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.reviewedFields = Set(PaystubField.allCases)
        stub.lineLayout = .fullRateBuckets
        stub.hoursBasis = .actualWork
        stub.guaranteeLayout = .separateLine
        try model.confirmPaystub(stub)
        #expect(model.currentAuditStatus == .grossMatches)
        #expect(model.currentPaystub?.assessment?.scope == .grossOnly)
        stub.regularPay = "400"
        stub.regularHours = "8"
        stub.reviewedFields = Set(PaystubField.allCases)
        stub.lineLayout = .fullRateBuckets
        stub.hoursBasis = .actualWork
        stub.guaranteeLayout = .separateLine
        try model.confirmPaystub(stub)
        #expect(model.currentAuditStatus == .matches)
        #expect(model.currentPaystub?.assessment?.scope == .confirmedLines)
    }

    @Test(arguments: ["7.5", "8.5", "0"])
    func confirmedHourMismatchPreventsMatchEvenWithEqualPay(_ hours: String) throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.regularPay = "400"
        stub.regularHours = hours
        stub.reviewedFields = Set(PaystubField.allCases)
        stub.lineLayout = .fullRateBuckets
        stub.hoursBasis = .actualWork
        stub.guaranteeLayout = .separateLine
        try model.confirmPaystub(stub)
        #expect(model.currentAuditStatus == .needsReview)
        #expect(evaluate(model).hours.first?.expected == 8)
        #expect(evaluate(model).hours.first?.differs == true)
    }

    @Test(arguments: ["400", "400.00", "399.99", "400.01"])
    func confirmedCentDifferencesSurviveArchiveAndReload(_ regularPay: String) throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.regularPay = regularPay
        stub.overtimePay = "0"
        stub.reviewedFields = Set(PaystubField.allCases)
        stub.lineLayout = .fullRateBuckets
        stub.hoursBasis = .actualWork
        stub.guaranteeLayout = .separateLine
        try model.confirmPaystub(stub)
        let expected: AuditDisplayStatus =
            ["400", "400.00"].contains(regularPay) ? .matches : .needsReview
        #expect(model.reconciliation?.direction == .matches)
        #expect(model.currentAuditStatus == expected)
        try model.archiveCurrentPeriod()
        let reloaded = AppModel(store: store)
        let archived = try #require(reloaded.history.first)
        #expect(reloaded.auditStatus(for: archived) == expected)
    }

    @Test func fractionalCentComponentCannotReplaceConfirmedAudit() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        try model.confirmPaystub(stub)
        let before = store.state
        let saves = store.saveCount
        stub.regularPay = "400.001"
        stub.reviewedFields.insert(.regularPay)
        stub.lineLayout = .fullRateBuckets
        #expect(throws: AppModelError.invalidField("regularPay")) {
            try model.confirmPaystub(stub)
        }
        #expect(store.state == before && store.saveCount == saves)
        #expect(model.currentAuditStatus == .grossMatches)
    }

    @Test func missingAndStaleCalculationsAreNotSuccess() throws {
        #expect(
            AuditAssessment.evaluate(calculation: nil, paystub: nil, reconciliation: nil).status
                == .notAudited)
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile())
        #expect(throws: AppModelError.calculationUnavailable) {
            try model.confirmPaystub(UnitFixture.paystub(model))
        }
        #expect(!model.hasUsedFreeAudit)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(8 * 3_600),
            kind: .regular)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let oldCalculation = model.calculation
        let oldReconciliation = model.reconciliation
        let entry = try #require(model.workEntries.first)
        try model.updateWork(
            id: entry.id, start: UnitFixture.start,
            end: UnitFixture.start.addingTimeInterval(9 * 3_600), kind: .regular)
        #expect(model.currentAuditStatus == .needsReview)
        #expect(
            AuditAssessment.evaluate(
                calculation: model.calculation, paystub: model.currentPaystub,
                reconciliation: oldReconciliation
            ).status == .needsReview)
        #expect(
            AuditAssessment.evaluate(
                calculation: oldCalculation, paystub: model.currentPaystub,
                reconciliation: nil
            ).status == .needsReview)
    }

    @Test func conflictingCurrencyCannotBeSilentlyIgnored() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let stub = ConfirmedPaystub(
            payPeriodStart: nil, payPeriodEnd: nil,
            grossPay: Money(amount: 400, currencyCode: "USD"),
            regularPay: Money(amount: 400, currencyCode: "CAD"))
        let result = AuditAssessment.evaluate(
            calculation: model.calculation, paystub: stub,
            reconciliation: model.reconciliation)
        #expect(result.status == .needsReview && result.explanation.contains("currencies"))
    }

    private func evaluate(_ model: AppModel) -> AuditAssessment {
        AuditAssessment.evaluate(
            calculation: model.calculation,
            paystub: model.currentPaystub, reconciliation: model.reconciliation)
    }
}
