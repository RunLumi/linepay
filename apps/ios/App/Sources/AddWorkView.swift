import Foundation
import LinePayDomain
import SwiftUI

struct AddWorkView: View {
    let model: AppModel
    let existingEntry: WorkEntry?
    let template: WorkEntry?
    let onDeleted: ((DeletedWorkUndo) -> Void)?
    let resumesPendingWork: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkDraft
    @State private var quick: Bool
    @State private var errorMessage: String?
    @State private var discardConfirmation = false
    @State private var viewingConflict: WorkEntry?

    init(
        model: AppModel, existingEntry: WorkEntry? = nil, template: WorkEntry? = nil,
        onDeleted: ((DeletedWorkUndo) -> Void)? = nil
    ) {
        self.model = model
        self.existingEntry = existingEntry
        self.template = template
        self.onDeleted = onDeleted
        let periodID = model.activePeriod?.id ?? UUID()
        resumesPendingWork = model.workDraft?.periodID == periodID
        let zone = TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
        if let saved = model.workDraft, saved.periodID == periodID {
            _draft = State(initialValue: saved)
        } else {
            let origin = existingEntry ?? template
            let start: Date
            let end: Date
            if let existingEntry {
                start = Date(
                    timeIntervalSince1970: TimeInterval(existingEntry.interval.startEpochSeconds))
                end = Date(
                    timeIntervalSince1970: TimeInterval(existingEntry.interval.endEpochSeconds))
            } else if let origin {
                let copied = Self.repeatDates(
                    origin.interval, day: Date(), zone: zone,
                    window: model.activePeriod?.window)
                start = copied.0
                end = copied.1
            } else {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = zone
                let day = max(
                    model.activePeriod?.window.startDate ?? Date(), calendar.startOfDay(for: Date())
                )
                let hour = model.activePeriod?.agreement.regularSchedule.first?.start.hour ?? 7
                let minute = model.activePeriod?.agreement.regularSchedule.first?.start.minute ?? 0
                start =
                    calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
                end = start.addingTimeInterval(8 * 3600)
            }
            let first = origin?.interval.unpaidBreaks.first
            let oldStart =
                origin.map { TimeInterval($0.interval.startEpochSeconds) }
                ?? start.timeIntervalSince1970
            let copiedFrom = template.map {
                Date(timeIntervalSince1970: TimeInterval($0.interval.startEpochSeconds))
            }
            let breakStartOffset: TimeInterval =
                first.map {
                    TimeInterval($0.startEpochSeconds) - oldStart
                } ?? 14_400
            let breakEndOffset: TimeInterval =
                first.map {
                    TimeInterval($0.endEpochSeconds) - oldStart
                } ?? 16_200
            var value = WorkDraft(
                periodID: periodID, editingEntryID: existingEntry?.id,
                start: start, end: end, kind: origin?.interval.kind ?? .regular,
                note: origin?.note ?? "", hasUnpaidBreak: first != nil,
                breakStart: start.addingTimeInterval(breakStartOffset),
                breakEnd: start.addingTimeInterval(breakEndOffset),
                copiedFrom: copiedFrom)
            value.additionalBreaks =
                origin?.interval.unpaidBreaks.dropFirst().map {
                    BreakDraft(
                        id: $0.id,
                        start: start.addingTimeInterval(
                            TimeInterval($0.startEpochSeconds) - oldStart),
                        end: start.addingTimeInterval(TimeInterval($0.endEpochSeconds) - oldStart))
                } ?? []
            _draft = State(initialValue: value)
        }
        _quick = State(initialValue: template != nil && !resumesPendingWork)
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    private var zone: TimeZone { TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current }
    private var conflict: WorkEntry? {
        model.conflictingWork(start: draft.start, end: draft.end, excluding: draft.editingEntryID)
    }
    private var worked: Decimal {
        let seconds = max(
            0,
            Int64(draft.end.timeIntervalSince1970.rounded())
                - Int64(draft.start.timeIntervalSince1970.rounded()))
        let breakSeconds =
            (draft.hasUnpaidBreak
                ? Int64(draft.breakEnd.timeIntervalSince(draft.breakStart).rounded()) : 0)
            + draft.additionalBreaks.reduce(0) {
                $0 + Int64($1.end.timeIntervalSince($1.start).rounded())
            }
        return Decimal(max(0, seconds - breakSeconds)) / 3600
    }
    var body: some View {
        NavigationStack {
            Form {
                if resumesPendingWork {
                    Section {
                        Text(
                            "Your work draft is saved on this device. Finish or discard it before starting a different entry."
                        )
                        .font(.footnote)
                    }
                }
                if quick {
                    Section("Repeat last shift") {
                        Text(workKindTitle(draft.kind)).font(.headline)
                        Text("\(clock(draft.start)) to \(clock(draft.end))")
                        Text(
                            "\(LinePayFormat.hours(worked)) worked hours, excluding the recorded breaks."
                        )
                        DatePicker(
                            "New date",
                            selection: Binding(
                                get: { draft.start },
                                set: { newDate in moveTemplate(newDate) }
                            ),
                            displayedComponents: .date)
                        Button("Edit details") { quick = false }
                    }
                } else {
                    Section("Actual work") {
                        Picker("Work type", selection: $draft.kind) {
                            Text("Regular").tag(WorkKind.regular)
                            Text("Callout").tag(WorkKind.callout)
                            Text("Other").tag(WorkKind.other)
                        }
                        DatePicker(
                            "Start", selection: $draft.start,
                            displayedComponents: [.date, .hourAndMinute]
                        ).accessibilityIdentifier("work.start")
                        DatePicker(
                            "End", selection: $draft.end,
                            displayedComponents: [.date, .hourAndMinute]
                        ).accessibilityIdentifier("work.end")
                        Text(
                            "An overnight shift uses the next date. Changing one field does not move another."
                        ).font(.footnote)
                    }
                    Section("Unpaid breaks") {
                        Toggle("Unpaid break", isOn: $draft.hasUnpaidBreak)
                        if draft.hasUnpaidBreak {
                            DatePicker("Break starts", selection: $draft.breakStart)
                            DatePicker("Break ends", selection: $draft.breakEnd)
                        }
                        ForEach($draft.additionalBreaks) { $item in
                            DatePicker("Additional break starts", selection: $item.start)
                            DatePicker("Additional break ends", selection: $item.end)
                            Button("Remove break", role: .destructive) {
                                draft.additionalBreaks.removeAll { $0.id == item.id }
                            }
                        }
                        Button("Add another break") {
                            draft.additionalBreaks.append(
                                BreakDraft(
                                    start: draft.start.addingTimeInterval(6 * 3600),
                                    end: draft.start.addingTimeInterval(6.5 * 3600)))
                        }
                    }
                    Section("Note") {
                        TextField("Storm, crew, ticket", text: $draft.note, axis: .vertical)
                            .lineLimit(1...5).accessibilityIdentifier("work.note")
                    }
                }
                Section("Preview") {
                    LabeledContent("Actual worked time", value: "\(LinePayFormat.hours(worked)) h")
                    Text("Payroll timezone: \(model.currentTimeZoneIdentifier)").font(.footnote)
                    Text(
                        "Guaranteed paid time is calculated separately, never added to your clock record."
                    ).font(.footnote)
                }
                if let conflict {
                    Section {
                        Label(
                            "Overlaps \(LinePayFormat.workDateRange(conflict.interval))",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(LinePayColor.review)
                        Button("View conflicting entry") { viewingConflict = conflict }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
                Section {
                    Button(quick ? "Save same shift" : "Save work") { save() }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .disabled(conflict != nil || draft.end <= draft.start)
                        .accessibilityIdentifier("work.save")
                    Button("Discard this draft", role: .destructive) { discardConfirmation = true }
                    if let existingEntry = model.workEntries.first(where: {
                        $0.id == draft.editingEntryID
                    }) {
                        Button("Delete work", role: .destructive) {
                            if let undo = model.deleteWork(id: existingEntry.id) {
                                onDeleted?(undo)
                                dismiss()
                            } else {
                                errorMessage = model.lastPersistenceError
                            }
                        }.frame(minHeight: 48).accessibilityIdentifier("work.delete")
                    }
                }
            }
            .scrollContentBackground(.hidden).background(LinePayColor.canvas)
            .linePayKeyboardDismiss()
            .navigationTitle(
                draft.editingEntryID != nil ? "Edit work" : quick ? "Repeat shift" : "Add work"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep draft") { dismiss() }.accessibilityIdentifier("work.cancel")
                }
            }
        }
        .environment(\.timeZone, zone)
        .tint(LinePayColor.actionText)
        .onChange(of: draft, initial: true) { _, value in
            do { try model.saveWorkDraft(value) } catch {
                errorMessage = "Draft could not be saved. Your earlier records are unchanged."
            }
        }
        .sheet(item: $viewingConflict) { item in
            NavigationStack {
                List {
                    Text(LinePayFormat.workDateRange(item.interval))
                    Text(item.note)
                }
                .navigationTitle("Conflicting work")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { viewingConflict = nil }
                    }
                }
            }
        }
        .confirmationDialog(
            "Discard this unfinished entry?", isPresented: $discardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard draft", role: .destructive) {
                do {
                    try model.saveWorkDraft(nil)
                    dismiss()
                } catch { errorMessage = error.localizedDescription }
            }
        }
    }
    private func save() {
        do {
            let extra = try draft.additionalBreaks.map {
                try WorkBreak(
                    id: $0.id,
                    startEpochSeconds: Int64($0.start.timeIntervalSince1970.rounded()),
                    endEpochSeconds: Int64($0.end.timeIntervalSince1970.rounded()))
            }
            if let id = draft.editingEntryID {
                try model.updateWork(
                    id: id, start: draft.start, end: draft.end, kind: draft.kind, note: draft.note,
                    unpaidBreakStart: draft.hasUnpaidBreak ? draft.breakStart : nil,
                    unpaidBreakEnd: draft.hasUnpaidBreak ? draft.breakEnd : nil,
                    additionalBreaks: extra)
            } else {
                try model.addWork(
                    start: draft.start, end: draft.end, kind: draft.kind, note: draft.note,
                    unpaidBreakStart: draft.hasUnpaidBreak ? draft.breakStart : nil,
                    unpaidBreakEnd: draft.hasUnpaidBreak ? draft.breakEnd : nil,
                    additionalBreaks: extra)
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
    private func moveTemplate(_ date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let days =
            calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: draft.start),
                to: calendar.startOfDay(for: date)
            ).day ?? 0
        func shift(_ value: Date) -> Date {
            calendar.date(byAdding: .day, value: days, to: value) ?? value
        }
        draft.start = shift(draft.start)
        draft.end = shift(draft.end)
        draft.breakStart = shift(draft.breakStart)
        draft.breakEnd = shift(draft.breakEnd)
        for index in draft.additionalBreaks.indices {
            draft.additionalBreaks[index].start = shift(draft.additionalBreaks[index].start)
            draft.additionalBreaks[index].end = shift(draft.additionalBreaks[index].end)
        }
    }
    private static func repeatDates(
        _ interval: WorkInterval, day: Date, zone: TimeZone,
        window: PayPeriodWindow?
    ) -> (Date, Date) {
        var original = Calendar(identifier: .gregorian)
        original.timeZone = TimeZone(identifier: interval.timeZoneIdentifier) ?? zone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let a = Date(timeIntervalSince1970: TimeInterval(interval.startEpochSeconds))
        let b = Date(timeIntervalSince1970: TimeInterval(interval.endEpochSeconds))
        let aClock = original.dateComponents([.hour, .minute], from: a)
        let bClock = original.dateComponents([.hour, .minute], from: b)
        let offset =
            original.dateComponents(
                [.day], from: original.startOfDay(for: a), to: original.startOfDay(for: b)
            ).day ?? 0
        let target = max(calendar.startOfDay(for: day), window?.startDate ?? day)
        let endDay = calendar.date(byAdding: .day, value: offset, to: target) ?? target
        return (
            calendar.date(
                bySettingHour: aClock.hour ?? 7, minute: aClock.minute ?? 0, second: 0, of: target)
                ?? target,
            calendar.date(
                bySettingHour: bClock.hour ?? 15, minute: bClock.minute ?? 0, second: 0, of: endDay)
                ?? endDay
        )
    }
}
