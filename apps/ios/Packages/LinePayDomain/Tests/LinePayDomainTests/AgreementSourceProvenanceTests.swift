import Foundation
import Testing

@testable import LinePayDomain

@Suite("Agreement document provenance")
struct AgreementSourceProvenanceTests {
    @Test func oldSourceJSONStillDecodesWithoutDocumentFields() throws {
        let data = Data(
            #"{"title":"Synthetic source","url":"","section":"Rate","ruleKey":"base"}"#.utf8)
        let source = try JSONDecoder().decode(AgreementSource.self, from: data)
        #expect(source.documentID == nil)
        #expect(source.documentSHA256 == nil)
        #expect(source.documentPage == nil)
        #expect(source.quotedText == nil)
        #expect(source.verifiedEpochSeconds == nil)
    }

    @Test func exactLocatorRoundTripsWithoutClaimingVerification() throws {
        let source = AgreementSource(
            title: "Synthetic agreement", url: "", ruleKey: .base,
            documentID: UUID(), documentSHA256: String(repeating: "a", count: 64),
            documentPage: 2, quotedText: "Base hourly rate: USD 50.00 per hour")
        #expect(
            try JSONDecoder().decode(AgreementSource.self, from: JSONEncoder().encode(source))
                == source)
        #expect(source.verifiedEpochSeconds == nil)
    }

    @Test func provenanceDoesNotAlterTheIndependentEightHourWageExpectation() throws {
        let source = AgreementSource(
            title: "Synthetic agreement", url: "", ruleKey: .base,
            documentID: UUID(), documentSHA256: String(repeating: "b", count: 64),
            documentPage: 0, quotedText: "Base hourly rate: USD 50.00 per hour")
        let rules = try AgreementSnapshot(
            id: "synthetic-document-rules", version: "1", displayName: "Synthetic",
            hourlyRate: Money(amount: decimal("50"), currencyCode: "USD"), regularSchedule: [],
            sources: [source])
        let shift = try work((2026, 8, 7, 0, 0), (2026, 8, 7, 8, 0), timeZoneIdentifier: "UTC")
        let result = try PayCalculator().calculate(
            work: [shift], agreement: rules, policy: .highestApplicable)
        #expect(result.expectedWages.amount == decimal("400"))
        #expect(result.expectedAllowances.amount == 0)
    }
}
