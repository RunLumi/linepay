import Foundation
import LinePayDomain
import PDFKit
import Testing

@testable import LinePay

@Suite("PDF report content", .serialized)
@MainActor
struct ReportExporterTests {
    @Test(arguments: ["400", "350", "450"])
    func auditedReportContainsComparisonAndDisclaimer(_ gross: String) throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: gross))
        let active = try #require(model.activePeriod)
        let calculation = try #require(model.calculation)
        let stub = try #require(model.currentPaystub)
        let url = try ReconciliationReportExporter().export(
            window: active.window, timeZoneIdentifier: "UTC",
            agreement: active.agreement, calculation: calculation, paystub: stub,
            reconciliation: model.reconciliation,
            findings: model.auditFindings(calculation: calculation, paystub: stub))
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try #require(PDFDocument(url: url))
        let text = try #require(pdf.string)
        #expect(pdf.pageCount > 0)
        #expect(text.contains("Expected wage pay") && text.contains("Confirmed paystub gross"))
        #expect(text.contains(model.currentAuditStatus.title))
        #expect(text.contains("Calculation engine: linepay.configured-pay/2"))
        #expect(text.contains("Rule snapshot") && text.contains("not a legal determination"))
        #expect(text.contains("Original paystub pages are excluded"))
    }

    @Test func longLedgerPaginatesWithoutDroppingTail() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        let active = try #require(model.activePeriod)
        let component = try #require(model.calculation?.components.first)
        let components = (0..<90).map { i in
            PayComponent(
                category: .workedHours, workIntervalID: component.workIntervalID,
                localDate: component.localDate, hours: 1, multiplier: 1,
                amount: Money(amount: 50, currencyCode: "USD"), explanation: "SYNTHETIC-ROW-\(i)")
        }
        let calculation = CalculationResult(
            agreementID: active.agreement.id,
            agreementVersion: active.agreement.version, components: components,
            total: Money(amount: 4_500, currencyCode: "USD"))
        let url = try ReconciliationReportExporter().export(
            window: active.window, timeZoneIdentifier: "UTC",
            agreement: active.agreement, calculation: calculation, paystub: nil,
            reconciliation: nil, findings: [])
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try #require(PDFDocument(url: url))
        let text = try #require(pdf.string)
        #expect(pdf.pageCount > 1 && text.contains("SYNTHETIC-ROW-89"))
        #expect(text.contains("Awaiting paycheck") && text.contains("Rule snapshot"))
    }
}
