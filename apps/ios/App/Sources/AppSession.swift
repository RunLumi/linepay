import Foundation
import LinePayDomain
import Observation

/// Owns the local model's lifetime, including explicit replacements after restore or an
/// unresolved-period lifecycle transition. StoreKit is intentionally not part of a data snapshot
/// or this ownership boundary.
@MainActor
@Observable
final class AppSession {
    @ObservationIgnored private let store: any AppStateStoring
    @ObservationIgnored private let evidenceStore: any EvidenceStoring
    @ObservationIgnored private let io: any BackupHandling

    private(set) var model: AppModel
    private(set) var revision = UUID()
    private(set) var isBusy = false
    var restoreNotice: String?

    init(
        store: any AppStateStoring,
        evidenceStore: any EvidenceStoring,
        io: any BackupHandling = BackupIO()
    ) {
        self.io = io
        self.store = store
        self.evidenceStore = evidenceStore
        model = AppModel(store: store, evidenceStore: evidenceStore)
    }

    static func production() -> AppSession {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                return UITestFixtures.session()
            }
        #endif
        return AppSession(store: VersionedLocalStateStore(), evidenceStore: LocalEvidenceStore())
    }

    /// Close the current work period without turning an unavailable calculation into zero.
    ///
    /// Priceable periods stay on AppModel's ordinary path. When the current facts/rules are
    /// deliberately preserved but cannot be priced safely, the session owns the one atomic store
    /// transition because it also owns replacement of the long-lived model instance.
    func archiveCurrentPeriod() throws {
        guard !isBusy else { throw BackupError.operationInProgress }
        if model.calculation != nil {
            try model.archiveCurrentPeriod()
            return
        }
        guard model.workDraft == nil else { throw AppModelError.unfinishedWorkDraft }
        guard let active = model.activePeriod else { throw AppModelError.missingActivePayPeriod }
        guard let profile = model.profile else { throw AppModelError.missingPayProfile }
        let issue = model.calculationError?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let issue, !issue.isEmpty else { throw AppModelError.calculationUnavailable }

        isBusy = true
        defer { isBusy = false }
        var candidate = try store.load() ?? AppPersistentState()
        guard let storedActive = candidate.activePeriod, storedActive.id == active.id else {
            throw AppModelError.staleUndo
        }

        let zone =
            storedActive.timeZoneIdentifier
            ?? storedActive.workEntries.first?.interval.timeZoneIdentifier
            ?? profile.timeZoneIdentifier
        let completed = CompletedPayPeriod(
            id: storedActive.id,
            window: storedActive.window,
            agreement: storedActive.agreement,
            timeZoneIdentifier: zone,
            workEntries: storedActive.workEntries,
            calculation: nil,
            paystub: storedActive.paystub,
            reconciliation: nil,
            archivedEpochSeconds: Int64(Date().timeIntervalSince1970.rounded()),
            auditRevisions: storedActive.auditRevisions,
            hasConsumedAuditAccess: storedActive.hasConsumedAuditAccess,
            agreementChanges: storedActive.agreementChanges,
            calculationIssue: issue
        )
        candidate.history.insert(completed, at: 0)
        candidate.workDraft = nil

        if zone != profile.timeZoneIdentifier {
            candidate.activePeriod = nil
        } else {
            candidate.activePeriod = try nextPeriod(after: storedActive, profile: profile)
        }

        try AppStateValidation.validate(candidate)
        try store.save(candidate)
        reloadModel()
    }

    /// Retry a closed unresolved period against the exact frozen work and rule timeline.
    /// This never edits B or rewrites A's facts to make the calculator succeed.
    func retryHistoricalCalculation(periodID: UUID) throws {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        var candidate = try store.load() ?? AppPersistentState()
        guard let index = candidate.history.firstIndex(where: { $0.id == periodID }) else {
            throw AppModelError.missingActivePayPeriod
        }
        let period = candidate.history[index]
        guard period.calculation == nil, period.calculationIssue != nil else { return }

        let calculation = try PayCalculator().calculate(
            work: period.workEntries.map(\.interval),
            agreement: period.agreement,
            changes: period.agreementChanges ?? [],
            policy: .highestApplicable)
        candidate.history[index] = CompletedPayPeriod(
            id: period.id,
            window: period.window,
            agreement: period.agreement,
            timeZoneIdentifier: period.timeZoneIdentifier,
            workEntries: period.workEntries,
            calculation: calculation,
            paystub: period.paystub,
            reconciliation: nil,
            archivedEpochSeconds: period.archivedEpochSeconds,
            auditRevisions: period.auditRevisions,
            hasConsumedAuditAccess: period.hasConsumedAuditAccess,
            agreementChanges: period.agreementChanges,
            calculationIssue: nil,
            workCorrections: period.workCorrections)
        try AppStateValidation.validate(candidate)
        try store.save(candidate)
        reloadModel()
    }

    func prepareBackup() async throws -> Data {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        guard model.persistenceIssue == nil else { throw BackupError.currentDataUnreadable }
        let state = try store.load() ?? AppPersistentState()
        let references = try BackupArchive.evidence(in: state)
        let sources = try references.map { reference in
            guard let url = evidenceStore.url(for: reference) else {
                throw BackupError.missingEvidence
            }
            return BackupSource(id: reference.id, url: url)
        }
        return try await io.create(state: state, sources: sources)
    }

    func inspectBackup(at url: URL) async throws -> BackupArchive {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        return try await io.open(url)
    }

    /// Call only after the worker confirms the replace-not-merge preview.
    /// Staged evidence is written first. The atomic state-file save is the commit point.
    func restore(_ archive: BackupArchive, replaceUnreadableData: Bool = false) throws {
        guard !isBusy else { throw BackupError.operationInProgress }
        isBusy = true
        defer { isBusy = false }
        try archive.validate()

        let previous: AppPersistentState?
        do {
            previous = try store.load()
        } catch {
            guard replaceUnreadableData else { throw BackupError.currentDataUnreadable }
            previous = nil
        }
        let wasUnreadable = model.persistenceIssue != nil
        let oldReferences = try previous.map { try BackupArchive.evidence(in: $0) } ?? []
        let incomingReferences = try BackupArchive.evidence(in: archive.state)
        let bytesByID = Dictionary(uniqueKeysWithValues: archive.files.map { ($0.id, $0.bytes) })
        var staged: [PaystubEvidence] = []
        var replacements: [UUID: PaystubEvidence] = [:]

        do {
            for reference in incomingReferences {
                guard let data = bytesByID[reference.id] else { throw BackupError.missingEvidence }
                // Never reuse imported physical paths or overwrite an existing original.
                let saved = try evidenceStore.save(
                    data: data, originalFilename: safeFilename(for: reference.mediaType),
                    mediaType: reference.mediaType, sourceKind: reference.sourceKind,
                    recognizedText: reference.recognizedText
                )
                staged.append(saved)
                replacements[reference.id] = PaystubEvidence(
                    id: reference.id, storedFilename: saved.storedFilename,
                    originalFilename: reference.originalFilename, mediaType: reference.mediaType,
                    sourceKind: reference.sourceKind,
                    createdEpochSeconds: reference.createdEpochSeconds,
                    recognizedText: reference.recognizedText
                )
            }
            var candidate = archive.state.replacingEvidence(replacements)
            // Imported deletion queues contain physical filenames from a different install.
            candidate.pendingEvidenceDeletions =
                oldReferences + (previous?.pendingEvidenceDeletions ?? [])
            // A data restore is not a way to grant Pro or reset previously used free access.
            candidate.hasUsedFreeAudit =
                candidate.hasUsedFreeAudit
                || (previous?.hasUsedFreeAudit ?? wasUnreadable)
            try store.save(candidate)
        } catch {
            var cleanupFailed = false
            for file in staged {
                do { try evidenceStore.delete(file) } catch { cleanupFailed = true }
            }
            throw cleanupFailed ? BackupError.cleanupFailed : BackupError.restoreFailed
        }

        // The state is now committed; retain a retryable queue for failed old-file cleanup.
        model = AppModel(store: store, evidenceStore: evidenceStore)
        var cleanupFailed = false
        if model.pendingDeletionCount > 0 {
            do { try model.retryEvidenceDeletion() } catch { cleanupFailed = true }
        }
        revision = UUID()
        if model.persistenceIssue != nil {
            restoreNotice =
                "The restored file was saved but could not be reopened. Use Data recovery."
        } else if cleanupFailed || wasUnreadable {
            restoreNotice =
                "Backup restored. Some previous original files may remain on this iPhone. "
                + "Use Delete all local data only when you intend to remove all local records. "
                + "Your iCloud backup was not changed."
        } else {
            restoreNotice =
                "Backup restored, including retained paystub originals. "
                + "Your App Store subscription is unchanged. Your iCloud backup was not changed."
        }
    }

    private func nextPeriod(after active: ActivePayPeriod, profile: PayProfile) throws
        -> ActivePayPeriod?
    {
        guard profile.preferredCadence != .manual else { return nil }
        guard let zone = TimeZone(identifier: profile.timeZoneIdentifier) else {
            throw AppModelError.invalidField("Time zone")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: active.window.endDate)
        let dayCount = profile.preferredCadence == .weekly ? 7 : 14
        guard let end = calendar.date(byAdding: .day, value: dayCount, to: start) else {
            throw AppModelError.invalidPayPeriod
        }
        let window = PayPeriodWindow(
            startEpochSeconds: Int64(start.timeIntervalSince1970.rounded()),
            endEpochSeconds: Int64(end.timeIntervalSince1970.rounded()),
            cadence: profile.preferredCadence)
        let timeline = try AgreementTimeline(
            baseline: profile.baselineAgreement ?? profile.agreement,
            changes: profile.agreementChanges ?? [])
        let localStart = localDate(start, timeZone: zone)
        let future = timeline.changes.filter { $0.effectiveDate > localStart }
        return ActivePayPeriod(
            window: window,
            agreement: timeline.agreement(on: localStart),
            timeZoneIdentifier: profile.timeZoneIdentifier,
            agreementChanges: future.isEmpty ? nil : future)
    }

    private func reloadModel() {
        model = AppModel(store: store, evidenceStore: evidenceStore)
        revision = UUID()
    }

    private func localDate(_ date: Date, timeZone: TimeZone) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return LocalDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    private func safeFilename(for mediaType: String) -> String {
        switch mediaType {
        case "application/pdf": "paystub.pdf"
        case "image/png": "paystub.png"
        case "image/heic": "paystub.heic"
        case "image/jpeg": "paystub.jpg"
        default: "paystub.bin"
        }
    }
}
