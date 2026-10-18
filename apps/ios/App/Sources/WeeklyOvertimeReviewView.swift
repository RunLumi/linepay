import LinePayDomain
import SwiftUI

struct WeeklyOvertimeReviewView: View {
    let model: AppModel
    @State private var weekStart: Date
    @State private var completeWorkweek = false
    @State private var straightTimeAmount = ""
    @State private var payments: [WeeklyPaymentDraft] = []
    @State private var remunerationComplete = false
    @State private var workweekBoundaryConfirmed = false
    @State private var result: WeeklyRegularRateResult?
    @State private var errorMessage: String?

    init(model: AppModel, weekStart: Date) {
        self.model = model
        _weekStart = State(initialValue: Self.alignedWeekStart(weekStart, model: model))
    }

    /// Starts on the configured workweek day on or before `date`, so the first suggestion is a
    /// real workweek rather than a pay-period boundary that may fall mid-week.
    static func alignedWeekStart(_ date: Date, model: AppModel) -> Date {
        guard let profile = model.profile, let rule = profile.agreement.weeklyOvertime,
            let zone = TimeZone(identifier: profile.timeZoneIdentifier)
        else { return date }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.startOfDay(for: date)
        let back = (calendar.component(.weekday, from: day) - rule.workweekStart.rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: -back, to: day) ?? date
    }

    static func errorMessage(for error: any Error) -> String {
        "Needs review: \(error.localizedDescription)"
    }

    var body: some View {
        List {
            Section {
                Text(
                    "Checks hours over 40 in one complete workweek, using the weekly regular rate. This is separate from the daily estimate on Pay and is not a state, CBA or nationwide legal determination."
                ).font(.footnote)
                DatePicker(
                    "Workweek starts", selection: $weekStart,
                    displayedComponents: [.date, .hourAndMinute])
                LabeledContent("Payroll timezone", value: LinePayFormat.timeZoneName(zone))
                LabeledContent("168-hour end (excluded)", value: boundaryEnd)
                Text(
                    "The initial date is a suggestion from your configured weekday. Review the actual start time against your employer's fixed recurring workweek. Its elapsed duration is 168 hours; local end time can shift across daylight saving. Do not use paycheck dates or change the week merely to move overtime hours."
                )
                .font(.footnote)
                ConfirmationCheckRow(
                    "I confirmed this exact workweek boundary from my employer's schedule",
                    isOn: $workweekBoundaryConfirmed)
                ConfirmationCheckRow(
                    "Every shift in this workweek is logged", isOn: $completeWorkweek)
                Text(
                    "Changing the week clears this unsaved review and payment rows. This review is not stored, added to Pay, or used to clear a paycheck's weekly-review warning."
                )
                .font(.footnote)
            }
            Section("Remuneration for this complete workweek") {
                Text(
                    "Enter the full straight-time wage amount earned under your reviewed rules for this week, including all its hours. Add every other cash payment separately. Do not enter net pay, YTD totals, employer fund contributions, or duplicate the base wages in another row. Clock records do not classify these payments automatically."
                )
                .font(.footnote)
                VStack(alignment: .leading) {
                    Text("Reviewed straight-time wages (\(currency))")
                    TextField("Amount for this week", text: $straightTimeAmount).keyboardType(
                        .decimalPad
                    )
                    .accessibilityIdentifier("weekly.straight-time")
                }
                ForEach($payments) { $payment in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other cash payment (\(currency))")
                        TextField("Amount", text: $payment.amount).keyboardType(.decimalPad)
                        Picker("Payment treatment", selection: $payment.kind) {
                            Text("Not classified").tag("")
                            Text("Other includable wages").tag(
                                WeeklyRemunerationKind.straightTime.rawValue)
                            Text("Includable bonus").tag(
                                WeeklyRemunerationKind.includableBonus.rawValue)
                            Text("Confirmed exclusion; no overtime credit").tag(
                                WeeklyRemunerationKind.excludedCash.rawValue)
                            Text("Extra work premium").tag(
                                WeeklyRemunerationKind.extraPremium.rawValue)
                        }
                        .onChange(of: payment.kind) { _, _ in payment.credit = "" }
                        if payment.kind == WeeklyRemunerationKind.extraPremium.rawValue {
                            Text(
                                "Enter only the extra premium above base wages already included in straight time. A full-rate overtime line is not the credit amount."
                            )
                            .font(.footnote)
                            Picker("Premium treatment", selection: $payment.credit) {
                                Text("Not reviewed").tag("")
                                Text("Unknown; needs review").tag(
                                    WeeklyPremiumCredit.unknown.rawValue)
                                Text("Eligible statutory overtime credit").tag(
                                    WeeklyPremiumCredit.eligibleExtraPremium.rawValue)
                                Text("Includable; no overtime credit").tag(
                                    WeeklyPremiumCredit.ineligible.rawValue)
                            }
                        }
                        Button("Remove payment", role: .destructive) {
                            payments.removeAll { $0.id == payment.id }
                        }
                        .linePayRowAction()
                    }
                }
                Button("Add other payment") { payments.append(WeeklyPaymentDraft()) }
                    .linePayRowAction()
                ConfirmationCheckRow(
                    "I reviewed every payment, inclusion/exclusion and credit classification for this week",
                    isOn: $remunerationComplete)
                Text(
                    "An overtime label alone does not qualify a credit. Unknown treatment requires review. This restricted calculation does not determine state/CBA, alternative-method or other legal coverage."
                )
                .font(.footnote)
                Button("Check this workweek") { calculate() }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .disabled(
                        !completeWorkweek || !remunerationComplete || !workweekBoundaryConfirmed
                    )
                    .accessibilityIdentifier("weekly.calculate")
            }
            if let result {
                Section("Result") {
                    LabeledContent(
                        "Qualifying hours", value: LinePayFormat.hours(result.qualifyingHours))
                    LabeledContent(
                        "Regular rate",
                        value: result.regularRate.map(LinePayFormat.money) ?? "Unavailable")
                    LabeledContent(
                        "Weekly overtime hours", value: LinePayFormat.hours(result.overtimeHours))
                    LabeledContent(
                        "Additional premium",
                        value: LinePayFormat.money(result.remainingAdditionalPremium))
                    LabeledContent(
                        "Reviewed includable remuneration",
                        value: LinePayFormat.money(result.includableRemuneration))
                    LabeledContent(
                        "Eligible extra-premium credit",
                        value: LinePayFormat.money(result.eligibleExtraPremiumCredit))
                    LabeledContent(
                        "Cash in this reviewed scope",
                        value: LinePayFormat.money(result.expectedCash))
                    Text(result.explanation).font(.footnote)
                }
                .labeledContentStyle(LinePayValueStyle())
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayCanvas()
        .linePayKeyboardDismiss()
        .onChange(of: weekStart) { _, _ in
            completeWorkweek = false
            workweekBoundaryConfirmed = false
            straightTimeAmount = ""
            payments = []
            clearPaymentReview()
        }
        .onChange(of: straightTimeAmount) { _, _ in clearPaymentReview() }
        .onChange(of: payments) { _, _ in clearPaymentReview() }
        .onChange(of: completeWorkweek) { _, _ in
            result = nil
            errorMessage = nil
        }
        .onChange(of: remunerationComplete) { _, _ in
            result = nil
            errorMessage = nil
        }
        .onChange(of: model.profile) { _, _ in
            completeWorkweek = false
            workweekBoundaryConfirmed = false
            clearPaymentReview()
        }
        .onChange(of: model.workEntries) { _, _ in
            completeWorkweek = false
            clearPaymentReview()
        }
        .onChange(of: model.history) { _, _ in
            completeWorkweek = false
            clearPaymentReview()
        }
        .onChange(of: workweekBoundaryConfirmed) { _, _ in
            result = nil
            errorMessage = nil
        }
        .environment(
            \.timeZone, TimeZone(identifier: zone) ?? .gmt
        )
        .navigationTitle("Weekly overtime")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func calculate() {
        do {
            result = try model.calculateWeeklyRegularRate(
                weekStart: weekStart, completeWorkweek: completeWorkweek,
                straightTimeRemuneration: Money(
                    amount: WeeklyPaymentDraft.amount(straightTimeAmount), currencyCode: currency),
                additionalRemuneration: payments.map { try $0.fact(currency: currency) },
                remunerationComplete: remunerationComplete,
                workweekBoundaryConfirmed: workweekBoundaryConfirmed)
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = Self.errorMessage(for: error)
        }
    }
    private var currency: String { model.profile?.agreement.hourlyRate.currencyCode ?? "USD" }
    private var zone: String {
        model.profile?.timeZoneIdentifier ?? model.currentTimeZoneIdentifier
    }
    private var boundaryEnd: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: zone) ?? .gmt
        return formatter.string(from: weekStart.addingTimeInterval(604_800))
    }
    private func clearPaymentReview() {
        remunerationComplete = false
        result = nil
        errorMessage = nil
    }
}

struct WeeklyPaymentDraft: Identifiable, Equatable {
    let id = UUID()
    var amount = ""
    var kind = ""
    var credit = ""
    static func amount(_ text: String) throws -> Decimal {
        try StrictDecimal.parse(
            text, maximum: 10_000_000, fractionDigits: 8,
            allowZero: true, allowDollarSign: true, decimalSeparator: NumberEntry.decimalSeparator)
    }
    func fact(currency: String) throws -> WeeklyRemunerationFact {
        guard let kind = WeeklyRemunerationKind(rawValue: kind) else {
            throw WeeklyRegularRateError.remunerationIncomplete
        }
        let treatment: WeeklyPremiumCredit
        if kind == .extraPremium {
            guard let selected = WeeklyPremiumCredit(rawValue: credit) else {
                throw WeeklyRegularRateError.remunerationIncomplete
            }
            treatment = selected
        } else {
            treatment = .notApplicable
        }
        return try WeeklyRemunerationFact(
            id: id, amount: Money(amount: Self.amount(amount), currencyCode: currency),
            kind: kind, premiumCredit: treatment)
    }
}
