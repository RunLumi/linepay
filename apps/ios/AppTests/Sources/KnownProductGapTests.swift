import Foundation
import Testing

@testable import LinePay

@Suite("Explicit outstanding payroll product gaps")
@MainActor
struct KnownProductGapTests {
    @Test func prospectiveRateChangeMustNotRepriceEarlierWork() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "60")
        draft.useEffectiveStart = true
        draft.effectiveStartDate = UnitFixture.start.addingTimeInterval(86_400)
        try model.saveProfile(draft)
        withKnownIssue(
            "RULE-SCOPE: profile editing replaces the active agreement; effective-dated work allocation is not implemented. See docs/testing.md."
        ) {
            #expect(model.calculation?.total.amount == 400)
        }
    }

    @Test func offsettingComponentsMustNotImplyFullMatch() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.regularPay = "350"
        stub.overtimePay = "50"
        try model.confirmPaystub(stub)
        withKnownIssue(
            "AUDIT-SCOPE: header compares gross only even when confirmed components differ. See docs/testing.md."
        ) {
            #expect(model.currentAuditStatus != .matches)
        }
    }
}
