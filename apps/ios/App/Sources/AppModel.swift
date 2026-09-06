import Foundation
import LinePayDomain
import Observation

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private let store: any AppStateStoring
    @ObservationIgnored private let evidenceStore: any EvidenceStoring
    @ObservationIgnored private let now: () -> Date

    private var state: AppPersistentState
    private(set) var calculation: CalculationResult?
    private(set) var calculationError: String?
    private(set) var persistenceIssue: String?
    private(set) var lastPersistenceError: String?

    init(
        store: any AppStateStoring = MemoryStateStore(),
        evidenceStore: any EvidenceStoring = MemoryEvidenceStore(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.evidenceStore = evidenceStore
        self.now = now

        do {
            state = try store.load() ?? AppPersistentState()
            try AppStateValidation.validate(state)
        } catch {
            state = AppPersistentState()
            persistenceIssue = error.localizedDescription
        }

        recalculate()
        if persistenceIssue == nil {
            do { try discoverUnreferencedEvidence() } catch {
                lastPersistenceError =
                    "Interrupted original-file cleanup could not be recorded. Free storage and retry from Privacy and local data."
            }
        }
    }

    static func production() -> AppModel {
        AppModel(
            store: VersionedLocalStateStore(),
            evidenceStore: LocalEvidenceStore()
        )
    }

    var profile: PayProfile? { state.profile }
    var activePeriod: ActivePayPeriod? { state.activePeriod }
    var history: [CompletedPayPeriod] { state.history }
    var workEntries: [WorkEntry] { state.activePeriod?.workEntries ?? [] }
    var workIntervals: [WorkInterval] { workEntries.map(\.interval) }
    var currentPaystub: ConfirmedPaystub? { state.activePeriod?.paystub }
    var reconciliation: ReconciliationResult? { state.activePeriod?.reconciliation }
    var hasUsedFreeAudit: Bool { state.hasUsedFreeAudit }
    var onboardingProgress: OnboardingProgress? { state.onboardingProgress }
    var isOnboarded: Bool { state.profile != nil }
    var recoveryFileURL: URL? { store.recoveryFileURL }

    var currentTimeZoneIdentifier: String {
        state.activePeriod?.agreementTimeZone(fallback: profile?.timeZoneIdentifier)
            ?? profile?.timeZoneIdentifier
            ?? TimeZone.current.identifier
    }

    func timeZoneIdentifier(for period: CompletedPayPeriod) -> String {
        period.timeZoneIdentifier
            ?? period.workEntries.first?.interval.timeZoneIdentifier
            ?? profile?.timeZoneIdentifier
            ?? TimeZone.current.identifier
    }

    var totalHours: Decimal {
        workIntervals.reduce(0) { $0 + $1.durationHours }
    }

    var lastWorkEntry: WorkEntry? {
        (workEntries + history.flatMap(\.workEntries)).max { lhs, rhs in
            lhs.interval.startEpochSeconds < rhs.interval.startEpochSeconds
        }
    }

    var currentAuditStatus: AuditDisplayStatus {
        guard let activePeriod = state.activePeriod else { return .notAudited }
        return auditStatus(
            calculation: calculation, paystub: activePeriod.paystub,
            reconciliation: activePeriod.reconciliation
        )
    }

    private func auditStatus(
        calculation: CalculationResult?, paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?
    ) -> AuditDisplayStatus {
        AuditAssessment.evaluate(
            calculation: calculation, paystub: paystub, reconciliation: reconciliation
        ).status
    }

    func canRunAudit(periodID: UUID? = nil, hasProAccess: Bool) -> Bool {
        guard let context = periodContext(id: periodID) else { return false }
        let consumed: Bool
        if let active = state.activePeriod, active.id == context.id {
            consumed = active.hasConsumedAuditAccess
        } else {
            let closed = state.history.first { $0.id == context.id }
            consumed = closed?.hasConsumedAuditAccess ?? (closed?.paystub != nil)
        }
        return hasProAccess || consumed || !state.hasUsedFreeAudit
    }

    func saveProfile(_ draft: PayProfileDraft, scope: RuleChangeScope? = nil) throws {
        var selected =
            scope ?? (draft.editScope == .currentPeriod ? .correctCurrentPeriod : .prospective)
        if scope == nil, draft.editScope == .futurePeriods,
            draft.timeZoneIdentifier != currentTimeZoneIdentifier
        {
            selected = .futurePeriods
        }
        try commit(candidateForProfile(draft, scope: selected))
    }

    func previewProfileChange(_ draft: PayProfileDraft, scope: RuleChangeScope) throws
        -> ProfileChangePreview
    {
        let candidate = try candidateForProfile(draft, scope: scope)
        return ProfileChangePreview(
            before: calculation?.total,
            after: candidate.activePeriod.flatMap { calculate(period: $0) }?.total,
            workCount: workEntries.count)
    }

    private func candidateForProfile(
        _ draft: PayProfileDraft, scope: RuleChangeScope = .prospective
    ) throws -> AppPersistentState {
        let agreement = try makeAgreement(from: draft)
        let existing = state.profile
        var candidate = state
        candidate.setupDraft = nil
        var baseline = existing?.baselineAgreement ?? existing?.agreement ?? agreement
        var changes = existing?.agreementChanges ?? []

        if var active = candidate.activePeriod {
            if scope == .futurePeriods && draft.timeZoneIdentifier != currentTimeZoneIdentifier {
                // Close on the frozen timezone before starting a new zone's calendar boundaries.
                baseline = agreement
                changes = []
            } else {
                guard
                    draft.timeZoneIdentifier
                        == active.agreementTimeZone(fallback: existing?.timeZoneIdentifier)
                else {
                    throw AppModelError.invalidField(
                        "The open period keeps its original payroll timezone")
                }
                let isUnusedSetup =
                    scope != .futurePeriods && active.workEntries.isEmpty && active.paystub == nil
                    && (active.agreementChanges ?? []).isEmpty
                    && draft.changeEffectiveDate == nil && !draft.useEffectiveStart
                if existing != nil && scope != .correctCurrentPeriod && !isUnusedSetup {
                    guard draft.timeZoneIdentifier == currentTimeZoneIdentifier else {
                        throw AppModelError.invalidField(
                            "Keep the current payroll timezone while scheduling a rule change")
                    }
                    let date = localDate(
                        from: scope == .futurePeriods
                            ? active.window.endDate
                            : (draft.changeEffectiveDate
                                ?? (draft.useEffectiveStart
                                    ? draft.effectiveStartDate : active.window.endDate)),
                        timeZoneIdentifier: currentTimeZoneIdentifier)
                    // A prospective edit cannot alter any recorded work, including an overnight tail.
                    let lastWorkDate = active.workEntries.map {
                        localDate(
                            from: Date(
                                timeIntervalSince1970: TimeInterval($0.interval.endEpochSeconds - 1)
                            ),
                            timeZoneIdentifier: currentTimeZoneIdentifier)
                    }.max()
                    guard lastWorkDate.map({ date > $0 }) ?? true else {
                        throw AppModelError.prospectiveChangeTouchesRecordedWork
                    }
                    let change = AgreementChange(effectiveDate: date, agreement: agreement)
                    changes.removeAll { $0.effectiveDate == date }
                    changes.append(change)
                    changes = try AgreementTimeline(baseline: baseline, changes: changes).changes
                    var periodChanges = active.agreementChanges ?? []
                    periodChanges.removeAll { $0.effectiveDate == date }
                    periodChanges.append(change)
                    active.agreementChanges = try AgreementTimeline(
                        baseline: active.agreement, changes: periodChanges
                    ).changes
                    active.workRevision = (active.workRevision ?? 0) + 1
                    // No recorded facts changed, so an existing audit remains valid.
                } else {
                    // The UI requires explicit confirmation for this whole-period correction.
                    baseline = agreement
                    let nextStart = localDate(
                        from: active.window.endDate,
                        timeZoneIdentifier: currentTimeZoneIdentifier)
                    changes = changes.filter { $0.effectiveDate >= nextStart }
                    active.agreement = agreement
                    active.agreementChanges = changes.isEmpty ? nil : changes
                    invalidateAudit(&active)
                    try validate(period: active)
                }
            }
            candidate.activePeriod = active
        } else {
            // No open work period exists. Archived snapshots are never rewritten.
            baseline = agreement
            changes = []
        }

        let profile = PayProfile(
            id: existing?.id ?? UUID(), name: normalizedProfileName(draft.name),
            timeZoneIdentifier: draft.timeZoneIdentifier, agreement: agreement,
            preferredCadence: draft.preferredCadence,
            baselineAgreement: baseline, agreementChanges: changes.isEmpty ? nil : changes)
        candidate.profile = profile
        if existing == nil {
            candidate.onboardingProgress = .firstWork
            let window = try makePeriodWindow(
                cadence: draft.preferredCadence, startDate: draft.periodStartDate,
                manualEndDate: draft.manualPeriodEndDate,
                timeZoneIdentifier: draft.timeZoneIdentifier)
            candidate.activePeriod = try makeActivePeriod(window: window, profile: profile)
        }
        return candidate
    }

    private func makeActivePeriod(window: PayPeriodWindow, profile: PayProfile) throws
        -> ActivePayPeriod
    {
        let timeline = try AgreementTimeline(
            baseline: profile.baselineAgreement ?? profile.agreement,
            changes: profile.agreementChanges ?? [])
        let start = localDate(
            from: window.startDate, timeZoneIdentifier: profile.timeZoneIdentifier)
        let future = timeline.changes.filter { $0.effectiveDate > start }
        return ActivePayPeriod(
            window: window, agreement: timeline.agreement(on: start),
            timeZoneIdentifier: profile.timeZoneIdentifier,
            agreementChanges: future.isEmpty ? nil : future)
    }

    func startNewPayPeriod(
        startDate: Date,
        manualEndDate: Date? = nil
    ) throws {
        guard state.activePeriod == nil else {
            throw AppModelError.activePayPeriodAlreadyExists
        }
        guard let profile = state.profile else {
            throw AppModelError.missingPayProfile
        }

        let window = try makePeriodWindow(
            cadence: profile.preferredCadence,
            startDate: startDate,
            manualEndDate: manualEndDate ?? startDate,
            timeZoneIdentifier: profile.timeZoneIdentifier
        )

        try validateNewWindow(window)
        var candidate = state
        candidate.activePeriod = try makeActivePeriod(window: window, profile: profile)
        try commit(candidate)
    }

    func addWork(
        start: Date,
        end: Date,
        kind: WorkKind,
        note: String = "",
        unpaidBreakStart: Date? = nil,
        unpaidBreakEnd: Date? = nil,
        additionalBreaks: [WorkBreak] = []
    ) throws {
        guard let active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        guard active.window.contains(start: start, end: end) else {
            throw AppModelError.workOutsideCurrentPayPeriod
        }

        let interval = try makeWorkInterval(
            id: UUID(),
            start: start,
            end: end,
            kind: kind,
            calloutEventID: kind == .callout ? UUID() : nil,
            timeZoneIdentifier: active.agreementTimeZone(fallback: profile?.timeZoneIdentifier),
            unpaidBreakStart: unpaidBreakStart,
            unpaidBreakEnd: unpaidBreakEnd,
            additionalBreaks: additionalBreaks
        )
        let entry = WorkEntry(
            interval: interval,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var candidate = state
        var candidateActive = active
        candidateActive.workEntries = sorted(candidateActive.workEntries + [entry])
        try validate(period: candidateActive)
        invalidateAudit(&candidateActive)
        candidate.activePeriod = candidateActive
        candidate.workDraft = nil
        if candidate.onboardingProgress == .firstWork
            || candidate.onboardingProgress == .waitingForFirstResult
        {
            candidate.onboardingProgress = .proof
        }
        try commit(candidate)
    }

    func updateWork(
        id: UUID,
        start: Date,
        end: Date,
        kind: WorkKind,
        note: String = "",
        unpaidBreakStart: Date? = nil,
        unpaidBreakEnd: Date? = nil,
        additionalBreaks: [WorkBreak] = []
    ) throws {
        guard let active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        guard active.workEntries.contains(where: { $0.id == id }) else {
            throw AppModelError.missingWorkInterval
        }
        guard active.window.contains(start: start, end: end) else {
            throw AppModelError.workOutsideCurrentPayPeriod
        }

        let calloutEventID: UUID? =
            if kind == .callout {
                active.workEntries.first(where: { $0.id == id })?.interval.calloutEventID ?? UUID()
            } else {
                nil
            }
        let replacement = WorkEntry(
            interval: try makeWorkInterval(
                id: id,
                start: start,
                end: end,
                kind: kind,
                calloutEventID: calloutEventID,
                timeZoneIdentifier: active.agreementTimeZone(
                    fallback: profile?.timeZoneIdentifier
                ),
                unpaidBreakStart: unpaidBreakStart,
                unpaidBreakEnd: unpaidBreakEnd,
                additionalBreaks: additionalBreaks
            ),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var candidate = state
        var candidateActive = active
        candidateActive.workEntries = sorted(
            candidateActive.workEntries.map { $0.id == id ? replacement : $0 }
        )
        try validate(period: candidateActive)
        invalidateAudit(&candidateActive)
        candidate.activePeriod = candidateActive
        candidate.workDraft = nil
        try commit(candidate)
    }

    func deleteWork(id: UUID) -> DeletedWorkUndo? {
        guard var active = state.activePeriod,
            let removed = active.workEntries.first(where: { $0.id == id })
        else { return nil }
        var candidate = state
        active.workEntries.removeAll { $0.id == id }
        if candidate.workDraft?.editingEntryID == id { candidate.workDraft = nil }
        invalidateAudit(&active)
        candidate.activePeriod = active
        do {
            try commit(candidate)
            return DeletedWorkUndo(
                periodID: active.id,
                expectedRevision: active.workRevision ?? 0, entry: removed)
        } catch {
            lastPersistenceError = error.localizedDescription
            return nil
        }
    }

    func restoreWork(_ undo: DeletedWorkUndo) throws {
        guard var active = state.activePeriod, active.id == undo.periodID,
            (active.workRevision ?? 0) == undo.expectedRevision
        else {
            throw AppModelError.staleUndo
        }
        let entry = undo.entry
        guard
            active.window.contains(
                start: Date(timeIntervalSince1970: TimeInterval(entry.interval.startEpochSeconds)),
                end: Date(timeIntervalSince1970: TimeInterval(entry.interval.endEpochSeconds)))
        else {
            throw AppModelError.workOutsideCurrentPayPeriod
        }
        guard !active.workEntries.contains(where: { $0.id == entry.id }) else { return }
        active.workEntries = sorted(active.workEntries + [entry])
        try validate(period: active)
        invalidateAudit(&active)
        var candidate = state
        candidate.activePeriod = active
        try commit(candidate)
    }

    func confirmPaystub(
        _ draft: PaystubConfirmationDraft, periodID: UUID? = nil, hasProAccess: Bool = false
    ) throws {
        let target = periodID ?? draft.targetPeriodID
        guard let context = periodContext(id: target), let calculation = context.calculation,
            !context.workEntries.isEmpty
        else { throw AppModelError.calculationUnavailable }
        guard canRunAudit(periodID: context.id, hasProAccess: hasProAccess) else {
            throw AppModelError.proRequired
        }
        guard draft.reviewedFields.isSuperset(of: [.grossPay, .periodStart, .periodEnd]),
            let start = draft.payPeriodStartDate, let end = draft.payPeriodEndDate
        else {
            throw AppModelError.unconfirmedPaystub
        }
        let zone = context.timeZoneIdentifier
        guard
            localDate(from: start, timeZoneIdentifier: zone)
                == localDate(from: context.window.startDate, timeZoneIdentifier: zone),
            localDate(from: end, timeZoneIdentifier: zone)
                == localDate(from: context.window.displayEndDate, timeZoneIdentifier: zone)
        else { throw AppModelError.invalidPayPeriod }
        let currency = context.agreement.hourlyRate.currencyCode
        let gross = Money(
            amount: try positiveDecimal(
                draft.grossPay,
                field: "Gross pay", allowZero: true), currencyCode: currency)
        var amounts: [PaystubField: Money] = [:]
        var hours: [PaystubField: Decimal] = [:]
        var hasUnreviewed =
            draft.hasAdditionalUnmappedPay
            || draft.suggestions.keys.contains {
                !draft.reviewedFields.contains($0) && $0 != .grossPay && !$0.isDate
            }
        for field in PaystubField.allCases where !field.isDate && field != .grossPay {
            let raw = draft[field].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            guard draft.reviewedFields.contains(field) else {
                hasUnreviewed = true
                continue
            }
            let number: Decimal
            do {
                number = try StrictDecimal.parse(
                    raw, maximum: field.isHours ? 10_000 : 10_000_000,
                    fractionDigits: field.isHours ? 4 : 2, allowDollarSign: !field.isHours)
            } catch { throw AppModelError.invalidField(field.rawValue) }
            if field.isHours {
                hours[field] = number
            } else {
                amounts[field] = Money(amount: number, currencyCode: currency)
            }
        }
        let assessment = try PaycheckAssessor().assess(
            calculation: calculation, agreement: context.agreement,
            facts: PaycheckFacts(
                hasCompleteWork: draft.workComplete == true,
                grossPay: gross, amounts: amounts, hours: hours,
                grossBasis: draft.grossBasis, lineLayout: draft.lineLayout,
                hoursBasis: draft.hoursBasis, guaranteeLayout: draft.guaranteeLayout,
                hasUnreviewedFields: hasUnreviewed,
                hasUnsupportedRules: (calculation.agreementSnapshots ?? [context.agreement])
                    .contains { !($0.unsupportedRuleNotes ?? "").isEmpty })
        )
        var createdEvidence: PaystubEvidence?
        var evidence = draft.sourceEvidence ?? context.paystub?.evidence
        if let bytes = draft.sourceData {
            createdEvidence = try evidenceStore.save(
                data: bytes,
                originalFilename: draft.originalFilename, mediaType: draft.mediaType,
                sourceKind: draft.sourceKind, recognizedText: draft.recognizedText)
            evidence = createdEvidence
        }
        let confirmed = ConfirmedPaystub(
            payPeriodStart: localDate(from: start, timeZoneIdentifier: zone),
            payPeriodEnd: localDate(from: end, timeZoneIdentifier: zone), grossPay: gross,
            regularHours: hours[.regularHours], regularPay: amounts[.regularPay],
            overtimeHours: hours[.overtimeHours], overtimePay: amounts[.overtimePay],
            doubleTimeHours: hours[.doubleTimeHours], doubleTimePay: amounts[.doubleTimePay],
            calloutPay: amounts[.calloutPay], perDiemPay: amounts[.perDiemPay],
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines), evidence: evidence,
            confirmedEpochSeconds: Int64(now().timeIntervalSince1970.rounded()),
            confirmation: PaystubConfirmation(
                grossBasis: draft.grossBasis,
                lineLayout: draft.lineLayout, hoursBasis: draft.hoursBasis,
                guaranteeLayout: draft.guaranteeLayout, reviewedFields: draft.reviewedFields,
                suggestions: draft.suggestions, hasAdditionalUnmappedPay: hasUnreviewed,
                workComplete: draft.workComplete),
            assessment: assessment
        )
        let reconciliation = assessment.expectedGross.flatMap { expected -> ReconciliationResult? in
            guard let difference = assessment.difference else { return nil }
            return ReconciliationResult(
                expectedGross: expected, actualGross: gross,
                difference: difference,
                direction: difference.amount == 0
                    ? .matches
                    : (difference.amount > 0 ? .possibleUnderpayment : .possibleOverpayment))
        }
        var revisions = context.revisions
        // Keep a legacy audit as its own revision before the first correction.
        if revisions.isEmpty, let prior = context.paystub {
            revisions.append(
                AuditRevision(
                    id: prior.id, window: context.window,
                    agreement: context.agreement, timeZoneIdentifier: zone,
                    workEntries: context.workEntries, calculation: calculation,
                    paystub: prior, reconciliation: context.reconciliation,
                    agreementChanges: context.agreementChanges))
        }
        revisions.append(
            AuditRevision(
                id: confirmed.id, window: context.window,
                agreement: context.agreement, timeZoneIdentifier: zone,
                workEntries: context.workEntries, calculation: calculation,
                paystub: confirmed, reconciliation: reconciliation,
                agreementChanges: context.agreementChanges))
        let consumesAccess = assessment.verdict != .notComparable
        var candidate = state
        if var active = candidate.activePeriod, active.id == context.id {
            active.paystub = confirmed
            active.reconciliation = reconciliation
            active.auditCompletedEpochSeconds = confirmed.confirmedEpochSeconds
            active.auditRevisions = revisions
            active.hasConsumedAuditAccess = active.hasConsumedAuditAccess || consumesAccess
            candidate.activePeriod = active
        } else if let index = candidate.history.firstIndex(where: { $0.id == context.id }) {
            let prior = candidate.history[index]
            candidate.history[index] = CompletedPayPeriod(
                id: prior.id, window: prior.window, agreement: prior.agreement,
                timeZoneIdentifier: zone, workEntries: prior.workEntries,
                calculation: prior.calculation, paystub: confirmed, reconciliation: reconciliation,
                archivedEpochSeconds: prior.archivedEpochSeconds, auditRevisions: revisions,
                hasConsumedAuditAccess: (prior.hasConsumedAuditAccess ?? (prior.paystub != nil))
                    || consumesAccess,
                agreementChanges: prior.agreementChanges
            )
        }
        candidate.hasUsedFreeAudit = candidate.hasUsedFreeAudit || (consumesAccess && !hasProAccess)
        if candidate.paystubDraft?.targetPeriodID == context.id { candidate.paystubDraft = nil }
        do { try commit(candidate) } catch {
            if let createdEvidence { queueUnreferencedEvidence(createdEvidence) }
            throw error
        }
        // Original evidence remains referenced by prior revisions until explicitly removed.
    }

    func clearCurrentPaystub() throws {
        guard var active = state.activePeriod else { throw AppModelError.missingActivePayPeriod }
        active.paystub = nil
        active.reconciliation = nil
        active.auditCompletedEpochSeconds = nil
        var candidate = state
        candidate.activePeriod = active
        try commit(candidate)
    }

    func archiveCurrentPeriod() throws {
        guard state.workDraft == nil else { throw AppModelError.unfinishedWorkDraft }
        guard let active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        guard let profile = state.profile else {
            throw AppModelError.missingPayProfile
        }
        guard
            let calculation = active.auditCompletedEpochSeconds != nil
                ? (active.auditRevisions?.last?.calculation ?? calculate(period: active))
                : calculate(period: active)
        else {
            throw AppModelError.calculationUnavailable
        }

        let completed = CompletedPayPeriod(
            id: active.id,
            window: active.window,
            agreement: active.agreement,
            timeZoneIdentifier: active.agreementTimeZone(
                fallback: profile.timeZoneIdentifier
            ),
            workEntries: active.workEntries,
            calculation: calculation,
            paystub: active.paystub,
            reconciliation: active.reconciliation,
            archivedEpochSeconds: Int64(now().timeIntervalSince1970.rounded()),
            auditRevisions: active.auditRevisions,
            hasConsumedAuditAccess: active.hasConsumedAuditAccess,
            agreementChanges: active.agreementChanges
        )

        var candidate = state
        candidate.history.insert(completed, at: 0)
        candidate.workDraft = nil

        // A new timezone can place its midnight before the old period's end.
        // Close safely, then ask for an explicit nonoverlapping start in the new zone.
        if currentTimeZoneIdentifier != profile.timeZoneIdentifier {
            candidate.activePeriod = nil
            try commit(candidate)
            return
        }

        switch profile.preferredCadence {
        case .weekly, .biweekly:
            let nextWindow = try makePeriodWindow(
                cadence: profile.preferredCadence,
                startDate: active.window.endDate,
                manualEndDate: active.window.endDate,
                timeZoneIdentifier: profile.timeZoneIdentifier
            )
            candidate.activePeriod = try makeActivePeriod(window: nextWindow, profile: profile)
        case .manual:
            candidate.activePeriod = nil
        }

        try commit(candidate)
    }

    func deleteHistoryPeriod(id: UUID) throws {
        guard let period = state.history.first(where: { $0.id == id }) else { return }
        var candidate = state
        candidate.history.removeAll { $0.id == id }
        let draftEvidence =
            candidate.paystubDraft?.targetPeriodID == id
            ? candidate.paystubDraft?.sourceEvidence : nil
        if candidate.paystubDraft?.targetPeriodID == id { candidate.paystubDraft = nil }
        let removed =
            ([period.paystub?.evidence, draftEvidence]
            + (period.auditRevisions ?? []).map { $0.paystub.evidence }).compactMap { $0 }
        enqueue(removed, in: &candidate)
        try commit(candidate)
        try retryEvidenceDeletion()
    }

    func removeCurrentPaystubEvidence() throws {
        guard let evidence = currentPaystub?.evidence else { return }
        try removeEvidence(id: evidence.id)
    }

    func removeHistoricalPaystubEvidence(periodID: UUID) throws {
        guard let evidence = state.history.first(where: { $0.id == periodID })?.paystub?.evidence
        else { return }
        try removeEvidence(id: evidence.id)
    }

    func evidenceURL(for evidence: PaystubEvidence) -> URL? {
        evidenceStore.url(for: evidence)
    }

    func auditFindings(calculation: CalculationResult, paystub: ConfirmedPaystub) -> [AuditFinding]
    {
        guard let assessment = paystub.assessment else { return [] }
        return assessment.comparisons.filter { $0.unit == .money }.map { item in
            AuditFinding(
                id: item.id, title: item.field.rawValue,
                expected: Money(amount: item.expected, currencyCode: item.currencyCode),
                paid: Money(amount: item.paid, currencyCode: item.currencyCode),
                difference: Money(amount: item.difference, currencyCode: item.currencyCode),
                explanation: "Compared using the paystub layout and gross basis you confirmed.")
        }
    }

    func exportBackupURL() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = try TemporaryExports.destination(
            name: "LinePaycheck-data-\(formatter.string(from: Date()))", extension: "json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: [.atomic])
        return url
    }

    func resetAllData() throws {
        // First persist a deletion queue so a failed file removal stays retryable.
        var empty = AppPersistentState()
        empty.hasUsedFreeAudit = state.hasUsedFreeAudit
        empty.pendingEvidenceDeletions = state.allEvidence + state.pendingEvidenceDeletions
        try commit(empty)
        try retryEvidenceDeletion()
        try evidenceStore.deleteAll()
        try TemporaryExports.removeAll()
        persistenceIssue = nil
        lastPersistenceError = nil
        recalculate()
    }

    func resetAfterPersistenceFailure() throws {
        guard persistenceIssue != nil else {
            try resetAllData()
            return
        }
        // Explicit user-confirmed destructive recovery, never automatic on a decode error.
        try evidenceStore.deleteAll()
        try TemporaryExports.removeAll()
        try store.reset()
        state = AppPersistentState()
        state.hasUsedFreeAudit = true
        try store.save(state)
        persistenceIssue = nil
        lastPersistenceError = nil
        recalculate()
    }

    var setupDraft: PayProfileDraft? { state.setupDraft }

    func deferFirstWork() throws {
        var candidate = state
        candidate.onboardingProgress = .waitingForFirstResult
        try commit(candidate)
    }

    func completeFirstResult() throws {
        var candidate = state
        candidate.onboardingProgress = nil
        try commit(candidate)
    }
    var workDraft: WorkDraft? { state.workDraft }
    var paystubDraft: PaystubConfirmationDraft? { state.paystubDraft }
    var retainedEvidence: [PaystubEvidence] {
        var seen = Set<UUID>()
        return state.allEvidence.filter { seen.insert($0.id).inserted }
    }
    var pendingDeletionCount: Int { state.pendingEvidenceDeletions.count }
    var currentWorkRevision: Int { state.activePeriod?.workRevision ?? 0 }

    static func safeSourceURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            let host = url.host, !host.isEmpty, url.user == nil, url.password == nil
        else { return nil }
        return url
    }

    func previewAgreement(_ draft: PayProfileDraft) throws -> AgreementSnapshot {
        try makeAgreement(from: draft)
    }

    func periodContext(id: UUID? = nil) -> PayPeriodContext? {
        if let active = state.activePeriod, id == nil || active.id == id {
            return PayPeriodContext(
                id: active.id, window: active.window, agreement: active.agreement,
                timeZoneIdentifier: currentTimeZoneIdentifier, workEntries: active.workEntries,
                calculation: active.auditCompletedEpochSeconds == nil
                    ? calculation
                    : (active.auditRevisions?.last?.calculation ?? calculation),
                paystub: active.paystub, reconciliation: active.reconciliation,
                revisions: active.auditRevisions ?? [], isClosed: false,
                agreementChanges: active.agreementChanges)
        }
        guard let period = state.history.first(where: { $0.id == id }) else { return nil }
        return PayPeriodContext(
            id: period.id, window: period.window, agreement: period.agreement,
            timeZoneIdentifier: timeZoneIdentifier(for: period), workEntries: period.workEntries,
            calculation: period.calculation, paystub: period.paystub,
            reconciliation: period.reconciliation,
            revisions: period.auditRevisions ?? [], isClosed: true,
            agreementChanges: period.agreementChanges)
    }

    func status(for context: PayPeriodContext) -> AuditDisplayStatus {
        auditStatus(
            calculation: context.calculation, paystub: context.paystub,
            reconciliation: context.reconciliation)
    }

    func saveSetupDraft(_ draft: PayProfileDraft?) throws {
        var candidate = state
        candidate.setupDraft = draft
        try commit(candidate)
    }
    func saveWorkDraft(_ draft: WorkDraft?) throws {
        guard state.workDraft != draft else { return }
        if let draft, draft.periodID != state.activePeriod?.id { throw AppModelError.staleUndo }
        var candidate = state
        candidate.workDraft = draft
        try commit(candidate)
    }
    func savePaystubDraft(_ draft: PaystubConfirmationDraft?) throws {
        guard state.paystubDraft != draft else { return }
        if let draft, let existing = state.paystubDraft,
            draft.targetPeriodID != existing.targetPeriodID
        {
            throw AppModelError.otherPaystubDraft
        }
        if let draft, periodContext(id: draft.targetPeriodID) == nil {
            throw AppModelError.missingActivePayPeriod
        }
        var candidate = state
        let old = candidate.paystubDraft?.sourceEvidence
        candidate.paystubDraft = draft
        if let old, old.id != draft?.sourceEvidence?.id { enqueue([old], in: &candidate) }
        try commit(candidate)
    }

    func stagePaystub(
        data: Data, filename: String, mediaType: String,
        kind: PaystubSourceKind, periodID: UUID
    ) throws -> PaystubConfirmationDraft {
        guard !data.isEmpty, data.count <= 25 * 1024 * 1024 else {
            throw AppModelError.documentTooLarge
        }
        guard let context = periodContext(id: periodID) else {
            throw AppModelError.missingActivePayPeriod
        }
        if let existing = state.paystubDraft, existing.targetPeriodID != periodID {
            throw AppModelError.otherPaystubDraft
        }
        let evidence = try evidenceStore.save(
            data: data, originalFilename: filename,
            mediaType: mediaType, sourceKind: kind, recognizedText: nil)
        var draft = PaystubConfirmationDraft()
        draft.targetPeriodID = periodID
        draft.payPeriodStartDate = context.window.startDate
        draft.payPeriodEndDate = context.window.displayEndDate
        draft.sourceEvidence = evidence
        draft.originalFilename = filename
        draft.mediaType = mediaType
        draft.sourceKind = kind
        do { try savePaystubDraft(draft) } catch {
            queueUnreferencedEvidence(evidence)
            throw error
        }
        return draft
    }

    func paycheckDraft(for periodID: UUID, correcting: Bool = true) throws
        -> PaystubConfirmationDraft
    {
        guard let context = periodContext(id: periodID) else {
            throw AppModelError.missingActivePayPeriod
        }
        if let saved = state.paystubDraft, saved.targetPeriodID == periodID { return saved }
        var draft = PaystubConfirmationDraft()
        draft.targetPeriodID = periodID
        draft.payPeriodStartDate = context.window.startDate
        draft.payPeriodEndDate = context.window.displayEndDate
        guard correcting, let paid = context.paystub else { return draft }
        draft.grossPay = LinePayFormat.decimal(paid.grossPay.amount)
        draft.regularHours = paid.regularHours.map(LinePayFormat.decimal) ?? ""
        draft.regularPay = paid.regularPay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.overtimeHours = paid.overtimeHours.map(LinePayFormat.decimal) ?? ""
        draft.overtimePay = paid.overtimePay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.doubleTimeHours = paid.doubleTimeHours.map(LinePayFormat.decimal) ?? ""
        draft.doubleTimePay = paid.doubleTimePay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.calloutPay = paid.calloutPay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.perDiemPay = paid.perDiemPay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.notes = paid.notes
        draft.sourceEvidence = paid.evidence
        if let confirmation = paid.confirmation {
            draft.workComplete = confirmation.workComplete
            draft.grossBasis = confirmation.grossBasis
            draft.lineLayout = confirmation.lineLayout
            draft.hoursBasis = confirmation.hoursBasis
            draft.guaranteeLayout = confirmation.guaranteeLayout
            draft.reviewedFields = confirmation.reviewedFields
            draft.suggestions = confirmation.suggestions
            draft.hasAdditionalUnmappedPay = confirmation.hasAdditionalUnmappedPay
        }
        return draft
    }

    func correctCurrentPeriod(start: Date, end: Date) throws {
        guard var active = state.activePeriod else { throw AppModelError.missingActivePayPeriod }
        let window = try makePeriodWindow(
            cadence: .manual, startDate: start,
            manualEndDate: end, timeZoneIdentifier: currentTimeZoneIdentifier)
        try validateNewWindow(window)
        guard
            active.workEntries.allSatisfy({
                window.contains(
                    start: Date(timeIntervalSince1970: TimeInterval($0.interval.startEpochSeconds)),
                    end: Date(timeIntervalSince1970: TimeInterval($0.interval.endEpochSeconds)))
            })
        else {
            throw AppModelError.workOutsideCurrentPayPeriod
        }
        active.window = window
        invalidateAudit(&active)
        var candidate = state
        candidate.activePeriod = active
        if candidate.paystubDraft?.targetPeriodID == active.id {
            candidate.paystubDraft?.reviewedFields.subtract([.periodStart, .periodEnd])
        }
        try commit(candidate)
    }

    private func validateNewWindow(_ window: PayPeriodWindow) throws {
        guard
            !state.history.contains(where: {
                $0.window.startEpochSeconds < window.endEpochSeconds
                    && $0.window.endEpochSeconds > window.startEpochSeconds
            })
        else { throw AppModelError.overlappingPayPeriods }
    }

    func conflictingWork(start: Date, end: Date, excluding id: UUID? = nil) -> WorkEntry? {
        workEntries.first {
            $0.id != id && TimeInterval($0.interval.startEpochSeconds) < end.timeIntervalSince1970
                && TimeInterval($0.interval.endEpochSeconds) > start.timeIntervalSince1970
        }
    }

    func retryLoad() throws {
        let loaded = try store.load() ?? AppPersistentState()
        state = loaded
        persistenceIssue = nil
        lastPersistenceError = nil
        recalculate()
    }

    func removeEvidence(id: UUID) throws {
        let references = state.allEvidence.filter { $0.id == id }
        guard !references.isEmpty else { return }
        var candidate = state.removingEvidence(id: id)
        enqueue(references, in: &candidate)
        try commit(candidate)
        try retryEvidenceDeletion()
    }

    func retryEvidenceDeletion() throws {
        try discoverUnreferencedEvidence()
        guard !state.pendingEvidenceDeletions.isEmpty else { return }
        var candidate = state
        var remaining: [PaystubEvidence] = []
        for evidence in state.pendingEvidenceDeletions {
            if state.allEvidence.contains(where: { $0.storedFilename == evidence.storedFilename }) {
                continue
            }
            do { try evidenceStore.delete(evidence) } catch { remaining.append(evidence) }
        }
        candidate.pendingEvidenceDeletions = remaining
        try commit(candidate)
        if !remaining.isEmpty { throw AppModelError.evidenceDeletionPending }
    }

    private func discoverUnreferencedEvidence() throws {
        let retained = Set(
            (state.allEvidence + state.pendingEvidenceDeletions).map(\.storedFilename))
        let interrupted = try evidenceStore.unreferencedFiles(excluding: retained)
        guard !interrupted.isEmpty else { return }
        var candidate = state
        candidate.pendingEvidenceDeletions += interrupted
        try commit(candidate)
    }

    private func enqueue(_ references: [PaystubEvidence], in candidate: inout AppPersistentState) {
        for evidence in references
        where !candidate.allEvidence.contains(where: { $0.id == evidence.id }) {
            if !candidate.pendingEvidenceDeletions.contains(where: {
                $0.storedFilename == evidence.storedFilename
            }) {
                candidate.pendingEvidenceDeletions.append(evidence)
            }
        }
    }

    private func queueUnreferencedEvidence(_ evidence: PaystubEvidence) {
        do { try evidenceStore.delete(evidence) } catch {
            var candidate = state
            enqueue([evidence], in: &candidate)
            do { try commit(candidate) } catch {
                lastPersistenceError =
                    "An unreferenced original could not be removed. Free storage and retry cleanup."
            }
        }
    }

    private func commit(_ candidate: AppPersistentState) throws {
        guard persistenceIssue == nil else { throw AppModelError.persistenceFailed }
        do {
            try AppStateValidation.validate(candidate)
            try store.save(candidate)
            let payChanged =
                state.activePeriod?.id != candidate.activePeriod?.id
                || state.activePeriod?.agreement != candidate.activePeriod?.agreement
                || state.activePeriod?.workEntries != candidate.activePeriod?.workEntries
                || state.activePeriod?.agreementChanges != candidate.activePeriod?.agreementChanges
            state = candidate
            lastPersistenceError = nil
            if payChanged { recalculate() }
        } catch {
            lastPersistenceError = error.localizedDescription
            throw AppModelError.persistenceFailed
        }
    }

    private func recalculate() {
        guard let active = state.activePeriod else {
            calculation = nil
            calculationError = nil
            return
        }

        do {
            calculation = try PayCalculator().calculate(
                work: active.workEntries.map(\.interval),
                agreement: active.agreement,
                changes: active.agreementChanges ?? [],
                policy: .highestApplicable
            )
            calculationError = nil
        } catch AgreementTimelineError.calloutGuaranteeNeedsReview {
            calculation = nil
            calculationError =
                "This callout crosses a rule change and may need a minimum-hours top-up. Your work is saved. Confirm how the agreement prices the guarantee before auditing."
        } catch {
            calculation = nil
            calculationError = error.localizedDescription
        }
    }

    private func calculate(period: ActivePayPeriod) -> CalculationResult? {
        try? PayCalculator().calculate(
            work: period.workEntries.map(\.interval),
            agreement: period.agreement,
            changes: period.agreementChanges ?? [],
            policy: .highestApplicable
        )
    }

    private func validate(period: ActivePayPeriod) throws {
        do {
            _ = try PayCalculator().calculate(
                work: period.workEntries.map(\.interval),
                agreement: period.agreement,
                changes: period.agreementChanges ?? [],
                policy: .highestApplicable
            )
        } catch AgreementTimelineError.calloutGuaranteeNeedsReview {
            // Preserve real work even when an agreement-specific guarantee cannot be priced safely.
        }
    }

    private func invalidateAudit(_ period: inout ActivePayPeriod) {
        period.workRevision = (period.workRevision ?? 0) + 1
        guard period.paystub != nil else { return }
        period.reconciliation = nil
        period.auditCompletedEpochSeconds = nil
    }

    private func makeWorkInterval(
        id: UUID,
        start: Date,
        end: Date,
        kind: WorkKind,
        calloutEventID: UUID?,
        timeZoneIdentifier: String,
        unpaidBreakStart: Date?,
        unpaidBreakEnd: Date?,
        additionalBreaks: [WorkBreak] = []
    ) throws -> WorkInterval {
        let unpaidBreaks: [WorkBreak]
        switch (unpaidBreakStart, unpaidBreakEnd) {
        case (nil, nil):
            unpaidBreaks = []
        case (.some(let breakStart), .some(let breakEnd)):
            unpaidBreaks = [
                try WorkBreak(
                    startEpochSeconds: epochSeconds(breakStart),
                    endEpochSeconds: epochSeconds(breakEnd)
                )
            ]
        default:
            throw AppModelError.invalidField("Unpaid break")
        }

        return try WorkInterval(
            id: id,
            startEpochSeconds: epochSeconds(start),
            endEpochSeconds: epochSeconds(end),
            timeZoneIdentifier: timeZoneIdentifier,
            kind: kind,
            unpaidBreaks: unpaidBreaks + additionalBreaks,
            calloutEventID: calloutEventID
        )
    }

    private func sorted(_ work: [WorkEntry]) -> [WorkEntry] {
        work.sorted { $0.interval.startEpochSeconds < $1.interval.startEpochSeconds }
    }

    private func makeAgreement(from draft: PayProfileDraft) throws -> AgreementSnapshot {
        let profileName = normalizedProfileName(draft.name)
        guard !profileName.isEmpty else {
            throw AppModelError.invalidField("Profile name")
        }
        guard TimeZone(identifier: draft.timeZoneIdentifier) != nil else {
            throw AppModelError.invalidField("Time zone")
        }

        let rate = try positiveDecimal(draft.hourlyRate, field: "Hourly rate")
        let existingAgreement = state.profile?.agreement
        let agreementID = existingAgreement?.id ?? UUID().uuidString
        let priorVersions =
            [existingAgreement?.version].compactMap { $0 }
            + (state.profile?.agreementChanges ?? []).map { $0.agreement.version }
        let nextVersion = String((priorVersions.compactMap(Int.init).max() ?? 0) + 1)

        var regularSchedule: [RegularScheduleWindow] = []
        var outsideMultiplier: Decimal = 1
        if draft.useRegularSchedule {
            guard !draft.regularWeekdays.isEmpty else {
                throw AppModelError.invalidField("Regular workdays")
            }
            let start = try localTime(
                from: draft.regularStartTime,
                timeZoneIdentifier: draft.timeZoneIdentifier
            )
            let end = try localTime(
                from: draft.regularEndTime,
                timeZoneIdentifier: draft.timeZoneIdentifier
            )
            regularSchedule = try draft.regularWeekdays
                .sorted { $0.rawValue < $1.rawValue }
                .map { try RegularScheduleWindow(weekday: $0, start: start, end: end) }
            outsideMultiplier = try multiplierDecimal(
                draft.outsideScheduleMultiplier,
                field: "Outside-schedule multiplier"
            )
        }

        var overtimeTiers: [DailyOvertimeTier] = []
        if draft.useDailyOvertime {
            overtimeTiers = [
                try DailyOvertimeTier(
                    afterHours: positiveDecimal(
                        draft.overtimeAfterHours,
                        field: "Overtime threshold",
                        allowZero: true
                    ),
                    multiplier: try multiplierDecimal(
                        draft.overtimeMultiplier,
                        field: "Overtime multiplier"
                    )
                )
            ]
        }

        if draft.useDailyOvertime {
            overtimeTiers += try draft.additionalOvertimeTiers.map {
                try DailyOvertimeTier(
                    afterHours: positiveDecimal(
                        $0.afterHours, field: "OT threshold", allowZero: true),
                    multiplier: multiplierDecimal($0.multiplier, field: "OT multiplier"))
            }
        }
        var weekdayPremiums: [WeekdayPremium] = []
        if draft.useSundayPremium {
            weekdayPremiums = [
                try WeekdayPremium(
                    weekday: .sunday,
                    multiplier: try multiplierDecimal(
                        draft.sundayMultiplier,
                        field: "Sunday multiplier"
                    )
                )
            ]
        }

        weekdayPremiums += try draft.additionalWeekdayPremiums.map {
            try WeekdayPremium(
                weekday: $0.weekday,
                multiplier: multiplierDecimal($0.multiplier, field: "Weekday multiplier"))
        }
        guard Set(weekdayPremiums.map(\.weekday)).count == weekdayPremiums.count else {
            throw AppModelError.invalidField("Each weekday may have only one premium")
        }
        let datePremiums = try draft.datePremiums.map {
            try DatePremium(
                date: localDate(
                    from: $0.date,
                    timeZoneIdentifier: draft.timeZoneIdentifier
                ),
                multiplier: multiplierDecimal(
                    $0.multiplier,
                    field: "Date premium multiplier"
                )
            )
        }

        let calloutMinimum: CalloutMinimumRule? =
            if draft.useCalloutMinimum {
                try CalloutMinimumRule(
                    minimumHours: positiveDecimal(
                        draft.calloutMinimumHours,
                        field: "Callout minimum"
                    )
                )
            } else {
                nil
            }

        let perDiem: FlatPerDiemRule? =
            if draft.usePerDiem {
                FlatPerDiemRule(
                    amountPerWorkDate: Money(
                        amount: try positiveDecimal(draft.perDiemAmount, field: "Per diem"),
                        currencyCode: "USD"
                    )
                )
            } else {
                nil
            }

        let effectiveStart =
            draft.useEffectiveStart
            ? localDate(
                from: draft.effectiveStartDate, timeZoneIdentifier: draft.timeZoneIdentifier)
            : nil
        let effectiveEnd =
            draft.useEffectiveEnd
            ? localDate(from: draft.effectiveEndDate, timeZoneIdentifier: draft.timeZoneIdentifier)
            : nil
        if let effectiveStart, let effectiveEnd, effectiveEnd < effectiveStart {
            throw AppModelError.invalidField("Agreement effective dates")
        }

        let trimmedURL = draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty, Self.safeSourceURL(trimmedURL) == nil {
            throw AppModelError.invalidField("Source URL")
        }
        let trimmedTitle = draft.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSection = draft.sourceSection.trimmingCharacters(in: .whitespacesAndNewlines)
        var sources: [AgreementSource]
        if trimmedTitle.isEmpty, trimmedURL.isEmpty, trimmedSection.isEmpty {
            sources = []
        } else {
            sources = [
                AgreementSource(
                    title: trimmedTitle.isEmpty ? "Worker-provided source" : trimmedTitle,
                    url: trimmedURL,
                    section: trimmedSection.isEmpty ? nil : trimmedSection,
                    ruleKey: draft.sourceRuleKey
                )
            ]
        }

        sources += try draft.additionalSources.map { source in
            let url = source.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard url.isEmpty || Self.safeSourceURL(url) != nil else {
                throw AppModelError.invalidField("Source URL")
            }
            return AgreementSource(
                title: source.title.isEmpty ? "Worker-provided source" : source.title,
                url: url, section: source.section.isEmpty ? nil : source.section,
                ruleKey: source.ruleKey)
        }
        return try AgreementSnapshot(
            id: agreementID,
            version: nextVersion,
            displayName: profileName,
            effectiveStart: effectiveStart,
            effectiveEnd: effectiveEnd,
            hourlyRate: Money(amount: rate, currencyCode: "USD"),
            regularSchedule: regularSchedule,
            outsideScheduleMultiplier: outsideMultiplier,
            weekdayPremiums: weekdayPremiums,
            datePremiums: datePremiums,
            dailyOvertimeTiers: overtimeTiers,
            calloutMinimum: calloutMinimum,
            flatPerDiem: perDiem,
            sources: sources,
            unsupportedRuleNotes: draft.unsupportedRuleNotes.trimmingCharacters(
                in: .whitespacesAndNewlines),
            confirmedEpochSeconds: Int64(now().timeIntervalSince1970)
        )
    }

    private func makePeriodWindow(
        cadence: PayPeriodCadence,
        startDate: Date,
        manualEndDate: Date,
        timeZoneIdentifier: String
    ) throws -> PayPeriodWindow {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw AppModelError.invalidField("Time zone")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: startDate)

        let end: Date
        switch cadence {
        case .weekly:
            guard let candidate = calendar.date(byAdding: .day, value: 7, to: start) else {
                throw AppModelError.invalidPayPeriod
            }
            end = candidate
        case .biweekly:
            guard let candidate = calendar.date(byAdding: .day, value: 14, to: start) else {
                throw AppModelError.invalidPayPeriod
            }
            end = candidate
        case .manual:
            let endDay = calendar.startOfDay(for: manualEndDate)
            guard endDay >= start,
                let candidate = calendar.date(byAdding: .day, value: 1, to: endDay)
            else {
                throw AppModelError.invalidPayPeriod
            }
            end = candidate
        }

        return PayPeriodWindow(
            startEpochSeconds: epochSeconds(start),
            endEpochSeconds: epochSeconds(end),
            cadence: cadence
        )
    }

    func auditStatus(for period: CompletedPayPeriod) -> AuditDisplayStatus {
        auditStatus(
            calculation: period.calculation, paystub: period.paystub,
            reconciliation: period.reconciliation)
    }

    private func normalizedProfileName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func positiveDecimal(_ text: String, field: String, allowZero: Bool = false) throws
        -> Decimal
    {
        do {
            return try StrictDecimal.parse(
                text,
                fractionDigits: field.lowercased().contains("hours")
                    || field.lowercased().contains("threshold") ? 4 : 2,
                allowZero: allowZero, allowDollarSign: true)
        } catch { throw AppModelError.invalidField(field) }
    }

    private func multiplierDecimal(_ text: String, field: String) throws -> Decimal {
        let value = try positiveDecimal(text, field: field)
        guard value >= 1 else {
            throw AppModelError.invalidField(field)
        }
        return value
    }

    private func localDate(from date: Date, timeZoneIdentifier: String) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return LocalDate(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    private func localTime(
        from date: Date,
        timeZoneIdentifier: String
    ) throws -> LocalTime {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw AppModelError.invalidField("Time zone")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return try LocalTime(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }

    private func epochSeconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }
}

extension ActivePayPeriod {
    fileprivate func agreementTimeZone(fallback: String?) -> String {
        if let timeZoneIdentifier {
            return timeZoneIdentifier
        }
        if let workTimeZone = workEntries.first?.interval.timeZoneIdentifier {
            return workTimeZone
        }
        return fallback ?? TimeZone.current.identifier
    }
}

enum AppModelError: LocalizedError, Equatable {
    case unfinishedWorkDraft
    case invalidField(String)
    case missingPayProfile
    case prospectiveChangeTouchesRecordedWork
    case missingActivePayPeriod
    case activePayPeriodAlreadyExists
    case missingWorkInterval
    case workOutsideCurrentPayPeriod
    case invalidPayPeriod
    case calculationUnavailable
    case persistenceFailed
    case otherPaystubDraft
    case staleUndo, proRequired, unconfirmedPaystub, overlappingPayPeriods
    case documentTooLarge, evidenceDeletionPending

    var errorDescription: String? {
        switch self {
        case .unfinishedWorkDraft:
            "Finish or discard your saved work draft from Today before closing this period."
        case .otherPaystubDraft:
            "Finish or discard the other paycheck review before starting a new one."
        case .staleUndo: "This action belongs to an earlier pay-period state. No work was moved."
        case .proRequired: "Your first audit is complete. Pro is required for another paycheck."
        case .unconfirmedPaystub:
            "Confirm the gross amount and both period dates against the paystub."
        case .overlappingPayPeriods:
            "These dates overlap a closed work period. Choose non-overlapping dates."
        case .documentTooLarge:
            "Choose a nonempty document up to 25 MB. Your existing source is unchanged."
        case .evidenceDeletionPending:
            "Some originals could not be deleted. Their cleanup is queued; retry from Settings."
        case .invalidField(let field):
            switch field {
            case "Profile name": "Enter a name for these confirmed pay rules."
            case "Time zone": "Choose a valid payroll timezone."
            case "Regular workdays": "Select at least one day for the regular schedule."
            case "Source URL": "Use a complete http or https source URL, or leave it blank."
            case "Agreement effective dates":
                "The agreement's end date must be on or after its start date."
            case "Unpaid break": "Enter both the start and end of the unpaid break."
            case "Each weekday may have only one premium":
                "Remove the duplicate weekday premium before saving."
            default:
                field.lowercased().contains("timezone")
                    ? "\(field). Choose future work periods for a timezone change."
                    : "Check \(field). Use a complete number with a decimal point, such as 1,250.00; no trailing text."
            }
        case .prospectiveChangeTouchesRecordedWork:
            "New rules must start after the last recorded work date. Use an explicit correction to reprice earlier open-period work."
        case .missingPayProfile:
            "Set up your pay rules before adding work."
        case .missingActivePayPeriod:
            "Start a pay period before adding work."
        case .activePayPeriodAlreadyExists:
            "Finish the current pay period before starting another one."
        case .missingWorkInterval:
            "That work interval no longer exists."
        case .workOutsideCurrentPayPeriod:
            "This shift falls outside the current pay period."
        case .invalidPayPeriod:
            "Check the pay-period dates."
        case .calculationUnavailable:
            "Expected pay could not be calculated with the current facts and rules."
        case .persistenceFailed:
            "LinePaycheck could not safely save this change. Your previous saved data is unchanged."
        }
    }
}
