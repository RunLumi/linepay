import Foundation
import Testing

@testable import LinePayDomain

@Suite("Portable worker-provided rule drafts")
struct CrewRuleTemplateTests {
    private struct Corpus: Decodable {
        let format: String
        let version: Int
        let cases: [Fixture]
    }
    private struct Fixture: Decodable {
        let id: String
        let packet: Packet
        let recipient: Recipient
        let expected: Expected
    }
    private struct Packet: Decodable { let templateID: UUID }
    private struct Recipient: Decodable {
        let profileID: UUID
        let hourlyRate: String
        let perDiemDecision: CrewRuleTemplate.PerDiemChoice
        let perDiemAmount: String?
    }
    private struct Expected: Decodable {
        let hourlyRateRequired: Bool
        let allowanceReviewRequired: Bool
        let dailyTierCount: Int
        let weekdayPremiumCount: Int
    }
    private func fixtureData() throws -> (Corpus, [[String: Any]]) {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let data = try Data(
            contentsOf: root.appendingPathComponent(
                "shared/contracts/templates/rule-drafts-v1.json"))
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return (corpus, try #require(json["cases"] as? [[String: Any]]))
    }
    @Test func everySharedDraftPreservesRulesAndRequiresRecipientValues() throws {
        let (corpus, objects) = try fixtureData()
        try #require(
            corpus.format == "com.streamentry.linepay.rule-template-fixtures" && corpus.version == 1
                && corpus.cases.count == 5)
        for (fixture, object) in zip(corpus.cases, objects) {
            let data = try JSONSerialization.data(withJSONObject: #require(object["packet"]))
            let draft = try CrewRuleTemplate.decode(data)
            #expect(draft.templateID == fixture.packet.templateID)
            #expect((draft.rules.hourlyRate == nil) == fixture.expected.hourlyRateRequired)
            #expect(draft.rules.perDiem.configured == fixture.expected.allowanceReviewRequired)
            let roundTrip = try CrewRuleTemplate.decode(draft.encoded())
            #expect(roundTrip == draft)
            let rate = Money(
                amount: try StrictDecimal.parse(fixture.recipient.hourlyRate, fractionDigits: 8),
                currencyCode: draft.rules.currency)
            let allowance = try fixture.recipient.perDiemAmount.map {
                Money(
                    amount: try StrictDecimal.parse($0, fractionDigits: 8),
                    currencyCode: draft.rules.currency)
            }
            let proposed = try draft.proposeAgreement(
                newAgreementID: fixture.recipient.profileID, hourlyRate: rate,
                perDiemChoice: fixture.recipient.perDiemDecision, perDiemAmount: allowance,
                applicabilityConfirmed: true, valuesConfirmed: true)
            #expect(proposed.id == fixture.recipient.profileID.uuidString.lowercased())
            #expect(proposed.hourlyRate == rate)
            #expect(proposed.flatPerDiem?.amountPerWorkDate == allowance)
            #expect(proposed.dailyOvertimeTiers.count == fixture.expected.dailyTierCount)
            #expect(proposed.weekdayPremiums.count == fixture.expected.weekdayPremiumCount)
            #expect(proposed.sources.isEmpty && proposed.confirmedEpochSeconds == nil)
            #expect(throws: CrewRuleTemplateError.confirmationRequired) {
                try draft.proposeAgreement(
                    newAgreementID: fixture.recipient.profileID, hourlyRate: rate,
                    perDiemChoice: fixture.recipient.perDiemDecision, applicabilityConfirmed: false,
                    valuesConfirmed: true)
            }
            #expect(throws: CrewRuleTemplateError.missingRate) {
                try draft.proposeAgreement(
                    newAgreementID: fixture.recipient.profileID, hourlyRate: nil,
                    perDiemChoice: fixture.recipient.perDiemDecision, applicabilityConfirmed: true,
                    valuesConfirmed: true)
            }
        }
    }
    @Test func exportOmitsAmountsAndPrivateAgreementIdentityByDefault() throws {
        let agreement = try AgreementSnapshot(
            id: "PRIVATE-SYNTHETIC-ID", version: "PRIVATE-VERSION",
            displayName: "PRIVATE SYNTHETIC NAME",
            hourlyRate: Money(amount: decimal("58.40"), currencyCode: "USD"), regularSchedule: [],
            dailyOvertimeTiers: [DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5"))],
            flatPerDiem: FlatPerDiemRule(amountPerWorkDate: Money(amount: 140, currencyCode: "USD"))
        )
        let id = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000001"))
        let draft = try CrewRuleTemplate.sharing(
            agreement, templateID: id, revision: "1", title: "SYNTHETIC selected rules")
        let encoded = try draft.encoded()
        let text = try #require(String(data: encoded, encoding: .utf8))
        #expect(
            draft.rules.hourlyRate == nil && draft.rules.perDiem.configured
                && draft.rules.perDiem.amount == nil)
        #expect(!text.contains("58.4") && !text.contains("140") && !text.contains("PRIVATE"))
        #expect(try CrewRuleTemplate.decode(encoded) == draft)
        let included = try CrewRuleTemplate.sharing(
            agreement, templateID: id, revision: "2", title: "SYNTHETIC explicit amounts",
            includeAmounts: true)
        #expect(included.rules.hourlyRate == "58.4" && included.rules.perDiem.amount == "140")
    }
    @Test func unknownFieldsNumericMoneyAndFractionalSecondThresholdsAreRefused() throws {
        let (_, objects) = try fixtureData()
        let original = try #require(objects.first?["packet"] as? [String: Any])
        let utf8 = try JSONSerialization.data(withJSONObject: original)
        let utf16 = try #require(
            String(data: utf8, encoding: .utf8)?.data(using: .utf16LittleEndian))
        #expect(throws: CrewRuleTemplateError.invalidFormat) { try CrewRuleTemplate.decode(utf16) }
        let originalText = try #require(String(data: utf8, encoding: .utf8))
        let duplicated = originalText.replacingOccurrences(
            of: "\"hourlyRate\":null", with: "\"hourlyRate\":null,\"hourly\\u0052ate\":\"99\"")
        #expect(duplicated != originalText)
        #expect(throws: CrewRuleTemplateError.invalidFormat) {
            try CrewRuleTemplate.decode(Data(duplicated.utf8))
        }
        var stacked = original
        stacked["premiumCombination"] = "multiply"
        #expect(throws: CrewRuleTemplateError.invalidFormat) {
            try CrewRuleTemplate.decode(JSONSerialization.data(withJSONObject: stacked))
        }
        var unknown = original
        unknown["workRecords"] = []
        #expect(throws: CrewRuleTemplateError.invalidFormat) {
            try CrewRuleTemplate.decode(JSONSerialization.data(withJSONObject: unknown))
        }
        var numeric = original
        var rules = try #require(original["rules"] as? [String: Any])
        rules["hourlyRate"] = 50
        numeric["rules"] = rules
        #expect(throws: (any Error).self) {
            try CrewRuleTemplate.decode(JSONSerialization.data(withJSONObject: numeric))
        }
        var fractional = original
        rules["hourlyRate"] = NSNull()
        rules["dailyOvertimeTiers"] = [["afterHours": "0.00001", "multiplier": "1.5"]]
        fractional["rules"] = rules
        #expect(throws: CrewRuleTemplateError.invalidFormat) {
            try CrewRuleTemplate.decode(JSONSerialization.data(withJSONObject: fractional))
        }
        #expect(throws: CrewRuleTemplateError.invalidFormat) {
            try CrewRuleTemplate.decode(Data(repeating: 0, count: 65_537))
        }
    }
}
