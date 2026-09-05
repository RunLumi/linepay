import Foundation
import Testing

@testable import LinePay

@Suite("Former payroll gaps are required regressions")
@MainActor
struct KnownProductGapTests {
    @Test func prospectiveRateChangeMustNotRepriceEarlierWork() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var draft = UnitFixture.profile(rate: "60")
        draft.useEffectiveStart = true
        draft.effectiveStartDate = UnitFixture.start.addingTimeInterval(86_400)
        try model.saveProfile(draft)
        #expect(model.calculation?.total.amount == 400)
    }

    @Test func offsettingComponentsMustNotImplyFullMatch() throws {
        let model = AppModel()
        try UnitFixture.populate(model)
        var stub = UnitFixture.paystub(model)
        stub.regularPay = "350"
        stub.overtimePay = "50"
        stub.reviewedFields.formUnion([.regularPay, .overtimePay])
        stub.lineLayout = .fullRateBuckets
        try model.confirmPaystub(stub)
        #expect(model.currentAuditStatus == .needsReview)
    }
}
