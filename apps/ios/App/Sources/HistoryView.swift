import SwiftUI

struct HistoryView: View {
    let model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                    Text("History starts with persistence")
                        .font(.title3.bold())
                        .foregroundStyle(LinePayColor.textPrimary)

                    Text(
                        "The current implementation keeps this session in memory while we finish "
                            + "the core calculation flow. Versioned local persistence is the next "
                            + "slice so historical pay never changes meaning after a rule edit."
                    )
                    .foregroundStyle(LinePayColor.textSecondary)

                    if !model.workIntervals.isEmpty {
                        Divider()

                        LabeledContent("Current session") {
                            Text("\(LinePayFormat.hours(model.totalHours)) h")
                                .monospacedDigit()
                        }
                    }
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("History")
        }
    }
}
