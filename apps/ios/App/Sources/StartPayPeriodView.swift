import SwiftUI

struct StartPayPeriodView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: model.profile?.timeZoneIdentifier ?? "") ?? .current
        let start = Self.proposedStart(
            afterHistory: model.history.map(\.window), calendar: calendar, now: Date())
        _startDate = State(initialValue: start)
        _endDate = State(
            initialValue: calendar.date(byAdding: .day, value: 6, to: start) ?? start
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let profile = model.profile {
                        LabeledContent("Cadence", value: profile.preferredCadence.title)
                    }
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    if model.profile?.preferredCadence == .manual {
                        DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                    }
                } footer: {
                    Text(
                        "Choose the first day of your next pay period. Closed periods keep their dates and results."
                    )
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LinePayColor.review)
                    }
                }
            }
            .linePayCanvas()
            .navigationTitle("Start pay period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                        .fontWeight(.semibold)
                }
            }
        }
        .environment(\.timeZone, payrollTimeZone)
        .tint(LinePayColor.brandPrimary)
    }

    /// Continues where the last closed period ended, so periods stay contiguous by default. After
    /// a timezone change, local midnight can fall before the old period's end; never propose an
    /// overlapping start.
    static func proposedStart(
        afterHistory windows: [PayPeriodWindow], calendar: Calendar, now: Date
    ) -> Date {
        guard let endSeconds = windows.map(\.endEpochSeconds).max() else {
            return calendar.startOfDay(for: now)
        }
        let lastEnd = Date(timeIntervalSince1970: TimeInterval(endSeconds))
        let start = calendar.startOfDay(for: lastEnd)
        guard start < lastEnd else { return start }
        return calendar.date(byAdding: .day, value: 1, to: start) ?? lastEnd
    }

    private var payrollTimeZone: TimeZone {
        TimeZone(identifier: model.profile?.timeZoneIdentifier ?? "") ?? .current
    }

    private func start() {
        do {
            try model.startNewPayPeriod(
                startDate: startDate,
                manualEndDate: model.profile?.preferredCadence == .manual ? endDate : nil
            )
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
