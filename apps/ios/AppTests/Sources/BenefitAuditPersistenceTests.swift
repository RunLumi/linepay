import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Local benefits evidence and immutable corrections")
@MainActor
struct BenefitAuditPersistenceTests {
    @Test func draftPreviewAndSaveDoNotChangeWagesOrConsumeAuditAccess() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store, now: { UnitFixture.start })
        try UnitFixture.populate(model)
        let wages = model.calculation
        let draft = filled(model)
        try model.keepBenefitDraft(draft)
        #expect(try draft.calculate().expectedEmployerContribution.amount == 350)
        #expect(model.benefitAuditRecords.isEmpty)
        let id = try model.saveBenefitCheck(draft)
        #expect(id == draft.id)
        #expect(model.benefitAuditDraft == nil)
        #expect(model.benefitAuditRecords.first?.revisions.first?.result.status == .notVerified)
        #expect(model.calculation == wages && !model.hasUsedFreeAudit)
        let reloaded = AppModel(store: store)
        #expect(reloaded.benefitAuditRecords == model.benefitAuditRecords)
    }

    @Test func laterStatementAppendsARevisionWithoutRewritingTheMissingStatement() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        let id = try model.saveBenefitCheck(filled(model))
        let first = try #require(model.benefitAuditRecords.first?.revisions.first)
        var correction = try model.reviseBenefitCheck(id: id)
        #expect(!correction.rulesConfirmed && !correction.completeEligibilityConfirmed)
        #expect(correction.segments.allSatisfy { !$0.eligibilityConfirmed })
        #expect(throws: (any Error).self) { try model.saveBenefitCheck(correction) }
        confirm(&correction)
        correction.hasStatement = true
        correction.statementMatchesFund = true
        correction.statementAmount = "310.63"
        correction.statementQuantity = "35.5"
        correction.statementConfirmed = true
        correction.note = "Synthetic statement arrived"
        try model.keepBenefitDraft(correction)
        correction = try #require(model.benefitAuditDraft)
        correction.statementConfirmed = true
        try model.keepBenefitDraft(correction)
        try model.saveBenefitCheck(correction)
        let record = try #require(model.benefitAuditRecords.first)
        #expect(record.revisions.count == 2 && record.revisions.first == first)
        #expect(
            record.revisions.last?.result.contributionDifference?.amount == Decimal(string: "39.37")
        )
        #expect(record.revisions.last?.result.quantityDifference == Decimal(string: "4.5"))
        #expect(first.result.statement == nil && first.result.contributionDifference == nil)
        #expect(model.calculation?.expectedWages.amount == 400)
    }

    @Test func failedWriteKeepsTheDraftAndAllEarlierData() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let draft = filled(model)
        try model.keepBenefitDraft(draft)
        let before = store.state
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) { try model.saveBenefitCheck(draft) }
        #expect(store.state == before && model.benefitAuditRecords.isEmpty)
        #expect(model.benefitAuditDraft == draft)
        #expect(model.calculation?.expectedWages.amount == 400)
    }

    @Test func aStalePreviewOrAnUnrelatedDraftCannotReplaceNewerInput() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        let original = filled(model)
        try model.keepBenefitDraft(original)
        var updated = original
        updated.segments[0].quantity = "41"
        try model.keepBenefitDraft(updated)
        #expect(throws: (any Error).self) { try model.saveBenefitCheck(original) }
        #expect(throws: (any Error).self) { try model.keepBenefitDraft(filled(model)) }
        #expect(
            model.benefitAuditDraft?.segments[0].quantity == "41"
                && model.benefitAuditRecords.isEmpty)
        #expect(model.benefitAuditDraft?.rulesConfirmed == false)
        #expect(model.benefitAuditDraft?.segments[0].eligibilityConfirmed == false)
        try model.discardBenefitDraft(id: updated.id)
        #expect(model.benefitAuditDraft == nil)
    }

    @Test func numericEntryContextAndRawObservationsSurviveBackup() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.decimalSeparator = ","
        draft.segments[0].rate = "8,75"
        draft.hasStatement = true
        draft.statementMatchesFund = true
        draft.statementAmount = "310,63"
        draft.statementQuantity = "35,5"
        draft.statementConfirmed = true
        try model.saveBenefitCheck(draft)
        let state = try #require(store.state)
        let archive = BackupArchive(createdAt: UnitFixture.start, state: state, files: [])
        let restored = try BackupArchive.decode(archive.encoded()).state
        #expect(restored.benefitAudits == state.benefitAudits)
        let input = try #require(restored.benefitAudits?.first?.revisions.first?.input)
        #expect(input.decimalSeparator == "," && input.statementAmount == "310,63")
        #expect(try input.calculate().contributionDifference?.amount == Decimal(string: "39.37"))
        #expect(restored.activePeriod == state.activePeriod)
    }

    @Test func referencedAgreementImportsStayProtectedByBenefitsHistory() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let id = try model.retainAgreement(
            data: Data("%PDF SYNTHETIC".utf8), filename: "synthetic.pdf")
        let document = try #require(model.agreementDocument(id: id))
        var draft = filled(model)
        draft.segments[0].sources = [
            AgreementSource(
                title: "Synthetic pension clause", url: "",
                documentID: id, documentSHA256: document.sha256, documentPage: 0,
                quotedText: "Employer pension contribution: USD 8.75 per eligible hour")
        ]
        try model.keepBenefitDraft(draft)
        #expect(!model.canDeleteAgreementImport(id: id))
        let recordID = try model.saveBenefitCheck(draft)
        #expect(!model.canDeleteAgreementImport(id: id))
        try model.deleteBenefitCheck(id: recordID)
        #expect(model.canDeleteAgreementImport(id: id))
    }

    @Test func schemaSixMigrationPreservesOldResultsAndDoesNotInventBenefits() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.archiveCurrentPeriod()
        let old = try #require(store.state)
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json["schemaVersion"] = 6
        json.removeValue(forKey: "benefitAudits")
        json.removeValue(forKey: "benefitAuditDraft")
        let restored = try JSONDecoder().decode(
            AppPersistentState.self,
            from: JSONSerialization.data(withJSONObject: json))
        try AppStateValidation.validate(restored)
        #expect(restored.schemaVersion == AppPersistentState.currentSchemaVersion)
        #expect(restored.history == old.history && restored.activePeriod == old.activePeriod)
        #expect(restored.benefitAudits == nil && restored.benefitAuditDraft == nil)
    }

    private func filled(_ model: AppModel) -> BenefitAuditDraft {
        var draft = model.makeBenefitDraft()
        draft.fundName = "Synthetic pension fund"
        draft.decimalSeparator = "."
        draft.segments[0].rate = "8.75"
        draft.segments[0].quantity = "40"
        confirm(&draft)
        return draft
    }

    private func confirm(_ draft: inout BenefitAuditDraft) {
        draft.rulesConfirmed = true
        draft.completeEligibilityConfirmed = true
        for index in draft.segments.indices { draft.segments[index].eligibilityConfirmed = true }
    }
}
