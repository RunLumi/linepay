import Foundation
import LinePayDomain

extension AppModel {
    func keepBenefitDraft(_ draft: BenefitAuditDraft) throws {
        guard benefitAuditDraft == nil || benefitAuditDraft?.id == draft.id else {
            throw AppModelError.invalidField("Resume or discard the existing benefits draft first")
        }
        let reviewed = benefitAuditDraft.map { draft.invalidatingReview(comparedTo: $0) } ?? draft
        try commitBenefits(records: benefitAuditRecords, draft: reviewed)
    }

    func discardBenefitDraft(id: UUID) throws {
        guard benefitAuditDraft?.id == id else {
            throw AppModelError.invalidField("The benefits draft changed")
        }
        try commitBenefits(records: benefitAuditRecords, draft: nil)
    }

    @discardableResult
    func saveBenefitCheck(_ draft: BenefitAuditDraft) throws -> UUID {
        guard benefitAuditDraft == nil || benefitAuditDraft == draft else {
            throw AppModelError.invalidField("The benefits draft changed; review the latest values")
        }
        let result = try draft.calculate()
        var records = benefitAuditRecords
        let recordID = draft.recordID ?? draft.id
        let revision = BenefitAuditRevision(
            id: UUID(), input: draft, result: result,
            recordedEpochSeconds: benefitRecordedEpochSeconds)
        if let index = records.firstIndex(where: { $0.id == recordID }) {
            guard draft.recordID == recordID,
                records[index].fundID == draft.fundID,
                records[index].revisions.last?.id == draft.baseRevisionID,
                !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AppModelError.invalidField(
                    "Review the latest revision and explain this correction")
            }
            records[index].revisions.append(revision)
        } else {
            guard draft.recordID == nil, draft.baseRevisionID == nil else {
                throw AppModelError.invalidField("This benefits record is no longer available")
            }
            records.append(
                BenefitAuditRecord(id: recordID, fundID: draft.fundID, revisions: [revision]))
        }
        try commitBenefits(records: records, draft: nil)
        return recordID
    }

    func startAnotherBenefitPeriod(recordID: UUID) throws -> BenefitAuditDraft {
        guard benefitAuditDraft == nil,
            let latest = benefitAuditRecords.first(where: { $0.id == recordID })?.revisions.last
        else {
            throw AppModelError.invalidField("Resume the open draft before starting another check")
        }
        var draft = makeBenefitDraft()
        draft.fundID = latest.input.fundID
        draft.fundName = latest.input.fundName
        draft.kind = latest.input.kind
        draft.currencyCode = latest.input.currencyCode
        draft.statementCurrencyCode = draft.currencyCode
        draft.roundingScale = NumberEntry.amountFractionDigits(currencyCode: draft.currencyCode)
        // Reuse fund identity only. Prior eligibility, rates and statement values are not new facts.
        try keepBenefitDraft(draft)
        return draft
    }

    func deleteBenefitCheck(id: UUID) throws {
        guard benefitAuditDraft?.recordID != id else {
            throw AppModelError.invalidField(
                "Discard the correction draft before deleting this record")
        }
        guard benefitAuditRecords.contains(where: { $0.id == id }) else {
            throw AppModelError.invalidField("Benefits record unavailable")
        }
        try commitBenefits(
            records: benefitAuditRecords.filter { $0.id != id }, draft: benefitAuditDraft)
    }

    func reviseBenefitCheck(id: UUID) throws -> BenefitAuditDraft {
        guard benefitAuditDraft == nil,
            let latest = benefitAuditRecords.first(where: { $0.id == id })?.revisions.last
        else {
            throw AppModelError.invalidField(
                "Resume the draft or open an available benefits record")
        }
        var draft = latest.input
        draft.id = UUID()
        draft.recordID = id
        draft.baseRevisionID = latest.id
        draft.segments = draft.segments.map { line in
            var value = line
            value.id = UUID()
            value.eligibilityConfirmed = false
            return value
        }
        draft.rulesConfirmed = false
        draft.completeEligibilityConfirmed = false
        draft.statementConfirmed = false
        draft.note = ""
        try keepBenefitDraft(draft)
        return draft
    }
}
