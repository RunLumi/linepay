import Foundation
import LinePayDomain

struct DatePremiumDraft: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var multiplier: String

    init(id: UUID = UUID(), date: Date = Date(), multiplier: String = "2") {
        self.id = id
        self.date = date
        self.multiplier = multiplier
    }
}

struct ProfileChangePreview {
    let before: Money?
    let after: Money?
    let workCount: Int
}

enum RuleChangeScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case prospective, correctCurrentPeriod, futurePeriods
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prospective: "New rules from a date"
        case .correctCurrentPeriod: "Correct this period's setup"
        case .futurePeriods: "Future work periods only"
        }
    }
}

struct PayProfileDraft: Codable, Hashable, Sendable {
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

    var additionalOvertimeTiers: [OvertimeTierDraft] = []
    var additionalWeekdayPremiums: [WeekdayPremiumDraft] = []
    var additionalSources: [RuleSourceDraft] = []
    var sourceRuleKey: PayRuleKey?
    var unsupportedRuleNotes = ""
    var changeEffectiveDate: Date?
    var editScope: RuleEditScope = .futurePeriods
    var setupStep = 0
    var sourceTitle = ""
    var sourceURL = ""
    var sourceSection = ""

    init() {}

    init(profile: PayProfile, activePeriod: ActivePayPeriod? = nil) {
        let agreement = profile.agreement
        unsupportedRuleNotes = agreement.unsupportedRuleNotes ?? ""
        additionalOvertimeTiers = agreement.dailyOvertimeTiers.dropFirst().map {
            OvertimeTierDraft(
                afterHours: LinePayFormat.decimal($0.afterHours),
                multiplier: LinePayFormat.decimal($0.multiplier))
        }
        additionalWeekdayPremiums = agreement.weekdayPremiums.filter { $0.weekday != .sunday }.map {
            WeekdayPremiumDraft(
                weekday: $0.weekday, multiplier: LinePayFormat.decimal($0.multiplier))
        }
        additionalSources = agreement.sources.dropFirst().map { RuleSourceDraft(source: $0) }
        sourceRuleKey = agreement.sources.first?.ruleKey
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
                minute: firstWindow.start.minute,
                timeZoneIdentifier: profile.timeZoneIdentifier
            )
            regularEndTime = Self.clockDate(
                hour: firstWindow.end.hour,
                minute: firstWindow.end.minute,
                timeZoneIdentifier: profile.timeZoneIdentifier
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

    private static func clockDate(
        hour: Int,
        minute: Int,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
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

struct PaystubConfirmationDraft: Codable, Hashable, Sendable {
    var targetPeriodID: UUID?
    var workComplete: Bool?
    var grossBasis: PaystubGrossBasis = .unconfirmed
    var lineLayout: PaystubLineLayout = .unconfirmed
    var hoursBasis: PaystubHoursBasis = .unconfirmed
    var guaranteeLayout: PaystubGuaranteeLayout = .unconfirmed
    var reviewedFields: Set<PaystubField> = []
    var suggestions: [PaystubField: OCRFieldSuggestion] = [:]
    var sourceEvidence: PaystubEvidence?
    var processingNotice: String?
    var sourcePageCount: Int?
    var hasAdditionalUnmappedPay = false

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

enum RuleEditScope: String, Codable, CaseIterable, Hashable, Sendable {
    case futurePeriods, currentPeriod, datedChange
}

struct OvertimeTierDraft: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var afterHours = "12"
    var multiplier = "2"
}

struct WeekdayPremiumDraft: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var weekday: Weekday = .saturday
    var multiplier = "2"
}

struct RuleSourceDraft: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var title = ""
    var url = ""
    var section = ""
    var ruleKey: PayRuleKey?
    init() {}
    init(source: AgreementSource) {
        title = source.title
        url = source.url
        section = source.section ?? ""
        ruleKey = source.ruleKey
    }
}

struct WorkDraft: Codable, Hashable, Sendable {
    var periodID: UUID
    var editingEntryID: UUID?
    var start: Date
    var end: Date
    var kind: WorkKind
    var note: String
    var hasUnpaidBreak: Bool
    var breakStart: Date
    var breakEnd: Date
    var copiedFrom: Date?
    var additionalBreaks: [BreakDraft] = []
}

struct DeletedWorkUndo: Hashable, Sendable {
    let periodID: UUID
    let expectedRevision: Int
    let entry: WorkEntry
}

/// Vision coordinates, not payroll quantities. Normalized to the page, with origin at bottom-left.
struct SourceRegion: Codable, Hashable, Sendable {
    let page: Int
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct OCRFieldSuggestion: Codable, Hashable, Sendable {
    let value: String?
    let sourceText: String
    let region: SourceRegion
    let confidence: Double
    let reason: String?
}

struct PaystubConfirmation: Codable, Hashable, Sendable {
    let grossBasis: PaystubGrossBasis
    let lineLayout: PaystubLineLayout
    let hoursBasis: PaystubHoursBasis
    let guaranteeLayout: PaystubGuaranteeLayout
    let reviewedFields: Set<PaystubField>
    let suggestions: [PaystubField: OCRFieldSuggestion]
    let hasAdditionalUnmappedPay: Bool
    let workComplete: Bool?
}

extension PaystubConfirmationDraft {
    subscript(field: PaystubField) -> String {
        get {
            switch field {
            case .grossPay: grossPay
            case .regularHours: regularHours
            case .regularPay: regularPay
            case .overtimeHours: overtimeHours
            case .overtimePay: overtimePay
            case .doubleTimeHours: doubleTimeHours
            case .doubleTimePay: doubleTimePay
            case .calloutPay: calloutPay
            case .perDiemPay: perDiemPay
            case .periodStart, .periodEnd: ""
            }
        }
        set {
            switch field {
            case .grossPay: grossPay = newValue
            case .regularHours: regularHours = newValue
            case .regularPay: regularPay = newValue
            case .overtimeHours: overtimeHours = newValue
            case .overtimePay: overtimePay = newValue
            case .doubleTimeHours: doubleTimeHours = newValue
            case .doubleTimePay: doubleTimePay = newValue
            case .calloutPay: calloutPay = newValue
            case .perDiemPay: perDiemPay = newValue
            case .periodStart, .periodEnd: break
            }
        }
    }
}

struct BreakDraft: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var start: Date
    var end: Date
}
