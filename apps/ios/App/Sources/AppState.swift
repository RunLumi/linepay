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
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
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
        confirmedEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970.rounded())
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
        self.agreementChanges = agreementChanges
    }
}

struct CompletedPayPeriod: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let window: PayPeriodWindow
    let agreement: AgreementSnapshot
    let agreementChanges: [AgreementChange]?
    let timeZoneIdentifier: String?
    let workEntries: [WorkEntry]
    let calculation: CalculationResult
    let paystub: ConfirmedPaystub?
    let reconciliation: ReconciliationResult?
    let archivedEpochSeconds: Int64

    init(
        id: UUID,
        window: PayPeriodWindow,
        agreement: AgreementSnapshot,
        timeZoneIdentifier: String? = nil,
        workEntries: [WorkEntry],
        calculation: CalculationResult,
        paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?,
        archivedEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970.rounded()),
        agreementChanges: [AgreementChange]? = nil
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
        self.agreementChanges = agreementChanges
    }
}

struct AppPersistentState: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion = Self.currentSchemaVersion
    var profile: PayProfile?
    var activePeriod: ActivePayPeriod?
    var history: [CompletedPayPeriod] = []
    var hasUsedFreeAudit = false

    /// Schema 1 has no scheduled rules. Upgrade in memory without rewriting historical results.
    func upgraded() throws -> AppPersistentState {
        guard schemaVersion == 1 || schemaVersion == Self.currentSchemaVersion else {
            throw LocalStateStoreError.unsupportedSchema(schemaVersion)
        }
        var result = self
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }
}

enum AuditDisplayStatus: Hashable, Sendable {
    case notAudited
    case matches
    case grossMatches
    case possibleShortfall
    case possibleOverpayment
    case needsReview

    var title: String {
        switch self {
        case .notAudited: "Not audited"
        case .matches: "Confirmed items match"
        case .grossMatches: "Gross total matches"
        case .possibleShortfall: "Possible shortfall"
        case .possibleOverpayment: "Possible overpayment"
        case .needsReview: "Needs review"
        }
    }

    var systemImage: String {
        switch self {
        case .notAudited: "doc.text.magnifyingglass"
        case .matches, .grossMatches: "checkmark.circle.fill"
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
}
