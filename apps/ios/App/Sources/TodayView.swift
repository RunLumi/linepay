import LinePayDomain
import SwiftUI

struct TodayView: View {
    let model: AppModel

    @State private var showingAddWork = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    expectedPayHeader

                    Button {
                        showingAddWork = true
                    } label: {
                        Label("Add work", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LinePayColor.brandPrimary)

                    recentWork
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("Today")
        }
        .sheet(isPresented: $showingAddWork) {
            AddWorkView(model: model)
        }
    }

    private var expectedPayHeader: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
            Text("EXPECTED GROSS")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            Text(expectedPayText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(LinePayColor.textPrimary)
                .minimumScaleFactor(0.75)

            HStack(spacing: LinePaySpacing.standard) {
                Label(
                    "\(LinePayFormat.hours(model.totalHours)) h logged",
                    systemImage: "clock"
                )
                if let profile = model.profile {
                    Label(profile.name, systemImage: "doc.text")
                }
            }
            .font(.footnote)
            .foregroundStyle(LinePayColor.textSecondary)

            if let calculationError = model.calculationError {
                Label(calculationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private var recentWork: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("WORK LOG")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            if model.workIntervals.isEmpty {
                VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                    Text("No work logged yet")
                        .font(.headline)
                    Text("Add the hours you actually worked. Your expected pay updates immediately.")
                        .font(.callout)
                        .foregroundStyle(LinePayColor.textSecondary)
                }
                .padding(.vertical, LinePaySpacing.standard)
            } else {
                ForEach(model.workIntervals.reversed()) { interval in
                    workRow(interval)
                    Divider()
                }
            }
        }
    }

    private func workRow(_ interval: WorkInterval) -> some View {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workKindLabel(interval.kind))
                    .font(.headline)
                    .foregroundStyle(LinePayColor.textPrimary)

                Text(workDateRange(interval))
                    .font(.callout)
                    .foregroundStyle(LinePayColor.textSecondary)

                Text("\(LinePayFormat.hours(interval.durationHours)) h")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(LinePayColor.textSecondary)
            }

            Spacer()

            Button(role: .destructive) {
                model.deleteWork(id: interval.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete work interval")
        }
    }

    private var expectedPayText: String {
        guard let calculation = model.calculation else {
            return "$0.00"
        }
        return LinePayFormat.money(calculation.total)
    }

    private func workKindLabel(_ kind: WorkKind) -> String {
        switch kind {
        case .regular: "Regular work"
        case .callout: "Callout"
        case .other: "Other work"
        }
    }

    private func workDateRange(_ interval: WorkInterval) -> String {
        let start = Date(timeIntervalSince1970: TimeInterval(interval.startEpochSeconds))
        let end = Date(timeIntervalSince1970: TimeInterval(interval.endEpochSeconds))
        return start.formatted(date: .abbreviated, time: .shortened)
            + " – "
            + end.formatted(date: .abbreviated, time: .shortened)
    }
}
