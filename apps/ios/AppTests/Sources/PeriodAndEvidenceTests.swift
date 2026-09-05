import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Pay periods and source preservation")
@MainActor
struct PeriodAndEvidenceTests {
    @Test(arguments: [PayPeriodCadence.weekly, .biweekly, .manual])
    func periodCadencesAndArchive(_ cadence: PayPeriodCadence) throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try model.saveProfile(UnitFixture.profile(cadence: cadence))
        let first = try #require(model.activePeriod)
        let days = cadence == .weekly ? 7 : cadence == .biweekly ? 14 : 3
        #expect(
            first.window.endEpochSeconds - first.window.startEpochSeconds == Int64(days * 86_400))
        #expect(first.window.displayEndDate.addingTimeInterval(1) == first.window.endDate)
        #expect(first.window.contains(start: first.window.startDate, end: first.window.endDate))
        #expect(
            !first.window.contains(
                start: first.window.startDate.addingTimeInterval(-1), end: first.window.endDate))
        #expect(
            !first.window.contains(
                start: first.window.startDate, end: first.window.endDate.addingTimeInterval(1)))
        #expect(throws: AppModelError.activePayPeriodAlreadyExists) {
            try model.startNewPayPeriod(startDate: UnitFixture.start)
        }
        try model.archiveCurrentPeriod()
        #expect(model.history.first?.id == first.id)
        if cadence == .manual {
            #expect(model.activePeriod == nil)
            try model.startNewPayPeriod(
                startDate: first.window.endDate,
                manualEndDate: first.window.endDate)
            #expect(
                model.activePeriod?.window.endEpochSeconds == first.window.endEpochSeconds + 86_400)
        } else {
            #expect(model.activePeriod?.window.startEpochSeconds == first.window.endEpochSeconds)
            #expect(model.activePeriod?.id != first.id)
        }
        try model.deleteHistoryPeriod(id: first.id)
        #expect(model.history.isEmpty)
        #expect(model.activePeriod != nil)
    }

    @Test(arguments: [(2026, 3, 7, 167), (2026, 10, 31, 169)])
    func weeklyWindowUsesCalendarDaysAcrossDST(_ year: Int, _ month: Int, _ day: Int, _ hours: Int)
        throws
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var draft = UnitFixture.profile()
        draft.timeZoneIdentifier = calendar.timeZone.identifier
        draft.periodStartDate = try #require(
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        let model = AppModel()
        try model.saveProfile(draft)
        let period = try #require(model.activePeriod)
        #expect(
            period.window.endEpochSeconds - period.window.startEpochSeconds == Int64(hours * 3_600))
        #expect(calendar.component(.hour, from: period.window.startDate) == 0)
        #expect(calendar.component(.hour, from: period.window.endDate) == 0)
    }

    @Test func invalidManualPeriodLeavesProfileUnset() {
        let model = AppModel()
        var draft = UnitFixture.profile(cadence: .manual)
        draft.manualPeriodEndDate = UnitFixture.start.addingTimeInterval(-86_400)
        #expect(throws: AppModelError.invalidPayPeriod) { try model.saveProfile(draft) }
        #expect(model.profile == nil)
        #expect(throws: AppModelError.missingPayProfile) {
            try model.startNewPayPeriod(startDate: UnitFixture.start)
        }
    }

    @Test func manualCorrectionPreservesOriginalAndFailedReplacementRollsBack() throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originals = LocalEvidenceStore(baseDirectory: directory)
        let store = UnitStateStore()
        let model = AppModel(store: store, evidenceStore: originals)
        try UnitFixture.populate(model, evidence: true)
        let prior = try #require(model.currentPaystub?.evidence)
        let priorURL = try #require(originals.url(for: prior))
        let bytes = try Data(contentsOf: priorURL)
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "399"))
        #expect(model.currentPaystub?.evidence == prior)
        #expect(try Data(contentsOf: priorURL) == bytes)

        var invalid = UnitFixture.paystub(model, original: Data("REPLACEMENT".utf8))
        invalid.regularPay = "not a number"
        #expect(throws: (any Error).self) { try model.confirmPaystub(invalid) }
        #expect(model.currentPaystub?.evidence == prior)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)

        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.confirmPaystub(UnitFixture.paystub(model, original: Data("REPLACEMENT".utf8)))
        }
        #expect(model.currentPaystub?.evidence == prior)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)
        store.failSave = false
        try model.confirmPaystub(UnitFixture.paystub(model, original: Data("REPLACEMENT".utf8)))
        #expect(originals.url(for: prior) == nil)
        #expect(model.currentPaystub?.evidence?.id != prior.id)
        let newURL = try #require(model.currentPaystub?.evidence.flatMap { originals.url(for: $0) })
        #expect(try Data(contentsOf: newURL) == Data("REPLACEMENT".utf8))
    }

    @Test func removingOriginalPreservesConfirmedFactsAndHistory() throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originals = LocalEvidenceStore(baseDirectory: directory)
        let model = AppModel(evidenceStore: originals)
        try UnitFixture.populate(model, evidence: true)
        let original = try #require(model.currentPaystub?.evidence)
        try model.archiveCurrentPeriod()
        let period = try #require(model.history.first)
        try model.removeHistoricalPaystubEvidence(periodID: period.id)
        #expect(model.history.first?.calculation == period.calculation)
        #expect(model.history.first?.paystub?.grossPay == period.paystub?.grossPay)
        #expect(model.history.first?.paystub?.id == period.paystub?.id)
        #expect(
            model.history.first?.paystub?.evidence == nil && originals.url(for: original) == nil)
    }

    @Test func failedHistoryDeleteRetainsOriginal() throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originals = LocalEvidenceStore(baseDirectory: directory)
        let store = UnitStateStore()
        let model = AppModel(store: store, evidenceStore: originals)
        try UnitFixture.populate(model, evidence: true)
        try model.archiveCurrentPeriod()
        let period = try #require(model.history.first)
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.deleteHistoryPeriod(id: period.id)
        }
        #expect(model.history.first == period)
        #expect(originals.url(for: try #require(period.paystub?.evidence)) != nil)
    }
}
