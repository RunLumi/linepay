import Foundation
import LinePayDomain
import Observation

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private let store: any AppStateStoring
    @ObservationIgnored private let evidenceStore: any EvidenceStoring

    private var state: AppPersistentState
    private(set) var calculation: CalculationResult?
    private(set) var calculationError: String?
    private(set) var persistenceIssue: String?
    private(set) var lastPersistenceError: String?

    init(
        store: any AppStateStoring = MemoryStateStore(),
        evidenceStore: any EvidenceStoring = MemoryEvidenceStore()
    ) {
        self.store = store
        self.evidenceStore = evidenceStore

        do {
            state = try store.load() ?? AppPersistentState()
        } catch {
            state = AppPersistentState()
            persistenceIssue = error.localizedDescription
        }

        recalculate()
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
            paystub: activePeriod.paystub,
            reconciliation: activePeriod.reconciliation
        )
    }

    private func auditStatus(paystub: ConfirmedPaystub?, reconciliation: ReconciliationResult?)
        -> AuditDisplayStatus
    {
        guard let paystub else { return .notAudited }
        guard let assessment = paystub.assessment else { return .needsReview }
        if assessment.verdict == .notComparable { return .notComparable }
        guard reconciliation != nil else { return .needsReview }
        switch assessment.verdict {
        case .matches: return assessment.scope == .grossOnly ? .grossMatches : .matches
        case .possibleShortfall: return .possibleShortfall
        case .possibleOverpayment: return .possibleOverpayment
        case .needsReview: return .needsReview
        case .notComparable: return .notComparable
        }
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

    func saveProfile(_ draft: PayProfileDraft) throws {
        let agreement = try makeAgreement(from: draft)
        let existing = state.profile
        let profile = PayProfile(
            id: existing?.id ?? UUID(), name: normalizedProfileName(draft.name),
            timeZoneIdentifier: draft.timeZoneIdentifier, agreement: agreement,
            preferredCadence: draft.preferredCadence
        )
        var candidate = state
        candidate.profile = profile
        candidate.setupDraft = nil
        if var active = candidate.activePeriod, draft.editScope == .currentPeriod {
            guard
                active.agreementTimeZone(fallback: existing?.timeZoneIdentifier)
                    == draft.timeZoneIdentifier
            else {
                throw AppModelError.invalidField("Use future periods for a payroll timezone change")
            }
            active.agreement = agreement
            try validate(period: active)
            invalidateAudit(&active)
            candidate.activePeriod = active
        } else if existing == nil {
            candidate.activePeriod = ActivePayPeriod(
                window: try makePeriodWindow(
                    cadence: draft.preferredCadence, startDate: draft.periodStartDate,
                    manualEndDate: draft.manualPeriodEndDate,
                    timeZoneIdentifier: draft.timeZoneIdentifier),
                agreement: agreement, timeZoneIdentifier: draft.timeZoneIdentifier
            )
        }
        try commit(candidate)
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
        candidate.activePeriod = ActivePayPeriod(
            window: window,
            agreement: profile.agreement,
            timeZoneIdentifier: profile.timeZoneIdentifier
        )
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

        let replacement = WorkEntry(
            interval: try makeWorkInterval(
                id: id,
                start: start,
                end: end,
                kind: kind,
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
                grossPay: gross, amounts: amounts, hours: hours,
                grossBasis: draft.grossBasis, lineLayout: draft.lineLayout,
                hoursBasis: draft.hoursBasis, guaranteeLayout: draft.guaranteeLayout,
                hasUnreviewedFields: hasUnreviewed,
                hasUnsupportedRules: !(context.agreement.unsupportedRuleNotes ?? "").isEmpty)
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
            notes: draft.notes, evidence: evidence,
            confirmation: PaystubConfirmation(
                grossBasis: draft.grossBasis,
                lineLayout: draft.lineLayout, hoursBasis: draft.hoursBasis,
                guaranteeLayout: draft.guaranteeLayout, reviewedFields: draft.reviewedFields,
                suggestions: draft.suggestions, hasAdditionalUnmappedPay: hasUnreviewed),
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
                    paystub: prior, reconciliation: context.reconciliation))
        }
        revisions.append(
            AuditRevision(
                id: confirmed.id, window: context.window,
                agreement: context.agreement, timeZoneIdentifier: zone,
                workEntries: context.workEntries, calculation: calculation,
                paystub: confirmed, reconciliation: reconciliation))
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
                    || consumesAccess
            )
        }
        candidate.hasUsedFreeAudit = candidate.hasUsedFreeAudit || consumesAccess
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
            auditRevisions: active.auditRevisions,
            hasConsumedAuditAccess: active.hasConsumedAuditAccess
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
            candidate.activePeriod = ActivePayPeriod(
                window: nextWindow,
                agreement: profile.agreement,
                timeZoneIdentifier: profile.timeZoneIdentifier
            )
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
                revisions: active.auditRevisions ?? [], isClosed: false)
        }
        guard let period = state.history.first(where: { $0.id == id }) else { return nil }
        return PayPeriodContext(
            id: period.id, window: period.window, agreement: period.agreement,
            timeZoneIdentifier: timeZoneIdentifier(for: period), workEntries: period.workEntries,
            calculation: period.calculation, paystub: period.paystub,
            reconciliation: period.reconciliation,
            revisions: period.auditRevisions ?? [], isClosed: true)
    }

    func status(for context: PayPeriodContext) -> AuditDisplayStatus {
        auditStatus(paystub: context.paystub, reconciliation: context.reconciliation)
    }

    func saveSetupDraft(_ draft: PayProfileDraft?) throws {
        var candidate = state
        candidate.setupDraft = draft
        try commit(candidate)
    }
    func saveWorkDraft(_ draft: WorkDraft?) throws {
        if let draft, draft.periodID != state.activePeriod?.id { throw AppModelError.staleUndo }
        var candidate = state
        candidate.workDraft = draft
        try commit(candidate)
    }
    func savePaystubDraft(_ draft: PaystubConfirmationDraft?) throws {
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

    private var activeTimeZoneIdentifier: String {
        currentTimeZoneIdentifier
    }

    private func commit(_ candidate: AppPersistentState) throws {
        do {
            try store.save(candidate)
            let payChanged =
                state.activePeriod?.id != candidate.activePeriod?.id
                || state.activePeriod?.agreement != candidate.activePeriod?.agreement
                || state.activePeriod?.workEntries != candidate.activePeriod?.workEntries
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
                policy: .highestApplicable
            )
            calculationError = nil
        } catch {
            calculation = nil
            calculationError = error.localizedDescription
        }
    }

    private func calculate(period: ActivePayPeriod) -> CalculationResult? {
        try? PayCalculator().calculate(
            work: period.workEntries.map(\.interval),
            agreement: period.agreement,
            policy: .highestApplicable
        )
    }

    private func validate(period: ActivePayPeriod) throws {
        _ = try PayCalculator().calculate(
            work: period.workEntries.map(\.interval),
            agreement: period.agreement,
            policy: .highestApplicable
        )
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
            unpaidBreaks: unpaidBreaks + additionalBreaks
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
        let nextVersion = String((Int(existingAgreement?.version ?? "0") ?? 0) + 1)

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
            confirmedEpochSeconds: Int64(Date().timeIntervalSince1970)
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
        auditStatus(paystub: period.paystub, reconciliation: period.reconciliation)
    }

    private func aggregate(
        calculation: CalculationResult,
        where predicate: (PayComponent) -> Bool
    ) -> Money {
        let amount = calculation.components
            .filter(predicate)
            .reduce(Decimal.zero) { $0 + $1.amount.amount }
        return Money(amount: amount, currencyCode: calculation.total.currencyCode)
    }

    private func appendFinding(
        id: String,
        title: String,
        expected: Money,
        paid: Money,
        explanation: String,
        to findings: inout [AuditFinding]
    ) {
        guard let difference = try? expected.subtracting(paid) else { return }
        findings.append(
            AuditFinding(
                id: id,
                title: title,
                expected: expected,
                paid: paid,
                difference: difference,
                explanation: explanation
            )
        )
    }

    private func copy(
        paystub: ConfirmedPaystub,
        evidence: PaystubEvidence?
    ) -> ConfirmedPaystub {
        ConfirmedPaystub(
            id: paystub.id,
            payPeriodStart: paystub.payPeriodStart,
            payPeriodEnd: paystub.payPeriodEnd,
            grossPay: paystub.grossPay,
            regularHours: paystub.regularHours,
            regularPay: paystub.regularPay,
            overtimeHours: paystub.overtimeHours,
            overtimePay: paystub.overtimePay,
            doubleTimeHours: paystub.doubleTimeHours,
            doubleTimePay: paystub.doubleTimePay,
            calloutPay: paystub.calloutPay,
            perDiemPay: paystub.perDiemPay,
            notes: paystub.notes,
            evidence: evidence,
            confirmedEpochSeconds: paystub.confirmedEpochSeconds,
            confirmation: paystub.confirmation, assessment: paystub.assessment
        )
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

    private func optionalDecimal(_ text: String, field: String) throws -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try positiveDecimal(trimmed, field: field, allowZero: true)
    }

    private func optionalMoney(
        _ text: String,
        field: String,
        currencyCode: String
    ) throws -> Money? {
        guard let amount = try optionalDecimal(text, field: field) else { return nil }
        return Money(amount: amount, currencyCode: currencyCode)
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
    case invalidField(String)
    case missingPayProfile
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
            "Check \(field). Use a complete number with a decimal point, such as 1,250.00; no trailing text."
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
