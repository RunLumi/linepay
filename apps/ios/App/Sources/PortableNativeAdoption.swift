import Foundation
import LinePayDomain

/// New native facts have their own identities. The imported snapshot remains immutable evidence.
struct PortableNativeAdoption: Codable, Hashable, Sendable {
    let id: UUID
    let sourceProfileRef: String
    let sourcePeriodRef: String?
    let sourceWorkSnapshotRef: String
    let sourceRuleRefs: [String]
    let nativeProfileName: String?
    let makesFutureDefault: Bool?
    let nativeProfileID: UUID
    let nativePeriodID: UUID
    let nativeRuleID: String
    let nativeRuleVersion: String
    let nativeAgreement: AgreementSnapshot
    let nativeWindow: PayPeriodWindow
    let nativeTimeZone: String
    let nativeWork: [WorkEntry]
    let confirmedEpochSeconds: Int64
    let confirmedFields: [String]

    static let requiredFields: Set<String> = [
        "payRules", "scheduleAndPremiums", "rounding", "periodContext", "workFacts",
    ]
    static let portableFieldsByConfirmation: [String: [String]] = [
        "payRules": ["currency", "hourlyRate"],
        "scheduleAndPremiums": [
            "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums",
            "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate",
        ],
        "rounding": ["rounding"],
        "periodContext": ["timeZone", "cadence", "cycleStartDate", "periodWindow"],
        "workFacts": ["currentWork"],
    ]
    var portableConfirmedFields: [String] {
        Set(confirmedFields.flatMap { Self.portableFieldsByConfirmation[$0] ?? [] }).sorted()
    }
}
