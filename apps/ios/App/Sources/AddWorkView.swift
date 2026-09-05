import LinePayDomain
import SwiftUI

struct AddWorkView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var kind: WorkKind = .regular
    @State private var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        let now = Date()
        _start = State(initialValue: now)
        _end = State(initialValue: now.addingTimeInterval(8 * 60 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.section) {
                    Text(
                        "Record what actually happened. LinePay uses the timezone from your "
                            + "pay profile."
                    )
                    .font(.callout)
                    .foregroundStyle(LinePayColor.textSecondary)

                    VStack(spacing: LinePaySpacing.standard) {
                        DatePicker(
                            "Start",
                            selection: $start,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Divider()

                        DatePicker(
                            "End",
                            selection: $end,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                        Text("WORK TYPE")
                            .font(.caption.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(LinePayColor.textSecondary)

                        Picker("Work type", selection: $kind) {
                            Text("Regular").tag(WorkKind.regular)
                            Text("Callout").tag(WorkKind.callout)
                            Text("Other").tag(WorkKind.other)
                        }
                        .pickerStyle(.segmented)
                    }

                    if let profile = model.profile {
                        LabeledContent("Timezone") {
                            Text(profile.timeZoneIdentifier)
                                .foregroundStyle(LinePayColor.textSecondary)
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("Add work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .environment(\.timeZone, payrollTimeZone)
        .tint(LinePayColor.brandPrimary)
    }

    private var payrollTimeZone: TimeZone {
        guard
            let identifier = model.profile?.timeZoneIdentifier,
            let timeZone = TimeZone(identifier: identifier)
        else {
            return .current
        }
        return timeZone
    }

    private func save() {
        do {
            try model.addWork(start: start, end: end, kind: kind)
            errorMessage = nil
            dismiss()
        } catch {
            if end <= start {
                errorMessage =
                    "End must be later than start. Overnight work should use the next date."
            } else {
                errorMessage =
                    "This work interval conflicts with existing work or your current rules."
            }
        }
    }
}
