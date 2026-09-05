import Foundation
import LinePayDomain
import Observation

struct DatePremiumDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var multiplier: String

    init(id: UUID = UUID(), date: Date = Date(), multiplier: String = "2") {
        self.id = id
        self.date = date
        self.multiplier = multiplier
    }
}

struct PayProfileDraft: Hashable, Sendable {
    var name = "My current pay"
    var hourlyRate = ""
    var timeZoneIdentifier = TimeZone.current.identifier
    var preferredCadence: PayPeriodCadence = .weekly
    var periodStartDate = Date()
    var manualPeriodEndDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()

    var useRegularSchedule = false
    var regularWeekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    var regularStartTime = Self.clockDate(hour: 7, minute: 0)
    var regularEndTime = Self.clockDate(hour: 15, minute: 30)
    var outsideScheduleMultiplier = "1"

    var useDailyOvertime = false
    var overtimeAfterHours = "8"
    var overtimeMultiplier = "1.5"

    var useSundayPremium = false
    var sundayMultiplier = "2"
    var datePremiums: [DatePremiumDraft] = []

    var useCalloutMinimum = false
    var calloutMinimumHours = "4"

    var usePerDiem = false
    var perDiemAmount = ""

    var useEffectiveStart = false
    var effectiveStartDate = Date()
    var useEffectiveEnd = false
    var effectiveEndDate = Date()

    var sourceTitle = ""
    var sourceURL = ""
    var sourceSection = ""

    init() {}

    init(profile: PayProfile, activePeriod: ActivePayPeriod? = nil) {
        let agreement = profile.agreement
        name = profile.name
        hourlyRate = LinePayFormat.decimal(agreement.hourlyRate.amount)
        timeZoneIdentifier = profile.timeZoneIdentifier
        preferredCadence = profile.preferredCadence

        if let activePeriod {
            periodStartDate = activePeriod.window.startDate
            manualPeriodEndDate = activePeriod.window.displayEndDate
        }

        if let firstWindow = agreement.regularSchedule.first {
            useRegularSchedule = true
            regularWeekdays = Set(agreement.regularSchedule.map(\.weekday))
            regularStartTime = Self.clockDate(
                hour: firstWindow.start.hour,
                minute: firstWindow.start.minute
            )
            regularEndTime = Self.clockDate(
                hour: firstWindow.end.hour,
                minute: firstWindow.end.minute
            )
            outsideScheduleMultiplier = LinePayFormat.decimal(agreement.outsideScheduleMultiplier)
        }

        if let tier = agreement.dailyOvertimeTiers.first {
            useDailyOvertime = true
            overtimeAfterHours = LinePayFormat.decimal(tier.afterHours)
            overtimeMultiplier = LinePayFormat.decimal(tier.multiplier)
        }

        if let sunday = agreement.weekdayPremiums.first(where: { $0.weekday == .sunday }) {
            useSundayPremium = true
            sundayMultiplier = LinePayFormat.decimal(sunday.multiplier)
        }

        datePremiums = agreement.datePremiums.map {
            DatePremiumDraft(
                date: Self.date(from: $0.date, timeZoneIdentifier: profile.timeZoneIdentifier),
                multiplier: LinePayFormat.decimal($0.multiplier)
            )
        }

        if let callout = agreement.calloutMinimum {
            useCalloutMinimum = true
            calloutMinimumHours = LinePayFormat.decimal(callout.minimumHours)
        }

        if let perDiem = agreement.flatPerDiem {
            usePerDiem = true
            perDiemAmount = LinePayFormat.decimal(perDiem.amountPerWorkDate.amount)
        }

        if let start = agreement.effectiveStart {
            useEffectiveStart = true
            effectiveStartDate = Self.date(
                from: start,
                timeZoneIdentifier: profile.timeZoneIdentifier
            )
        }
        if let end = agreement.effectiveEnd {
            useEffectiveEnd = true
            effectiveEndDate = Self.date(
                from: end,
                timeZoneIdentifier: profile.timeZoneIdentifier
            )
        }

        if let source = agreement.sources.first {
            sourceTitle = source.title
            sourceURL = source.url
            sourceSection = source.section ?? ""
        }
    }

    private static func clockDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private static func date(from localDate: LocalDate, timeZoneIdentifier: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.date(
            from: DateComponents(
                year: localDate.year,
                month: localDate.month,
                day: localDate.day
            )
        ) ?? Date()
    }
}

struct PaystubConfirmationDraft: Sendable {
    var payPeriodStartDate: Date?
    var payPeriodEndDate: Date?
    var grossPay = ""
    var regularHours = ""
    var regularPay = ""
    var overtimeHours = ""
    var overtimePay = ""
    var doubleTimeHours = ""
    var doubleTimePay = ""
    var calloutPay = ""
    var perDiemPay = ""
    var notes = ""

    var sourceData: Data?
    var originalFilename = "paystub"
    var mediaType = "application/octet-stream"
    var sourceKind: PaystubSourceKind = .manual
    var recognizedText: String?
}

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

    var totalHours: Decimal {
        workIntervals.reduce(0) { $0 + $1.durationHours }
    }

    var lastWorkEntry: WorkEntry? {
        workEntries.max { lhs, rhs in
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

    func auditStatus(for period: CompletedPayPeriod) -> AuditDisplayStatus {
        auditStatus(paystub: period.paystub, reconciliation: period.reconciliation)
    }

    func canRunAudit(hasProAccess: Bool) -> Bool {
        guard let activePeriod = state.activePeriod else { return false }
        return hasProAccess
            || activePeriod.hasConsumedAuditAccess
            || !state.hasUsedFreeAudit
    }

    func saveProfile(_ draft: PayProfileDraft) throws {
        let agreement = try makeAgreement(from: draft)
        let existingProfile = state.profile
        let profile = PayProfile(
            id: existingProfile?.id ?? UUID(),
            name: normalizedProfileName(draft.name),
            timeZoneIdentifier: draft.timeZoneIdentifier,
            agreement: agreement,
            preferredCadence: draft.preferredCadence
        )

        var candidate = state
        let isFirstProfile = candidate.profile == nil
        candidate.profile = profile

        if var active = candidate.activePeriod {
            active.agreement = agreement
            active.reconciliation = nil
            active.auditCompletedEpochSeconds = nil
            candidate.activePeriod = active
        } else if isFirstProfile {
            let window = try makePeriodWindow(
                cadence: draft.preferredCadence,
                startDate: draft.periodStartDate,
                manualEndDate: draft.manualPeriodEndDate,
                timeZoneIdentifier: draft.timeZoneIdentifier
            )
            candidate.activePeriod = ActivePayPeriod(
                window: window,
                agreement: agreement
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

        var candidate = state
        candidate.activePeriod = ActivePayPeriod(
            window: window,
            agreement: profile.agreement
        )
        try commit(candidate)
    }

    func addWork(
        start: Date,
        end: Date,
        kind: WorkKind,
        note: String = "",
        unpaidBreakStart: Date? = nil,
        unpaidBreakEnd: Date? = nil
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
            unpaidBreakEnd: unpaidBreakEnd
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
        try commit(candidate)
    }

    func updateWork(
        id: UUID,
        start: Date,
        end: Date,
        kind: WorkKind,
        note: String = "",
        unpaidBreakStart: Date? = nil,
        unpaidBreakEnd: Date? = nil
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
                unpaidBreakEnd: unpaidBreakEnd
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
        try commit(candidate)
    }

    @discardableResult
    func deleteWork(id: UUID) -> WorkEntry? {
        guard var active = state.activePeriod,
            let removed = active.workEntries.first(where: { $0.id == id })
        else {
            return nil
        }

        var candidate = state
        active.workEntries.removeAll { $0.id == id }
        invalidateAudit(&active)
        candidate.activePeriod = active

        do {
            try commit(candidate)
            return removed
        } catch {
            lastPersistenceError = error.localizedDescription
            return nil
        }
    }

    func restoreWork(_ entry: WorkEntry) throws {
        guard var active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        guard !active.workEntries.contains(where: { $0.id == entry.id }) else {
            return
        }

        var candidate = state
        active.workEntries = sorted(active.workEntries + [entry])
        try validate(period: active)
        invalidateAudit(&active)
        candidate.activePeriod = active
        try commit(candidate)
    }

    func confirmPaystub(_ draft: PaystubConfirmationDraft) throws {
        guard var active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        guard let calculation = calculate(period: active) else {
            throw AppModelError.calculationUnavailable
        }

        let gross = try positiveDecimal(draft.grossPay, field: "Gross pay", allowZero: true)
        let currencyCode = active.agreement.hourlyRate.currencyCode
        let oldEvidence = active.paystub?.evidence
        var savedEvidence: PaystubEvidence?

        if let sourceData = draft.sourceData {
            savedEvidence = try evidenceStore.save(
                data: sourceData,
                originalFilename: draft.originalFilename,
                mediaType: draft.mediaType,
                sourceKind: draft.sourceKind,
                recognizedText: draft.recognizedText
            )
        }

        do {
            let confirmed = ConfirmedPaystub(
                payPeriodStart: draft.payPeriodStartDate.map {
                    localDate(from: $0, timeZoneIdentifier: activeTimeZoneIdentifier)
                },
                payPeriodEnd: draft.payPeriodEndDate.map {
                    localDate(from: $0, timeZoneIdentifier: activeTimeZoneIdentifier)
                },
                grossPay: Money(amount: gross, currencyCode: currencyCode),
                regularHours: try optionalDecimal(draft.regularHours, field: "Regular hours"),
                regularPay: try optionalMoney(
                    draft.regularPay,
                    field: "Regular pay",
                    currencyCode: currencyCode
                ),
                overtimeHours: try optionalDecimal(
                    draft.overtimeHours,
                    field: "Overtime hours"
                ),
                overtimePay: try optionalMoney(
                    draft.overtimePay,
                    field: "Overtime pay",
                    currencyCode: currencyCode
                ),
                doubleTimeHours: try optionalDecimal(
                    draft.doubleTimeHours,
                    field: "Double-time hours"
                ),
                doubleTimePay: try optionalMoney(
                    draft.doubleTimePay,
                    field: "Double-time pay",
                    currencyCode: currencyCode
                ),
                calloutPay: try optionalMoney(
                    draft.calloutPay,
                    field: "Callout pay",
                    currencyCode: currencyCode
                ),
                perDiemPay: try optionalMoney(
                    draft.perDiemPay,
                    field: "Per diem",
                    currencyCode: currencyCode
                ),
                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                evidence: savedEvidence
            )
            let reconciliation = try PayReconciler().reconcile(
                expected: calculation,
                paystub: PaystubSummary(grossPay: confirmed.grossPay),
                rounding: active.agreement.rounding
            )

            active.paystub = confirmed
            active.reconciliation = reconciliation
            active.auditCompletedEpochSeconds = Int64(Date().timeIntervalSince1970.rounded())
            active.hasConsumedAuditAccess = true

            var candidate = state
            candidate.activePeriod = active
            candidate.hasUsedFreeAudit = true
            try commit(candidate)

            if let oldEvidence, oldEvidence != savedEvidence {
                try? evidenceStore.delete(oldEvidence)
            }
        } catch {
            if let savedEvidence {
                try? evidenceStore.delete(savedEvidence)
            }
            throw error
        }
    }

    func clearCurrentPaystub() throws {
        guard var active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        let evidence = active.paystub?.evidence
        active.paystub = nil
        active.reconciliation = nil
        active.auditCompletedEpochSeconds = nil

        var candidate = state
        candidate.activePeriod = active
        try commit(candidate)
        if let evidence {
            try? evidenceStore.delete(evidence)
        }
    }

    func archiveCurrentPeriod() throws {
        guard let active = state.activePeriod else {
            throw AppModelError.missingActivePayPeriod
        }
        guard let profile = state.profile else {
            throw AppModelError.missingPayProfile
        }
        guard let calculation = calculate(period: active) else {
            throw AppModelError.calculationUnavailable
        }

        let completed = CompletedPayPeriod(
            id: active.id,
            window: active.window,
            agreement: active.agreement,
            workEntries: active.workEntries,
            calculation: calculation,
            paystub: active.paystub,
            reconciliation: active.reconciliation
        )

        var candidate = state
        candidate.history.insert(completed, at: 0)

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
                agreement: profile.agreement
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
        try commit(candidate)
        if let evidence = period.paystub?.evidence {
            try? evidenceStore.delete(evidence)
        }
    }

    func removeCurrentPaystubEvidence() throws {
        guard var active = state.activePeriod,
            let paystub = active.paystub,
            let evidence = paystub.evidence
        else {
            return
        }

        active.paystub = copy(paystub: paystub, evidence: nil)
        var candidate = state
        candidate.activePeriod = active
        try commit(candidate)
        try? evidenceStore.delete(evidence)
    }

    func removeHistoricalPaystubEvidence(periodID: UUID) throws {
        guard let index = state.history.firstIndex(where: { $0.id == periodID }),
            let paystub = state.history[index].paystub,
            let evidence = paystub.evidence
        else {
            return
        }

        let original = state.history[index]
        let replacement = CompletedPayPeriod(
            id: original.id,
            window: original.window,
            agreement: original.agreement,
            workEntries: original.workEntries,
            calculation: original.calculation,
            paystub: copy(paystub: paystub, evidence: nil),
            reconciliation: original.reconciliation,
            archivedEpochSeconds: original.archivedEpochSeconds
        )

        var candidate = state
        candidate.history[index] = replacement
        try commit(candidate)
        try? evidenceStore.delete(evidence)
    }

    func evidenceURL(for evidence: PaystubEvidence) -> URL? {
        evidenceStore.url(for: evidence)
    }

    func auditFindings(
        calculation: CalculationResult,
        paystub: ConfirmedPaystub
    ) -> [AuditFinding] {
        var findings: [AuditFinding] = []
        appendFinding(
            id: "gross",
            title: "Gross pay",
            expected: calculation.total,
            paid: paystub.grossPay,
            explanation:
                "Expected gross from your confirmed work and rules compared with confirmed paystub gross.",
            to: &findings
        )

        let expectedRegular = aggregate(
            calculation: calculation,
            where: {
                $0.category == .workedHours && ($0.multiplier ?? 1) <= 1
            }
        )
        let expectedOvertime = aggregate(
            calculation: calculation,
            where: {
                let multiplier = $0.multiplier ?? 1
                return $0.category == .workedHours && multiplier > 1 && multiplier < 2
            }
        )
        let expectedDoubleTime = aggregate(
            calculation: calculation,
            where: {
                $0.category == .workedHours && ($0.multiplier ?? 1) >= 2
            }
        )
        let expectedCallout = aggregate(
            calculation: calculation,
            where: { $0.category == .calloutGuarantee }
        )
        let expectedPerDiem = aggregate(
            calculation: calculation,
            where: { $0.category == .perDiem }
        )

        if let paid = paystub.regularPay {
            appendFinding(
                id: "regular",
                title: "Regular pay",
                expected: expectedRegular,
                paid: paid,
                explanation:
                    "Worked-hour components at 1× compared with the confirmed regular-pay line.",
                to: &findings
            )
        }
        if let paid = paystub.overtimePay {
            appendFinding(
                id: "overtime",
                title: "Overtime pay",
                expected: expectedOvertime,
                paid: paid,
                explanation:
                    "Worked-hour components above 1× and below 2× compared with confirmed overtime pay.",
                to: &findings
            )
        }
        if let paid = paystub.doubleTimePay {
            appendFinding(
                id: "double-time",
                title: "Double-time pay",
                expected: expectedDoubleTime,
                paid: paid,
                explanation:
                    "Worked-hour components at 2× or higher compared with confirmed double-time pay.",
                to: &findings
            )
        }
        if let paid = paystub.calloutPay {
            appendFinding(
                id: "callout",
                title: "Callout guarantee",
                expected: expectedCallout,
                paid: paid,
                explanation:
                    "Derived callout-minimum entitlement compared with the confirmed paystub line.",
                to: &findings
            )
        }
        if let paid = paystub.perDiemPay {
            appendFinding(
                id: "per-diem",
                title: "Per diem",
                expected: expectedPerDiem,
                paid: paid,
                explanation:
                    "Expected flat per-diem components compared with the confirmed paystub amount.",
                to: &findings
            )
        }

        return findings
    }

    func exportBackupURL() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LinePay-backup-\(formatter.string(from: Date())).json"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: [.atomic])
        return url
    }

    func resetAllData() throws {
        try store.reset()
        try evidenceStore.deleteAll()
        state = AppPersistentState()
        persistenceIssue = nil
        lastPersistenceError = nil
        recalculate()
    }

    func resetAfterPersistenceFailure() throws {
        try resetAllData()
    }

    private var activeTimeZoneIdentifier: String {
        profile?.timeZoneIdentifier ?? TimeZone.current.identifier
    }

    private func commit(_ candidate: AppPersistentState) throws {
        do {
            try store.save(candidate)
            state = candidate
            lastPersistenceError = nil
            recalculate()
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
        unpaidBreakEnd: Date?
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
            unpaidBreaks: unpaidBreaks
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
            let start = try localTime(from: draft.regularStartTime)
            let end = try localTime(from: draft.regularEndTime)
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
        if !trimmedURL.isEmpty, URL(string: trimmedURL) == nil {
            throw AppModelError.invalidField("Source URL")
        }
        let trimmedTitle = draft.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSection = draft.sourceSection.trimmingCharacters(in: .whitespacesAndNewlines)
        let sources: [AgreementSource]
        if trimmedTitle.isEmpty, trimmedURL.isEmpty, trimmedSection.isEmpty {
            sources = []
        } else {
            sources = [
                AgreementSource(
                    title: trimmedTitle.isEmpty ? "Worker-provided source" : trimmedTitle,
                    url: trimmedURL,
                    section: trimmedSection.isEmpty ? nil : trimmedSection
                )
            ]
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
            sources: sources
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

    private func auditStatus(
        paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?
    ) -> AuditDisplayStatus {
        guard paystub != nil else { return .notAudited }
        guard let reconciliation else { return .needsReview }
        switch reconciliation.direction {
        case .matches: return .matches
        case .possibleUnderpayment: return .possibleShortfall
        case .possibleOverpayment: return .possibleOverpayment
        }
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
            confirmedEpochSeconds: paystub.confirmedEpochSeconds
        )
    }

    private func normalizedProfileName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func positiveDecimal(
        _ text: String,
        field: String,
        allowZero: Bool = false
    ) throws -> Decimal {
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw AppModelError.invalidField(field)
        }
        guard allowZero ? value >= 0 : value > 0 else {
            throw AppModelError.invalidField(field)
        }
        return value
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

    private func localTime(from date: Date) throws -> LocalTime {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.hour, .minute], from: date)
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
        fallback ?? TimeZone.current.identifier
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

    var errorDescription: String? {
        switch self {
        case .invalidField(let field):
            "Check the value for \(field)."
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
            "LinePay could not safely save this change. Your previous saved data is unchanged."
        }
    }
}
