import Foundation
import LinePayDomain

enum ImportedRuleKind: String, Codable, CaseIterable, Hashable, Sendable {
    case baseRate, dailyOvertime, dailyDoubleTime, sundayPremium, holidayPremium
    case calloutMinimum, perDiem, weeklyOvertime, benefitRate, shiftDifferential
    case mealPremium, showUpMinimum, effectiveStart, effectiveEnd, unmapped

    var title: String {
        switch self {
        case .baseRate: "Base hourly rate"
        case .dailyOvertime: "Daily overtime"
        case .dailyDoubleTime: "Daily double time"
        case .sundayPremium: "Sunday premium"
        case .holidayPremium: "Holiday premium"
        case .calloutMinimum: "Callout minimum"
        case .perDiem: "Per diem per worked date"
        case .weeklyOvertime: "Weekly overtime"
        case .benefitRate: "Employer benefit contribution"
        case .shiftDifferential: "Shift differential"
        case .mealPremium: "Meal premium"
        case .showUpMinimum: "Show-up minimum"
        case .effectiveStart: "Effective start"
        case .effectiveEnd: "Effective end"
        case .unmapped: "Unmapped clause"
        }
    }

    var canPreparePayRule: Bool {
        [.baseRate, .dailyOvertime, .dailyDoubleTime, .sundayPremium, .calloutMinimum, .perDiem]
            .contains(self)
    }

    var ruleKey: PayRuleKey? {
        switch self {
        case .baseRate: .base
        case .dailyOvertime, .dailyDoubleTime: .dailyOvertime
        case .sundayPremium: .weekday
        case .calloutMinimum: .callout
        case .perDiem: .perDiem
        default: nil
        }
    }

    var valueLabel: String {
        switch self {
        case .baseRate: "Hourly amount"
        case .dailyOvertime, .dailyDoubleTime: "After worked hours per day"
        case .sundayPremium, .holidayPremium: "Multiplier"
        case .calloutMinimum, .showUpMinimum: "Minimum paid hours"
        case .perDiem: "Amount per worked date"
        default: "Value"
        }
    }

    var behavior: String {
        switch self {
        case .baseRate: "Straight-time hourly wage, in the profile's currency."
        case .dailyOvertime, .dailyDoubleTime:
            "A payroll-local calendar-day threshold. The highest applicable multiplier wins; premiums do not stack. Selected daily tiers replace the draft's daily tiers."
        case .sundayPremium: "A multiplier for work on Sunday in the payroll timezone."
        case .calloutMinimum:
            "An isolated paid-hours minimum per confirmed physical callout. Separate callout rates, adjoining work, rest and repeated-call interactions are not inferred."
        case .perDiem: "One flat allowance per worked local date, kept apart from wages."
        default:
            "This clause needs separate review. It is not automatically applied to expected wages."
        }
    }
}

enum ImportedRuleStatus: String, Codable, Hashable, Sendable {
    case suggested, manualReview, conflicting, unsupported
}

struct ImportedRuleCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: ImportedRuleKind
    let page: Int
    let quote: String
    var value: String?
    var multiplier: String?
    let currencyCode: String?
    let recognitionConfidence: Double?
    var status: ImportedRuleStatus
    var reason: String?
}

enum ImportedRuleDecision: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case unreviewed, confirmed, notApplicable, unresolved
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unreviewed: "Not reviewed"
        case .confirmed: "Reviewed for my work"
        case .notApplicable: "Not applicable to my work"
        case .unresolved: "Keep as unresolved"
        }
    }
}

struct ImportedRuleReview: Identifiable, Codable, Hashable, Sendable {
    let candidateID: String
    var decision: ImportedRuleDecision = .unreviewed
    var value: String
    var multiplier: String
    var id: String { candidateID }

    init(candidate: ImportedRuleCandidate) {
        candidateID = candidate.id
        value = candidate.value ?? ""
        multiplier = candidate.multiplier ?? ""
    }
}

struct AgreementImportReview: Codable, Hashable, Sendable {
    var rules: [ImportedRuleReview] = []
    var applicabilityConfirmed = false
    var currencyConfirmed = false
    var currencyCode = "USD"
    var timeZoneIdentifier = TimeZone.current.identifier
    var startDate: Date?
    var endDate: Date?
    var datesConfirmed = false
    var noEndDateSpecified = false
    var dailyTierReplacementConfirmed = false
}

struct ImportedAgreementDocument: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let filename: String
    let sha256: String
    var evidence: PaystubEvidence?
    var pageCount: Int?
    var candidates: [ImportedRuleCandidate]?
    var extractionNotice: String?
    var review: AgreementImportReview?
    let importedEpochSeconds: Int64
    let extractionVersion: String
}

struct AgreementTextLine: Sendable {
    let text: String
    let page: Int
    let confidence: Double?
}

struct AgreementExtraction: Sendable {
    let pageCount: Int
    let candidates: [ImportedRuleCandidate]
    let notice: String?
}

extension AppPersistentState {
    var referencedAgreementDocumentIDs: Set<UUID> {
        var agreements = [profile?.agreement, profile?.baselineAgreement, activePeriod?.agreement]
            .compactMap { $0 }
        agreements += (profile?.agreementChanges ?? []).map(\.agreement)
        agreements += (activePeriod?.agreementChanges ?? []).map(\.agreement)
        agreements += history.map(\.agreement)
        agreements += history.flatMap { ($0.agreementChanges ?? []).map(\.agreement) }
        agreements += history.flatMap { $0.calculation?.agreementSnapshots ?? [] }
        for revision in (activePeriod?.auditRevisions ?? [])
            + history.flatMap({ $0.auditRevisions ?? [] })
        {
            agreements.append(revision.agreement)
            agreements += (revision.agreementChanges ?? []).map(\.agreement)
            agreements += revision.calculation?.agreementSnapshots ?? []
        }
        var ids = Set(agreements.flatMap(\.sources).compactMap(\.documentID))
        if let id = setupDraft?.sourceDocumentID { ids.insert(id) }
        ids.formUnion((setupDraft?.additionalSources ?? []).compactMap(\.documentID))
        let benefits =
            (benefitAudits ?? []).flatMap { $0.revisions.map(\.input) }
            + [benefitAuditDraft].compactMap { $0 }
        ids.formUnion(benefits.flatMap(\.segments).flatMap(\.sources).compactMap(\.documentID))
        return ids
    }
}
