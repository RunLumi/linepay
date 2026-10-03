import Foundation
import LinePayDomain
import SwiftUI

struct AddWorkView: View {
    let model: AppModel
    let existingEntry: WorkEntry?
    let onDeleted: ((DeletedWorkUndo) -> Void)?
    /// Fixed when the sheet first appears. SwiftUI re-creates this view after the draft autosaves,
    /// so recomputing these from the store would misread a brand-new entry as a resumed draft.
    @State private var resumesPendingWork: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkDraft
    @State private var errorMessage: String?
    @State private var discardConfirmation = false
    @State private var viewingConflict: WorkEntry?
    @State private var isClosing = false
    @State private var separateAdjacentCalloutConfirmed = false
    @State private var cancelConfirmation = false
    /// What the sheet opened with. Closing an untouched sheet must not leave a draft behind that
    /// would block repeating, editing, or deleting other shifts.
    @State private var initialDraft: WorkDraft

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
        _resumesPendingWork = State(initialValue: canResumeSavedDraft)

        let initial: WorkDraft
        if canResumeSavedDraft, let saved {
            initial = saved
        } else if let existingEntry {
            let start = Date(
                timeIntervalSince1970: TimeInterval(existingEntry.interval.startEpochSeconds))
            let end = Date(
                timeIntervalSince1970: TimeInterval(existingEntry.interval.endEpochSeconds))
            let first = existingEntry.interval.unpaidBreaks.first
            initial = WorkDraft(
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
                })
        } else {
            let (start, end) = Self.suggestedInterval(model: model, now: Date())
            initial = WorkDraft(
                periodID: periodID,
                editingEntryID: nil,
                start: start,
                end: end,
                kind: .regular,
                note: "",
                hasUnpaidBreak: false,
                breakStart: start.addingTimeInterval(4 * 3_600),
                breakEnd: start.addingTimeInterval(4.5 * 3_600),
                copiedFrom: nil)
        }
        _draft = State(initialValue: initial)
        _initialDraft = State(initialValue: initial)
    }

    private var zone: TimeZone {
        TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
    }

    /// The usual start time today, inside the period. When that would overlap a shift already
    /// logged that day, suggest the next day instead, so a new entry never opens in conflict.
    static func suggestedInterval(model: AppModel, now: Date) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
        let today = calendar.startOfDay(for: now)
        let periodStart = model.activePeriod?.window.startDate ?? today
        let periodEnd = model.activePeriod?.window.displayEndDate ?? today
        let hour = model.activePeriod?.agreement.regularSchedule.first?.start.hour ?? 7
        let minute = model.activePeriod?.agreement.regularSchedule.first?.start.minute ?? 0
        func interval(on day: Date) -> (start: Date, end: Date) {
            let start =
                calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            return (start, start.addingTimeInterval(8 * 3_600))
        }
        var day = calendar.startOfDay(for: min(max(today, periodStart), periodEnd))
        for _ in 0..<31 {
            let candidate = interval(on: day)
            guard
                model.conflictingWork(start: candidate.start, end: candidate.end, excluding: nil)
                    != nil
            else { return candidate }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day),
                next <= periodEnd
            else { break }
            day = next
        }
        // Every day is taken: keep today's suggestion and let the overlap warning explain it.
        return interval(on: calendar.startOfDay(for: min(max(today, periodStart), periodEnd)))
    }

    private var conflict: WorkEntry? {
        // A just-saved entry overlaps the closing draft; never flash that as a conflict.
        guard !isClosing else { return nil }
        return model.conflictingWork(
            start: draft.start, end: draft.end, excluding: draft.editingEntryID)
    }

    private var isDirty: Bool { draft != initialDraft }

    /// Shown only for a draft that could be saved as-is; overlapping or undecided callout drafts
    /// would otherwise preview a total the saved record will never have.
    private var wagesChange: Money? {
        guard conflict == nil, draft.end > draft.start, !newCalloutNeedsDecision,
            !legacyCalloutNeedsReview
        else { return nil }
        return model.expectedWagesChange(saving: draft)
    }

    private var periodRange: ClosedRange<Date>? {
        guard let window = model.activePeriod?.window else { return nil }
        return window.startDate...window.displayEndDate
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
                    Group {
                        if let periodRange {
                            DatePicker(
                                "Start", selection: $draft.start, in: periodRange,
                                displayedComponents: [.date, .hourAndMinute])
                        } else {
                            DatePicker(
                                "Start", selection: $draft.start,
                                displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    .accessibilityIdentifier("work.start")
                    DatePicker(
                        "End", selection: $draft.end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("work.end")
                    Text(
                        "An overnight shift ends on the next date. Changing one field does not move another."
                    ).font(.footnote)
                    if let window = model.activePeriod?.window {
                        Text(
                            "This pay period: \(LinePayFormat.payPeriod(window, timeZoneIdentifier: model.currentTimeZoneIdentifier))"
                        )
                        .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                    }
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
                    if let change = wagesChange {
                        LabeledContent(
                            draft.editingEntryID == nil
                                ? "Adds to expected wages" : "Changes expected wages by"
                        ) {
                            Text(
                                draft.editingEntryID == nil
                                    ? LinePayFormat.money(change)
                                    : LinePayFormat.signedMoney(change)
                            )
                            .font(.headline).monospacedDigit()
                        }
                        .accessibilityIdentifier("work.wages-preview")
                    }
                    Text(
                        "Payroll timezone: \(LinePayFormat.timeZoneName(model.currentTimeZoneIdentifier))"
                    ).font(.footnote)
                    Text(
                        "Guaranteed paid time is calculated separately, never added to your clock record."
                    ).font(.footnote)
                }

                if let conflict {
                    Section {
                        Label(
                            "Overlaps a logged shift: \(LinePayFormat.shiftTimes(conflict.interval)). Change the start or end time.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(LinePayColor.review)
                        Button("View that shift") { viewingConflict = conflict }
                    }
                }

                Section {
                    if resumesPendingWork {
                        Button("Discard this draft", role: .destructive) {
                            discardConfirmation = true
                        }
                        .frame(minHeight: 44)
                    }
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
            .linePayCanvas()
            .linePayKeyboardDismiss()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LinePayBottomBar {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(LinePayColor.review)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("work.error")
                    }
                    Button(draft.editingEntryID != nil ? "Save changes" : "Save work") { save() }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .disabled(
                            conflict != nil || draft.end <= draft.start || newCalloutNeedsDecision
                                || legacyCalloutNeedsReview
                        )
                        .accessibilityIdentifier("work.save")
                }
            }
            .navigationTitle(draft.editingEntryID != nil ? "Edit work" : "Add work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isDirty {
                            cancelConfirmation = true
                        } else {
                            closeUnchanged()
                        }
                    }
                    .accessibilityIdentifier("work.cancel")
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
                .linePayCanvas()
                .navigationTitle("Conflicting work")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { viewingConflict = nil }
                    }
                }
            }
        }
        .confirmationDialog(
            "Keep your changes?", isPresented: $cancelConfirmation, titleVisibility: .visible
        ) {
            Button("Keep as draft") {
                do {
                    isClosing = true
                    try model.saveWorkDraft(draft)
                    dismiss()
                } catch {
                    isClosing = false
                    errorMessage = error.localizedDescription
                }
            }
            .accessibilityIdentifier("work.keep-draft")
            Button("Discard changes", role: .destructive) {
                do {
                    isClosing = true
                    // A resumed draft returns to how it was saved; a new or edited entry
                    // leaves no draft behind. Saved work is never touched here.
                    try model.saveWorkDraft(resumesPendingWork ? initialDraft : nil)
                    dismiss()
                } catch {
                    isClosing = false
                    errorMessage = error.localizedDescription
                }
            }
        } message: {
            Text("A draft stays on this iPhone so you can finish it later.")
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

    private func closeUnchanged() {
        do {
            isClosing = true
            if !resumesPendingWork, model.workDraft == draft { try model.saveWorkDraft(nil) }
            dismiss()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
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
            model.workEntries.contains(where: { $0.id == currentID })
        else {
            errorMessage = "The callout being edited is no longer available."
            return
        }
        do {
            // Use the visible draft facts, not a stale saved copy. A worker may correct the
            // current row and merge it in the same review without losing those unsaved changes.
            let plan = try CalloutEntryWorkflow.merge(
                existing: adjacent,
                segmentStart: draft.start,
                segmentEnd: draft.end,
                segmentNote: draft.note,
                segmentBreaks: draftBreaks())
            isClosing = true
            guard let undo = model.deleteWork(id: adjacent.id) else {
                isClosing = false
                errorMessage =
                    model.lastPersistenceError ?? "The adjacent callout could not be merged."
                return
            }
            do {
                try apply(plan, to: currentID)
                dismiss()
            } catch {
                do {
                    try model.restoreWork(undo)
                    isClosing = false
                    errorMessage =
                        "The merge was not saved. The adjacent callout was restored and your edits remain in this draft. \(error.localizedDescription)"
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
