import Foundation
import LinePayDomain
import SwiftUI

extension BenefitKind {
    var title: String {
        switch self {
        case .pension: "Pension"
        case .annuity: "Annuity"
        case .healthAndWelfare: "Health and welfare"
        case .other: "Other employer contribution"
        }
    }
}

extension BenefitContributionBasis {
    var title: String {
        switch self {
        case .eligibleHour: "Per eligible hour"
        case .eligibleDay: "Per eligible day"
        case .percentOfEligibleEarnings: "Percent of eligible earnings"
        case .fixedPeriod: "Fixed amount for this whole period"
        }
    }
    var quantityTitle: String {
        switch self {
        case .eligibleHour: "Eligible hours"
        case .eligibleDay: "Eligible days"
        case .percentOfEligibleEarnings: "Eligible earnings in the stated currency"
        case .fixedPeriod: "Whole period count (1)"
        }
    }
    var rateTitle: String {
        self == .percentOfEligibleEarnings
            ? "Contribution percentage" : "Employer contribution rate"
    }
}

extension BenefitContributionResult {
    var comparisonTitle: String {
        switch status {
        case .notVerified: "Not verified"
        case .notComparable: "Not comparable"
        case .possibleDifference: "Possible benefits difference"
        case .comparedValuesMatch:
            contributionDifference == nil
                ? "Compared units match"
                : quantityDifference == nil
                    ? "Compared contribution amount matches" : "Compared values match"
        }
    }
}

/// Keep every recorded decimal visible, including nonstandard confirmed fund rounding scales.
func benefitMoney(_ money: Money) -> String {
    "\(money.currencyCode) \(LinePayFormat.entry(money.amount))"
}

func benefitErrorMessage(_ error: any Error) -> String {
    if let error = error as? AppModelError { return error.localizedDescription }
    if error is DecimalInputError {
        return
            "Enter a complete nonnegative number using the draft's displayed decimal separator. Check its precision and size."
    }
    guard let error = error as? BenefitContributionError else {
        return
            "The benefits check could not be read or saved safely. Keep this screen open and retry; earlier saved checks remain unchanged."
    }
    switch error {
    case .invalidPeriod: return "Check the first and last covered dates and their payroll timezone."
    case .invalidRule:
        return
            "Review each rate and its source snapshot; a rule identity cannot describe conflicting rates."
    case .invalidQuantity:
        return
            "Check eligible units. A fixed-period amount needs one whole period with exactly the same applicable dates."
    case .eligibilityNotConfirmed:
        return "Review and confirm eligibility for every date/rate segment."
    case .incompleteCoverage:
        return "Confirm that the eligible units cover this whole benefits period."
    case .overlappingSegments:
        return "Use nonoverlapping date segments for one fund. Check another fund separately."
    case .ruleNotEffective:
        return
            "Every segment must fit inside the check's dates and the source rule's applicable dates, in the same timezone."
    case .currencyMismatch, .fundMismatch:
        return "Keep each expectation in one fund and currency. No conversion or merging is made."
    case .invalidStatement:
        return
            "Review the statement amount and unit count. Missing is different from zero; negative adjustments need separate review."
    case .arithmeticNotExact:
        return
            "This calculation cannot be represented exactly. Review the input and unsupported precision; no approximate amount was saved."
    case .invalidRounding:
        return "Review the fund-total rounding policy and number of decimal places."
    }
}

func benefitLastDate(_ exclusive: Binding<Date>, zone: String) -> Binding<Date> {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
    return Binding(
        get: {
            calendar.date(byAdding: .day, value: -1, to: exclusive.wrappedValue)
                ?? exclusive.wrappedValue
        },
        set: { exclusive.wrappedValue = calendar.date(byAdding: .day, value: 1, to: $0) ?? $0 })
}

func benefitDateRange(_ start: Date, _ end: Date, zone: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
    func text(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return LinePayFormat.localDate(
            LocalDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0))
    }
    return "\(text(start)) – \(text(calendar.date(byAdding: .day, value: -1, to: end) ?? end))"
}

func benefitPeriodLabel(_ period: BenefitPeriod) -> String {
    // Civil calendar display, not elapsed seconds or the device's current timezone.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let end = calendar.date(
        from: DateComponents(year: period.end.year, month: period.end.month, day: period.end.day))
    guard let end, let last = calendar.date(byAdding: .day, value: -1, to: end) else {
        return
            "From \(LinePayFormat.localDate(period.start)) until before \(LinePayFormat.localDate(period.end))"
    }
    let parts = calendar.dateComponents([.year, .month, .day], from: last)
    let lastDate = LocalDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    return "\(LinePayFormat.localDate(period.start)) – \(LinePayFormat.localDate(lastDate))"
}

func benefitRebase(_ date: Date, from old: String, to new: String) -> Date {
    guard let oldZone = TimeZone(identifier: old), let newZone = TimeZone(identifier: new) else {
        return date
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = oldZone
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    calendar.timeZone = newZone
    return calendar.date(from: components) ?? date
}

struct BenefitResultSections: View {
    let result: BenefitContributionResult
    var body: some View {
        Section {
            Label(
                result.comparisonTitle,
                systemImage: result.status == .possibleDifference
                    ? "exclamationmark.triangle" : "list.bullet.rectangle"
            )
            .font(.title2.bold()).accessibilityElement(children: .ignore)
            .accessibilityLabel(result.comparisonTitle).accessibilityIdentifier("benefits.verdict")
            Text("Expected employer contribution").font(.subheadline)
            Text(benefitMoney(result.expectedEmployerContribution)).font(.largeTitle.bold())
                .monospacedDigit().accessibilityIdentifier("benefits.expected")
            Text("Separate from cash wages, allowances and employee deductions.").font(.footnote)
        }
        Section("Compared values") {
            LabeledContent(
                "Confirmed employer contribution",
                value: result.confirmedEmployerContribution.map(benefitMoney) ?? "Not available")
            LabeledContent(
                "Expected minus confirmed",
                value: result.contributionDifference.map(benefitMoney) ?? "Not compared"
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Expected minus confirmed: \(result.contributionDifference.map(benefitMoney) ?? "Not compared")"
            )
            .accessibilityIdentifier("benefits.amount-difference")
            if let units = result.eligibleQuantity, let basis = result.quantityBasis {
                LabeledContent(basis.quantityTitle, value: LinePayFormat.entry(units))
                    .monospacedDigit()
            }
            if let units = result.statement?.quantity, let basis = result.statement?.quantityBasis {
                LabeledContent(
                    "\(result.statement?.confirmed == true ? "Statement" : "Unconfirmed reading"): \(basis.quantityTitle.lowercased())",
                    value: LinePayFormat.entry(units)
                ).monospacedDigit()
            }
            LabeledContent(
                "Eligible unit difference",
                value: result.quantityDifference.map(LinePayFormat.entry) ?? "Not compared"
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Eligible unit difference: \(result.quantityDifference.map(LinePayFormat.entry) ?? "Not compared")"
            )
            .accessibilityIdentifier("benefits.unit-difference")
            if let limitation = result.limitation { Text(limitation).font(.footnote) }
        }
        Section("How this expectation was built") {
            ForEach(result.components) { component in
                if let line = result.segments.first(where: { $0.id == component.id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(line.rule.basis.title).font(.headline)
                        Text(
                            "\(LinePayFormat.entry(line.quantity)) × \(LinePayFormat.entry(line.rule.rate))\(line.rule.basis == .percentOfEligibleEarnings ? "%" : "") = \(benefitMoney(component.unroundedContribution)) before fund rounding"
                        ).monospacedDigit()
                        Text(benefitPeriodLabel(line.period)).font(.footnote)
                    }
                } else {
                    Text("Component source is unavailable; review this record.")
                }
            }
        }
        Section("Scope") {
            Text(
                "Only this fund's confirmed contribution values are checked. Eligibility exceptions, caps, remittance deadlines, project/fringe compliance, employee deductions and legally owed amounts are not determined."
            ).font(.footnote)
            Text("\(benefitPeriodLabel(result.period)) · \(result.period.timeZoneIdentifier)")
                .font(.footnote)
            Text(
                "\(result.engineVersion) · round once per fund to \(result.rounding.scale) decimal places (\(result.rounding.mode.rawValue))"
            )
            .font(.caption)
        }
    }
}
