import Foundation
import LinePayDomain

/// Converts explicit worker decisions into an editable draft, never an active rule snapshot.
enum AgreementImportDraftBuilder {
    static func build(
        document: ImportedAgreementDocument, review: AgreementImportReview,
        profile: PayProfile?, activePeriod: ActivePayPeriod?
    ) throws -> PayProfileDraft {
        guard let candidates = document.candidates else { throw invalid("Read the document first") }
        guard review.applicabilityConfirmed, review.currencyConfirmed,
            review.datesConfirmed, let start = review.startDate,
            review.endDate != nil || review.noEndDateSpecified,
            TimeZone(identifier: review.timeZoneIdentifier) != nil,
            review.endDate.map({ $0 >= start }) ?? true
        else { throw invalid("Confirm applicability, currency and effective dates") }
        guard PayProfileDraft.supportedCurrencyCodes.contains(review.currencyCode),
            profile.map({ $0.agreement.hourlyRate.currencyCode == review.currencyCode }) ?? true
        else {
            throw invalid("The imported currency must match this profile; no conversion is made")
        }
        guard review.rules.count == candidates.count,
            Set(review.rules.map(\.candidateID)) == Set(candidates.map(\.id)),
            Set(review.rules.map(\.candidateID)).count == review.rules.count,
            review.rules.allSatisfy({ $0.decision != .unreviewed })
        else { throw invalid("Review every candidate, including unresolved clauses") }
        let decisions = Dictionary(uniqueKeysWithValues: review.rules.map { ($0.candidateID, $0) })
        let selected = candidates.filter { decisions[$0.id]?.decision == .confirmed }
        for candidate in selected {
            guard candidate.status != .unsupported,
                candidate.kind.canPreparePayRule
                    || [.effectiveStart, .effectiveEnd].contains(candidate.kind)
            else { throw invalid("Unsupported conditions cannot become a wage rule") }
            if let currency = candidate.currencyCode, currency != review.currencyCode {
                throw invalid("A selected clause uses a different currency")
            }
        }
        for kind in [ImportedRuleKind.baseRate, .sundayPremium, .calloutMinimum, .perDiem] {
            guard selected.filter({ $0.kind == kind }).count <= 1 else {
                throw invalid("Choose only one applicable \(kind.title.lowercased()) clause")
            }
        }
        if review.endDate == nil,
            candidates.contains(where: {
                $0.kind == .effectiveEnd && decisions[$0.id]?.decision != .notApplicable
            })
        {
            throw invalid("Review the document's end date before preparing rules")
        }
        for candidate in selected {
            let value = try requireReview(candidate, decisions)
            switch candidate.kind {
            case .baseRate:
                _ = try NumberEntry.amount(
                    value.value, currencyCode: review.currencyCode, allowZero: false)
            case .perDiem:
                _ = try NumberEntry.amount(value.value, currencyCode: review.currencyCode)
            case .calloutMinimum:
                guard try NumberEntry.hours(value.value) > 0 else {
                    throw invalid("Callout minimum must be positive")
                }
            case .dailyOvertime, .dailyDoubleTime:
                _ = try NumberEntry.hours(value.value)
                guard try NumberEntry.hours(value.multiplier) >= 1 else {
                    throw invalid("Multiplier must be at least one")
                }
            case .sundayPremium:
                guard try NumberEntry.hours(value.value) >= 1 else {
                    throw invalid("Multiplier must be at least one")
                }
            default: break
            }
        }
        var draft =
            profile.map { PayProfileDraft(profile: $0, activePeriod: activePeriod) }
            ?? PayProfileDraft()
        draft.currencyCode = review.currencyCode
        draft.timeZoneIdentifier = review.timeZoneIdentifier
        draft.useEffectiveStart = true
        draft.effectiveStartDate = start
        draft.changeEffectiveDate = start
        draft.editScope = .datedChange
        draft.useEffectiveEnd = review.endDate != nil
        if let end = review.endDate { draft.effectiveEndDate = end }
        draft.setupStep = 0
        let tiers = selected.filter { [.dailyOvertime, .dailyDoubleTime].contains($0.kind) }
        if !tiers.isEmpty {
            guard review.dailyTierReplacementConfirmed else {
                throw invalid("Confirm replacement of the draft's daily overtime tiers")
            }
            let values = try tiers.map { candidate -> (Decimal, ImportedRuleReview) in
                let value = try requireReview(candidate, decisions)
                return (try NumberEntry.hours(value.value), value)
            }.sorted { $0.0 < $1.0 }
            guard Set(values.map(\.0)).count == values.count else {
                throw invalid("Daily tier thresholds must be distinct")
            }
            if let first = values.first {
                draft.useDailyOvertime = true
                draft.overtimeAfterHours = first.1.value
                draft.overtimeMultiplier = first.1.multiplier
                draft.additionalOvertimeTiers = values.dropFirst().map {
                    OvertimeTierDraft(afterHours: $0.1.value, multiplier: $0.1.multiplier)
                }
            }
        }
        for candidate in selected {
            let value = try requireReview(candidate, decisions)
            switch candidate.kind {
            case .baseRate: draft.hourlyRate = value.value
            case .sundayPremium:
                draft.useSundayPremium = true
                draft.sundayMultiplier = value.value
            case .calloutMinimum:
                draft.useCalloutMinimum = true
                draft.calloutMinimumHours = value.value
            case .perDiem:
                draft.usePerDiem = true
                draft.perDiemAmount = value.value
            default: break
            }
            draft.additionalSources.append(
                RuleSourceDraft(
                    source: AgreementSource(
                        title: document.filename, url: "",
                        section: "PDF page \(candidate.page + 1)",
                        ruleKey: candidate.kind.ruleKey, documentID: document.id,
                        documentSHA256: document.sha256, documentPage: candidate.page,
                        quotedText: candidate.quote)))
        }
        if selected.isEmpty {
            draft.additionalSources.append(
                RuleSourceDraft(
                    source: AgreementSource(
                        title: document.filename, url: "",
                        section: "Imported PDF; enter confirmed rules manually",
                        documentID: document.id, documentSHA256: document.sha256, documentPage: 0)))
        }
        var limitations = candidates.filter { decisions[$0.id]?.decision == .unresolved }.map {
            "\(document.filename), PDF page \($0.page + 1): \($0.kind.title) remains unresolved. \($0.quote.prefix(200))"
        }
        if let notice = document.extractionNotice { limitations.append(notice) }
        if !limitations.isEmpty {
            draft.unsupportedRuleNotes = ([draft.unsupportedRuleNotes] + limitations)
                .filter { !$0.isEmpty }.joined(separator: "\n")
        }
        return draft
    }

    private static func requireReview(
        _ candidate: ImportedRuleCandidate, _ reviews: [String: ImportedRuleReview]
    ) throws -> ImportedRuleReview {
        guard let review = reviews[candidate.id] else { throw invalid("Missing clause review") }
        return review
    }

    private static func invalid(_ message: String) -> AppModelError { .invalidField(message) }
}
