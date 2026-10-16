import Foundation
import Testing

@testable import LinePayDomain

@Suite("Retained recipient rule-draft choices")
struct CrewRuleAdoptionTests {
    private func packet() throws -> Data {
        let sender = try AgreementSnapshot(
            id: "PRIVATE-SENDER", version: "1", displayName: "PRIVATE NAME",
            hourlyRate: Money(amount: 50, currencyCode: "USD"), regularSchedule: [],
            dailyOvertimeTiers: [
                DailyOvertimeTier(afterHours: 8, multiplier: Decimal(string: "1.5")!)
            ],
            flatPerDiem: FlatPerDiemRule(amountPerWorkDate: Money(amount: 140, currencyCode: "USD"))
        )
        return try CrewRuleTemplate.sharing(
            sender, templateID: UUID(), revision: "1", title: "Synthetic crew"
        ).encoded()
    }

    @Test func originalBytesAndOwnAmountsSurviveRoundTripWithoutInventingSourceApproval() throws {
        let bytes = try packet()
        let adoption = try CrewRuleAdoption(
            templateData: bytes, hourlyRate: Money(amount: 75, currencyCode: "USD"),
            perDiemChoice: .confirmedAmount, perDiemAmount: Money(amount: 0, currencyCode: "USD"),
            applicabilityConfirmed: true, valuesConfirmed: true)
        let restored = try JSONDecoder().decode(
            CrewRuleAdoption.self, from: JSONEncoder().encode(adoption))
        #expect(restored == adoption && restored.templateData == bytes)
        let ownID = UUID()
        let agreement = try restored.proposedAgreement(newAgreementID: ownID)
        try restored.validate(agreement: agreement)
        #expect(agreement.id == ownID.uuidString.lowercased())
        #expect(
            agreement.hourlyRate.amount == 75
                && agreement.flatPerDiem?.amountPerWorkDate.amount == 0)
        #expect(agreement.sources.isEmpty && agreement.confirmedEpochSeconds == nil)
        #expect(!String(decoding: bytes, as: UTF8.self).contains("PRIVATE"))
    }

    @Test func unconfirmedAndUnknownAllowanceChoicesCannotBecomeAnAdoption() throws {
        let bytes = try packet()
        #expect(throws: CrewRuleTemplateError.confirmationRequired) {
            try CrewRuleAdoption(
                templateData: bytes, hourlyRate: Money(amount: 75, currencyCode: "USD"),
                perDiemChoice: .notApplicable, applicabilityConfirmed: false, valuesConfirmed: true)
        }
        #expect(throws: CrewRuleTemplateError.allowanceReviewRequired) {
            try CrewRuleAdoption(
                templateData: bytes, hourlyRate: Money(amount: 75, currencyCode: "USD"),
                perDiemChoice: .unreviewed, applicabilityConfirmed: true, valuesConfirmed: true)
        }
    }

    @Test func changedTermsOrDecodedChoicesMustBeReviewedAgain() throws {
        let adoption = try CrewRuleAdoption(
            templateData: packet(), hourlyRate: Money(amount: 75, currencyCode: "USD"),
            perDiemChoice: .notApplicable, applicabilityConfirmed: true, valuesConfirmed: true)
        let agreement = try adoption.proposedAgreement(newAgreementID: UUID())
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(agreement)) as? [String: Any])
        object["hourlyRate"] = ["amount": 80, "currencyCode": "USD"]
        let changed = try JSONDecoder().decode(
            AgreementSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: CrewRuleTemplateError.confirmationRequired) {
            try adoption.validate(agreement: changed)
        }
        var raw = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(adoption)) as? [String: Any])
        raw["perDiemChoice"] = "unreviewed"
        let invalid = try JSONDecoder().decode(
            CrewRuleAdoption.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(throws: CrewRuleTemplateError.allowanceReviewRequired) {
            try invalid.validate(agreement: agreement)
        }
    }
}
