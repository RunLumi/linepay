import Foundation
import LinePayDomain
import SwiftUI
import Testing
import ViewInspector

@testable import LinePay

/// Fixed synthetic supported layouts, not a production precision estimate or Vision benchmark.
@Suite("Synthetic OCR extraction corpus")
struct OCRCorpusTests {
    struct Case: Sendable {
        let field: PaystubField
        let label: String
        let printed: String
        let expected: String
    }

    static let cases: [Case] = [
        Case(field: .grossPay, label: "Gross pay", printed: "$1,250.50", expected: "1250.5"),
        Case(field: .regularHours, label: "Regular hours", printed: "40.00", expected: "40"),
        Case(field: .regularPay, label: "Regular pay", printed: "$800.00", expected: "800"),
        Case(field: .overtimeHours, label: "Overtime hours", printed: "5.25", expected: "5.25"),
        Case(field: .overtimePay, label: "Overtime pay", printed: "$157.50", expected: "157.5"),
        Case(field: .doubleTimeHours, label: "Double time hours", printed: "2.00", expected: "2"),
        Case(field: .doubleTimePay, label: "Double time pay", printed: "$80.00", expected: "80"),
        Case(field: .calloutPay, label: "Callout pay", printed: "$120.00", expected: "120"),
        Case(field: .perDiemPay, label: "Per diem", printed: "$150.00", expected: "150"),
    ]

    @Test(arguments: cases, [0, 1, 2])
    func supportedCurrentLayoutsKeepExactValuesAndProvenance(_ item: Case, _ layout: Int) throws {
        let text: String
        switch layout {
        case 0: text = "\(item.label) \(item.printed)"
        case 1: text = "\(item.label) Current \(item.printed) YTD 99999.00"
        default: text = "Current \(item.label): \(item.printed)"
        }
        let source = line(text, page: layout)
        let suggestion = try #require(PaystubTextParser.parse([source])[item.field])
        #expect(suggestion.value == item.expected)
        #expect(suggestion.sourceText == text)
        #expect(suggestion.region == source.region)
        #expect(suggestion.confidence == source.confidence)
    }

    @Test(arguments: [
        "Gross pay $100.00 $200.00", "Gross pay -$100.00", "Gross pay ($100.00)",
        "Gross YTD $5000.00", "Gross YTD $5000.00 Current $100.00",
        "Gross current $10.00 rate $5.00", "Gross pay $100.00 and 40 hours",
    ])
    func ambiguousRowsAbstainEvenAtHighRecognitionConfidence(_ text: String) throws {
        let suggestion = try #require(PaystubTextParser.parse([line(text)])[.grossPay])
        #expect(suggestion.value == nil)
        #expect(suggestion.reason != nil)
    }

    @Test func differentPageGrossValuesAreNotSilentlyCombinedOrSelected() throws {
        let result = PaystubTextParser.parse([
            line("Current gross $400.00", page: 0),
            line("Current gross $800.00", page: 1),
        ])
        #expect(try #require(result[.grossPay]).value == nil)
    }

    @Test func lowConfidenceDatesRemainUnconfirmedWithAnExplicitWarning() throws {
        let result = PaystubTextParser.parse([
            line("Pay period 08/31/2026 to 09/06/2026", confidence: 0.4)
        ])
        #expect(result[.periodStart]?.value == "2026-08-31")
        #expect(result[.periodEnd]?.value == "2026-09-06")
        #expect(result[.periodStart]?.reason != nil)
        #expect(result[.periodEnd]?.reason != nil)
        // Recognition only creates suggestions; it cannot mark a draft as reviewed.
        var draft = PaystubConfirmationDraft()
        draft.suggestions = result
        #expect(draft.reviewedFields.isEmpty)
    }

    @MainActor
    @Test func confidenceReceiptDescribesRecognitionRatherThanPayCorrectness() throws {
        let suggestion = OCRFieldSuggestion(
            value: "400", sourceText: "Gross 400.00", region: line("").region,
            confidence: 0.72, reason: "Check the original.")
        let view = OCRFieldProvenanceView(suggestion: suggestion)
        let text = try view.inspect().findAll(ViewType.Text.self)
            .map { try $0.string() }.joined(separator: "\n")
        #expect(text.contains("Original OCR reading"))
        #expect(text.contains("72%"))
        #expect(text.contains("does not verify"))
        #expect(text.contains("Check the original."))
    }

    @MainActor
    @Test(arguments: [-1, 10_000, Int.max])
    func invalidDraftSourcePagesFailBeforeReview(_ page: Int) throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var state = AppPersistentState()
        state.profile = model.profile
        state.activePeriod = model.activePeriod
        var draft = PaystubConfirmationDraft()
        draft.targetPeriodID = model.activePeriod?.id
        draft.suggestions[.grossPay] = OCRFieldSuggestion(
            value: "400", sourceText: "Synthetic gross 400", region: line("", page: page).region,
            confidence: 0.9, reason: nil)
        state.paystubDraft = draft
        #expect(throws: LocalStateStoreError.invalidState) {
            try AppStateValidation.validate(state)
        }
        #expect(throws: AppModelError.persistenceFailed) { try model.savePaystubDraft(draft) }
        #expect(model.paystubDraft == nil)
    }

    @MainActor
    @Test(arguments: [Double.nan, Double.infinity, -0.1, 1.1])
    func invalidDraftConfidenceCannotBecomeSavedSourceMetadata(_ confidence: Double) throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var draft = PaystubConfirmationDraft()
        draft.targetPeriodID = model.activePeriod?.id
        draft.suggestions[.grossPay] = OCRFieldSuggestion(
            value: "400", sourceText: "Synthetic gross 400", region: line("").region,
            confidence: confidence, reason: nil)
        #expect(throws: AppModelError.persistenceFailed) { try model.savePaystubDraft(draft) }
        #expect(model.paystubDraft == nil)
    }

    private func line(_ text: String, page: Int = 0, confidence: Double = 0.96)
        -> RecognizedPaystubLine
    {
        RecognizedPaystubLine(
            text: text, region: SourceRegion(page: page, x: 0.1, y: 0.2, width: 0.7, height: 0.1),
            confidence: confidence)
    }
}
