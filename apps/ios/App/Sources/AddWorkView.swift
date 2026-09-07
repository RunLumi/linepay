import Foundation
import LinePayDomain
import SwiftUI

struct AddWorkView: View {
    let model: AppModel
    let existingEntry: WorkEntry?
    let onDeleted: ((DeletedWorkUndo) -> Void)?
    let resumesPendingWork: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkDraft
    @State private var errorMessage: String?
    @State private var discardConfirmation = false
    @State private var viewingConflict: WorkEntry?
    @State private var isClosing = false
    @State private var separateAdjacentCalloutConfirmed = false

    init(
        model: AppModel,
        existingEntry: WorkEntry? = nil,
        onDeleted: ((DeletedWorkUndo) -> Void)? = nil
    ) {
        self.model = model
        self.existingEntry = existingEntry
        self.onDeleted = onDeleted

        let periodID = model.activePeriod?.id ?? UUID()
        let saved = model.workDraft
        let canResumeSavedDraft =
            existingEntry == nil && saved?.periodID == periodID && saved?.templateSource == nil
        resumesPendingWork = canResumeSavedDraft

        if canResumeSavedDraft, let saved {
            _draft = State(initialValue: saved)
        } else if let existingEntry {
            let start = Date(
                timeIntervalSince1970: TimeInterval(existingEntry.interval.startEpochSeconds))
            let end = Date(
                timeIntervalSince1970: TimeInterval(existingEntry.interval.endEpochSeconds))
            let first = existingEntry.interval.unpaidBreaks.first
            _draft = State(
                initialValue: WorkDraft(
                    periodID: periodID,
                    editingEntryID: existingEntry.id,
                    start: start,
                    end: end,
                    kind: existingEntry.interval.kind,
                    note: existingEntry.note,
                    hasUnpaidBreak: first != nil,
                    breakStart: first.map {
                        Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds))
                    } ?? start.addingTimeInterval(4 * 3_600),
                    breakEnd: first.map {
                        Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds))
                    } ?? start.addingTimeInterval(4.5 * 3_600),
                    copiedFrom: nil,
                    calloutEventID: existingEntry.interval.calloutEventID,
                    additionalBreaks: existingEntry.interval.unpaidBreaks.dropFirst().map {
                        BreakDraft(
                            id: $0.id,
                            start: Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds)),
                            end: Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds)))
                    }))
        } else {
            let zone = TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let today = calendar.startOfDay(for: Date())
            let periodStart = model.activePeriod?.window.startDate ?? today
            let periodEnd = model.activePeriod?.window.displayEndDate ?? today
            let day = min(max(today, periodStart), periodEnd)
            let hour = model.activePeriod?.agreement.regularSchedule.first?.start.hour ?? 7
            let minute = model.activePeriod?.agreement.regularSchedule.first?.start.minute ?? 0
            let start =
                calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            let end = start.addingTimeInterval(8 * 3_600)
            _draft = State(
                initialValue: WorkDraft(
                    periodID: periodID,
                    editingEntryID: nil,
                    start: start,
                    end: end,
                    kind: .regular,
                    note: "",
                    hasUnpaidBreak: false,
                    breakStart: start.addingTimeInterval(4 * 3_600),
                    breakEnd: start.addingTimeInterval(4.5 * 3_600),
                    copiedFrom: nil))
        }
    }

    private var zone: TimeZone {
        TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
    }

    private var conflict: WorkEntry? {
        model.conflictingWork(start: draft.start, end: draft.end, excluding: draft.editingEntryID)
    }

    private var adjacentCallouts: [WorkEntry] {
        guard draft.kind == .callout else { return [] }
        return CalloutEntryWorkflow.adjacentCallouts(
            start: draft.start,
            end: draft.end,
            excluding: draft.editingEntryID,
            entries: model.workEntries)
    }

    private var newCalloutNeedsDecision: Bool {
        draft.kind == .callout && draft.editingEntryID == nil && !adjacentCallouts.isEmpty
            && !separateAdjacentCalloutConfirmed
    }

    private var legacyCalloutNeedsReview: Bool {
        draft.kind == .callout && draft.editingEntryID != nil && draft.calloutEventID == nil
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
        return Decimal(max(0, seconds - breakSeconds)) / 3_600
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

                Section("Actual work") {
                    Picker("Work type", selection: $draft.kind) {
                        Text("Regular").tag(WorkKind.regular)
                        Text("Callout").tag(WorkKind.callout)
                        Text("Other").tag(WorkKind.other)
                    }
                    DatePicker(
                        "Start", selection: $draft.start,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("work.start")
                    DatePicker(
                        "End", selection: $draft.end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("work.end")
                    Text(
                        "An overnight shift uses the next date. Changing one field does not move another."
                    ).font(.footnote)
                }

                if draft.kind == .callout {
                    calloutEventSection
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
                                start: draft.start.addingTimeInterval(6 * 3_600),
                                end: draft.start.addingTimeInterval(6.5 * 3_600)))
                    }
                }

                Section("Note") {
                    TextField("Storm, crew, ticket", text: $draft.note, axis: .vertical)
                        .lineLimit(1...5)
                        .accessibilityIdentifier("work.note")
                }

                Section("Preview") {
                    LabeledContent(
                        "Actual worked time", value: "\(LinePayFormat.hours(worked)) h")
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
                    Button("Save work") { save() }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .disabled(
                            conflict != nil || draft.end <= draft.start || newCalloutNeedsDecision
                                || legacyCalloutNeedsReview)
                        .accessibilityIdentifier("work.save")
                    Button("Discard this draft", role: .destructive) { discardConfirmation = true }
                    if let existingEntry = model.workEntries.first(where: {
                        $0.id == draft.editingEntryID
                    }) {
                        Button("Delete work", role: .destructive) {
                            isClosing = true
                            if let undo = model.deleteWork(id: existingEntry.id) {
                                onDeleted?(undo)
                                dismiss()
                            } else {
                                isClosing = false
                                errorMessage = model.lastPersistenceError
                            }
                        }
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("work.delete")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .linePayKeyboardDismiss()
            .navigationTitle(draft.editingEntryID != nil ? "Edit work" : "Add work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep draft") {
                        do {
                            isClosing = true
                            try model.saveWorkDraft(draft)
                            dismiss()
                        } catch {
                            isClosing = false
                            errorMessage = error.localizedDescription
                        }
                    }
                    .accessibilityIdentifier("work.cancel")
                }
            }
        }
        .environment(\.timeZone, zone)
        .tint(LinePayColor.actionText)
        .onChange(of: draft) { _, value in
            guard !isClosing else { return }
            do { try model.saveWorkDraft(value) } catch {
                errorMessage = "Draft could not be saved. Your earlier records are unchanged."
            }
        }
        .onChange(of: draft.kind) { _, _ in
            separateAdjacentCalloutConfirmed = false
        }
        .onChange(of: draft.start) { _, _ in
            separateAdjacentCalloutConfirmed = false
        }
        .onChange(of: draft.end) { _, _ in
            separateAdjacentCalloutConfirmed = false
        }
        .sheet(item: $viewingConflict) { item in
            NavigationStack {
                List {
                    Text(LinePayFormat.workDateRange(item.interval))
                    if !item.note.isEmpty { Text(item.note) }
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
                    isClosing = true
                    try model.saveWorkDraft(nil)
                    dismiss()
                } catch {
                    isClosing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private var calloutEventSection: some View {
        Section("Callout event") {
            if legacyCalloutNeedsReview {
                Label(
                    "This older callout has no confirmed event identity.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(LinePayColor.review)
                Text(
                    "Do not let LinePaycheck guess whether older rows were one call or several. Confirm this row as one event, or merge it with an adjacent segment only when you know they were the same physical callout."
                )
                .font(.footnote)
                Button("Confirm this row is one callout event") {
                    draft.calloutEventID = UUID()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("work.callout-confirm-event")
            }

            if draft.editingEntryID == nil {
                if adjacentCallouts.isEmpty {
                    Text(
                        "One Callout entry represents one physical callout event. If later work is part of this same call, extend this entry instead of adding another event."
                    )
                    .font(.footnote)
                } else {
                    Label(
                        adjacentCallouts.count == 1
                            ? "This segment touches an existing callout."
                            : "This segment touches more than one existing callout.",
                        systemImage: "link"
                    )
                    Text(
                        "If this is continued work from the same physical call, merge it into the matching callout. If a new triggering call happened, explicitly confirm that it is separate."
                    )
                    .font(.footnote)
                    ForEach(adjacentCallouts) { callout in
                        Button(
                            "Continue existing callout · \(LinePayFormat.workDateRange(callout.interval))"
                        ) {
                            mergeDraftInto(callout)
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("work.callout-continue")
                    }
                    Toggle(
                        "This is a separate callout",
                        isOn: $separateAdjacentCalloutConfirmed
                    )
                    .accessibilityIdentifier("work.callout-separate")
                }
            } else {
                Text(
                    "Keep one physical callout as one row in this version of LinePaycheck. If this row was split from an adjacent segment of the same call, merge them below."
                )
                .font(.footnote)
                ForEach(adjacentCallouts) { callout in
                    Button(
                        "Merge adjacent callout · \(LinePayFormat.workDateRange(callout.interval))"
                    ) {
                        mergeSavedCallout(with: callout)
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("work.callout-merge")
                }
            }

            Text(
                "Callout grouping does not create a pay rule. If your confirmed rules include a minimum, that minimum is evaluated once per physical callout event; actual worked time stays unchanged."
            )
            .font(.footnote)
        }
    }

    private func draftBreaks() throws -> [WorkBreak] {
        var breaks: [WorkBreak] = []
        if draft.hasUnpaidBreak {
            breaks.append(
                try WorkBreak(
                    startEpochSeconds: Int64(draft.breakStart.timeIntervalSince1970.rounded()),
                    endEpochSeconds: Int64(draft.breakEnd.timeIntervalSince1970.rounded())))
        }
        breaks.append(
            contentsOf: try draft.additionalBreaks.map {
                try WorkBreak(
                    id: $0.id,
                    startEpochSeconds: Int64($0.start.timeIntervalSince1970.rounded()),
                    endEpochSeconds: Int64($0.end.timeIntervalSince1970.rounded()))
            })
        return breaks.sorted { $0.startEpochSeconds < $1.startEpochSeconds }
    }

    private func apply(_ plan: CalloutMergePlan, to entryID: UUID) throws {
        let first = plan.breaks.first
        try model.updateWork(
            id: entryID,
            start: plan.start,
            end: plan.end,
            kind: .callout,
            note: plan.note,
            unpaidBreakStart: first.map {
                Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds))
            },
            unpaidBreakEnd: first.map {
                Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds))
            },
            additionalBreaks: Array(plan.breaks.dropFirst()))
    }

    private func mergeDraftInto(_ existing: WorkEntry) {
        do {
            let plan = try CalloutEntryWorkflow.merge(
                existing: existing,
                segmentStart: draft.start,
                segmentEnd: draft.end,
                segmentNote: draft.note,
                segmentBreaks: draftBreaks())
            isClosing = true
            try apply(plan, to: existing.id)
            dismiss()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }

    private func mergeSavedCallout(with adjacent: WorkEntry) {
        guard let currentID = draft.editingEntryID,
            let current = model.workEntries.first(where: { $0.id == currentID })
        else {
            errorMessage = "The callout being edited is no longer available."
            return
        }
        do {
            let plan = try CalloutEntryWorkflow.merge(current, adjacent)
            isClosing = true
            guard let undo = model.deleteWork(id: adjacent.id) else {
                isClosing = false
                errorMessage = model.lastPersistenceError ?? "The adjacent callout could not be merged."
                return
            }
            do {
                try apply(plan, to: currentID)
                dismiss()
            } catch {
                do {
                    try model.restoreWork(undo)
                    isClosing = false
                    errorMessage = "The merge was not saved. Both original callout rows were restored. \(error.localizedDescription)"
                } catch let restoreError {
                    isClosing = false
                    errorMessage =
                        "The merge failed and the adjacent row could not be restored automatically. Preserve your records and contact support. \(restoreError.localizedDescription)"
                }
            }
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            isClosing = true
            let extra = try draft.additionalBreaks.map {
                try WorkBreak(
                    id: $0.id,
                    startEpochSeconds: Int64($0.start.timeIntervalSince1970.rounded()),
                    endEpochSeconds: Int64($0.end.timeIntervalSince1970.rounded()))
            }
            if let id = draft.editingEntryID {
                try model.updateWork(
                    id: id,
                    start: draft.start,
                    end: draft.end,
                    kind: draft.kind,
                    note: draft.note,
                    unpaidBreakStart: draft.hasUnpaidBreak ? draft.breakStart : nil,
                    unpaidBreakEnd: draft.hasUnpaidBreak ? draft.breakEnd : nil,
                    additionalBreaks: extra)
            } else {
                try model.addWork(
                    start: draft.start,
                    end: draft.end,
                    kind: draft.kind,
                    note: draft.note,
                    unpaidBreakStart: draft.hasUnpaidBreak ? draft.breakStart : nil,
                    unpaidBreakEnd: draft.hasUnpaidBreak ? draft.breakEnd : nil,
                    additionalBreaks: extra)
            }
            dismiss()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }
}
