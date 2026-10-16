import Foundation
import LinePayDomain

struct CrewRuleOrigin: Codable, Hashable, Sendable {
    let adoption: CrewRuleAdoption
    let agreement: AgreementSnapshot
    let timeZoneIdentifier: String
}

enum CrewRuleDraftBuilder {
    static func validateIdentity(_ adoption: CrewRuleAdoption, among origins: [CrewRuleOrigin])
        throws
    {
        let packet = try CrewRuleTemplate.decode(adoption.templateData)
        for origin in origins {
            let previous = try CrewRuleTemplate.decode(origin.adoption.templateData)
            if previous.templateID == packet.templateID, previous.revision == packet.revision,
                previous != packet
            {
                throw AppModelError.invalidField(
                    "This draft identity already has different retained contents; request a new revision"
                )
            }
        }
    }
    static func build(
        data: Data, hourlyRate: String, perDiemChoice: CrewRuleTemplate.PerDiemChoice,
        perDiemAmount: String, applicabilityConfirmed: Bool, valuesConfirmed: Bool,
        timeZoneIdentifier: String, profile: PayProfile?, activePeriod: ActivePayPeriod?
    ) throws -> PayProfileDraft {
        let packet = try CrewRuleTemplate.decode(data)
        guard PayProfileDraft.supportedCurrencyCodes.contains(packet.rules.currency),
            profile.map({ $0.agreement.hourlyRate.currencyCode == packet.rules.currency }) ?? true,
            TimeZone(identifier: timeZoneIdentifier) != nil
        else {
            throw AppModelError.invalidField(
                "Review the draft currency and payroll timezone; an existing profile keeps its currency"
            )
        }
        let rate = Money(
            amount: try NumberEntry.amount(
                hourlyRate, currencyCode: packet.rules.currency, allowZero: false),
            currencyCode: packet.rules.currency)
        let allowance =
            try perDiemChoice == .confirmedAmount
            ? Money(
                amount: NumberEntry.amount(perDiemAmount, currencyCode: packet.rules.currency),
                currencyCode: packet.rules.currency) : nil
        let adoption = try CrewRuleAdoption(
            templateData: data, hourlyRate: rate, perDiemChoice: perDiemChoice,
            perDiemAmount: allowance, applicabilityConfirmed: applicabilityConfirmed,
            valuesConfirmed: valuesConfirmed)
        let agreement = try adoption.proposedAgreement(newAgreementID: UUID())
        if let previous = profile?.agreement {
            guard previous.rounding == agreement.rounding else {
                throw AppModelError.invalidField(
                    "This draft uses different rounding. Keep the existing profile's rounding and review rules manually"
                )
            }
        }
        let recipient = PayProfile(
            id: profile?.id ?? UUID(), name: profile?.name ?? "My current pay",
            timeZoneIdentifier: timeZoneIdentifier, agreement: agreement,
            preferredCadence: profile?.preferredCadence ?? .weekly)
        var draft = PayProfileDraft(profile: recipient, activePeriod: activePeriod)
        draft.sourceTitle = "Worker-provided rule draft: " + packet.title
        draft.sourceSection = "Draft revision " + packet.revision + "; not a verified agreement"
        draft.crewRuleAdoption = adoption
        draft.editScope = .futurePeriods
        return draft
    }

    static func validate(_ origins: [CrewRuleOrigin]) throws {
        guard origins.count <= 256,
            Set(origins.map { [$0.agreement.id, $0.agreement.version] }).count == origins.count
        else { throw LocalStateStoreError.invalidState }
        var identities: [[String]: CrewRuleTemplate] = [:]
        for origin in origins {
            guard TimeZone(identifier: origin.timeZoneIdentifier) != nil,
                !origin.agreement.id.isEmpty, origin.agreement.id.count <= 256,
                !origin.agreement.version.isEmpty, origin.agreement.version.count <= 128,
                let confirmed = origin.agreement.confirmedEpochSeconds,
                (-62_135_596_800...253_402_300_799).contains(confirmed)
            else {
                throw LocalStateStoreError.invalidState
            }
            try origin.adoption.validate(agreement: origin.agreement)
            let packet = try CrewRuleTemplate.decode(origin.adoption.templateData)
            let key = [packet.templateID.uuidString, packet.revision]
            guard identities[key].map({ $0 == packet }) ?? true else {
                throw LocalStateStoreError.invalidState
            }
            identities[key] = packet
            for source in origin.agreement.sources {
                try AgreementImportValidation.validate(source)
            }
        }
    }
}
