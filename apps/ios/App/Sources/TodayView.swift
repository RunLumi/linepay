import LinePayDomain
import SwiftUI

struct TodayView: View {
    let model: AppModel
    let onOpenPay: () -> Void

    @State private var showingAddWork = false
    @State private var showingStartPeriod = false
    @State private var editingEntry: WorkEntry?
    @State private var repeatingEntry: WorkEntry?
    @State private var deletedEntry: WorkEntry?
    @State private var undoError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    if let active = model.activePeriod {
                        expectedPayHeader(active)
                        primaryActions
                        auditState
                        recentWork
                    } else {
                        noActivePeriod
                    }
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .labeledContentStyle(LinePayValueStyle())
            .navigationTitle("Today")
            .safeAreaInset(edge: .bottom) {
                if let deletedEntry {
                    undoBar(deletedEntry)
                }
            }
        }
        .sheet(isPresented: $showingAddWork) {
            AddWorkView(model: model)
        }
        .sheet(isPresented: $showingStartPeriod) {
            StartPayPeriodView(model: model)
        }
        .sheet(item: $editingEntry) { entry in
            AddWorkView(model: model, existingEntry: entry)
        }
        .sheet(item: $repeatingEntry) { entry in
            AddWorkView(model: model, template: entry)
        }
    }

    private func expectedPayHeader(_ active: ActivePayPeriod) -> some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
            Text("Expected gross")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LinePayColor.textSecondary)

            Text(expectedPayText)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(LinePayColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.expected-pay")

            Text(
                LinePayFormat.payPeriod(
                    active.window,
                    timeZoneIdentifier: model.currentTimeZoneIdentifier
                )
            )
            .font(.subheadline)
            .foregroundStyle(LinePayColor.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Label(
                    "\(LinePayFormat.hours(model.totalHours)) h recorded",
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
                    .foregroundStyle(LinePayColor.difference)
            }
        }
    }

    private var primaryActions: some View {
        VStack(spacing: LinePaySpacing.compact) {
            Button {
                showingAddWork = true
            } label: {
                Label("Add work", systemImage: "plus")
            }
            .buttonStyle(LinePayPrimaryButtonStyle())
            .accessibilityIdentifier("today.add-work")

            if let last = model.lastWorkEntry {
                Button {
                    repeatingEntry = last
                } label: {
                    Label("Repeat last shift", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(LinePayColor.actionText)
                .accessibilityIdentifier("today.repeat-shift")
            }
        }
    }

    private var auditState: some View {
        Button(action: onOpenPay) {
            HStack(alignment: .center, spacing: LinePaySpacing.standard) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paycheck")
                        .font(.headline)
                        .foregroundStyle(LinePayColor.textSecondary)
                    AuditStatusView(status: model.currentAuditStatus)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LinePayColor.textSecondary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .padding(.vertical, LinePaySpacing.compact)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.open-pay")
    }

    private var recentWork: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("Work log")
                .font(.headline)
                .foregroundStyle(LinePayColor.textSecondary)

            if model.workEntries.isEmpty {
                VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                    Text("No work logged yet")
                        .font(.headline)
                    Text("Add what actually happened. Expected pay updates immediately.")
                        .font(.callout)
                        .foregroundStyle(LinePayColor.textSecondary)
                }
                .padding(.vertical, LinePaySpacing.standard)
            } else {
                ForEach(model.workEntries.reversed()) { entry in
                    workRow(entry)
                    Divider()
                }
            }
        }
    }

    private func workRow(_ entry: WorkEntry) -> some View {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            Button {
                editingEntry = entry
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workKindLabel(entry.interval.kind))
                        .font(.headline)
                        .foregroundStyle(LinePayColor.textPrimary)

                    Text(LinePayFormat.workDateRange(entry.interval))
                        .font(.callout)
                        .foregroundStyle(LinePayColor.textSecondary)

                    HStack(spacing: LinePaySpacing.compact) {
                        Text("\(LinePayFormat.hours(entry.interval.durationHours)) h")
                            .monospacedDigit()
                        if let breakText = LinePayFormat.breakDuration(entry.interval) {
                            Text("· \(breakText)")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)

                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.footnote)
                            .foregroundStyle(LinePayColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today.edit-work")

            Button(role: .destructive) {
                deletedEntry = model.deleteWork(id: entry.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete work interval")
            .accessibilityIdentifier("today.delete-work")
        }
    }

    private var noActivePeriod: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.section) {
            Text("Ready for the next check")
                .font(.title2.bold())
                .foregroundStyle(LinePayColor.textPrimary)
            Text(
                "Your last manual pay period is finished. Start the next one before logging work."
            )
            .foregroundStyle(LinePayColor.textSecondary)
            Button {
                showingStartPeriod = true
            } label: {
                Label("Start pay period", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(LinePayPrimaryButtonStyle())
        }
    }

    private func undoBar(_ entry: WorkEntry) -> some View {
        HStack(spacing: LinePaySpacing.standard) {
            Text(undoError ?? "Work entry deleted")
                .font(.callout)
            Spacer()
            Button("Undo") {
                do {
                    try model.restoreWork(entry)
                    deletedEntry = nil
                    undoError = nil
                } catch {
                    undoError = error.localizedDescription
                }
            }
            .fontWeight(.semibold)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("today.undo-delete")
        }
        .padding(.horizontal, LinePaySpacing.section)
        .padding(.vertical, LinePaySpacing.standard)
        .background(LinePayColor.surfaceSecondary)
    }

    private var expectedPayText: String {
        guard let calculation = model.calculation else { return "$0.00" }
        return LinePayFormat.money(calculation.total)
    }

    private func workKindLabel(_ kind: WorkKind) -> String {
        switch kind {
        case .regular: "Regular work"
        case .callout: "Callout"
        case .other: "Other work"
        }
    }
}
