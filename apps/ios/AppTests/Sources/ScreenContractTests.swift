import Foundation
import LinePayDomain
import SwiftUI
import Testing
import UIKit
import ViewInspector

@testable import LinePay

/// Inspect actual SwiftUI bodies and their values. No generated mirror of the UI or payroll logic.
/// Interactive/device behavior remains a separate test layer from synchronous body inspection.
@Suite("Screen content and intent contracts")
@MainActor
struct ScreenContractTests {
    private func text<V: View>(_ view: V) throws -> String {
        try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }.joined(
            separator: "\n")
    }

    private func commerce() -> SubscriptionStore {
        SubscriptionStore(commerceEnabled: false)
    }

    @Test func welcomeExplainsTheProductAndInvokesItsContinuation() throws {
        var continued = 0
        let view = OnboardingWelcomeView { continued += 1 }
        let content = try text(view)
        #expect(content.contains("LinePaycheck"))
        #expect(content.contains("pay"))
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count == 1)
        try #require(buttons.first).tap()
        #expect(continued == 1)
    }

    @Test func emptyScreensDoNotInventWorkOrPaychecks() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile())
        let today = try text(TodayView(model: model) {})
        #expect(today.contains("No work logged yet"))
        #expect(today.contains(LinePayFormat.money(try #require(model.calculation).total)))
        let pay = try text(PayLedgerView(model: model, subscriptionStore: commerce()))
        #expect(pay.contains("Your ledger is empty"))
        #expect(pay.contains("Audit first paycheck free"))
        #expect(try text(HistoryView(model: model)).contains("No finished pay periods yet"))
        #expect(model.currentPaystub == nil)
    }

    @Test func todayShowsEveryWorkKindBreakNoteAndOpensPayWithoutMutatingData() throws {
        let model = try populatedModel()
        var opened = 0
        let view = TodayView(model: model) { opened += 1 }
        let content = try text(view)
        for expected in [
            "Regular work", "Callout", "Other work", "Synthetic regular", "Synthetic callout",
            "Repeat last shift",
        ] {
            #expect(content.contains(expected), "Missing work-log content: \(expected)")
        }
        let before = model.workEntries
        try view.inspect().find(viewWithAccessibilityIdentifier: "today.open-pay").button().tap()
        #expect(opened == 1)
        #expect(model.workEntries == before)
        try view.inspect().find(viewWithAccessibilityIdentifier: "today.delete-work").button().tap()
        #expect(model.workEntries.count == before.count - 1)
    }

    @Test func configuredRuleEditorAndSettingsShowOnlyConfirmedRules() throws {
        let model = try populatedModel()
        let settings = try text(SettingsView(model: model, subscriptionStore: commerce()))
        for expected in [
            "Synthetic agreement", "Daily OT", "Sunday", "Callout minimum", "Per diem",
            "Rule source", "Synthetic source",
        ] {
            #expect(settings.contains(expected), "Missing confirmed rule: \(expected)")
        }
        let editor = PayProfileSetupView(model: model)
        let fields = try editor.inspect().findAll(ViewType.TextField.self)
        let values = try fields.map { try $0.input() }
        #expect(values.contains("50"))
        #expect(values.contains("Synthetic agreement"))
        #expect(try text(editor).contains("Per diem"))
        let emptySettings = try text(SettingsView(model: AppModel(), subscriptionStore: commerce()))
        #expect(!emptySettings.contains("Synthetic agreement"))
        #expect(emptySettings.contains("No LinePaycheck account"))
    }

    @Test func missingActivePeriodOffersAStartInsteadOfAnInventedLedger() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile(cadence: .manual))
        try model.archiveCurrentPeriod()
        #expect(model.activePeriod == nil)
        #expect(try text(TodayView(model: model) {}).contains("Start pay period"))
        #expect(
            try text(PayLedgerView(model: model, subscriptionStore: commerce())).contains(
                "No active pay period"))
        let start = StartPayPeriodView(model: model)
        #expect(try start.inspect().findAll(ViewType.DatePicker.self).count == 2)
        #expect(try text(start).contains("Choose dates manually"))
    }

    @Test func addEditAndRepeatFormsRetainTheirWorkFacts() throws {
        let model = try populatedModel()
        let entry = try #require(model.workEntries.first)
        let edit = AddWorkView(model: model, existingEntry: entry)
        #expect(try text(edit).contains("Unpaid break"))
        let note = try edit.inspect().findAll(ViewType.TextField.self).map { try $0.input() }
        #expect(note.contains(entry.note))
        let repeating = AddWorkView(model: model, template: entry)
        #expect(try text(repeating).contains("Unpaid break"))
        let fresh = AddWorkView(model: model)
        #expect(try text(fresh).contains("Unpaid break"))
        #expect(model.workEntries.count == 3)
    }

    @Test func everyAuditDirectionIncludesAmountsRulesAndEvidence() throws {
        for difference in [-1, 0, 1] {
            let model = try populatedModel()
            let total = try #require(model.calculation).total.amount
            var draft = UnitFixture.paystub(
                model, gross: LinePayFormat.decimal(total + Decimal(difference)))
            draft.regularPay = "100"
            draft.overtimePay = "20"
            draft.doubleTimePay = "30"
            draft.calloutPay = "40"
            draft.perDiemPay = "50"
            try model.confirmPaystub(draft)
            let active = try #require(model.activePeriod)
            let calculation = try #require(model.calculation)
            let paystub = try #require(active.paystub)
            let findings = model.auditFindings(calculation: calculation, paystub: paystub)
            let view = AuditDetailView(
                window: active.window, timeZoneIdentifier: "UTC", agreement: active.agreement,
                calculation: calculation, paystub: paystub, reconciliation: active.reconciliation,
                findings: findings, evidenceURL: nil, onRemoveEvidence: nil)
            let content = try text(view)
            #expect(content.contains(LinePayFormat.money(totalMoney(total))))
            #expect(content.contains(LinePayFormat.money(paystub.grossPay)))
            #expect(content.contains("Synthetic source"))
            #expect(content.contains("Regular pay"))
            #expect(content.contains("Per diem"))
            #expect(findings.count == 6)
            #expect(
                try text(PayLedgerView(model: model, subscriptionStore: commerce())).contains(
                    "Replace or correct paycheck"))
            try model.archiveCurrentPeriod()
            let history = try text(HistoryView(model: model))
            #expect(history.contains("Synthetic source"))
            #expect(history.contains(LinePayFormat.money(paystub.grossPay)))
        }
    }

    @Test func changedWorkRequiresAuditReviewAndKeepsItsOriginal() throws {
        let model = AppModel()
        try UnitFixture.populate(model, evidence: true)
        try model.addWork(
            start: UnitFixture.start + 9 * 3_600, end: UnitFixture.start + 10 * 3_600, kind: .other)
        #expect(model.currentAuditStatus == .needsReview)
        let content = try text(PayLedgerView(model: model, subscriptionStore: commerce()))
        #expect(content.contains("Re-run audit with current work"))
        #expect(content.contains("Needs review"))
        let active = try #require(model.activePeriod)
        let paystub = try #require(active.paystub)
        let calculation = try #require(model.calculation)
        let view = AuditDetailView(
            window: active.window, timeZoneIdentifier: "UTC", agreement: active.agreement,
            calculation: calculation, paystub: paystub, reconciliation: nil,
            findings: model.auditFindings(calculation: calculation, paystub: paystub),
            evidenceURL: nil, onRemoveEvidence: { try model.removeCurrentPaystubEvidence() })
        #expect(try text(view).contains("Re-run the audit"))
        #expect(try text(view).contains("synthetic.pdf"))
        #expect(model.currentPaystub?.evidence != nil)
    }

    @Test func importAndManualReviewStateTheirConfirmationBoundary() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        let importView = PaystubImportView(model: model) {}
        let importContent = try text(importView)
        #expect(importContent.contains("Enter paycheck manually"))
        #expect(importContent.contains("Choose PDF or image"))
        #expect(importContent.contains("Choose photo"))
        #expect(importContent.contains("confirm the numbers before auditing"))
        var draft = UnitFixture.paystub(model)
        draft.recognizedText = "SYNTHETIC OCR TEXT"
        draft.regularPay = "400"
        let review = PaystubReviewView(model: model, draft: draft) {}
        let values = try review.inspect().findAll(ViewType.TextField.self).map { try $0.input() }
        #expect(values.contains("400"))
        #expect(try text(review).contains("Gross pay"))
        #expect(model.currentPaystub == nil)
    }

    @Test func recoveryScreenPreservesCorruptFileAndProvidesExport() throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("state-v1.json")
        let corrupt = Data("synthetic corrupt state".utf8)
        try corrupt.write(to: url)
        let store = VersionedLocalStateStore(baseDirectory: directory)
        let model = AppModel(store: store)
        let content = try text(RootView(model: model, subscriptionStore: commerce()))
        #expect(content.contains("Your saved LinePaycheck data needs attention"))
        #expect(content.contains("Export recovery file"))
        #expect(try Data(contentsOf: url) == corrupt)
    }

    @Test func backupAndPaywallDoNotClaimExternalSuccess() throws {
        let session = AppSession(store: MemoryStateStore(), evidenceStore: MemoryEvidenceStore())
        let backupView = BackupRestoreView(session: session)
        let backup = try text(backupView)
        #expect(backup.contains("Back up to iCloud Drive"))
        #expect(backup.contains("Restore from iCloud Drive"))
        #expect(backup.contains("Manual backup, not automatic backup or live sync."))
        #expect(backup.contains("not password-encrypted"))
        #expect(backup.contains("check in Files that upload has completed"))
        #expect(backup.contains("Deleting local data does not delete copies"))
        // Reflection cannot propagate this custom @Environment key into EntryPoint.
        // Its navigation/sheet contract requires native UI testing, not a false text assertion.
        let save = try backupView.inspect().find(viewWithAccessibilityIdentifier: "backup.save")
        let restore = try backupView.inspect().find(
            viewWithAccessibilityIdentifier: "backup.restore")
        #expect(try !save.button().isDisabled())
        #expect(try !restore.button().isDisabled())
        let paywall = try text(ProPaywallView(store: commerce()) {})
        #expect(paywall.contains("Audit every paycheck."))
        #expect(paywall.contains("Yearly"))
        #expect(paywall.contains("Monthly"))
        #expect(paywall.contains("Subscriptions renew automatically"))
        #expect(!session.isBusy)
        #expect(session.restoreNotice == nil)
    }

    @Test func semanticStatusIsNeverColorOnly() throws {
        for status in [
            AuditDisplayStatus.notAudited, .matches, .needsReview, .possibleShortfall,
            .possibleOverpayment,
        ] {
            let view = AuditStatusView(status: status)
            #expect(try text(view).contains(status.title))
            #expect(try view.inspect().findAll(ViewType.Image.self).count == 1)
        }
    }

    @Test func semanticColorsResolveInEveryContrastAndAppearance() throws {
        let colors = [
            LinePayColor.canvas, LinePayColor.surfacePrimary, LinePayColor.surfaceSecondary,
            LinePayColor.textPrimary, LinePayColor.textSecondary,
            LinePayColor.brandPrimary, LinePayColor.actionText, LinePayColor.actionOnFill,
            LinePayColor.review, LinePayColor.difference, LinePayColor.match,
            LinePayColor.information, LinePayColor.brandCopper,
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection { values in
                    values.userInterfaceStyle = style
                    values.accessibilityContrast = contrast
                }
                for color in colors {
                    let resolved = UIColor(color).resolvedColor(with: traits)
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0
                    #expect(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
                    #expect(a == 1)
                    #expect((0...1).contains(r) && (0...1).contains(g) && (0...1).contains(b))
                }
                #expect(
                    UIColor(LinePayColor.canvas).resolvedColor(with: traits)
                        != UIColor(LinePayColor.textPrimary).resolvedColor(with: traits))
            }
        }
    }

    private func totalMoney(_ value: Decimal) -> Money { Money(amount: value, currencyCode: "USD") }

    private func populatedModel() throws -> AppModel {
        let model = AppModel()
        var profile = UnitFixture.profile()
        profile.name = "Synthetic agreement"
        profile.useRegularSchedule = true
        profile.regularWeekdays = Set(Weekday.allCases)
        profile.regularStartTime = UnitFixture.start + 7 * 3_600
        profile.regularEndTime = UnitFixture.start + 15 * 3_600
        profile.outsideScheduleMultiplier = "2"
        profile.useDailyOvertime = true
        profile.useSundayPremium = true
        profile.useCalloutMinimum = true
        profile.usePerDiem = true
        profile.perDiemAmount = "50"
        profile.datePremiums = [DatePremiumDraft(date: UnitFixture.start, multiplier: "2")]
        profile.sourceTitle = "Synthetic source"
        profile.sourceURL = "https://example.invalid/synthetic-agreement"
        profile.sourceSection = "Synthetic section 1"
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start + 6 * 3_600, end: UnitFixture.start + 16 * 3_600,
            kind: .regular, note: "Synthetic regular",
            unpaidBreakStart: UnitFixture.start + 12 * 3_600,
            unpaidBreakEnd: UnitFixture.start + 12.5 * 3_600)
        try model.addWork(
            start: UnitFixture.start + 17 * 3_600, end: UnitFixture.start + 18 * 3_600,
            kind: .callout, note: "Synthetic callout")
        try model.addWork(
            start: UnitFixture.start + 19 * 3_600, end: UnitFixture.start + 20 * 3_600, kind: .other
        )
        return model
    }
}
