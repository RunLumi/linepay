import SwiftUI

struct StartPayPeriodView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var errorMessage: String?

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
        .tint(LinePayColor.brandPrimary)
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
