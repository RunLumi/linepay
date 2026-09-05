import Foundation

public struct LocalDate: Codable, Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public struct LocalTime: Codable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw DomainValidationError.invalidLocalTime(hour: hour, minute: minute)
        }
        self.hour = hour
        self.minute = minute
    }

    public var minuteOfDay: Int {
        hour * 60 + minute
    }
}

public enum WorkKind: String, Codable, Hashable, Sendable {
    case regular
    case callout
    case other
}

public struct WorkInterval: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let startEpochSeconds: Int64
    public let endEpochSeconds: Int64
    public let timeZoneIdentifier: String
    public let kind: WorkKind

    public init(
        id: UUID = UUID(),
        startEpochSeconds: Int64,
        endEpochSeconds: Int64,
        timeZoneIdentifier: String,
        kind: WorkKind = .regular
    ) throws {
        guard endEpochSeconds > startEpochSeconds else {
            throw DomainValidationError.invalidWorkInterval
        }
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw DomainValidationError.invalidTimeZone(timeZoneIdentifier)
        }

        self.id = id
        self.startEpochSeconds = startEpochSeconds
        self.endEpochSeconds = endEpochSeconds
        self.timeZoneIdentifier = timeZoneIdentifier
        self.kind = kind
    }

    public var durationHours: Decimal {
        Decimal(endEpochSeconds - startEpochSeconds) / 3_600
    }
}

public struct RegularScheduleWindow: Codable, Hashable, Sendable {
    public let weekday: Weekday
    public let start: LocalTime
    public let end: LocalTime

    public init(weekday: Weekday, start: LocalTime, end: LocalTime) throws {
        guard end.minuteOfDay > start.minuteOfDay else {
            throw DomainValidationError.overnightScheduleWindowUnsupported
        }

        self.weekday = weekday
        self.start = start
        self.end = end
    }
}

public struct WeekdayPremium: Codable, Hashable, Sendable {
    public let weekday: Weekday
    public let multiplier: Decimal

    public init(weekday: Weekday, multiplier: Decimal) throws {
        guard multiplier >= 1 else {
            throw DomainValidationError.invalidMultiplier
        }
        self.weekday = weekday
        self.multiplier = multiplier
    }
}

public struct DatePremium: Codable, Hashable, Sendable {
    public let date: LocalDate
    public let multiplier: Decimal

    public init(date: LocalDate, multiplier: Decimal) throws {
        guard multiplier >= 1 else {
            throw DomainValidationError.invalidMultiplier
        }
        self.date = date
        self.multiplier = multiplier
    }
}

public struct DailyOvertimeTier: Codable, Hashable, Sendable {
    public let afterHours: Decimal
    public let multiplier: Decimal

    public init(afterHours: Decimal, multiplier: Decimal) throws {
        guard afterHours >= 0, multiplier >= 1 else {
            throw DomainValidationError.invalidOvertimeTier
        }
        self.afterHours = afterHours
        self.multiplier = multiplier
    }
}

public struct CalloutMinimumRule: Codable, Hashable, Sendable {
    public let minimumHours: Decimal

    public init(minimumHours: Decimal) throws {
        guard minimumHours > 0 else {
            throw DomainValidationError.invalidCalloutMinimum
        }
        self.minimumHours = minimumHours
    }
}

public struct FlatPerDiemRule: Codable, Hashable, Sendable {
    public let amountPerWorkDate: Money

    public init(amountPerWorkDate: Money) {
        self.amountPerWorkDate = amountPerWorkDate
    }
}

public struct AgreementSource: Codable, Hashable, Sendable {
    public let title: String
    public let url: String
    public let section: String?
    public let verifiedEpochSeconds: Int64?

    public init(
        title: String,
        url: String,
        section: String? = nil,
        verifiedEpochSeconds: Int64? = nil
    ) {
        self.title = title
        self.url = url
        self.section = section
        self.verifiedEpochSeconds = verifiedEpochSeconds
    }
}

public struct AgreementSnapshot: Codable, Hashable, Sendable {
    public let id: String
    public let version: String
    public let displayName: String
    public let effectiveStart: LocalDate?
    public let effectiveEnd: LocalDate?
    public let hourlyRate: Money
    public let regularSchedule: [RegularScheduleWindow]
    public let outsideScheduleMultiplier: Decimal
    public let weekdayPremiums: [WeekdayPremium]
    public let datePremiums: [DatePremium]
    public let dailyOvertimeTiers: [DailyOvertimeTier]
    public let calloutMinimum: CalloutMinimumRule?
    public let flatPerDiem: FlatPerDiemRule?
    public let rounding: MoneyRoundingRule
    public let sources: [AgreementSource]

    public init(
        id: String,
        version: String,
        displayName: String,
        effectiveStart: LocalDate? = nil,
        effectiveEnd: LocalDate? = nil,
        hourlyRate: Money,
        regularSchedule: [RegularScheduleWindow],
        outsideScheduleMultiplier: Decimal = 1,
        weekdayPremiums: [WeekdayPremium] = [],
        datePremiums: [DatePremium] = [],
        dailyOvertimeTiers: [DailyOvertimeTier] = [],
        calloutMinimum: CalloutMinimumRule? = nil,
        flatPerDiem: FlatPerDiemRule? = nil,
        rounding: MoneyRoundingRule = MoneyRoundingRule(),
        sources: [AgreementSource] = []
    ) throws {
        guard outsideScheduleMultiplier >= 1 else {
            throw DomainValidationError.invalidMultiplier
        }
        guard hourlyRate.currencyCode.count == 3 else {
            throw DomainValidationError.invalidCurrencyCode(hourlyRate.currencyCode)
        }

        let sortedTiers = dailyOvertimeTiers.sorted { $0.afterHours < $1.afterHours }
        guard Set(sortedTiers.map(\.afterHours)).count == sortedTiers.count else {
            throw DomainValidationError.duplicateOvertimeThreshold
        }

        self.id = id
        self.version = version
        self.displayName = displayName
        self.effectiveStart = effectiveStart
        self.effectiveEnd = effectiveEnd
        self.hourlyRate = hourlyRate
        self.regularSchedule = regularSchedule
        self.outsideScheduleMultiplier = outsideScheduleMultiplier
        self.weekdayPremiums = weekdayPremiums
        self.datePremiums = datePremiums
        self.dailyOvertimeTiers = sortedTiers
        self.calloutMinimum = calloutMinimum
        self.flatPerDiem = flatPerDiem
        self.rounding = rounding
        self.sources = sources
    }
}

public enum PayComponentCategory: String, Codable, Hashable, Sendable {
    case workedHours
    case calloutGuarantee
    case perDiem
}

public struct PayComponent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let category: PayComponentCategory
    public let workIntervalID: UUID?
    public let localDate: LocalDate
    public let hours: Decimal?
    public let multiplier: Decimal?
    public let amount: Money
    public let explanation: String

    public init(
        id: UUID = UUID(),
        category: PayComponentCategory,
        workIntervalID: UUID?,
        localDate: LocalDate,
        hours: Decimal?,
        multiplier: Decimal?,
        amount: Money,
        explanation: String
    ) {
        self.id = id
        self.category = category
        self.workIntervalID = workIntervalID
        self.localDate = localDate
        self.hours = hours
        self.multiplier = multiplier
        self.amount = amount
        self.explanation = explanation
    }
}

public struct CalculationResult: Codable, Hashable, Sendable {
    public let agreementID: String
    public let agreementVersion: String
    public let components: [PayComponent]
    public let total: Money

    public init(
        agreementID: String,
        agreementVersion: String,
        components: [PayComponent],
        total: Money
    ) {
        self.agreementID = agreementID
        self.agreementVersion = agreementVersion
        self.components = components
        self.total = total
    }
}

public enum DomainValidationError: Error, Equatable, Sendable {
    case invalidLocalTime(hour: Int, minute: Int)
    case invalidWorkInterval
    case invalidTimeZone(String)
    case overnightScheduleWindowUnsupported
    case invalidMultiplier
    case invalidOvertimeTier
    case duplicateOvertimeThreshold
    case invalidCalloutMinimum
    case invalidCurrencyCode(String)
}
