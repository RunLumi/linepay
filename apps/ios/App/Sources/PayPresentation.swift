import Foundation
import LinePayDomain
import SwiftUI

struct LineGapMark: View {
    var body: some View {
        Image(decorative: "LinePaycheckLogo")
            .resizable().scaledToFit().frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
    }
}

extension PaystubField {
    var title: String {
        switch self {
        case .periodStart: "Period starts"
        case .periodEnd: "Period ends"
        case .grossPay: "Gross pay"
        case .regularHours: "Regular hours"
        case .regularPay: "Regular pay"
        case .overtimeHours: "Overtime hours"
        case .overtimePay: "Overtime pay"
        case .doubleTimeHours: "Double-time hours"
        case .doubleTimePay: "Double-time pay"
        case .calloutPay: "Callout guarantee"
        case .perDiemPay: "Per diem"
        }
    }
}

extension PayRuleKey {
    var title: String {
        switch self {
        case .base: "Base rate"
        case .schedule: "Regular schedule"
        case .weekday: "Weekday premium"
        case .date: "Date premium"
        case .dailyOvertime: "Daily overtime"
        case .callout: "Callout minimum"
        case .perDiem: "Per diem"
        }
    }
}

extension PaystubGrossBasis {
    var title: String {
        switch self {
        case .unconfirmed: "Not confirmed"
        case .wagesOnly: "Wages only; per diem is separate"
        case .wagesAndPerDiem: "Wages and per diem together"
        }
    }
}
extension PaystubLineLayout {
    var title: String {
        switch self {
        case .unconfirmed: "Not confirmed"
        case .fullRateBuckets: "Each line includes its full hourly pay"
        case .basePlusPremium: "Base pay for all hours, plus premium-only lines"
        }
    }
}
extension PaystubHoursBasis {
    var title: String {
        switch self {
        case .unconfirmed: "Not confirmed"
        case .actualWork: "Actual worked hours"
        case .paidEquivalents: "Includes guaranteed paid hours"
        }
    }
}
extension PaystubGuaranteeLayout {
    var title: String {
        switch self {
        case .unconfirmed: "Not confirmed"
        case .separateLine: "Separate callout guarantee line"
        case .includedInHourlyLines: "Included in the hourly earnings lines"
        }
    }
}

extension AuditDisplayStatus {
    static func assessment(_ assessment: PaycheckAssessment?) -> AuditDisplayStatus {
        guard let assessment else { return .needsReview }
        switch assessment.verdict {
        case .matches: return assessment.scope == .grossOnly ? .grossMatches : .matches
        case .possibleShortfall: return .possibleShortfall
        case .possibleOverpayment: return .possibleOverpayment
        case .needsReview: return .needsReview
        case .notComparable: return .notComparable
        }
    }
}

struct PayAmount: View {
    let label: String
    let money: Money?
    var prominent = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(LinePayColor.textSecondary)
            Text(money.map(LinePayFormat.money) ?? "Unavailable")
                .font(prominent ? .largeTitle.bold() : .title2.bold())
                .monospacedDigit().foregroundStyle(LinePayColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ComparisonAmounts: View {
    let expected: Money?
    let paid: Money
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                PayAmount(label: "Expected, same basis", money: expected)
                    .fixedSize(horizontal: true, vertical: true)
                Spacer(minLength: 0)
                PayAmount(label: "Confirmed paid", money: paid)
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: 16) {
                PayAmount(label: "Expected, same basis", money: expected)
                PayAmount(label: "Confirmed paid", money: paid)
            }
        }
    }
}

struct LineGapComparison: View {
    let difference: Money?
    var body: some View {
        if let difference {
            HStack(spacing: difference.amount == 0 ? 0 : 12) {
                Rectangle().frame(height: 2)
                Rectangle().frame(height: 2)
            }
            .foregroundStyle(LinePayColor.brandPrimary)
            .padding(.vertical, 8)
            .accessibilityHidden(true)
        }
    }
}

func workKindTitle(_ kind: WorkKind) -> String {
    switch kind {
    case .regular: "Regular work"
    case .callout: "Callout"
    case .other: "Other work"
    }
}

func componentTitle(_ component: PayComponent) -> String {
    switch component.category {
    case .calloutGuarantee: "Callout guarantee"
    case .perDiem: "Per diem"
    case .workedHours:
        (component.multiplier ?? 1) == 1 ? "Regular work" : "Premium work"
    }
}

struct CalculationProblemView: View {
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Calculation unavailable", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
            Text(
                "Review work and rule effective dates in Settings. No zero estimate has been substituted."
            )
            .font(.footnote)
        }
        .foregroundStyle(LinePayColor.review)
        .accessibilityIdentifier("pay.calculation-error")
    }
}

struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
                            for: nil)
                    }.accessibilityIdentifier("keyboard.done")
                }
            }
    }
}
extension View {
    func linePayKeyboardDismiss() -> some View { modifier(KeyboardDismissModifier()) }
}
