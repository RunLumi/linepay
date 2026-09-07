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
        _weekStart = State(initialValue: weekStart)
    }

    static func errorMessage(for error: any Error) -> String {
        "Needs review: \(error.localizedDescription)"
    }

    var body: some View {
        List {
            Section("Restricted weekly layer") {
                Text(
                    "This review covers one complete workweek for the configured covered/nonexempt hourly profile. It is not a nationwide legal or CBA determination."
                ).font(.footnote)
                DatePicker("Workweek starts", selection: $weekStart, displayedComponents: .date)
                Toggle("I confirm this workweek is complete", isOn: $completeWorkweek)
                Button("Calculate weekly regular rate") { calculate() }
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
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
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
