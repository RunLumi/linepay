import Foundation

public struct WeeklyStoredPeriod: Sendable {
    public let id: UUID
    public let timeZoneIdentifier: String
    public let agreement: AgreementSnapshot
    public let changes: [AgreementChange]
    public let work: [WorkInterval]
    public init(
        id: UUID, timeZoneIdentifier: String, agreement: AgreementSnapshot,
        changes: [AgreementChange] = [], work: [WorkInterval]
    ) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.agreement = agreement
        self.changes = changes
        self.work = work
    }
}

public struct WeeklyRecordedSlice: Hashable, Sendable {
    public let sourceWorkID: UUID
    public let payPeriodID: UUID
    public let startEpochSeconds: Int64
    public let endEpochSeconds: Int64
    public let agreement: AgreementReference
    public var workedSeconds: Int64 { endEpochSeconds - startEpochSeconds }
}

/// Clips actual worked instants, removes exact breaks, and selects each payroll-local dated rate.
/// It does not infer remuneration, premium credit, coverage, or completeness from clock records.
public enum WeeklyRecordedWork {
    public static func slices(
        weekStart: LocalDate, startEpochSeconds: Int64, rule: WeeklyOvertimeRule,
        timeZoneIdentifier: String,
        periods: [WeeklyStoredPeriod]
    ) throws -> [WeeklyRecordedSlice] {
        guard rule.applicability == .coveredNonexemptHourly,
            let zone = TimeZone(identifier: timeZoneIdentifier)
        else { throw WeeklyRegularRateError.applicabilityUnknown }
        guard (-62_135_596_800...(253_402_300_799 - 604_800)).contains(startEpochSeconds) else {
            throw WeeklyRegularRateError.invalidWorkweek
        }
        let endEpochSeconds = startEpochSeconds + 604_800
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let first = Date(timeIntervalSince1970: TimeInterval(startEpochSeconds))
        guard calendar.component(.year, from: first) == weekStart.year,
            calendar.component(.month, from: first) == weekStart.month,
            calendar.component(.day, from: first) == weekStart.day
        else {
            throw WeeklyRegularRateError.invalidWorkweek
        }
        guard Set(periods.map(\.id)).count == periods.count else {
            throw WeeklyRegularRateError.duplicateFactID
        }
        var seen = Set<UUID>()
        var occupied: [(Int64, Int64)] = []
        var result: [WeeklyRecordedSlice] = []
        for period in periods {
            let relevant = period.work.filter {
                $0.startEpochSeconds < endEpochSeconds
                    && $0.endEpochSeconds > startEpochSeconds
            }
            if relevant.isEmpty { continue }
            guard period.timeZoneIdentifier == timeZoneIdentifier else {
                throw WeeklyRegularRateError.applicabilityUnknown
            }
            let timeline = try AgreementTimeline(
                baseline: period.agreement, changes: period.changes)
            for original in relevant {
                guard seen.insert(original.id).inserted,
                    original.timeZoneIdentifier == period.timeZoneIdentifier,
                    original.startEpochSeconds >= -62_135_596_800,
                    original.endEpochSeconds <= 253_402_300_799
                else { throw WeeklyRegularRateError.invalidWorkFact(original.id) }
                let entry = try WorkInterval(
                    id: original.id, startEpochSeconds: original.startEpochSeconds,
                    endEpochSeconds: original.endEpochSeconds,
                    timeZoneIdentifier: original.timeZoneIdentifier,
                    kind: original.kind,
                    unpaidBreaks: original.unpaidBreaks.map {
                        try WorkBreak(
                            id: $0.id, startEpochSeconds: $0.startEpochSeconds,
                            endEpochSeconds: $0.endEpochSeconds)
                    },
                    calloutEventID: original.calloutEventID)
                let start = max(entry.startEpochSeconds, startEpochSeconds)
                let end = min(entry.endEpochSeconds, endEpochSeconds)
                occupied.append((start, end))
                var boundaries: Set<Int64> = [start, end]
                for pause in entry.unpaidBreaks {
                    if pause.startEpochSeconds > start && pause.startEpochSeconds < end {
                        boundaries.insert(pause.startEpochSeconds)
                    }
                    if pause.endEpochSeconds > start && pause.endEpochSeconds < end {
                        boundaries.insert(pause.endEpochSeconds)
                    }
                }
                var day = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(start)))
                while true {
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                        throw WeeklyRegularRateError.invalidWorkweek
                    }
                    day = calendar.startOfDay(for: next)
                    let epoch = Int64(day.timeIntervalSince1970)
                    if epoch >= end { break }
                    guard epoch > start else { throw WeeklyRegularRateError.invalidWorkweek }
                    boundaries.insert(epoch)
                }
                let sorted = boundaries.sorted()
                for (a, b) in zip(sorted, sorted.dropFirst()) {
                    if entry.unpaidBreaks.contains(where: {
                        a >= $0.startEpochSeconds && b <= $0.endEpochSeconds
                    }) {
                        continue
                    }
                    let date = Date(timeIntervalSince1970: TimeInterval(a))
                    let local = LocalDate(
                        year: calendar.component(.year, from: date),
                        month: calendar.component(.month, from: date),
                        day: calendar.component(.day, from: date))
                    let agreement = timeline.agreement(on: local)
                    guard agreement.weeklyOvertime == rule,
                        agreement.effectiveStart.map({ local >= $0 }) ?? true,
                        agreement.effectiveEnd.map({ local <= $0 }) ?? true,
                        !agreement.hourlyRate.amount.isNaN, agreement.hourlyRate.amount >= 0
                    else { throw WeeklyRegularRateError.applicabilityUnknown }
                    result.append(
                        WeeklyRecordedSlice(
                            sourceWorkID: entry.id, payPeriodID: period.id,
                            startEpochSeconds: a, endEpochSeconds: b,
                            agreement: AgreementReference(agreement)))
                }
            }
        }
        let intervals = occupied.sorted { $0.0 < $1.0 }
        for (a, b) in zip(intervals, intervals.dropFirst()) where a.1 > b.0 {
            throw WeeklyRegularRateError.duplicateFactID
        }
        return result.sorted {
            $0.startEpochSeconds == $1.startEpochSeconds
                ? $0.sourceWorkID.uuidString < $1.sourceWorkID.uuidString
                : $0.startEpochSeconds < $1.startEpochSeconds
        }
    }
}
