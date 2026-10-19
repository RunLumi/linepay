import Foundation
import LinePayDomain

struct PayProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let timeZoneIdentifier: String
    let agreement: AgreementSnapshot
    let preferredCadence: PayPeriodCadence
    let baselineAgreement: AgreementSnapshot?
    let agreementChanges: [AgreementChange]?

    init(
        id: UUID = UUID(),
        name: String,
        timeZoneIdentifier: String,
        agreement: AgreementSnapshot,
        preferredCadence: PayPeriodCadence = .weekly,
        baselineAgreement: AgreementSnapshot? = nil,
        agreementChanges: [AgreementChange]? = nil
    ) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.agreement = agreement
        self.preferredCadence = preferredCadence
        self.baselineAgreement = baselineAgreement
        self.agreementChanges = agreementChanges
    }
}

enum PayPeriodCadence: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case weekly
    case biweekly
    case semimonthly
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .semimonthly: "Twice monthly (1–15, 16–end)"
        case .manual: "Choose dates manually"
        }
    }
}

struct PayPeriodWindow: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let startEpochSeconds: Int64
    let endEpochSeconds: Int64
    let cadence: PayPeriodCadence

    init(
        id: UUID = UUID(),
        startEpochSeconds: Int64,
        endEpochSeconds: Int64,
        cadence: PayPeriodCadence
    ) {
        self.id = id
        self.startEpochSeconds = startEpochSeconds
        self.endEpochSeconds = endEpochSeconds
        self.cadence = cadence
    }

    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startEpochSeconds))
    }

    /// Exclusive end instant. Use `displayEndDate` when presenting the worker-facing final date.
    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(endEpochSeconds))
    }

    var displayEndDate: Date {
        Date(timeIntervalSince1970: TimeInterval(endEpochSeconds - 1))
    }

    func contains(start: Date, end: Date) -> Bool {
        let startSeconds = Int64(start.timeIntervalSince1970.rounded())
        let endSeconds = Int64(end.timeIntervalSince1970.rounded())
        return startSeconds >= startEpochSeconds && endSeconds <= endEpochSeconds
    }
}

struct WorkEntry: Codable, Hashable, Sendable, Identifiable {
    let interval: WorkInterval
    let note: String

    var id: UUID { interval.id }
}

enum PaystubSourceKind: String, Codable, Hashable, Sendable {
    case scan
    case photo
    case file
    case manual
}

struct PaystubEvidence: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let storedFilename: String
    let originalFilename: String
    let mediaType: String
    let sourceKind: PaystubSourceKind
    let createdEpochSeconds: Int64
    let recognizedText: String?

    init(
        id: UUID = UUID(),
        storedFilename: String,
        originalFilename: String,
        mediaType: String,
        sourceKind: PaystubSourceKind,
        createdEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970.rounded()),
        recognizedText: String? = nil
    ) {
        self.id = id
        self.storedFilename = storedFilename
        self.originalFilename = originalFilename
        self.mediaType = mediaType
        self.sourceKind = sourceKind
        self.createdEpochSeconds = createdEpochSeconds
        self.recognizedText = recognizedText
    }
}

struct ConfirmedPaystub: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let payPeriodStart: LocalDate?
    let payPeriodEnd: LocalDate?
    let grossPay: Money
    let regularHours: Decimal?
    let regularPay: Money?
    let overtimeHours: Decimal?
    let overtimePay: Money?
    let doubleTimeHours: Decimal?
    let doubleTimePay: Money?
    let calloutPay: Money?
    let perDiemPay: Money?
    let notes: String
    let evidence: PaystubEvidence?
    let confirmedEpochSeconds: Int64
    let confirmation: PaystubConfirmation?
    let assessment: PaycheckAssessment?

    init(
        id: UUID = UUID(),
        payPeriodStart: LocalDate?,
        payPeriodEnd: LocalDate?,
        grossPay: Money,
        regularHours: Decimal? = nil,
        regularPay: Money? = nil,
        overtimeHours: Decimal? = nil,
        overtimePay: Money? = nil,
        doubleTimeHours: Decimal? = nil,
        doubleTimePay: Money? = nil,
        calloutPay: Money? = nil,
        perDiemPay: Money? = nil,
        notes: String = "",
        evidence: PaystubEvidence? = nil,
        confirmedEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970.rounded()),
        confirmation: PaystubConfirmation? = nil,
        assessment: PaycheckAssessment? = nil
    ) {
        self.id = id
        self.payPeriodStart = payPeriodStart
        self.payPeriodEnd = payPeriodEnd
        self.grossPay = grossPay
        self.regularHours = regularHours
        self.regularPay = regularPay
        self.overtimeHours = overtimeHours
        self.overtimePay = overtimePay
        self.doubleTimeHours = doubleTimeHours
        self.doubleTimePay = doubleTimePay
        self.calloutPay = calloutPay
        self.perDiemPay = perDiemPay
        self.notes = notes
        self.evidence = evidence
        self.confirmedEpochSeconds = confirmedEpochSeconds
        self.confirmation = confirmation
        self.assessment = assessment
    }
}

struct ActivePayPeriod: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var window: PayPeriodWindow
    var agreement: AgreementSnapshot
    var agreementChanges: [AgreementChange]?
    var timeZoneIdentifier: String?
    var workEntries: [WorkEntry]
    var paystub: ConfirmedPaystub?
    var reconciliation: ReconciliationResult?
    var auditCompletedEpochSeconds: Int64?
    var hasConsumedAuditAccess: Bool
    var auditRevisions: [AuditRevision]?
    var workRevision: Int?

    init(
        id: UUID = UUID(),
        window: PayPeriodWindow,
        agreement: AgreementSnapshot,
        timeZoneIdentifier: String? = nil,
        workEntries: [WorkEntry] = [],
        paystub: ConfirmedPaystub? = nil,
        reconciliation: ReconciliationResult? = nil,
        auditCompletedEpochSeconds: Int64? = nil,
        hasConsumedAuditAccess: Bool = false,
        auditRevisions: [AuditRevision]? = nil,
        workRevision: Int? = nil,
        agreementChanges: [AgreementChange]? = nil
    ) {
        self.id = id
        self.window = window
        self.agreement = agreement
        self.timeZoneIdentifier = timeZoneIdentifier
        self.workEntries = workEntries
        self.paystub = paystub
        self.reconciliation = reconciliation
        self.auditCompletedEpochSeconds = auditCompletedEpochSeconds
        self.hasConsumedAuditAccess = hasConsumedAuditAccess
        self.auditRevisions = auditRevisions
        self.workRevision = workRevision
        self.agreementChanges = agreementChanges
    }
}

struct CompletedPayPeriod: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let window: PayPeriodWindow
    let agreement: AgreementSnapshot
    let agreementChanges: [AgreementChange]?
    let calculationIssue: String?
    let workCorrections: [ClosedWorkRevision]?
    let timeZoneIdentifier: String?
    let workEntries: [WorkEntry]
    let calculation: CalculationResult?
    let paystub: ConfirmedPaystub?
    let reconciliation: ReconciliationResult?
    let archivedEpochSeconds: Int64
    let auditRevisions: [AuditRevision]?
    let hasConsumedAuditAccess: Bool?

    /// The original period estimate stays frozen; an explicit newer audit owns its own calculation.
    var comparisonCalculation: CalculationResult? {
        if let paid = paystub,
            let revision = auditRevisions?.last(where: { $0.paystub.id == paid.id })
        {
            return revision.calculation
        }
        return calculation
    }

    init(
        id: UUID,
        window: PayPeriodWindow,
        agreement: AgreementSnapshot,
        timeZoneIdentifier: String? = nil,
        workEntries: [WorkEntry],
        calculation: CalculationResult?,
        paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?,
        archivedEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970.rounded()),
        auditRevisions: [AuditRevision]? = nil,
        hasConsumedAuditAccess: Bool? = nil,
        agreementChanges: [AgreementChange]? = nil,
        calculationIssue: String? = nil,
        workCorrections: [ClosedWorkRevision]? = nil
    ) {
        self.id = id
        self.window = window
        self.agreement = agreement
        self.timeZoneIdentifier = timeZoneIdentifier
        self.workEntries = workEntries
        self.calculation = calculation
        self.paystub = paystub
        self.reconciliation = reconciliation
        self.archivedEpochSeconds = archivedEpochSeconds
        self.auditRevisions = auditRevisions
        self.hasConsumedAuditAccess = hasConsumedAuditAccess
        self.agreementChanges = agreementChanges
        self.calculationIssue = calculationIssue
        self.workCorrections = workCorrections
    }
}

/// Earlier facts survive an explicit correction to a closed, unresolved period.
struct ClosedWorkRevision: Codable, Hashable, Sendable {
    let workEntries: [WorkEntry]
    let reason: String
    let correctedEpochSeconds: Int64
}

struct AppPersistentState: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 11
    var schemaVersion = Self.currentSchemaVersion
    var profile: PayProfile?
    var activePeriod: ActivePayPeriod?
    var history: [CompletedPayPeriod] = []
    var hasUsedFreeAudit = false
    var resolutionEvents: [ResolutionEvent]?
    var agreementDocuments: [ImportedAgreementDocument]?
    var crewRuleOrigins: [CrewRuleOrigin]?
    var benefitAudits: [BenefitAuditRecord]?
    var benefitAuditDraft: BenefitAuditDraft?
    var onboardingProgress: OnboardingProgress?
    var setupDraft: PayProfileDraft?
    var workDraft: WorkDraft?
    var paystubDraft: PaystubConfirmationDraft?
    var pendingEvidenceDeletions: [PaystubEvidence] = []

    init() {}

    func upgraded() throws -> AppPersistentState {
        guard (1...Self.currentSchemaVersion).contains(schemaVersion) else {
            throw LocalStateStoreError.unsupportedSchema(schemaVersion)
        }
        var result = self
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, profile, activePeriod, history, hasUsedFreeAudit, resolutionEvents,
            agreementDocuments, benefitAudits, benefitAuditDraft
        case setupDraft, workDraft, paystubDraft, pendingEvidenceDeletions
        case onboardingProgress
        case crewRuleOrigins
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .schemaVersion)
        guard (1...Self.currentSchemaVersion).contains(version) else {
            throw LocalStateStoreError.unsupportedSchema(version)
        }
        // V1–v10 admission preserves recorded calculations and comparison versions unchanged.
        schemaVersion = Self.currentSchemaVersion
        crewRuleOrigins = try values.decodeIfPresent(
            [CrewRuleOrigin].self, forKey: .crewRuleOrigins)
        agreementDocuments = try values.decodeIfPresent(
            [ImportedAgreementDocument].self, forKey: .agreementDocuments)
        benefitAudits = try values.decodeIfPresent(
            [BenefitAuditRecord].self, forKey: .benefitAudits)
        benefitAuditDraft = try values.decodeIfPresent(
            BenefitAuditDraft.self, forKey: .benefitAuditDraft)
        resolutionEvents = try values.decodeIfPresent(
            [ResolutionEvent].self, forKey: .resolutionEvents)
        profile = try values.decodeIfPresent(PayProfile.self, forKey: .profile)
        activePeriod = try values.decodeIfPresent(ActivePayPeriod.self, forKey: .activePeriod)
        history = try values.decodeIfPresent([CompletedPayPeriod].self, forKey: .history) ?? []
        hasUsedFreeAudit = try values.decodeIfPresent(Bool.self, forKey: .hasUsedFreeAudit) ?? false
        onboardingProgress = try values.decodeIfPresent(
            OnboardingProgress.self, forKey: .onboardingProgress)
        setupDraft = try values.decodeIfPresent(PayProfileDraft.self, forKey: .setupDraft)
        workDraft = try values.decodeIfPresent(WorkDraft.self, forKey: .workDraft)
        paystubDraft = try values.decodeIfPresent(
            PaystubConfirmationDraft.self, forKey: .paystubDraft)
        pendingEvidenceDeletions =
            try values.decodeIfPresent(
                [PaystubEvidence].self, forKey: .pendingEvidenceDeletions) ?? []
    }
}

/// Absent in older snapshots: returning workers keep their existing navigation.
enum OnboardingProgress: String, Codable, Hashable, Sendable {
    case firstWork, waitingForFirstResult, proof
}

struct AuditRevision: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let window: PayPeriodWindow
    let agreement: AgreementSnapshot
    let timeZoneIdentifier: String
    let workEntries: [WorkEntry]
    let calculation: CalculationResult?
    let paystub: ConfirmedPaystub
    let reconciliation: ReconciliationResult?
    var agreementChanges: [AgreementChange]?
}

struct PayPeriodContext: Identifiable, Hashable, Sendable {
    let id: UUID
    let window: PayPeriodWindow
    let agreement: AgreementSnapshot
    let timeZoneIdentifier: String
    let workEntries: [WorkEntry]
    let calculation: CalculationResult?
    let paystub: ConfirmedPaystub?
    let reconciliation: ReconciliationResult?
    let revisions: [AuditRevision]
    let isClosed: Bool
    var agreementChanges: [AgreementChange]?
    var calculationIssue: String? = nil
    var resolutionEvents: [ResolutionEvent] = []
    var requiresCalculationReview = false
    var requiresAssessmentReview = false
}

enum AuditDisplayStatus: Hashable, Sendable {
    case notAudited
    case matches
    case grossMatches
    case notComparable
    case possibleShortfall
    case possibleOverpayment
    case needsReview

    /// v3 result vocabulary (docs/plan/v3.md section 5). A match is scoped to what was compared;
    /// a difference is possible, never proven; missing or incompatible inputs are never "correct".
    var title: String {
        switch self {
        case .notAudited: "Not compared yet"
        case .matches: "No difference within compared items"
        case .grossMatches: "No difference within compared items: gross total only"
        case .notComparable: "Unable to verify"
        case .possibleShortfall: "Possible difference: paystub is lower"
        case .possibleOverpayment: "Possible difference: paystub is higher"
        case .needsReview: "Needs review"
        }
    }

    var systemImage: String {
        switch self {
        case .notAudited: "doc.text.magnifyingglass"
        case .matches, .grossMatches: "checkmark.circle.fill"
        case .notComparable: "questionmark.square"
        case .possibleShortfall: "exclamationmark.circle.fill"
        case .possibleOverpayment: "arrow.up.arrow.down.circle.fill"
        case .needsReview: "questionmark.circle.fill"
        }
    }
}

struct AuditFinding: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let expected: Money
    let paid: Money
    let difference: Money
    let explanation: String

    static func contains(_ id: String, in paystub: ConfirmedPaystub) -> Bool {
        paystub.assessment?.comparisons.contains { $0.unit == .money && $0.id == id } ?? false
    }

    static func from(paystub: ConfirmedPaystub) -> [AuditFinding] {
        guard let assessment = paystub.assessment else { return [] }
        return assessment.comparisons.filter { $0.unit == .money }.map { item in
            AuditFinding(
                id: item.id,
                title: item.field.title,
                expected: Money(amount: item.expected, currencyCode: item.currencyCode),
                paid: Money(amount: item.paid, currencyCode: item.currencyCode),
                difference: Money(amount: item.difference, currencyCode: item.currencyCode),
                explanation: "Compared using the paystub layout and gross basis you confirmed."
            )
        }
    }
}
