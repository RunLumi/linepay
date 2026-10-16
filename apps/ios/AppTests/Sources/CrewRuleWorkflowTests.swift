import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Native crew draft adoption and recovery")
@MainActor
struct CrewRuleWorkflowTests {
    private func packet() throws -> Data {
        let sender = try AgreementSnapshot(
            id: "PRIVATE-SENDER", version: "1", displayName: "PRIVATE NAME",
            hourlyRate: Money(amount: 60, currencyCode: "USD"), regularSchedule: [])
        return try CrewRuleTemplate.sharing(
            sender, templateID: UUID(), revision: "1", title: "SYNTHETIC crew"
        ).encoded()
    }
    private func draft(_ model: AppModel) throws -> PayProfileDraft {
        var result = try CrewRuleDraftBuilder.build(
            data: packet(), hourlyRate: "75", perDiemChoice: .notConfigured, perDiemAmount: "",
            applicabilityConfirmed: true, valuesConfirmed: true, timeZoneIdentifier: "UTC",
            profile: model.profile, activePeriod: model.activePeriod)
        result.periodStartDate = UnitFixture.start
        return result
    }
    @Test func inspectionAndPreparedSetupDoNotActivateRulesOrEraseAnUnfinishedDraft() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let before = store.state
        _ = try CrewRuleTemplate.decode(packet())
        let proposal = try draft(model)
        #expect(store.state == before)
        try model.prepareCrewRuleDraft(proposal)
        #expect(model.calculation?.expectedWages.amount == 400)
        #expect(model.profile == before?.profile && model.crewRuleOrigins.isEmpty)
        let prepared = store.state
        #expect(throws: (any Error).self) { try model.prepareCrewRuleDraft(draft(model)) }
        #expect(store.state == prepared)
    }
    @Test func futureAdoptionPreservesTheCurrentAuditAndOriginalBytesThroughBackup() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store, now: { UnitFixture.start })
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let original = try #require(model.activePeriod)
        let result = model.calculation
        let proposal = try draft(model)
        try model.prepareCrewRuleDraft(proposal)
        try model.saveProfile(proposal, scope: .futurePeriods)
        #expect(model.calculation == result && model.currentPaystub == original.paystub)
        #expect(model.activePeriod?.agreement == original.agreement)
        let origin = try #require(model.crewRuleOrigins.first)
        #expect(origin.adoption.templateData == proposal.crewRuleAdoption?.templateData)
        #expect(origin.agreement.hourlyRate.amount == 75)
        #expect(origin.agreement.version != original.agreement.version)
        #expect(model.profile?.agreement == origin.agreement)
        let state = try #require(store.state)
        let archive = BackupArchive(createdAt: UnitFixture.start, state: state, files: [])
        let restored = try BackupArchive.decode(archive.encoded())
        #expect(restored.state.crewRuleOrigins == state.crewRuleOrigins)
        #expect(restored.state.activePeriod == state.activePeriod)
        try AppStateValidation.validate(restored.state)
        let reloaded = AppModel(store: store)
        #expect(
            reloaded.persistenceIssue == nil && reloaded.crewRuleOrigins == model.crewRuleOrigins)
    }
    @Test func changedTermsCurrentCorrectionAndFailedSaveDoNotPartiallyAdopt() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let proposal = try draft(model)
        try model.prepareCrewRuleDraft(proposal)
        let before = store.state
        #expect(throws: (any Error).self) {
            try model.saveProfile(proposal, scope: .correctCurrentPeriod)
        }
        var changed = proposal
        changed.hourlyRate = "80"
        #expect(throws: (any Error).self) { try model.saveProfile(changed, scope: .futurePeriods) }
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.saveProfile(proposal, scope: .futurePeriods)
        }
        #expect(store.state == before && model.crewRuleOrigins.isEmpty)
        #expect(model.setupDraft == proposal && model.calculation?.expectedWages.amount == 400)
    }
    @Test func oldSchemasGainNoInventedOriginsAndChangedStoredChoicesRefuse() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let original = try #require(store.state)
        for version in 1...7 {
            var raw = try #require(
                JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
            )
            raw["schemaVersion"] = version
            let restored = try JSONDecoder().decode(
                AppPersistentState.self, from: JSONSerialization.data(withJSONObject: raw))
            #expect(restored.crewRuleOrigins == nil)
            #expect(
                restored.profile == original.profile
                    && restored.activePeriod == original.activePeriod)
        }
        let proposal = try draft(model)
        try model.saveProfile(proposal, scope: .futurePeriods)
        var raw = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(store.state)) as? [String: Any])
        var origins = try #require(raw["crewRuleOrigins"] as? [[String: Any]])
        var adoption = try #require(origins[0]["adoption"] as? [String: Any])
        adoption["hourlyRate"] = ["amount": 80, "currencyCode": "USD"]
        origins[0]["adoption"] = adoption
        raw["crewRuleOrigins"] = origins
        let invalid = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(throws: (any Error).self) { try AppStateValidation.validate(invalid) }
    }

    @Test func explicitZeroAllowanceStaysConfiguredAndRoundingMismatchRefuses() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        let sender = try AgreementSnapshot(
            id: "SYNTHETIC-SENDER", version: "1", displayName: "Synthetic sender",
            hourlyRate: Money(amount: 60, currencyCode: "USD"), regularSchedule: [],
            flatPerDiem: FlatPerDiemRule(amountPerWorkDate: Money(amount: 140, currencyCode: "USD"))
        )
        let data = try CrewRuleTemplate.sharing(
            sender, templateID: UUID(), revision: "1", title: "SYNTHETIC allowance"
        ).encoded()
        var proposal = try CrewRuleDraftBuilder.build(
            data: data, hourlyRate: "75", perDiemChoice: .confirmedAmount, perDiemAmount: "0",
            applicabilityConfirmed: true, valuesConfirmed: true, timeZoneIdentifier: "UTC",
            profile: nil, activePeriod: nil)
        proposal.periodStartDate = UnitFixture.start
        try model.saveProfile(proposal)
        #expect(model.profile?.agreement.flatPerDiem?.amountPerWorkDate.amount == 0)
        #expect(model.crewRuleOrigins.first?.adoption.perDiemChoice == .confirmedAmount)
        let different = try AgreementSnapshot(
            id: "SYNTHETIC-ROUNDING", version: "1", displayName: "Synthetic rounding",
            hourlyRate: Money(amount: 60, currencyCode: "USD"), regularSchedule: [],
            rounding: MoneyRoundingRule(scale: 2, mode: .bankers))
        let incompatible = try CrewRuleTemplate.sharing(
            different, templateID: UUID(), revision: "1", title: "SYNTHETIC rounding"
        ).encoded()
        let before = store.state
        #expect(throws: (any Error).self) {
            try CrewRuleDraftBuilder.build(
                data: incompatible, hourlyRate: "75", perDiemChoice: .notConfigured,
                perDiemAmount: "", applicabilityConfirmed: true, valuesConfirmed: true,
                timeZoneIdentifier: "UTC", profile: model.profile, activePeriod: model.activePeriod)
        }
        #expect(store.state == before)
        let newModel = AppModel(store: UnitStateStore())
        var bankers = try CrewRuleDraftBuilder.build(
            data: incompatible, hourlyRate: "75", perDiemChoice: .notConfigured,
            perDiemAmount: "", applicabilityConfirmed: true, valuesConfirmed: true,
            timeZoneIdentifier: "UTC", profile: nil, activePeriod: nil)
        bankers.periodStartDate = UnitFixture.start
        try newModel.saveProfile(bankers)
        var later = PayProfileDraft(
            profile: try #require(newModel.profile), activePeriod: newModel.activePeriod)
        later.hourlyRate = "80"
        try newModel.saveProfile(later, scope: .futurePeriods)
        #expect(newModel.profile?.agreement.rounding.mode == .bankers)
    }

    @Test func samePublicIdentityCannotHideDifferentRetainedContents() throws {
        let model = AppModel(store: UnitStateStore())
        var proposal = try draft(model)
        try model.saveProfile(proposal)
        let original = try #require(proposal.crewRuleAdoption)
        var raw = try #require(
            JSONSerialization.jsonObject(with: original.templateData) as? [String: Any])
        raw["title"] = "Different SYNTHETIC contents"
        let changed = try CrewRuleAdoption(
            templateData: JSONSerialization.data(withJSONObject: raw),
            hourlyRate: original.hourlyRate,
            perDiemChoice: original.perDiemChoice, applicabilityConfirmed: true,
            valuesConfirmed: true)
        proposal.crewRuleAdoption = changed
        #expect(throws: (any Error).self) { try model.prepareCrewRuleDraft(proposal) }
        #expect(model.setupDraft == nil && model.crewRuleOrigins.count == 1)
        #expect(model.crewRuleOrigins.first?.adoption == original)
    }
}
