import Foundation
import LinePayDomain
import PDFKit
import Testing
import UIKit

@testable import LinePay

@Suite("Synthetic document input and report output", .serialized)
@MainActor
struct DocumentPipelineTests {
    @Test func localVisionDoesNotPreferYTDOverCurrentGross() async throws {
        let data = document(pages: 1, line: "Gross pay: Current $1,000.00 YTD $12,000.00")
        let result = try await PaystubOCRService().recognize(data: data, fileExtension: "pdf")
        #expect(result.pageCount == 1)
        #expect(!result.recognizedText.isEmpty)
        if let suggestion = result.suggestions[.grossPay] {
            #expect(suggestion.value == nil || suggestion.value == "1000")
            #expect(suggestion.region.page == 0)
            #expect((0...1).contains(suggestion.region.x))
            #expect((0...1).contains(suggestion.confidence))
        }
    }
    @Test func pageLimitIsExplicitAndOriginalDataIsUnmodified() async throws {
        let original = document(pages: 9, line: "Gross pay $400.00")
        let result = try await PaystubOCRService().recognize(data: original, fileExtension: "pdf")
        #expect(result.pageCount == 9)
        #expect(result.notice?.contains("first 8") == true)
        #expect(PDFDocument(data: original)?.pageCount == 9)
    }
    @Test func reportUsesComparableWagesAndPaginatesLongEvidence() throws {
        let model = try ReadinessTests().configured()
        var profile = PayProfileDraft(
            profile: try #require(model.profile), activePeriod: model.activePeriod)
        profile.editScope = .currentPeriod
        profile.usePerDiem = true
        profile.perDiemAmount = "125"
        profile.sourceTitle =
            String(repeating: "SYNTHETIC SOURCE WITH LONG NOTES ", count: 1000)
            + "END OF LONG SOURCE"
        try model.saveProfile(profile)
        var stub = try ReadinessTests().paycheck(model)
        stub.perDiemPay = "125"
        stub.reviewedFields.insert(.perDiemPay)
        try model.confirmPaystub(stub)
        let context = try #require(model.periodContext())
        let calculation = try #require(context.calculation)
        let url = try ReconciliationReportExporter().export(
            window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
            agreement: context.agreement, calculation: calculation, paystub: context.paystub,
            reconciliation: context.reconciliation, findings: [])
        defer { try? FileManager.default.removeItem(at: url) }
        let report = try #require(PDFDocument(url: url))
        let text = try #require(report.string)
        #expect(report.pageCount > 2)
        #expect(
            text.contains(
                "Expected wage pay: \(LinePayFormat.money(Money(amount: 400, currencyCode: "USD")))"
            ))
        #expect(
            text.contains(
                "Expected per diem: \(LinePayFormat.money(Money(amount: 125, currencyCode: "USD")))"
            ))
        #expect(
            text.contains(
                "Expected on the same basis: \(LinePayFormat.money(Money(amount: 400, currencyCode: "USD")))"
            ))
        #expect(!text.contains("Possible shortfall"))
        #expect(text.contains("Report created:"))
        #expect(text.contains("END OF LONG SOURCE"))
    }
    private func document(pages: Int, line: String) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for index in 0..<pages {
                context.beginPage()
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fill(bounds)
                ("SYNTHETIC PAYSTUB - PAGE \(index + 1)" as NSString).draw(
                    at: CGPoint(x: 40, y: 60),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.black,
                    ])
                (line as NSString).draw(
                    at: CGPoint(x: 40, y: 120),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.black,
                    ])
            }
        }
    }
}
