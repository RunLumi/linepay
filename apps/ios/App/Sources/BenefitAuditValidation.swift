import Foundation
import LinePayDomain

enum BenefitAuditValidation {
    static func validate(records: [BenefitAuditRecord], draft: BenefitAuditDraft?) throws {
        guard records.count <= 2_000, Set(records.map(\.id)).count == records.count,
            records.reduce(0, { $0 + $1.revisions.count }) <= 10_000
        else { throw LocalStateStoreError.invalidState }
        var revisionIDs = Set<UUID>()
        var snapshots: [UUID: BenefitRuleSnapshot] = [:]
        for record in records {
            guard !record.revisions.isEmpty, record.revisions.count <= 100 else {
                throw LocalStateStoreError.invalidState
            }
            var previous: UUID?
            for revision in record.revisions {
                try validateDraft(revision.input)
                guard revisionIDs.insert(revision.id).inserted,
                    revision.input.fundID == record.fundID,
                    revision.result.fundID == record.fundID,
                    revision.input.baseRevisionID == previous,
                    previous != nil || revision.input.id == record.id,
                    previous == nil
                        ? revision.input.recordID == nil : revision.input.recordID == record.id,
                    (-62_135_596_800...253_402_300_799).contains(revision.recordedEpochSeconds)
                else { throw LocalStateStoreError.invalidState }
                // Replay only this known version. Future arithmetic versions need a deliberate
                // migration policy; never silently replace the saved result while validating.
                guard revision.result.engineVersion == BenefitContributionCalculator.version,
                    try revision.input.calculate() == revision.result
                else { throw LocalStateStoreError.invalidState }
                for line in revision.result.segments {
                    if let old = snapshots[line.rule.id], old != line.rule {
                        throw LocalStateStoreError.invalidState
                    }
                    snapshots[line.rule.id] = line.rule
                }
                previous = revision.id
            }
        }
        if let draft {
            try validateDraft(draft)
            if let recordID = draft.recordID {
                guard let record = records.first(where: { $0.id == recordID }),
                    record.fundID == draft.fundID,
                    record.revisions.last?.id == draft.baseRevisionID
                else { throw LocalStateStoreError.invalidState }
            } else if draft.baseRevisionID != nil {
                throw LocalStateStoreError.invalidState
            }
        }
    }

    private static func validateDraft(_ draft: BenefitAuditDraft) throws {
        guard draft.fundName.count <= 256, draft.note.count <= 4_000,
            PayProfileDraft.supportedCurrencyCodes.contains(draft.currencyCode),
            PayProfileDraft.supportedCurrencyCodes.contains(draft.statementCurrencyCode),
            TimeZone(identifier: draft.timeZoneIdentifier) != nil,
            TimeZone(identifier: draft.statementTimeZoneIdentifier) != nil,
            [".", ","].contains(draft.decimalSeparator), (0...8).contains(draft.roundingScale),
            !draft.segments.isEmpty, draft.segments.count <= 64,
            Set(draft.segments.map(\.id)).count == draft.segments.count,
            draft.statementAmount.count <= 100, draft.statementQuantity.count <= 100,
            draft.otherStatementFundID != draft.fundID
        else { throw LocalStateStoreError.invalidState }
        if let digest = draft.statementSHA256, !AgreementImportValidation.isDigest(digest) {
            throw LocalStateStoreError.invalidState
        }
        if let evidence = draft.statementEvidence {
            guard draft.statementSHA256 != nil, evidence.mediaType == "application/pdf" else {
                throw LocalStateStoreError.invalidState
            }
        }
        let dates =
            [draft.start, draft.end, draft.statementStart, draft.statementEnd]
            + draft.segments.flatMap { [$0.start, $0.end, $0.effectiveStart, $0.effectiveEnd] }
        for date in dates {
            guard date.timeIntervalSince1970.isFinite,
                (-62_135_596_800...253_402_300_799).contains(date.timeIntervalSince1970)
            else { throw LocalStateStoreError.invalidState }
        }
        for rule in draft.segments {
            guard rule.rate.count <= 100, rule.quantity.count <= 100,
                rule.reference.count <= 2_000, rule.sources.count <= 64
            else { throw LocalStateStoreError.invalidState }
            for source in rule.sources {
                guard source.title.count <= 512, source.url.count <= 4_096,
                    (source.section?.count ?? 0) <= 4_000
                else { throw LocalStateStoreError.invalidState }
                try AgreementImportValidation.validate(source)
            }
        }
    }
}
