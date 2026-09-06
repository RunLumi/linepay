import Foundation
import LinePayDomain
import PDFKit
import SwiftUI
import Testing
import ViewInspector

@testable import LinePay

@Suite("Legal consent and historical report boundaries")
@MainActor
struct LegalConsentAndReportTests {
    @Test func everyScopeHasDistinctAccurateConsentAndUsesThePayrollZone() throws {
        let date = Date(timeIntervalSince1970: 1_788_736_200)
        let messages = RuleEditScope.allCases.map {
            RuleChangeConsent.explanation(
                scope: $0, effectiveDate: date,
                timeZoneIdentifier: "America/Los_Angeles", workCount: 3)
        }
        #expect(Set(messages).count == 3)
        let dated = RuleChangeConsent.explanation(
            scope: .datedChange, effectiveDate: date,
            timeZoneIdentifier: "America/Los_Angeles", workCount: 3)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .long
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        #expect(dated.contains(formatter.string(from: date)))
        #expect(dated.contains("America/Los_Angeles"))
        #expect(dated.contains("Previously recorded work keeps its original rules"))
        let invalid = RuleChangeConsent.explanation(
            scope: .datedChange, effectiveDate: date, timeZoneIdentifier: "Invalid/Zone",
            workCount: 3)
        #expect(invalid.contains("needs review"))
        let correction = RuleChangeConsent.explanation(
            scope: .currentPeriod, effectiveDate: date, timeZoneIdentifier: "UTC", workCount: 3)
        #expect(correction.contains("Saved work entries to recalculate: 3"))
        #expect(correction.contains("before and after"))
    }

    @Test func datedConsentUsesTheSameEffectiveStartFallbackAsSaving() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "60")
        draft.setupStep = 3
        draft.editScope = .datedChange
        draft.changeEffectiveDate = nil
        draft.useEffectiveStart = true
        draft.effectiveStartDate = UnitFixture.start + 2 * 86_400
        try model.saveSetupDraft(draft)
        let text = try PayProfileSetupView(model: model).inspect().findAll(ViewType.Text.self)
            .map { try $0.string() }.joined(separator: "\n")
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .long
        formatter.timeZone = TimeZone(identifier: "UTC")
        #expect(text.contains(formatter.string(from: draft.effectiveStartDate)))
        let preview = try model.previewProfileChange(draft, scope: .prospective)
        #expect(preview.before == preview.after)
        try model.saveProfile(draft, scope: .prospective)
        #expect(model.calculation?.total.amount == 400)
    }

    @Test func optingIntoSourceDetailsDoesNotChangeStoredEvidence() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        var profile = UnitFixture.profile()
        profile.name = "SYNTHETIC-IDENTITY"
        profile.sourceTitle = "SYNTHETIC-PRIVATE-SOURCE"
        profile.sourceURL = "https://example.invalid/private"
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start + 8 * 3_600, kind: .regular)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let before = store.state
        let context = try #require(model.periodContext())
        let url = try export(context, privacy: ReportPrivacyOptions(includeSourceDetails: true))
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try #require(PDFDocument(url: url)?.string)
        #expect(text.contains("SYNTHETIC-IDENTITY"))
        #expect(text.contains("SYNTHETIC-PRIVATE-SOURCE"))
        #expect(text.contains("includes optional OCR source text"))
        #expect(text.contains("not anonymous"))
        #expect(store.state == before)
    }

    @Test func archivedAndRevisionReportsKeepScopeAndOmitPrivateRuleNotes() throws {
        let model = AppModel()
        var profile = UnitFixture.profile()
        profile.name = "SYNTHETIC-PRIVATE-PROFILE"
        profile.unsupportedRuleNotes = "SYNTHETIC-PRIVATE-EMPLOYER-DETAIL"
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start + 8 * 3_600, kind: .regular)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let originalContext = try #require(model.periodContext())
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "399"))
        try model.archiveCurrentPeriod()
        // The retained context is the exact earlier revision, not a recomputation with today's rules.
        let archived = try #require(model.history.first)
        let contexts = [originalContext, try #require(model.periodContext(id: archived.id))]
        for context in contexts {
            let url = try export(context)
            defer { try? FileManager.default.removeItem(at: url) }
            let text = try #require(PDFDocument(url: url)?.string)
            #expect(!text.contains("SYNTHETIC-PRIVATE-PROFILE"))
            #expect(!text.contains("SYNTHETIC-PRIVATE-EMPLOYER-DETAIL"))
            #expect(text.contains("Incomplete rule coverage"))
            #expect(text.contains("Not a complete wage-law check"))
            #expect(text.contains("does not extend"))
        }
    }

    @Test func theSystemSharePayloadSurvivesWorkingFileCleanupUnchanged() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        let context = try #require(model.periodContext())
        var session = ReportShareSession { privacy in try export(context, privacy: privacy) }
        session.prepare(privacy: ReportPrivacyOptions())
        let report = try #require(session.preparedReport)
        session.previewLoaded(report)
        #expect(session.shareURL == report.url)
        let payload = ReportSharePayload(report: report)
        session.discard()
        #expect(!FileManager.default.fileExists(atPath: report.url.path))
        #expect(payload.data == report.data)
        #expect(
            PDFDocument(data: payload.data)?.string?.contains("Not a complete wage-law check")
                == true)
    }

    private func export(
        _ context: PayPeriodContext, privacy: ReportPrivacyOptions = ReportPrivacyOptions()
    ) throws -> URL {
        try ReconciliationReportExporter().export(
            window: context.window, timeZoneIdentifier: context.timeZoneIdentifier,
            agreement: context.agreement, calculation: #require(context.calculation),
            paystub: context.paystub, reconciliation: context.reconciliation, findings: [],
            privacy: privacy)
    }
}
