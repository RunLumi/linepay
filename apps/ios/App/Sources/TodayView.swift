import LinePayDomain
import SwiftUI

struct TodayView: View {
    let model: AppModel
    var onOpenHistory: () -> Void = {}
    var onOpenPay: () -> Void = {}
    @State private var showingAdd = false
    @State private var showingRepeatDraft = false
    @State private var showingStart = false
    @State private var editing: WorkEntry?
    @State private var repeating: WorkEntry?
    @State private var undo: DeletedWorkUndo?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let active = model.activePeriod {
                    Section {
                        Text(
                            LinePayFormat.payPeriod(
                                active.window, timeZoneIdentifier: model.currentTimeZoneIdentifier)
                        ).font(.subheadline)
                        PayAmount(
                            label: "Expected wages", money: model.calculation?.expectedWages,
                            prominent: true
                        )
                        .accessibilityIdentifier("today.expected-wages")
                        if let allowance = model.calculation?.expectedAllowances,
                            allowance.amount > 0
                        {
                            PayAmount(label: "Separate expected per diem", money: allowance)
                        }
                        Text("\(LinePayFormat.hours(model.totalHours)) actual worked hours").font(
                            .footnote)
                        if let problem = model.calculationError {
                            CalculationProblemView(message: problem)
                        }
                        if !(active.agreement.unsupportedRuleNotes ?? "").isEmpty {
                            Label(
                                "Some agreement rules are not configured",
                                systemImage: "exclamationmark.triangle"
                            ).foregroundStyle(LinePayColor.review)
                        }
                    }
                    Section {
                        if let last = model.lastWorkEntry {
                            Button("Repeat last shift") { repeating = last }
                                .frame(minHeight: 48)
                                .disabled(model.workDraft != nil)
                                .accessibilityIdentifier("today.repeat-shift")
                            if model.workDraft != nil {
                                Text(
                                    "Finish or discard the saved work draft before repeating, editing, or deleting another shift."
                                )
                                .font(.footnote)
                                .foregroundStyle(LinePayColor.textSecondary)
                            }
                        }
                        Button(workButtonTitle) {
                            if model.workDraft?.templateSource != nil {
                                showingRepeatDraft = true
                            } else {
                                showingAdd = true
                            }
                        }
                        .buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                            "today.add-work")
                        Button("Check paycheck") { onOpenPay() }.frame(minHeight: 44)
                            .accessibilityIdentifier("today.open-pay")
                    }
                    Section("Work log") {
                        if model.workEntries.isEmpty {
                            Text("No work logged this period. Record what actually happened.")
                        }
                        ForEach(model.workEntries.reversed()) { entry in
                            Button {
                                editing = entry
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(workKindTitle(entry.interval.kind)).font(.headline)
                                    Text(LinePayFormat.workDateRange(entry.interval)).font(.callout)
                                    Text(
                                        "\(LinePayFormat.hours(entry.interval.durationHours)) actual h"
                                    ).monospacedDigit()
                                    if let text = LinePayFormat.breakDuration(entry.interval) {
                                        Text(text).font(.footnote)
                                    }
                                    if !entry.note.isEmpty { Text(entry.note).font(.footnote) }
                                }.foregroundStyle(LinePayColor.textPrimary).padding(.vertical, 6)
                            }
                            .accessibilityIdentifier("today.edit-work")
                            .disabled(model.workDraft != nil)
                            .swipeActions {
                                if model.workDraft == nil {
                                    Button("Delete", role: .destructive) {
                                        undo = model.deleteWork(id: entry.id)
                                    }
                                }
                            }
                            .contextMenu {
                                if model.workDraft == nil {
                                    Button("Delete work", role: .destructive) {
                                        undo = model.deleteWork(id: entry.id)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Ready for the next work period").font(.title2.bold())
                        Button("Start pay period") { showingStart = true }.buttonStyle(
                            LinePayPrimaryButtonStyle())
                    }
                }

                let pending = model.history.filter { $0.paystub == nil }.count
                if pending > 0 {
                    Section {
                        Button("\(pending) closed work period(s) awaiting a paycheck") {
                            onOpenHistory()
                        }.frame(minHeight: 44)
                    }
                }

                if let error = errorMessage ?? model.lastPersistenceError {
                    Section { Text(error).foregroundStyle(LinePayColor.review) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .navigationTitle("Today")
            .safeAreaInset(edge: .bottom) {
                if let undo {
                    HStack {
                        Text("Work deleted")
                        Spacer()
                        Button("Undo") {
                            do {
                                try model.restoreWork(undo)
                                self.undo = nil
                            } catch {
                                errorMessage = error.localizedDescription
                                self.undo = nil
                            }
                        }
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("today.undo-delete")
                    }
                    .padding(.horizontal, 24)
                    .background(LinePayColor.surfacePrimary)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddWorkView(model: model) }
        .sheet(isPresented: $showingRepeatDraft) { RepeatWorkView(model: model) }
        .sheet(isPresented: $showingStart) { StartPayPeriodView(model: model) }
        .sheet(item: $editing) {
            AddWorkView(model: model, existingEntry: $0, onDeleted: { undo = $0 })
        }
        .sheet(item: $repeating) { RepeatWorkView(model: model, source: $0) }
        .onChange(of: model.activePeriod?.id) { _, _ in undo = nil }
        .onChange(of: model.currentWorkRevision) { _, revision in
            if let undo, undo.expectedRevision != revision { self.undo = nil }
        }
    }

    private var workButtonTitle: String {
        if model.workDraft?.templateSource != nil { return "Resume repeated shift" }
        return model.workDraft != nil ? "Resume work draft" : "Add work"
    }
}
