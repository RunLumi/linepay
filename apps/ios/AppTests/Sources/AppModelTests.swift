import Foundation
import LinePayDomain
import Testing
@testable import LinePay

@Suite("AppModel orchestration")
@MainActor
struct AppModelTests {
    @Test("First-run profile does not invent optional pay rules")
    func profileDefaultsDoNotInventRules() throws {
        let model = AppModel()
        var draft = PayProfileDraft()
        draft.name = "Test agreement"
        draft.hourlyRate = "50"
        draft.timeZoneIdentifier = "America/Los_Angeles"

        try model.saveProfile(draft)

        let profile = try #require(model.profile)
        #expect(profile.agreement.version == "1")
        #expect(profile.agreement.hourlyRate.amount == Decimal(50))
        #expect(profile.agreement.dailyOvertimeTiers.isEmpty)
        #expect(profile.agreement.weekdayPremiums.isEmpty)
        #expect(profile.agreement.calloutMinimum == nil)
        #expect(profile.agreement.flatPerDiem == nil)
    }

    @Test("Editing a profile creates a new agreement version while preserving identity")
    func profileEditsVersionAgreementSnapshot() throws {
        let model = AppModel()
        var draft = makeDraft(rate: "50")

        try model.saveProfile(draft)
        let original = try #require(model.profile)

        draft.hourlyRate = "55"
        try model.saveProfile(draft)
        let updated = try #require(model.profile)

        #expect(updated.id == original.id)
        #expect(updated.agreement.id == original.agreement.id)
        #expect(updated.agreement.version == "2")
        #expect(updated.agreement.hourlyRate.amount == Decimal(55))
    }

    @Test("Adding, editing, and deleting work recalculates expected pay")
    func workMutationsRecalculate() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50"))

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let eightHoursLater = start.addingTimeInterval(8 * 60 * 60)
        try model.addWork(start: start, end: eightHoursLater, kind: .regular)

        let interval = try #require(model.workIntervals.first)
        #expect(model.totalHours == Decimal(8))
        #expect(model.calculation?.total.amount == Decimal(400))

        let tenHoursLater = start.addingTimeInterval(10 * 60 * 60)
        try model.updateWork(
            id: interval.id,
            start: start,
            end: tenHoursLater,
            kind: .regular
        )

        #expect(model.totalHours == Decimal(10))
        #expect(model.calculation?.total.amount == Decimal(500))

        model.deleteWork(id: interval.id)
        #expect(model.workIntervals.isEmpty)
        #expect(model.totalHours == 0)
        #expect(model.calculation?.total.amount == 0)
    }

    @Test("Rejected overlapping work does not mutate existing state")
    func overlapFailureIsAtomic() throws {
        let model = AppModel()
        try model.saveProfile(makeDraft(rate: "50"))

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(8 * 60 * 60)
        try model.addWork(start: start, end: end, kind: .regular)
        let original = model.workIntervals

        let overlapStart = start.addingTimeInterval(4 * 60 * 60)
        let overlapEnd = end.addingTimeInterval(2 * 60 * 60)

        var didThrow = false
        do {
            try model.addWork(start: overlapStart, end: overlapEnd, kind: .regular)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        #expect(model.workIntervals == original)
        #expect(model.calculation?.total.amount == Decimal(400))
    }

    private func makeDraft(rate: String) -> PayProfileDraft {
        var draft = PayProfileDraft()
        draft.name = "Test agreement"
        draft.hourlyRate = rate
        draft.timeZoneIdentifier = "America/Los_Angeles"
        return draft
    }
}
