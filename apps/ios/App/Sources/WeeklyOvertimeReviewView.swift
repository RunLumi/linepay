import LinePayDomain
import SwiftUI

struct WeeklyOvertimeReviewView: View {
    let model: AppModel
    @State private var weekStart: Date
    @State private var completeWorkweek = false
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
                DatePicker("Workweek starts", selection: $weekStart, displayedComponents: .date)
                ConfirmationCheckRow(
                    "Every shift in this workweek is logged", isOn: $completeWorkweek)
                Button("Check this workweek") { calculate() }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .disabled(!completeWorkweek)
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
                    LabeledContent("Expected cash", value: LinePayFormat.money(result.expectedCash))
                    Text(result.explanation).font(.footnote)
                }
                .labeledContentStyle(LinePayValueStyle())
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayCanvas()
        .environment(
            \.timeZone, TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
        )
        .navigationTitle("Weekly overtime")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func calculate() {
        do {
            result = try model.calculateWeeklyRegularRate(
                weekStart: weekStart, completeWorkweek: completeWorkweek)
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = Self.errorMessage(for: error)
        }
    }
}
