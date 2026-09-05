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
        calendar.timeZone = TimeZone(identifier: model.profile?.timeZoneIdentifier ?? "") ?? .current
        let start = calendar.startOfDay(for: Date())
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
                        "This creates a new pay-period boundary. Archived periods are never reinterpreted."
                    )
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
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
