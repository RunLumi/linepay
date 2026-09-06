import Foundation

/// A worker-confirmed change starting at midnight on a payroll-local calendar date.
public struct AgreementChange: Codable, Hashable, Sendable {
    public let effectiveDate: LocalDate
    public let agreement: AgreementSnapshot

    public init(effectiveDate: LocalDate, agreement: AgreementSnapshot) {
        self.effectiveDate = effectiveDate
        self.agreement = agreement
    }
}

public struct AgreementReference: Codable, Hashable, Sendable {
    public let id: String
    public let version: String
    public let hourlyRate: Money

    public init(_ agreement: AgreementSnapshot) {
        id = agreement.id
        version = agreement.version
        hourlyRate = agreement.hourlyRate
    }
}

/// The baseline remains intact: adding a future rule never changes earlier work.
public struct AgreementTimeline: Sendable {
    public let baseline: AgreementSnapshot
    public let changes: [AgreementChange]

    public init(baseline: AgreementSnapshot, changes: [AgreementChange]) throws {
        guard changes.count <= 256,
            Set(changes.map(\.effectiveDate)).count == changes.count,
            Set(([baseline] + changes.map(\.agreement)).map(\.version)).count == changes.count + 1
        else { throw AgreementTimelineError.duplicateOrExcessiveChanges }
        for change in changes {
            guard change.agreement.id == baseline.id,
                change.agreement.hourlyRate.currencyCode == baseline.hourlyRate.currencyCode,
                change.agreement.rounding.scale == baseline.rounding.scale,
                change.agreement.rounding.mode == baseline.rounding.mode
            else { throw AgreementTimelineError.incompatibleAgreement }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let value = change.effectiveDate
            guard (1...9999).contains(value.year),
                let date = calendar.date(
                    from: DateComponents(
                        year: value.year, month: value.month, day: value.day)),
                calendar.component(.year, from: date) == value.year,
                calendar.component(.month, from: date) == value.month,
                calendar.component(.day, from: date) == value.day
            else { throw AgreementTimelineError.invalidEffectiveDate }
        }
        self.baseline = baseline
        self.changes = changes.sorted { $0.effectiveDate < $1.effectiveDate }
    }

    public func agreement(on date: LocalDate) -> AgreementSnapshot {
        changes.last(where: { $0.effectiveDate <= date })?.agreement ?? baseline
    }
}

public enum AgreementTimelineError: Error, Equatable, Sendable {
    case duplicateOrExcessiveChanges
    case incompatibleAgreement
    case invalidEffectiveDate
    case calloutGuaranteeNeedsReview(UUID)
}
