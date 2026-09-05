import Foundation

@testable import LinePayDomain

func decimal(_ value: String) -> Decimal {
    guard let parsed = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
        preconditionFailure("Invalid decimal test fixture: \(value)")
    }
    return parsed
}

func epoch(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int = 0,
    timeZoneIdentifier: String = "America/Los_Angeles"
) -> Int64 {
    guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
        preconditionFailure("Invalid test timezone")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = 0

    guard let date = calendar.date(from: components) else {
        preconditionFailure("Invalid test date")
    }
    return Int64(date.timeIntervalSince1970.rounded())
}

func work(
    _ start: (Int, Int, Int, Int, Int),
    _ end: (Int, Int, Int, Int, Int),
    kind: WorkKind = .regular,
    timeZoneIdentifier: String = "America/Los_Angeles",
    id: UUID = UUID()
) throws -> WorkInterval {
    try WorkInterval(
        id: id,
        startEpochSeconds: epoch(
            year: start.0,
            month: start.1,
            day: start.2,
            hour: start.3,
            minute: start.4,
            timeZoneIdentifier: timeZoneIdentifier
        ),
        endEpochSeconds: epoch(
            year: end.0,
            month: end.1,
            day: end.2,
            hour: end.3,
            minute: end.4,
            timeZoneIdentifier: timeZoneIdentifier
        ),
        timeZoneIdentifier: timeZoneIdentifier,
        kind: kind
    )
}

func weekdaySchedule(
    startHour: Int = 8,
    endHour: Int = 16
) throws -> [RegularScheduleWindow] {
    try [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
    ].map { weekday in
        try RegularScheduleWindow(
            weekday: weekday,
            start: LocalTime(hour: startHour, minute: 0),
            end: LocalTime(hour: endHour, minute: 0)
        )
    }
}

func agreement(
    hourlyRate: String = "10.00",
    schedule: [RegularScheduleWindow] = [],
    outsideScheduleMultiplier: Decimal = 1,
    weekdayPremiums: [WeekdayPremium] = [],
    datePremiums: [DatePremium] = [],
    dailyOvertimeTiers: [DailyOvertimeTier] = [],
    calloutMinimum: CalloutMinimumRule? = nil,
    flatPerDiem: FlatPerDiemRule? = nil,
    effectiveStart: LocalDate? = nil,
    effectiveEnd: LocalDate? = nil
) throws -> AgreementSnapshot {
    try AgreementSnapshot(
        id: "test-agreement",
        version: "v1",
        displayName: "Test Agreement",
        effectiveStart: effectiveStart,
        effectiveEnd: effectiveEnd,
        hourlyRate: Money(amount: decimal(hourlyRate), currencyCode: "USD"),
        regularSchedule: schedule,
        outsideScheduleMultiplier: outsideScheduleMultiplier,
        weekdayPremiums: weekdayPremiums,
        datePremiums: datePremiums,
        dailyOvertimeTiers: dailyOvertimeTiers,
        calloutMinimum: calloutMinimum,
        flatPerDiem: flatPerDiem
    )
}
