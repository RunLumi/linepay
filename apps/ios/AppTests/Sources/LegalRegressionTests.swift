import Foundation
import LinePayDomain
import PDFKit
import SwiftUI
import Testing
import ViewInspector

@testable import LinePay

/// Synthetic identifiers deliberately resemble sensitive fields; never use a real worker's data.
@Suite("Legal safeguards: truthful consent, comparison scope and private exports")
@MainActor
struct LegalRegressionTests {
    private func text<V: View>(_ view: V) throws -> String {
        try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }.joined(
            separator: "\n")
    }

    @Test func datedRuleChangeNeverClaimsToRecalculateEarlierWork() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "60")
        draft.setupStep = 3
        draft.editScope = .datedChange
        draft.changeEffectiveDate = UnitFixture.start + 86_400
        try model.saveSetupDraft(draft)
        let content = try text(PayProfileSetupView(model: model))
        #expect(!content.contains("All work in the current open period will be recalculated"))
        #expect(!content.contains("This does not implement a mid-period rate change"))
        #expect(content.contains("Previously recorded work keeps its original rules"))
        #expect(content.contains("UTC"))
        #expect(model.calculation?.total.amount == 400)
    }

    @Test(arguments: RuleEditScope.allCases)
    func allScopeChoicesDiscloseTheLimitsBeforeConfirmation(_ scope: RuleEditScope) throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "60")
        draft.setupStep = 3
        draft.editScope = scope
        try model.saveSetupDraft(draft)
        let content = try text(PayProfileSetupView(model: model))
        #expect(content.contains("Not a complete wage-law check"))
        #expect(content.contains("weekly overtime"))
        #expect(content.contains("regular-rate"))
        #expect(content.contains("daily tiers do not replace"))
        #expect(model.calculation?.total.amount == 400)
    }

    @Test(arguments: ["400", "350", "450"])
    func matchedAndDiscrepantAuditsAlwaysDiscloseLegalScope(_ gross: String) throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: gross))
        let context = try #require(model.periodContext())
        let content = try text(AuditDetailView(model: model, context: context))
        #expect(content.contains("Not a complete wage-law check"))
        #expect(content.contains("statutory or contractual entitlement"))
        let expected = try UnitFixture.decimal(gross)
        #expect(model.currentPaystub?.grossPay.amount == expected)
    }

    @Test func defaultReportDoesNotCopyAdjacentOCRIdentifiersOrFreeTextIdentity() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        var profile = UnitFixture.profile()
        profile.name = "EMPLOYEE-ID-SYNTH-83"
        profile.sourceTitle = "BANK-ACCOUNT-SYNTH-246810"
        profile.sourceURL = "https://example.invalid/private-worker-reference"
        profile.sourceSection = "IDENTIFYING-SOURCE-SECTION"
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start + 8 * 3_600,
            kind: .regular, note: "PRIVATE-WORK-NOTE")
        var draft = UnitFixture.paystub(model, original: Data("SYNTHETIC-ORIGINAL".utf8))
        draft.regularPay = "400"
        draft.lineLayout = .fullRateBuckets
        draft.reviewedFields.insert(.regularPay)
        draft.suggestions[.regularPay] = OCRFieldSuggestion(
            value: "400.00",
            sourceText:
                "Regular 400.00 EMPLOYEE-ID-SYNTH-83 SSN-LIKE-000-12-3456 BANK-ACCOUNT-SYNTH-246810",
            region: SourceRegion(page: 0, x: 0.1, y: 0.2, width: 0.8, height: 0.1),
            confidence: 0.99, reason: nil)
        try model.confirmPaystub(draft)
        let before = store.state
        let context = try #require(model.periodContext())
        let url = try export(context)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try #require(PDFDocument(url: url))
        let content = try #require(pdf.string)
        for sensitive in [
            "EMPLOYEE-ID-SYNTH-83", "SSN-LIKE-000-12-3456", "BANK-ACCOUNT-SYNTH-246810",
            "private-worker-reference", "IDENTIFYING-SOURCE-SECTION", "PRIVATE-WORK-NOTE",
        ] {
            #expect(!content.contains(sensitive), "Default report leaked \(sensitive)")
        }
        #expect(content.contains("400.00"))
        #expect(content.contains("Source: page 1"))
        #expect(content.contains("Not a complete wage-law check"))
        #expect(content.contains("not anonymous"))
        #expect(store.state == before, "A sharing copy must not alter original evidence")
        #expect(
            model.currentPaystub?.confirmation?.suggestions[.regularPay]?.sourceText
                == draft.suggestions[.regularPay]?.sourceText)
    }

    @Test func supportDoesNotTreatVoluntarySharingAsSufficientAuthorization() throws {
        let privacy = try text(LegalTextView(kind: .privacy))
        #expect(!privacy.contains("unless you deliberately choose to share it"))
        let support = try text(LegalTextView(kind: .support))
        #expect(support.contains("Do not attach a paystub or complete backup"))
        #expect(support.contains("cannot retrieve records"))
        #expect(support.contains("does not extend"))
    }

    private func export(_ context: PayPeriodContext) throws -> URL {
        try ReconciliationReportExporter().export(
            window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
            agreement: context.agreement, calculation: #require(context.calculation),
            paystub: context.paystub, reconciliation: context.reconciliation, findings: [])
    }
}
