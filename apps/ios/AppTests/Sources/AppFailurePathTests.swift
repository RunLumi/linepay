import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Application guard, recovery, and provenance boundaries")
@MainActor
struct AppFailurePathTests {
    @Test func missingActivePeriodGuardsEveryMutation() throws {
        let model = AppModel()
        let entry = WorkEntry(
            interval: try WorkInterval(
                startEpochSeconds: 0, endEpochSeconds: 3_600, timeZoneIdentifier: "UTC",
                kind: .regular), note: "Synthetic")
        #expect(throws: AppModelError.missingActivePayPeriod) { try model.restoreWork(entry) }
        #expect(throws: AppModelError.missingActivePayPeriod) { try model.clearCurrentPaystub() }
        #expect(throws: AppModelError.missingActivePayPeriod) {
            try model.confirmPaystub(PaystubConfirmationDraft())
        }
        #expect(throws: AppModelError.missingActivePayPeriod) { try model.archiveCurrentPeriod() }
        #expect(throws: AppModelError.missingActivePayPeriod) {
            try model.updateWork(
                id: entry.id, start: UnitFixture.start, end: UnitFixture.start + 3_600,
                kind: .regular)
        }
        #expect(throws: AppModelError.missingPayProfile) {
            try model.startNewPayPeriod(startDate: UnitFixture.start)
        }
        try model.removeCurrentPaystubEvidence()
        try model.removeHistoricalPaystubEvidence(periodID: UUID())
        #expect(model.workEntries.isEmpty && model.lastWorkEntry == nil)
        #expect(model.currentTimeZoneIdentifier == TimeZone.current.identifier)
        #expect(model.currentAuditStatus == .notAudited)
    }

    @Test func failedWorkDeletionDoesNotLoseTheEntryOrAudit() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model, evidence: true)
        let before = store.state
        store.failSave = true
        #expect(model.deleteWork(id: try #require(model.lastWorkEntry).id) == nil)
        #expect(store.state == before)
        #expect(model.workEntries == before?.activePeriod?.workEntries)
        #expect(model.lastPersistenceError != nil)
        #expect(model.reconciliation == before?.activePeriod?.reconciliation)
    }

    @Test func incompleteBreakAndOutsideEditAreRejectedAtomically() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        let id = try #require(model.lastWorkEntry).id
        for startOnly in [true, false] {
            #expect(throws: AppModelError.invalidField("Unpaid break")) {
                try model.updateWork(
                    id: id, start: UnitFixture.start, end: UnitFixture.start + 8 * 3_600,
                    kind: .regular,
                    unpaidBreakStart: startOnly ? UnitFixture.start + 3_600 : nil,
                    unpaidBreakEnd: startOnly ? nil : UnitFixture.start + 4 * 3_600)
            }
            #expect(store.state == before)
        }
        // The fixture starts at 08:00, not the midnight pay-period boundary.
        let window = try #require(model.activePeriod).window
        for dates in [
            (window.startDate - 3_600, window.startDate),
            (window.endDate - 3_600, window.endDate + 1),
        ] {
            #expect(throws: AppModelError.workOutsideCurrentPayPeriod) {
                try model.updateWork(id: id, start: dates.0, end: dates.1, kind: .other)
            }
            #expect(store.state == before)
        }
        try model.updateWork(
            id: id, start: UnitFixture.start, end: UnitFixture.start + 8 * 3_600, kind: .regular,
            unpaidBreakStart: UnitFixture.start + 3_600, unpaidBreakEnd: UnitFixture.start + 5_400)
        #expect(model.totalHours == Decimal(string: "7.5"))
        #expect(model.calculation?.total.amount == 375)
    }

    @Test func failedEvidenceRemovalKeepsOriginalUntilStateIsSaved() throws {
        let store = UnitStateStore()
        let evidenceStore = MemoryEvidenceStore()
        let model = AppModel(store: store, evidenceStore: evidenceStore)
        try UnitFixture.populate(model, evidence: true)
        let evidence = try #require(model.currentPaystub?.evidence)
        let confirmed = model.currentPaystub
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.removeCurrentPaystubEvidence()
        }
        #expect(model.currentPaystub == confirmed && model.evidenceURL(for: evidence) != nil)
        store.failSave = false
        try model.removeCurrentPaystubEvidence()
        #expect(model.currentPaystub?.grossPay == confirmed?.grossPay)
        #expect(model.currentPaystub?.evidence == nil && model.evidenceURL(for: evidence) == nil)
        try model.removeCurrentPaystubEvidence()
        try model.clearCurrentPaystub()
        #expect(model.currentPaystub == nil && model.hasUsedFreeAudit)
    }

    @Test func historicalDeletionRemovesOnlyItsOwnOriginal() throws {
        let model = AppModel()
        try UnitFixture.populate(model, evidence: true)
        let old = try #require(model.currentPaystub?.evidence)
        try model.archiveCurrentPeriod()
        let id = try #require(model.history.first).id
        var next = UnitFixture.paystub(
            model, gross: "0", original: Data("new synthetic original".utf8))
        next.originalFilename = "next.png"
        next.mediaType = "image/png"
        try model.confirmPaystub(next)
        let retained = try #require(model.currentPaystub?.evidence)
        try model.deleteHistoryPeriod(id: id)
        #expect(model.history.isEmpty)
        #expect(model.evidenceURL(for: old) == nil)
        #expect(model.evidenceURL(for: retained) != nil)
        try model.clearCurrentPaystub()
        #expect(model.evidenceURL(for: retained) == nil)
    }

    @Test func invalidLoadedCalculationCannotBeArchivedOrConfirmed() throws {
        let store = UnitStateStore()
        let valid = AppModel(store: store)
        try UnitFixture.populate(valid)
        var broken = try #require(store.state)
        let entry = try #require(broken.activePeriod?.workEntries.first)
        broken.activePeriod?.workEntries.append(entry)
        store.state = broken
        let model = AppModel(store: store)
        #expect(model.calculation == nil && model.calculationError != nil)
        #expect(throws: AppModelError.calculationUnavailable) { try model.archiveCurrentPeriod() }
        #expect(throws: AppModelError.calculationUnavailable) {
            try model.confirmPaystub(UnitFixture.paystub(model))
        }
        #expect(store.state == broken)
    }

    @Test func archiveWithoutProfileFailsRatherThanInventingRules() throws {
        let store = UnitStateStore()
        let valid = AppModel(store: store)
        try UnitFixture.populate(valid)
        store.state?.profile = nil
        let model = AppModel(store: store)
        #expect(throws: AppModelError.missingPayProfile) { try model.archiveCurrentPeriod() }
        #expect(model.workEntries.count == 1)
    }

    @Test func legacyTimezoneFallbackPreservesWorkBeforeUsingProfile() throws {
        let store = UnitStateStore()
        let original = AppModel(store: store)
        try UnitFixture.populate(original)
        try original.archiveCurrentPeriod()
        let state = try #require(store.state)
        let history = try #require(state.history.first)
        let legacy = CompletedPayPeriod(
            id: history.id, window: history.window, agreement: history.agreement,
            workEntries: history.workEntries, calculation: history.calculation, paystub: nil,
            reconciliation: nil)
        #expect(original.timeZoneIdentifier(for: legacy) == "UTC")
        var copy = state
        copy.activePeriod?.timeZoneIdentifier = nil
        copy.activePeriod?.workEntries = history.workEntries
        let fromWork = AppModel(store: MemoryStateStore(state: copy))
        #expect(fromWork.currentTimeZoneIdentifier == "UTC")
        copy.activePeriod?.workEntries = []
        let fromProfile = AppModel(store: MemoryStateStore(state: copy))
        #expect(fromProfile.currentTimeZoneIdentifier == "UTC")
        copy.profile = nil
        let fromDevice = AppModel(store: MemoryStateStore(state: copy))
        #expect(fromDevice.currentTimeZoneIdentifier == TimeZone.current.identifier)
        let empty = CompletedPayPeriod(
            id: UUID(), window: history.window, agreement: history.agreement,
            workEntries: [], calculation: history.calculation, paystub: nil, reconciliation: nil)
        #expect(original.timeZoneIdentifier(for: empty) == "UTC")
        #expect(fromDevice.timeZoneIdentifier(for: empty) == TimeZone.current.identifier)
        #expect(original.auditStatus(for: empty) == .notAudited)
    }

    @Test func failedResetDoesNotClearTheCurrentModel() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model, evidence: true)
        let before = store.state
        store.failReset = true
        #expect(throws: UnitFailure.injected) { try model.resetAllData() }
        #expect(store.state == before)
        #expect(model.workEntries.count == 1 && model.currentPaystub?.evidence != nil)
    }

    @Test func profileDraftKeepsScheduleSourceAndEffectiveDates() throws {
        let model = AppModel()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let dayStart = calendar.startOfDay(for: UnitFixture.start)
        var draft = UnitFixture.profile()
        draft.useRegularSchedule = true
        draft.regularWeekdays = [.monday, .wednesday]
        draft.regularStartTime = dayStart + 7 * 3_600
        draft.regularEndTime = dayStart + 15 * 3_600
        draft.sourceURL = "https://example.invalid/rule"
        draft.useEffectiveStart = true
        draft.effectiveStartDate = UnitFixture.start
        draft.useEffectiveEnd = true
        draft.effectiveEndDate = UnitFixture.start + 6 * 86_400
        try model.saveProfile(draft)
        let restored = PayProfileDraft(
            profile: try #require(model.profile), activePeriod: model.activePeriod)
        #expect(restored.useRegularSchedule && restored.regularWeekdays == draft.regularWeekdays)
        #expect(restored.sourceTitle == "Worker-provided source" && restored.sourceSection.isEmpty)
        #expect(restored.useEffectiveStart && restored.useEffectiveEnd)
        // Agreement effective bounds represent calendar dates, not the input's clock time.
        #expect(restored.effectiveStartDate == dayStart)
        #expect(restored.effectiveEndDate == calendar.startOfDay(for: draft.effectiveEndDate))
        #expect(calendar.component(.hour, from: restored.regularStartTime) == 7)
        #expect(calendar.component(.hour, from: restored.regularEndTime) == 15)
    }

    @Test func manualRestartDefaultsToOneDayAndKeepsHistory() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile(cadence: .manual))
        try model.archiveCurrentPeriod()
        try model.startNewPayPeriod(startDate: UnitFixture.start + 7 * 86_400)
        let active = try #require(model.activePeriod)
        #expect(active.window.endEpochSeconds - active.window.startEpochSeconds == 86_400)
        #expect(model.history.count == 1 && model.currentPaystub == nil)
    }

    @Test func allActionableErrorsHaveSpecificRecoveryText() throws {
        let errors: [any LocalizedError] = [
            AppModelError.invalidField("Rate"), AppModelError.missingPayProfile,
            AppModelError.missingActivePayPeriod,
            AppModelError.activePayPeriodAlreadyExists, AppModelError.missingWorkInterval,
            AppModelError.workOutsideCurrentPayPeriod,
            AppModelError.invalidPayPeriod, AppModelError.calculationUnavailable,
            AppModelError.persistenceFailed,
            BackupError.operationInProgress, BackupError.tooLarge, BackupError.invalidArchive,
            BackupError.damagedArchive,
            BackupError.newerVersion, BackupError.missingEvidence, BackupError.unavailableFile,
            BackupError.currentDataUnreadable,
            BackupError.restoreFailed, BackupError.cleanupFailed,
            PaystubOCRError.unsupportedDocument, PaystubOCRError.noReadablePages,
            LocalStateStoreError.unsupportedSchema(99),
        ]
        let descriptions = try errors.map { try #require($0.errorDescription) }
        #expect(Set(descriptions).count == errors.count)
        #expect(descriptions.allSatisfy { $0.count > 15 })
        #expect(descriptions[0].contains("Rate"))
        #expect(descriptions.last?.contains("99") == true)
    }
}
