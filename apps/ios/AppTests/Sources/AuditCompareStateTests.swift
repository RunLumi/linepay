import Foundation
import LinePayDomain
import Testing

@testable import LinePay

/// v3 compare-state semantics (docs/plan/v3.md section 5). Fixture: one 8 h shift at $50.00/h
/// is $400.00 expected wages, derived by hand rather than from the code under test.
@Suite("Compare states never read as an unqualified correct", .serialized)
@MainActor
struct AuditCompareStateTests {
    @Test func resultVocabularyFollowsTheV3Table() {
        #expect(AuditDisplayStatus.matches.title == "No difference within compared items")
        #expect(
            AuditDisplayStatus.grossMatches.title
                == "No difference within compared items: gross total only")
        #expect(AuditDisplayStatus.possibleShortfall.title.hasPrefix("Possible difference"))
        #expect(AuditDisplayStatus.possibleOverpayment.title.hasPrefix("Possible difference"))
        #expect(AuditDisplayStatus.notComparable.title == "Unable to verify")
        #expect(AuditDisplayStatus.needsReview.title == "Needs review")
        #expect(AuditDisplayStatus.notAudited.title == "Not compared yet")
        let all: [AuditDisplayStatus] = [
            .notAudited, .matches, .grossMatches, .notComparable, .possibleShortfall,
            .possibleOverpayment, .needsReview,
        ]
        for status in all {
            let title = status.title.lowercased()
            for claim in ["correct", "verified", "shortfall", "underpaid", "wage theft"] {
                #expect(!title.contains(claim), "\(status.title) must not claim \(claim)")
            }
        }
    }

    @Test func incompleteWorkIsUnableToVerifyEvenWhenGrossIsEqual() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model, gross: "400")
        stub.workComplete = false
        try model.confirmPaystub(stub)
        #expect(model.currentPaystub?.assessment?.expectedGross == nil)
        #expect(model.currentAuditStatus == .notComparable)
        #expect(!model.hasUsedFreeAudit)
    }

    @Test func unmodeledRuleKeepsEqualGrossInReview() throws {
        let model = AppModel()
        var profile = UnitFixture.profile()
        profile.unsupportedRuleNotes = "Overtime rule not confirmed"
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(8 * 3_600),
            kind: .regular)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "400"))
        #expect(model.currentPaystub?.assessment?.expectedGross?.amount == 400)
        #expect(model.currentPaystub?.assessment?.difference?.amount == 0)
        #expect(model.currentAuditStatus == .needsReview)
    }

    @Test func weeklyOvertimeThatIsNotMappedKeepsEqualGrossInReview() throws {
        let model = AppModel()
        var profile = UnitFixture.profile()
        profile.useWeeklyOvertime = true
        profile.weeklyApplicabilityConfirmed = true
        try model.saveProfile(profile)
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(8 * 3_600),
            kind: .regular)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "400"))
        #expect(model.currentAuditStatus == .needsReview)
    }

    @Test func unconfirmedPaystubDetailKeepsEqualGrossInReview() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model, gross: "400")
        stub.hasAdditionalUnmappedPay = true
        try model.confirmPaystub(stub)
        #expect(model.currentAuditStatus == .needsReview)
    }

    @Test func mismatchedPaystubPeriodComparesNothingAndKeepsTheFreeAudit() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model, gross: "400")
        stub.payPeriodStartDate = stub.payPeriodStartDate?.addingTimeInterval(7 * 86_400)
        stub.payPeriodEndDate = stub.payPeriodEndDate?.addingTimeInterval(7 * 86_400)
        #expect(throws: AppModelError.paystubPeriodMismatch) {
            try model.confirmPaystub(stub)
        }
        #expect(model.currentPaystub == nil && !model.hasUsedFreeAudit)
        #expect(
            AppModelError.paystubPeriodMismatch.errorDescription?.contains("nothing was compared")
                == true)
    }

    @Test(arguments: [
        ("350", Decimal(50)), ("450", Decimal(-50)), ("399.99", Decimal(string: "0.01")!),
    ])
    func differencesAreExactAndPossibleOnly(gross: String, expectedDifference: Decimal) throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: gross))
        let assessment = try #require(model.currentPaystub?.assessment)
        #expect(assessment.expectedGross?.amount == 400)
        #expect(assessment.difference?.amount == expectedDifference)
        let status = model.currentAuditStatus
        #expect(status.title.hasPrefix("Possible difference"))
        #expect(status == (expectedDifference > 0 ? .possibleShortfall : .possibleOverpayment))
    }
}
