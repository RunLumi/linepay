import Foundation
import LinePayDomain
import SwiftUI
import Testing
import UIKit
import ViewInspector

@testable import LinePay

/// Synchronous view contracts complement, rather than replace, the native UI journeys.
@Suite("Screen content and intent contracts")
@MainActor
struct ScreenContractTests {
    private func text<V: View>(_ view: V) throws -> String {
        try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }.joined(
            separator: "\n")
    }
    private func commerce() -> SubscriptionStore { SubscriptionStore(commerceEnabled: false) }

    @Test func welcomeExplainsTheProductAndInvokesItsContinuation() throws {
        var continued = 0
        let view = OnboardingWelcomeView { continued += 1 }
        let content = try text(view)
        #expect(content.contains("LinePaycheck") && content.contains("pay"))
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count == 1)
        try #require(buttons.first).tap()
        #expect(continued == 1)
    }

    @Test func emptyScreensDoNotInventWorkOrPaychecks() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile())
        let today = try text(TodayView(model: model))
        // DESIGN.md: an empty period says what is missing instead of showing "$0.00 earned".
        #expect(today.contains("No work logged"))
        #expect(!today.contains(LinePayFormat.money(try #require(model.calculation).expectedWages)))
        let pay = try text(PayLedgerView(model: model, subscriptionStore: commerce()))
        #expect(pay.contains("No work to check yet"))
        #expect(!pay.contains("Check first paycheck free"))
        #expect(
            try text(HistoryView(model: model, subscriptionStore: commerce())).contains(
                "No finished work periods"))
        #expect(model.currentPaystub == nil)
    }

    @Test func todayShowsEveryWorkKindBreakNoteAndOpensPayWithoutMutatingData() throws {
        let model = try populatedModel()
        var opened = 0
        let view = TodayView(model: model, onOpenPay: { opened += 1 })
        let content = try text(view)
        for expected in [
            "Regular work", "Callout", "Other work", "Synthetic regular", "Synthetic callout",
            "Repeat last shift",
        ] {
            #expect(content.contains(expected), "Missing work-log content: \(expected)")
        }
        let before = model.workEntries
        try view.inspect().find(viewWithAccessibilityIdentifier: "today.open-pay").button().tap()
        #expect(opened == 1 && model.workEntries == before)
        var undo: DeletedWorkUndo?
        let firstEntry = try #require(before.first)
        let edit = AddWorkView(
            model: model, existingEntry: firstEntry, onDeleted: { undo = $0 })
        try edit.inspect().find(viewWithAccessibilityIdentifier: "work.delete").button().tap()
        #expect(model.workEntries.count == before.count - 1)
        try model.restoreWork(#require(undo))
        #expect(model.workEntries == before)
    }

    @Test func configuredRuleEditorAndSettingsShowOnlyConfirmedRules() throws {
        let model = try populatedModel()
        let settings = try text(SettingsView(model: model, subscriptionStore: commerce()))
        #expect(settings.contains("Pay profile") && settings.contains("Rule sources"))
        let agreement = try #require(model.profile).agreement
        let summary = try text(AgreementSummaryView(agreement: agreement))
        let labels = try AgreementSummaryView(agreement: agreement).inspect()
            .findAll(ViewType.LabeledContent.self)
            .map { try $0.labelView().find(ViewType.Text.self).string() }
        #expect(labels.contains(Calendar(identifier: .gregorian).weekdaySymbols[0]))
        #expect(labels.contains("Callout minimum"))
        #expect(
            summary.contains(
                LinePayFormat.money(try #require(agreement.flatPerDiem).amountPerWorkDate)))
        #expect(try text(RuleSourcesView(agreement: agreement)).contains("Synthetic source"))
        let values = try PayProfileSetupView(model: model).inspect().findAll(
            ViewType.TextField.self
        ).map { try $0.input() }
        #expect(values.contains("50") && values.contains("Synthetic agreement"))
        #expect(
            try !text(SettingsView(model: AppModel(), subscriptionStore: commerce())).contains(
                "Synthetic agreement"))
    }

    @Test func missingActivePeriodOffersAStartInsteadOfAnInventedLedger() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile(cadence: .manual))
        try model.archiveCurrentPeriod()
        #expect(model.activePeriod == nil)
        #expect(try text(TodayView(model: model)).contains("Start pay period"))
        #expect(
            try text(PayLedgerView(model: model, subscriptionStore: commerce())).contains(
                "Start the next manual period"))
        #expect(
            try StartPayPeriodView(model: model).inspect().findAll(ViewType.DatePicker.self).count
                == 2)
    }

    @Test func nextPeriodStartContinuesFromTheLastClosedPeriodWithoutOverlap() throws {
        var chicago = Calendar(identifier: .gregorian)
        chicago.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let start = try #require(
            chicago.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let end = try #require(chicago.date(byAdding: .day, value: 7, to: start))
        let window = PayPeriodWindow(
            startEpochSeconds: Int64(start.timeIntervalSince1970),
            endEpochSeconds: Int64(end.timeIntervalSince1970), cadence: .manual)
        let later = end.addingTimeInterval(30 * 86_400)
        // Same zone: the exclusive end is already local midnight, so the next period starts there.
        #expect(
            StartPayPeriodView.proposedStart(afterHistory: [window], calendar: chicago, now: later)
                == end)
        // A zone where that instant is mid-day must move to the following midnight, not overlap.
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let proposed = StartPayPeriodView.proposedStart(
            afterHistory: [window], calendar: tokyo, now: later)
        #expect(proposed >= end && proposed == tokyo.startOfDay(for: proposed))
        // No history: today, at local midnight.
        #expect(
            StartPayPeriodView.proposedStart(afterHistory: [], calendar: chicago, now: later)
                == chicago.startOfDay(for: later))
    }

    @Test func addEditAndRepeatFormsRetainTheirWorkFacts() throws {
        let model = try populatedModel()
        let entry = try #require(model.workEntries.first)
        let edit = AddWorkView(model: model, existingEntry: entry)
        #expect(try text(edit).contains("Unpaid break"))
        let values = try edit.inspect().findAll(ViewType.TextField.self).map { try $0.input() }
        #expect(values.contains(entry.note))
        let repeatView = RepeatWorkView(model: model, source: entry)
        #expect(try text(repeatView).contains("recorded breaks"))
        #expect(try text(repeatView).contains("New date"))
        #expect(try text(AddWorkView(model: model)).contains("Unpaid break"))
        #expect(model.workEntries.count == 3)
    }

    @Test func everyAuditDirectionIncludesAmountsRulesAndEvidence() throws {
        for difference in [-1, 0, 1] {
            let model = try populatedModel()
            let total = try #require(model.calculation).total.amount
            var draft = UnitFixture.paystub(
                model, gross: LinePayFormat.decimal(total + Decimal(difference)))
            draft.grossBasis = .wagesAndPerDiem
            draft.regularPay = "100"
            draft.overtimePay = "20"
            draft.doubleTimePay = "30"
            draft.calloutPay = "40"
            draft.perDiemPay = "50"
            draft.reviewedFields = Set(PaystubField.allCases)
            draft.lineLayout = .fullRateBuckets
            draft.guaranteeLayout = .separateLine
            try model.confirmPaystub(draft)
            let context = try #require(model.periodContext())
            let content = try text(AuditDetailView(model: model, context: context))
            #expect(content.contains(LinePayFormat.money(totalMoney(total))))
            #expect(content.contains(LinePayFormat.money(try #require(context.paystub).grossPay)))
            #expect(content.contains("Regular pay") && content.contains("Per diem"))
            #expect(
                model.auditFindings(
                    calculation: try #require(context.calculation),
                    paystub: try #require(context.paystub)
                ).count == 6)
            #expect(
                try text(PayLedgerView(model: model, subscriptionStore: commerce())).contains(
                    "Review or correct paycheck"))
            try model.archiveCurrentPeriod()
            #expect(
                try text(HistoryView(model: model, subscriptionStore: commerce())).contains(
                    LinePayFormat.money(try #require(context.paystub).grossPay)))
        }
    }

    @Test func changedWorkRequiresAuditReviewAndKeepsItsOriginal() throws {
        let model = AppModel()
        try UnitFixture.populate(model, evidence: true)
        let original = model.currentPaystub?.evidence
        try model.addWork(
            start: UnitFixture.start + 9 * 3_600, end: UnitFixture.start + 10 * 3_600, kind: .other)
        #expect(model.currentAuditStatus == .needsReview)
        #expect(
            try text(PayLedgerView(model: model, subscriptionStore: commerce())).contains(
                "Review or correct paycheck"))
        let detail = AuditDetailView(model: model, context: try #require(model.periodContext()))
        #expect(try text(detail).contains("Work or rules changed"))
        #expect(model.currentPaystub?.evidence == original && original != nil)
    }

    @Test func importAndManualReviewStateTheirConfirmationBoundary() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        let id = try #require(model.activePeriod).id
        let imported = try text(
            PaystubImportView(model: model, subscriptionStore: commerce(), periodID: id) {})
        #expect(
            imported.contains("Type in the gross pay") && imported.contains("Choose PDF or image")
                && imported.contains("Choose photo"))
        let draft = UnitFixture.paystub(model)
        let review = try text(
            PaystubReviewView(model: model, subscriptionStore: commerce(), draft: draft) {})
        #expect(review.contains("Gross pay") && review.contains("400"))
        #expect(
            review.contains("full work period") && review.contains("Unconfirmed optional lines"))
        #expect(model.currentPaystub == nil)
    }

    @Test func recoveryScreenPreservesCorruptFileAndProvidesExport() throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("state-v1.json")
        let corrupt = Data("synthetic corrupt state".utf8)
        try corrupt.write(to: url)
        let model = AppModel(store: VersionedLocalStateStore(baseDirectory: directory))
        let content = try text(RootView(model: model, subscriptionStore: commerce()))
        #expect(
            content.contains("Your saved LinePaycheck data needs attention")
                && content.contains("Export recovery file"))
        #expect(try Data(contentsOf: url) == corrupt)
    }

    @Test func backupAndPaywallDoNotClaimExternalSuccess() throws {
        let session = AppSession(store: MemoryStateStore(), evidenceStore: MemoryEvidenceStore())
        let view = BackupRestoreView(session: session)
        let backup = try text(view)
        #expect(
            backup.contains("Back up to iCloud Drive")
                && backup.contains("Restore from iCloud Drive"))
        #expect(backup.contains("automatic backup") && backup.contains("not password-encrypted"))
        #expect(backup.contains("upload") && backup.contains("Files"))
        #expect(
            try !view.inspect().find(viewWithAccessibilityIdentifier: "backup.save").button()
                .isDisabled())
        #expect(
            try !view.inspect().find(viewWithAccessibilityIdentifier: "backup.restore").button()
                .isDisabled())
        let paywall = ProPaywallView(store: commerce()) {}
        let content = try text(paywall)
        #expect(content.contains("Check every paycheck.") && content.contains("Continue free"))
        #expect(content.contains("Price unavailable"))
        #expect(
            try paywall.inspect().find(viewWithAccessibilityIdentifier: "paywall.purchase").button()
                .isDisabled())
        #expect(!session.isBusy && session.restoreNotice == nil)
    }

    @Test func trialOfferStatesTheFullChargeTimelineAndFreeExit() async throws {
        let store = SubscriptionStore.fixture(plans: UITestFixtures.samplePlans(trial: true))
        await store.load()
        let shown = Date(timeIntervalSince1970: 1_791_000_000)
        let paywall = ProPaywallView(
            store: store, context: .onboarding(expectedPay: "$400.00"), referenceDate: shown
        ) {}
        let content = try text(paywall)
        for expected in [
            "Try Pro free for 7 days with the annual plan.", "Nothing is charged today.",
            "$79.99 / year",
            "7 days free, then billed yearly. Works out to $6.67/month.", "Save 33%",
            ProPaywallView.timelineDate(daysFromNow: 5, from: shown),
            ProPaywallView.timelineDate(daysFromNow: 7, from: shown),
            "Your annual plan starts: $79.99 for the year.",
            "Remind me before I'm charged", "We remind you the trial ends in 2 days.",
            "$9.99 / month", "Billed monthly, starting today. No free trial.",
            "7 days free, then $79.99 per year, renewing automatically.",
            "Continue free", "$400.00",
        ] {
            #expect(content.contains(expected), "Missing offer content: \(expected)")
        }
        let purchase = try paywall.inspect().find(
            viewWithAccessibilityIdentifier: "paywall.purchase"
        )
        .button()
        #expect(try purchase.labelView().text().string() == "Start my 7-day free trial")
        #expect(!purchase.isDisabled())
    }

    @Test func offerWithoutTrialMakesNoFreeClaim() async throws {
        let store = SubscriptionStore.fixture(plans: UITestFixtures.samplePlans(trial: false))
        await store.load()
        let paywall = ProPaywallView(store: store) {}
        let content = try text(paywall)
        #expect(!content.contains("days free") && !content.contains("Try Pro free"))
        #expect(!content.contains("Nothing is charged today"))
        #expect(
            !content.localizedCaseInsensitiveContains("remind"),
            "A reminder is offered only with a free trial")
        #expect(content.contains("$79.99 billed today and every year until you cancel"))
        let purchase = try paywall.inspect().find(
            viewWithAccessibilityIdentifier: "paywall.purchase"
        )
        .button()
        #expect(try purchase.labelView().text().string() == "Subscribe yearly")
    }

    @Test func firstResultContinuesThroughTheOfferOnlyWhenProIsSellable() async throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile())
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(28_800),
            kind: .regular)
        #expect(model.onboardingProgress == .proof)

        let sellable = SubscriptionStore.fixture(plans: UITestFixtures.samplePlans(trial: true))
        await sellable.load()
        try FirstPayResultView(model: model, subscriptionStore: sellable).inspect()
            .find(viewWithAccessibilityIdentifier: "activation.continue").button().tap()
        #expect(model.onboardingProgress == .proof, "The offer is shown before onboarding ends")

        try FirstPayResultView(model: model, subscriptionStore: commerce()).inspect()
            .find(viewWithAccessibilityIdentifier: "activation.continue").button().tap()
        #expect(model.onboardingProgress == nil, "Without a sellable offer the result completes")
    }

    @Test func semanticStatusIsNeverColorOnly() throws {
        for status in [
            AuditDisplayStatus.notAudited, .matches, .grossMatches, .needsReview, .notComparable,
            .possibleShortfall, .possibleOverpayment,
        ] {
            let view = AuditStatusView(status: status)
            #expect(try text(view).contains(status.title))
            #expect(try view.inspect().findAll(ViewType.Image.self).count == 1)
        }
    }

    @Test func semanticColorsResolveInEveryContrastAndAppearance() throws {
        let pairs: [(Color, Color, Double)] = [
            (LinePayColor.textPrimary, LinePayColor.canvas, 7),
            (LinePayColor.textSecondary, LinePayColor.surfaceSecondary, 4.5),
            (LinePayColor.actionText, LinePayColor.surfaceSecondary, 4.5),
            (LinePayColor.actionOnFill, LinePayColor.brandPrimary, 4.5),
            (LinePayColor.review, LinePayColor.surfaceSecondary, 4.5),
            (LinePayColor.difference, LinePayColor.surfaceSecondary, 4.5),
            (LinePayColor.match, LinePayColor.surfaceSecondary, 4.5),
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection { values in
                    values.userInterfaceStyle = style
                    values.accessibilityContrast = contrast
                }
                for (foreground, background, minimum) in pairs {
                    let a = try luminance(UIColor(foreground).resolvedColor(with: traits))
                    let b = try luminance(UIColor(background).resolvedColor(with: traits))
                    #expect((max(a, b) + 0.05) / (min(a, b) + 0.05) >= minimum)
                }
            }
        }
    }

    private func luminance(_ color: UIColor) throws -> Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        #expect(color.getRed(&r, green: &g, blue: &b, alpha: &a) && a == 1)
        func linear(_ value: CGFloat) -> Double {
            value <= 0.04045 ? Double(value) / 12.92 : pow((Double(value) + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func totalMoney(_ value: Decimal) -> Money {
        Money(amount: value, currencyCode: "USD")
    }

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
