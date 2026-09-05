import Foundation
import LinePayDomain

/// Codable does not call validating initializers. Validate stored/imported semantics before use.
enum AppStateValidation {
    static func validate(_ state: AppPersistentState) throws {
        let contexts =
            state.history.map { ($0.window, $0.workEntries, $0.agreement, $0.timeZoneIdentifier) }
            + [
                state.activePeriod.map {
                    ($0.window, $0.workEntries, $0.agreement, $0.timeZoneIdentifier)
                }
            ].compactMap { $0 }
        let ids = state.history.map(\.id) + [state.activePeriod?.id].compactMap { $0 }
        guard ids.count <= 2_000, Set(ids).count == ids.count,
            state.profile != nil || ids.isEmpty,
            state.schemaVersion == AppPersistentState.currentSchemaVersion
        else { throw invalid() }
        if let profile = state.profile {
            guard TimeZone(identifier: profile.timeZoneIdentifier) != nil else { throw invalid() }
            try validate(profile.agreement)
        }
        for (window, entries, agreement, zone) in contexts {
            try validate(window: window, entries: entries, zone: zone)
            try validate(agreement)
        }
        let sorted = contexts.map { $0.0 }.sorted { $0.startEpochSeconds < $1.startEpochSeconds }
        for (a, b) in zip(sorted, sorted.dropFirst()) where a.endEpochSeconds > b.startEpochSeconds
        { throw invalid() }
        for original in state.allEvidence + state.pendingEvidenceDeletions {
            guard safeFilename(original.storedFilename) else { throw invalid() }
        }
        if let draft = state.workDraft, draft.periodID != state.activePeriod?.id { throw invalid() }
        if let draft = state.paystubDraft, !ids.contains(draft.targetPeriodID ?? UUID()) {
            throw invalid()
        }
        let revisions =
            (state.activePeriod?.auditRevisions ?? [])
            + state.history.flatMap { $0.auditRevisions ?? [] }
        for revision in revisions {
            try validate(
                window: revision.window, entries: revision.workEntries,
                zone: revision.timeZoneIdentifier)
            try validate(revision.agreement)
            try validate(calculation: revision.calculation, agreement: revision.agreement)
        }
        for period in state.history {
            try validate(calculation: period.calculation, agreement: period.agreement)
        }
    }

    static func safeFilename(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ ."))
        return !value.isEmpty && value.count <= 150 && !value.contains("..")
            && value != "." && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func validate(calculation: CalculationResult, agreement: AgreementSnapshot)
        throws
    {
        guard calculation.agreementID == agreement.id,
            calculation.agreementVersion == agreement.version,
            !calculation.total.amount.isNaN, calculation.total.amount >= 0,
            calculation.total.currencyCode == agreement.hourlyRate.currencyCode,
            calculation.components.allSatisfy({
                !$0.amount.amount.isNaN && $0.amount.amount >= 0
                    && $0.amount.currencyCode == calculation.total.currencyCode
            })
        else { throw invalid() }
        // Do not recalculate historical amounts with a new engine version.
    }

    private static func validate(_ agreement: AgreementSnapshot) throws {
        guard !agreement.hourlyRate.amount.isNaN, agreement.hourlyRate.amount > 0,
            agreement.hourlyRate.amount <= 10_000_000,
            agreement.hourlyRate.currencyCode.utf8.count == 3,
            agreement.hourlyRate.currencyCode.utf8.allSatisfy({ (65...90).contains($0) }),
            (0...8).contains(agreement.rounding.scale),
            !agreement.outsideScheduleMultiplier.isNaN, agreement.outsideScheduleMultiplier >= 1,
            Set(agreement.dailyOvertimeTiers.map(\.afterHours)).count
                == agreement.dailyOvertimeTiers.count,
            Set(agreement.weekdayPremiums.map(\.weekday)).count == agreement.weekdayPremiums.count,
            Set(agreement.datePremiums.map(\.date)).count == agreement.datePremiums.count
        else { throw invalid() }
        for item in agreement.regularSchedule {
            _ = try RegularScheduleWindow(
                weekday: item.weekday,
                start: LocalTime(hour: item.start.hour, minute: item.start.minute),
                end: LocalTime(hour: item.end.hour, minute: item.end.minute))
        }
        for tier in agreement.dailyOvertimeTiers {
            guard !tier.afterHours.isNaN, !tier.multiplier.isNaN else { throw invalid() }
            _ = try DailyOvertimeTier(afterHours: tier.afterHours, multiplier: tier.multiplier)
        }
        for premium in agreement.weekdayPremiums {
            guard !premium.multiplier.isNaN, premium.multiplier >= 1 else { throw invalid() }
        }
        for premium in agreement.datePremiums {
            try validate(premium.date)
            guard !premium.multiplier.isNaN, premium.multiplier >= 1 else { throw invalid() }
        }
        if let start = agreement.effectiveStart { try validate(start) }
        if let end = agreement.effectiveEnd { try validate(end) }
        if let start = agreement.effectiveStart, let end = agreement.effectiveEnd, start > end {
            throw invalid()
        }
        if let rule = agreement.calloutMinimum {
            guard !rule.minimumHours.isNaN, rule.minimumHours > 0 else { throw invalid() }
        }
        if let rule = agreement.flatPerDiem {
            guard !rule.amountPerWorkDate.amount.isNaN, rule.amountPerWorkDate.amount >= 0,
                rule.amountPerWorkDate.currencyCode == agreement.hourlyRate.currencyCode
            else { throw invalid() }
        }
    }
    private static func validate(_ date: LocalDate) throws {
        guard (1...9999).contains(date.year), (1...12).contains(date.month),
            (1...31).contains(date.day)
        else { throw invalid() }
        let calendar = Calendar(identifier: .gregorian)
        let parts = DateComponents(year: date.year, month: date.month, day: date.day)
        guard let value = calendar.date(from: parts),
            calendar.component(.day, from: value) == date.day
        else { throw invalid() }
    }
    private static func validate(window: PayPeriodWindow, entries: [WorkEntry], zone: String?)
        throws
    {
        let range: ClosedRange<Int64> = -62_135_596_800...253_402_300_799
        guard range.contains(window.startEpochSeconds), range.contains(window.endEpochSeconds),
            window.endEpochSeconds > window.startEpochSeconds, entries.count <= 50_000,
            Set(entries.map(\.id)).count == entries.count
        else { throw invalid() }
        if let zone, TimeZone(identifier: zone) == nil { throw invalid() }
        let ordered = entries.sorted {
            $0.interval.startEpochSeconds < $1.interval.startEpochSeconds
        }
        var priorEnd: Int64?
        for entry in ordered {
            let work = entry.interval
            guard work.startEpochSeconds >= window.startEpochSeconds,
                work.endEpochSeconds <= window.endEpochSeconds,
                work.endEpochSeconds > work.startEpochSeconds,
                work.startEpochSeconds >= (priorEnd ?? work.startEpochSeconds)
            else { throw invalid() }
            _ = try WorkInterval(
                id: work.id, startEpochSeconds: work.startEpochSeconds,
                endEpochSeconds: work.endEpochSeconds, timeZoneIdentifier: work.timeZoneIdentifier,
                kind: work.kind,
                unpaidBreaks: try work.unpaidBreaks.map {
                    try WorkBreak(
                        id: $0.id, startEpochSeconds: $0.startEpochSeconds,
                        endEpochSeconds: $0.endEpochSeconds)
                })
            priorEnd = work.endEpochSeconds
        }
    }
    private static func invalid() -> LocalStateStoreError { .invalidState }
}
