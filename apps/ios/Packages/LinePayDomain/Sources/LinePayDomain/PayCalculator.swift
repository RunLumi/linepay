import Foundation

public struct PayCalculationPolicy: Hashable, Sendable {
    public enum PremiumCombination: Hashable, Sendable {
        case highestApplicable
    }

    public let premiumCombination: PremiumCombination

    public init(premiumCombination: PremiumCombination) {
        self.premiumCombination = premiumCombination
    }

    public static let highestApplicable = PayCalculationPolicy(
        premiumCombination: .highestApplicable
    )
}

public struct PayCalculator: Sendable {
    public init() {}

    public func calculate(
        work: [WorkInterval],
        agreement: AgreementSnapshot,
        policy: PayCalculationPolicy
    ) throws -> CalculationResult {
        try validate(work: work)

        var rawSegments: [RawSegment] = []
        for interval in work {
            rawSegments += try split(interval: interval, agreement: agreement)
        }
        rawSegments.sort { $0.startEpochSeconds < $1.startEpochSeconds }

        var cumulativeHoursByDay: [DayKey: Decimal] = [:]
        var components: [PayComponent] = []

        for segment in rawSegments {
            try validateEffectiveDate(segment.localDate, agreement: agreement)

            let dayKey = DayKey(
                date: segment.localDate,
                timeZoneIdentifier: segment.timeZoneIdentifier
            )
            let startingDailyHours = cumulativeHoursByDay[dayKey, default: 0]
            let slices = overtimeSlices(
                hours: segment.durationHours,
                startingDailyHours: startingDailyHours,
                tiers: agreement.dailyOvertimeTiers
            )

            var hoursConsumed: Decimal = 0
            for slice in slices {
                let baseMultiplier = applicableBaseMultiplier(
                    for: segment,
                    agreement: agreement,
                    overtimeMultiplier: slice.multiplier,
                    policy: policy
                )
                let amount = agreement.hourlyRate
                    .multiplied(by: slice.hours)
                    .multiplied(by: baseMultiplier)
                    .rounded(using: agreement.rounding)

                components.append(
                    PayComponent(
                        category: .workedHours,
                        workIntervalID: segment.workIntervalID,
                        localDate: segment.localDate,
                        hours: slice.hours,
                        multiplier: baseMultiplier,
                        amount: amount,
                        explanation: explanation(
                            for: segment,
                            overtimeMultiplier: slice.multiplier,
                            finalMultiplier: baseMultiplier,
                            agreement: agreement
                        )
                    )
                )
                hoursConsumed += slice.hours
            }

            cumulativeHoursByDay[dayKey] = startingDailyHours + hoursConsumed
        }

        components += try calloutGuarantees(
            work: work,
            existingComponents: components,
            agreement: agreement
        )
        components += try perDiemComponents(work: work, agreement: agreement)

        let zero = Money.zero(currencyCode: agreement.hourlyRate.currencyCode)
        let total = try components.reduce(zero) {
            try $0.adding($1.amount)
        }

        return CalculationResult(
            agreementID: agreement.id,
            agreementVersion: agreement.version,
            components: components,
            total: total.rounded(using: agreement.rounding)
        )
    }

    private func validate(work: [WorkInterval]) throws {
        guard Set(work.map(\.id)).count == work.count else {
            throw PayCalculationError.duplicateWorkIntervalID
        }

        let sorted = work.sorted { $0.startEpochSeconds < $1.startEpochSeconds }
        for pair in zip(sorted, sorted.dropFirst()) {
            if pair.1.startEpochSeconds < pair.0.endEpochSeconds {
                throw PayCalculationError.overlappingWorkIntervals
            }
        }
    }

    private func validateEffectiveDate(
        _ date: LocalDate,
        agreement: AgreementSnapshot
    ) throws {
        if let start = agreement.effectiveStart, date < start {
            throw PayCalculationError.workOutsideAgreementEffectiveDates(date)
        }
        if let end = agreement.effectiveEnd, date > end {
            throw PayCalculationError.workOutsideAgreementEffectiveDates(date)
        }
    }

    /// Splits actual clock time at local-day, schedule, and unpaid-break boundaries.
    /// Break spans are omitted entirely, so downstream OT/premium logic operates only on paid worked time.
    private func split(
        interval: WorkInterval,
        agreement: AgreementSnapshot
    ) throws -> [RawSegment] {
        guard let timeZone = TimeZone(identifier: interval.timeZoneIdentifier) else {
            throw DomainValidationError.invalidTimeZone(interval.timeZoneIdentifier)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var result: [RawSegment] = []
        var cursor = interval.startEpochSeconds

        while cursor < interval.endEpochSeconds {
            let cursorDate = date(fromEpochSeconds: cursor)
            let dayStart = calendar.startOfDay(for: cursorDate)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                throw PayCalculationError.calendarComputationFailed
            }

            let nextDayEpoch = epochSeconds(from: nextDay)
            let chunkEnd = min(interval.endEpochSeconds, nextDayEpoch)
            let localDate = localDate(for: cursorDate, calendar: calendar)
            let weekday = try weekday(for: cursorDate, calendar: calendar)

            var boundaries: Set<Int64> = [cursor, chunkEnd]
            for window in agreement.regularSchedule where window.weekday == weekday {
                let start = try epochSeconds(
                    for: localDate,
                    localTime: window.start,
                    calendar: calendar
                )
                let end = try epochSeconds(
                    for: localDate,
                    localTime: window.end,
                    calendar: calendar
                )
                if start > cursor, start < chunkEnd {
                    boundaries.insert(start)
                }
                if end > cursor, end < chunkEnd {
                    boundaries.insert(end)
                }
            }

            for workBreak in interval.unpaidBreaks {
                if workBreak.startEpochSeconds > cursor,
                    workBreak.startEpochSeconds < chunkEnd
                {
                    boundaries.insert(workBreak.startEpochSeconds)
                }
                if workBreak.endEpochSeconds > cursor,
                    workBreak.endEpochSeconds < chunkEnd
                {
                    boundaries.insert(workBreak.endEpochSeconds)
                }
            }

            let sortedBoundaries = boundaries.sorted()
            for pair in zip(sortedBoundaries, sortedBoundaries.dropFirst()) {
                let midpoint = pair.0 + (pair.1 - pair.0) / 2
                if isInsideUnpaidBreak(epochSeconds: midpoint, interval: interval) {
                    continue
                }

                result.append(
                    RawSegment(
                        workIntervalID: interval.id,
                        kind: interval.kind,
                        startEpochSeconds: pair.0,
                        endEpochSeconds: pair.1,
                        timeZoneIdentifier: interval.timeZoneIdentifier,
                        localDate: localDate,
                        weekday: weekday,
                        isWithinRegularSchedule: isWithinRegularSchedule(
                            epochSeconds: midpoint,
                            weekday: weekday,
                            calendar: calendar,
                            schedule: agreement.regularSchedule
                        )
                    )
                )
            }

            cursor = chunkEnd
        }

        return result
    }

    private func isInsideUnpaidBreak(
        epochSeconds: Int64,
        interval: WorkInterval
    ) -> Bool {
        interval.unpaidBreaks.contains {
            epochSeconds >= $0.startEpochSeconds && epochSeconds < $0.endEpochSeconds
        }
    }

    private func applicableBaseMultiplier(
        for segment: RawSegment,
        agreement: AgreementSnapshot,
        overtimeMultiplier: Decimal,
        policy: PayCalculationPolicy
    ) -> Decimal {
        let scheduleMultiplier: Decimal =
            segment.isWithinRegularSchedule
            ? 1
            : agreement.outsideScheduleMultiplier
        let weekdayPremiums = agreement.weekdayPremiums.filter {
            $0.weekday == segment.weekday
        }
        let weekdayMultiplier = weekdayPremiums.map(\.multiplier).max() ?? 1
        let datePremiums = agreement.datePremiums.filter {
            $0.date == segment.localDate
        }
        let dateMultiplier = datePremiums.map(\.multiplier).max() ?? 1

        switch policy.premiumCombination {
        case .highestApplicable:
            return [
                scheduleMultiplier,
                weekdayMultiplier,
                dateMultiplier,
                overtimeMultiplier,
            ].max() ?? 1
        }
    }

    private func overtimeSlices(
        hours: Decimal,
        startingDailyHours: Decimal,
        tiers: [DailyOvertimeTier]
    ) -> [OvertimeSlice] {
        guard hours > 0 else {
            return []
        }

        var result: [OvertimeSlice] = []
        var remaining = hours
        var position = startingDailyHours

        while remaining > 0 {
            let activeTiers = tiers.filter { $0.afterHours <= position }
            let currentMultiplier = activeTiers.last?.multiplier ?? 1
            let futureThresholds = tiers.map(\.afterHours).filter { $0 > position }
            let nextThreshold = futureThresholds.min()

            let sliceHours: Decimal
            if let nextThreshold {
                sliceHours = min(remaining, nextThreshold - position)
            } else {
                sliceHours = remaining
            }

            result.append(OvertimeSlice(hours: sliceHours, multiplier: currentMultiplier))
            remaining -= sliceHours
            position += sliceHours
        }

        return result
    }

    private func calloutGuarantees(
        work: [WorkInterval],
        existingComponents: [PayComponent],
        agreement: AgreementSnapshot
    ) throws -> [PayComponent] {
        guard let rule = agreement.calloutMinimum else {
            return []
        }

        var result: [PayComponent] = []
        for interval in work where interval.kind == .callout {
            let missingHours = rule.minimumHours - interval.durationHours
            guard missingHours > 0 else {
                continue
            }

            let intervalComponents = existingComponents.filter {
                $0.workIntervalID == interval.id && $0.category == .workedHours
            }
            let multipliers = intervalComponents.compactMap(\.multiplier)
            let applicableMultiplier = multipliers.max() ?? 1
            let amount = agreement.hourlyRate
                .multiplied(by: missingHours)
                .multiplied(by: applicableMultiplier)
                .rounded(using: agreement.rounding)
            let date = try localDate(
                epochSeconds: interval.startEpochSeconds,
                timeZoneIdentifier: interval.timeZoneIdentifier
            )

            result.append(
                PayComponent(
                    category: .calloutGuarantee,
                    workIntervalID: interval.id,
                    localDate: date,
                    hours: missingHours,
                    multiplier: applicableMultiplier,
                    amount: amount,
                    explanation: "callout minimum guarantee"
                )
            )
        }
        return result
    }

    private func perDiemComponents(
        work: [WorkInterval],
        agreement: AgreementSnapshot
    ) throws -> [PayComponent] {
        guard let rule = agreement.flatPerDiem else {
            return []
        }
        guard rule.amountPerWorkDate.currencyCode == agreement.hourlyRate.currencyCode else {
            throw MoneyError.currencyMismatch(
                lhs: agreement.hourlyRate.currencyCode,
                rhs: rule.amountPerWorkDate.currencyCode
            )
        }

        var dates: Set<DayKey> = []
        for interval in work {
            for segment in try split(interval: interval, agreement: agreement) {
                dates.insert(
                    DayKey(
                        date: segment.localDate,
                        timeZoneIdentifier: segment.timeZoneIdentifier
                    )
                )
            }
        }

        return dates.sorted().map { day in
            PayComponent(
                category: .perDiem,
                workIntervalID: nil,
                localDate: day.date,
                hours: nil,
                multiplier: nil,
                amount: rule.amountPerWorkDate.rounded(using: agreement.rounding),
                explanation: "flat per diem for worked local date"
            )
        }
    }

    private func explanation(
        for segment: RawSegment,
        overtimeMultiplier: Decimal,
        finalMultiplier: Decimal,
        agreement: AgreementSnapshot
    ) -> String {
        var reasons: [String] = []
        if !segment.isWithinRegularSchedule, agreement.outsideScheduleMultiplier > 1 {
            reasons.append("outside regular schedule")
        }
        if agreement.weekdayPremiums.contains(where: {
            $0.weekday == segment.weekday && $0.multiplier == finalMultiplier
        }) {
            reasons.append("weekday premium")
        }
        if agreement.datePremiums.contains(where: {
            $0.date == segment.localDate && $0.multiplier == finalMultiplier
        }) {
            reasons.append("date premium")
        }
        if overtimeMultiplier > 1, overtimeMultiplier == finalMultiplier {
            reasons.append("daily overtime tier")
        }
        if reasons.isEmpty {
            reasons.append("regular scheduled hours")
        }
        return reasons.joined(separator: ", ")
    }

    private func isWithinRegularSchedule(
        epochSeconds: Int64,
        weekday: Weekday,
        calendar: Calendar,
        schedule: [RegularScheduleWindow]
    ) -> Bool {
        guard !schedule.isEmpty else {
            return true
        }

        let date = date(fromEpochSeconds: epochSeconds)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return false
        }
        let minuteOfDay = hour * 60 + minute

        return schedule.contains {
            $0.weekday == weekday
                && minuteOfDay >= $0.start.minuteOfDay
                && minuteOfDay < $0.end.minuteOfDay
        }
    }

    private func localDate(
        epochSeconds: Int64,
        timeZoneIdentifier: String
    ) throws -> LocalDate {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw DomainValidationError.invalidTimeZone(timeZoneIdentifier)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return localDate(for: date(fromEpochSeconds: epochSeconds), calendar: calendar)
    }

    private func localDate(for date: Date, calendar: Calendar) -> LocalDate {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return LocalDate(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    private func weekday(for date: Date, calendar: Calendar) throws -> Weekday {
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) else {
            throw PayCalculationError.calendarComputationFailed
        }
        return weekday
    }

    private func epochSeconds(
        for localDate: LocalDate,
        localTime: LocalTime,
        calendar: Calendar
    ) throws -> Int64 {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = localDate.year
        components.month = localDate.month
        components.day = localDate.day
        components.hour = localTime.hour
        components.minute = localTime.minute
        components.second = 0

        guard let date = calendar.date(from: components) else {
            throw PayCalculationError.calendarComputationFailed
        }
        return epochSeconds(from: date)
    }

    private func date(fromEpochSeconds epochSeconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(epochSeconds))
    }

    private func epochSeconds(from date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }
}

private struct RawSegment: Sendable {
    let workIntervalID: UUID
    let kind: WorkKind
    let startEpochSeconds: Int64
    let endEpochSeconds: Int64
    let timeZoneIdentifier: String
    let localDate: LocalDate
    let weekday: Weekday
    let isWithinRegularSchedule: Bool

    var durationHours: Decimal {
        Decimal(Int(endEpochSeconds - startEpochSeconds)) / 3_600
    }
}

private struct OvertimeSlice: Sendable {
    let hours: Decimal
    let multiplier: Decimal
}

private struct DayKey: Hashable, Sendable, Comparable {
    let date: LocalDate
    let timeZoneIdentifier: String

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return lhs.timeZoneIdentifier < rhs.timeZoneIdentifier
    }
}

public enum PayCalculationError: Error, Equatable, Sendable {
    case duplicateWorkIntervalID
    case overlappingWorkIntervals
    case calendarComputationFailed
    case workOutsideAgreementEffectiveDates(LocalDate)
}
