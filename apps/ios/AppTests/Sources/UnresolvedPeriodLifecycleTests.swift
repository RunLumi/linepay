import Foundation
import LinePayDomain
import SwiftUI
import Testing
import ViewInspector

@testable import LinePay

@Suite("Unresolved work-period lifecycle")
@MainActor
struct UnresolvedPeriodLifecycleTests {
    @Test func ambiguousPeriodCanCloseAndNextPeriodStaysUsableAcrossRelaunch() throws {
        let store = UnitStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try createAmbiguousCallout(in: session.model)
        let periodAID = try #require(session.model.activePeriod).id
        let workA = session.model.workEntries
        #expect(session.model.calculation == nil)
        #expect(!session.model.hasUsedFreeAudit)

        try session.archiveCurrentPeriod()

        let closedA = try #require(session.model.history.first { $0.id == periodAID })
        #expect(closedA.calculation == nil)
        #expect(closedA.calculationIssue?.contains("callout crosses a rule change") == true)
        #expect(closedA.workEntries == workA)
        #expect(closedA.reconciliation == nil)
        #expect(!session.model.hasUsedFreeAudit)

        let periodB = try #require(session.model.activePeriod)
        #expect(periodB.id != periodAID)
        try session.model.addWork(
            start: periodB.window.startDate + 8 * 3_600,
            end: periodB.window.startDate + 16 * 3_600,
            kind: .regular,
            note: "Next-period work")
        let bWork = session.model.workEntries
        #expect(!bWork.isEmpty && session.model.calculation != nil)

        let reloaded = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        let reloadedA = try #require(reloaded.model.history.first { $0.id == periodAID })
        #expect(reloadedA.calculation == nil)
        #expect(reloadedA.calculationIssue == closedA.calculationIssue)
        #expect(reloadedA.workEntries == workA)
        #expect(reloaded.model.activePeriod?.id == periodB.id)
        #expect(reloaded.model.workEntries == bWork)
        #expect(!reloaded.model.hasUsedFreeAudit)
    }

    @Test func failedUnresolvedArchiveLeavesTheActivePeriodUntouched() throws {
        let store = UnitStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try createAmbiguousCallout(in: session.model)
        let before = try #require(store.state)
        let activeID = try #require(session.model.activePeriod).id
        store.failSave = true

        #expect(throws: UnitFailure.injected) {
            try session.archiveCurrentPeriod()
        }
        #expect(store.state == before)
        #expect(session.model.activePeriod?.id == activeID)
        #expect(session.model.history.isEmpty)
        #expect(session.model.calculation == nil)
    }

    @Test func unresolvedPeriodSurvivesBackupEncodingWithoutBecomingZero() throws {
        let store = UnitStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try createAmbiguousCallout(in: session.model)
        try session.archiveCurrentPeriod()
        let state = try #require(store.state)
        let archive = BackupArchive(
            createdAt: Date(timeIntervalSince1970: 1_800_000_000), state: state, files: [])
        let restored = try BackupArchive.decode(archive.encoded())
        let period = try #require(restored.state.history.first)

        #expect(period.calculation == nil)
        #expect(period.calculationIssue == state.history.first?.calculationIssue)
        #expect(period.workEntries == state.history.first?.workEntries)
        #expect(period.reconciliation == nil)
    }

    @Test func failedRetryLeavesOldReviewAndNewPeriodUntouched() throws {
        let store = UnitStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try createAmbiguousCallout(in: session.model)
        try session.archiveCurrentPeriod()
        let periodAID = try #require(session.model.history.first).id
        let periodB = try #require(session.model.activePeriod)
        try session.model.addWork(
            start: periodB.window.startDate + 8 * 3_600,
            end: periodB.window.startDate + 16 * 3_600,
            kind: .regular)
        let before = try #require(store.state)

        #expect(throws: (any Error).self) {
            try session.retryHistoricalCalculation(periodID: periodAID)
        }
        #expect(store.state == before)
        #expect(session.model.activePeriod == before.activePeriod)
        #expect(session.model.history == before.history)
    }

    @Test func laterRetryCanResolveOnlyAWhileBRemainsByteForByteEquivalent() throws {
        let store = UnitStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try UnitFixture.populate(session.model)
        let periodAID = try #require(session.model.activePeriod).id
        try session.model.archiveCurrentPeriod()
        let periodB = try #require(session.model.activePeriod)
        try session.model.addWork(
            start: periodB.window.startDate + 8 * 3_600,
            end: periodB.window.startDate + 16 * 3_600,
            kind: .regular,
            note: "B must not move")

        var syntheticUnresolved = try #require(store.state)
        let index = try #require(syntheticUnresolved.history.firstIndex { $0.id == periodAID })
        let originalA = syntheticUnresolved.history[index]
        syntheticUnresolved.history[index] = CompletedPayPeriod(
            id: originalA.id,
            window: originalA.window,
            agreement: originalA.agreement,
            timeZoneIdentifier: originalA.timeZoneIdentifier,
            workEntries: originalA.workEntries,
            calculation: nil,
            paystub: originalA.paystub,
            reconciliation: nil,
            archivedEpochSeconds: originalA.archivedEpochSeconds,
            auditRevisions: originalA.auditRevisions,
            hasConsumedAuditAccess: originalA.hasConsumedAuditAccess,
            agreementChanges: originalA.agreementChanges,
            calculationIssue: "Synthetic older engine could not calculate this period.",
            workCorrections: originalA.workCorrections)
        try AppStateValidation.validate(syntheticUnresolved)
        store.state = syntheticUnresolved

        let retrySession = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        let beforeB = try #require(retrySession.model.activePeriod)
        let beforeBBytes = try JSONEncoder().encode(beforeB)
        try retrySession.retryHistoricalCalculation(periodID: periodAID)

        let resolvedA = try #require(retrySession.model.history.first { $0.id == periodAID })
        #expect(resolvedA.calculation?.total.amount == 400)
        #expect(resolvedA.calculationIssue == nil)
        #expect(resolvedA.workEntries == originalA.workEntries)
        let afterB = try #require(retrySession.model.activePeriod)
        #expect(try JSONEncoder().encode(afterB) == beforeBBytes)
    }

    @Test func unresolvedFinishAndHistoryExplainTheStateWithoutOfferingAnAudit() throws {
        let store = UnitStateStore()
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        try createAmbiguousCallout(in: session.model)

        let finish = FinishPayPeriodView(model: session.model).environment(
            \.linePaySession, session)
        let finishText = try text(finish)
        #expect(finishText.contains("Calculation needs review"))
        #expect(finishText.contains("does not set expected pay to $0"))
        #expect(
            try !finish.inspect().find(viewWithAccessibilityIdentifier: "period.confirm-close")
                .button().isDisabled())

        try session.archiveCurrentPeriod()
        let periodID = try #require(session.model.history.first).id
        let history = HistoricalPeriodView(
            model: session.model,
            subscriptionStore: SubscriptionStore(commerceEnabled: false),
            periodID: periodID
        )
        .environment(\.linePaySession, session)
        let historyText = try text(history)
        #expect(historyText.contains("Calculation needs review"))
        #expect(historyText.contains("No $0 value was substituted"))
        #expect(historyText.contains("Frozen work"))
        #expect(historyText.contains("Retry saved calculation"))
        #expect(!historyText.contains("Add this paycheck"))
        #expect(throws: (any Error).self) {
            try history.inspect().find(viewWithAccessibilityIdentifier: "history.audit")
        }
    }

    private func createAmbiguousCallout(in model: AppModel) throws {
        var draft = UnitFixture.profile()
        draft.useCalloutMinimum = true
        draft.calloutMinimumHours = "4"
        try model.saveProfile(draft)
        let boundary = try nextMidnight()
        draft.hourlyRate = "60"
        draft.changeEffectiveDate = boundary
        try model.saveProfile(draft)
        try model.addWork(
            start: boundary - 3_600,
            end: boundary + 3_600,
            kind: .callout,
            note: "Ambiguous spanning callout")
        #expect(model.totalHours == 2)
        #expect(model.calculation == nil)
        #expect(model.calculationError?.contains("Your work is saved") == true)
    }

    private func nextMidnight() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let midnight = calendar.startOfDay(for: UnitFixture.start)
        return try #require(calendar.date(byAdding: .day, value: 1, to: midnight))
    }

    private func text<V: View>(_ view: V) throws -> String {
        try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }.joined(
            separator: "\n")
    }
}
