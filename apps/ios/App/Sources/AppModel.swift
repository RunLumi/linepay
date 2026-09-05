import Foundation
import LinePayDomain
import Observation

struct PayProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let timeZoneIdentifier: String
    let agreement: AgreementSnapshot

    init(
        id: UUID = UUID(),
        name: String,
        timeZoneIdentifier: String,
        agreement: AgreementSnapshot
    ) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.agreement = agreement
    }
}

struct PayProfileDraft: Hashable, Sendable {
    var name = "My current pay"
    var hourlyRate = ""
    var timeZoneIdentifier = TimeZone.current.identifier

    var useDailyOvertime = false
    var overtimeAfterHours = "8"
    var overtimeMultiplier = "1.5"

    var useSundayPremium = false
    var sundayMultiplier = "2"

    var useCalloutMinimum = false
    var calloutMinimumHours = "4"

    var usePerDiem = false
    var perDiemAmount = ""

    init() {}

    init(profile: PayProfile) {
        let agreement = profile.agreement
        name = profile.name
        hourlyRate = LinePayFormat.decimal(agreement.hourlyRate.amount)
        timeZoneIdentifier = profile.timeZoneIdentifier

        if let tier = agreement.dailyOvertimeTiers.first {
            useDailyOvertime = true
            overtimeAfterHours = LinePayFormat.decimal(tier.afterHours)
            overtimeMultiplier = LinePayFormat.decimal(tier.multiplier)
        }

        if let sunday = agreement.weekdayPremiums.first(where: { $0.weekday == .sunday }) {
            useSundayPremium = true
            sundayMultiplier = LinePayFormat.decimal(sunday.multiplier)
        }

        if let callout = agreement.calloutMinimum {
            useCalloutMinimum = true
            calloutMinimumHours = LinePayFormat.decimal(callout.minimumHours)
        }

        if let perDiem = agreement.flatPerDiem {
            usePerDiem = true
            perDiemAmount = LinePayFormat.decimal(perDiem.amountPerWorkDate.amount)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var profile: PayProfile?
    private(set) var workIntervals: [WorkInterval] = []
    private(set) var calculation: CalculationResult?
    private(set) var calculationError: String?

    var totalHours: Decimal {
        workIntervals.reduce(0) { $0 + $1.durationHours }
    }

    func saveProfile(_ draft: PayProfileDraft) throws {
        let rate = try positiveDecimal(draft.hourlyRate, field: "Hourly rate")
        let existingAgreement = profile?.agreement
        let agreementID = existingAgreement?.id ?? UUID().uuidString
        let nextVersion = String((Int(existingAgreement?.version ?? "0") ?? 0) + 1)

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

        let calloutMinimum: CalloutMinimumRule? = if draft.useCalloutMinimum {
            try CalloutMinimumRule(
                minimumHours: positiveDecimal(
                    draft.calloutMinimumHours,
                    field: "Callout minimum"
                )
            )
        } else {
            nil
        }

        let perDiem: FlatPerDiemRule? = if draft.usePerDiem {
            FlatPerDiemRule(
                amountPerWorkDate: Money(
                    amount: try positiveDecimal(draft.perDiemAmount, field: "Per diem"),
                    currencyCode: "USD"
                )
            )
        } else {
            nil
        }

        guard TimeZone(identifier: draft.timeZoneIdentifier) != nil else {
            throw AppModelError.invalidField("Time zone")
        }

        let agreement = try AgreementSnapshot(
            id: agreementID,
            version: nextVersion,
            displayName: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            hourlyRate: Money(amount: rate, currencyCode: "USD"),
            regularSchedule: [],
            weekdayPremiums: weekdayPremiums,
            dailyOvertimeTiers: overtimeTiers,
            calloutMinimum: calloutMinimum,
            flatPerDiem: perDiem,
            sources: []
        )

        profile = PayProfile(
            id: profile?.id ?? UUID(),
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            timeZoneIdentifier: draft.timeZoneIdentifier,
            agreement: agreement
        )
        recalculate()
    }

    func addWork(start: Date, end: Date, kind: WorkKind) throws {
        guard let profile else {
            throw AppModelError.missingPayProfile
        }

        let interval = try WorkInterval(
            startEpochSeconds: Int64(start.timeIntervalSince1970.rounded()),
            endEpochSeconds: Int64(end.timeIntervalSince1970.rounded()),
            timeZoneIdentifier: profile.timeZoneIdentifier,
            kind: kind
        )

        let candidate = (workIntervals + [interval]).sorted {
            $0.startEpochSeconds < $1.startEpochSeconds
        }

        _ = try PayCalculator().calculate(
            work: candidate,
            agreement: profile.agreement,
            policy: .highestApplicable
        )

        workIntervals = candidate
        recalculate()
    }

    func deleteWork(id: UUID) {
        workIntervals.removeAll { $0.id == id }
        recalculate()
    }

    private func recalculate() {
        guard let profile else {
            calculation = nil
            calculationError = nil
            return
        }

        do {
            calculation = try PayCalculator().calculate(
                work: workIntervals,
                agreement: profile.agreement,
                policy: .highestApplicable
            )
            calculationError = nil
        } catch {
            calculation = nil
            calculationError = error.localizedDescription
        }
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

    private func multiplierDecimal(_ text: String, field: String) throws -> Decimal {
        let value = try positiveDecimal(text, field: field)
        guard value >= 1 else {
            throw AppModelError.invalidField(field)
        }
        return value
    }
}

enum AppModelError: LocalizedError, Equatable {
    case invalidField(String)
    case missingPayProfile

    var errorDescription: String? {
        switch self {
        case .invalidField(let field):
            "Check the value for \(field)."
        case .missingPayProfile:
            "Set up your pay rules before adding work."
        }
    }
}
