import Foundation
import LinePayDomain
import SwiftUI

struct RepeatWorkView: View {
    let model: AppModel
    let source: WorkEntry?
    let resumesPendingWork: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkDraft
    @State private var quick: Bool
    @State private var errorMessage: String?
    @State private var discardConfirmation = false
    @State private var viewingConflict: WorkEntry?
    @State private var isClosing = false

    init(model: AppModel, source: WorkEntry? = nil) {
        self.model = model
        self.source = source
        let periodID = model.activePeriod?.id ?? UUID()
        let saved = model.workDraft
        let savedRepeat = saved?.periodID == periodID && saved?.templateSource != nil
        resumesPendingWork = savedRepeat

        if savedRepeat, let saved {
            _draft = State(initialValue: saved)
            _quick = State(initialValue: true)
            _errorMessage = State(initialValue: nil)
        } else if let source {
            do {
                let value = try RepeatWorkDraft.make(
                    source: source,
                    periodID: periodID,
                    day: Date(),
                    timeZoneIdentifier: model.currentTimeZoneIdentifier,
                    window: model.activePeriod?.window)
                _draft = State(initialValue: value)
                _quick = State(initialValue: true)
                _errorMessage = State(initialValue: nil)
            } catch {
                _draft = State(initialValue: Self.fallbackDraft(source: source, periodID: periodID))
                _quick = State(initialValue: false)
                _errorMessage = State(
                    initialValue:
                        "The copied clock times could not be prepared safely. Review every date and time before saving."
                )
            }
        } else {
            _draft = State(initialValue: Self.emptyDraft(periodID: periodID))
            _quick = State(initialValue: false)
            _errorMessage = State(
                initialValue: "The repeated-shift draft is unavailable. Return to Today and choose Repeat last shift again."
            )
        }
    }

    private var zone: TimeZone {
        TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
    }

    private var proposal: WorkTemplateProposal? {
        try? RepeatWorkDraft.proposal(
            for: draft, timeZoneIdentifier: model.currentTimeZoneIdentifier)
    }

    private var reviewPoints: [WorkTemplatePoint] {
        proposal?.points.filter { $0.candidates.count != 1 } ?? []
    }

    private var hasNonexistentTime: Bool {
        reviewPoints.contains { $0.candidates.isEmpty }
    }

    private var conflict: WorkEntry? {
        model.conflictingWork(start: draft.start, end: draft.end, excluding: nil)
    }

    private var withinCurrentPeriod: Bool {
        model.activePeriod?.window.contains(start: draft.start, end: draft.end) == true
    }

    private var canConfirmManualTimes: Bool {
        RepeatWorkDraft.canConfirmManualReview(
            draft,
            timeZoneIdentifier: model.currentTimeZoneIdentifier,
            window: model.activePeriod?.window)
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
                            "Your repeated-shift draft is saved on this device. Finish it or discard it before starting another entry."
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
                                get: { draft.templateDay ?? draft.start },
                                set: { moveRepeat(to: $0) }
                            ),
                            displayedComponents: .date
                        )
                        .accessibilityIdentifier("repeat.date")
                        Button("Edit details") { quick = false }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("repeat.edit-details")
                    }
                } else {
                    Section("Actual work") {
                        Picker("Work type", selection: $draft.kind) {
                            Text("Regular").tag(WorkKind.regular)
                            Text("Callout").tag(WorkKind.callout)
                            Text("Other").tag(WorkKind.other)
                        }
                        DatePicker(
                            "Start", selection: manualBinding(\.start),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityIdentifier("repeat.start")
                        DatePicker(
                            "End", selection: manualBinding(\.end),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityIdentifier("repeat.end")
                        Text(
                            "An overnight shift uses the next date. Changing one field does not move another."
                        ).font(.footnote)
                    }
                    Section("Unpaid breaks") {
                        Toggle("Unpaid break", isOn: $draft.hasUnpaidBreak)
                        if draft.hasUnpaidBreak {
                            DatePicker("Break starts", selection: manualBinding(\.breakStart))
                            DatePicker("Break ends", selection: manualBinding(\.breakEnd))
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
                    }
                }

                templateReview

                Section("Preview") {
                    LabeledContent(
                        "Actual worked time", value: "\(LinePayFormat.hours(worked)) h")
                    Text("Payroll timezone: \(model.currentTimeZoneIdentifier)").font(.footnote)
                    Text(
                        "Guaranteed paid time is calculated separately, never added to your clock record."
                    ).font(.footnote)
                    if !withinCurrentPeriod {
                        Label(
                            "This repeated shift falls outside the current work period. Choose another date or review the times.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(LinePayColor.review)
                    }
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
                        .disabled(
                            conflict != nil || draft.end <= draft.start || !withinCurrentPeriod
                                || draft.templateUnresolved == true)
                        .accessibilityIdentifier("repeat.save")
                    Button("Discard this draft", role: .destructive) {
                        discardConfirmation = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .linePayKeyboardDismiss()
            .navigationTitle(quick ? "Repeat shift" : "Review repeated shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep draft") { keepDraft() }
                        .accessibilityIdentifier("repeat.keep-draft")
                }
            }
        }
        .environment(\.timeZone, zone)
        .tint(LinePayColor.actionText)
        .interactiveDismissDisabled()
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, value in
            guard !isClosing else { return }
            do { try model.saveWorkDraft(value) } catch {
                errorMessage = "Draft could not be saved. Your earlier records are unchanged."
            }
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
            "Discard this repeated shift?", isPresented: $discardConfirmation,
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
    private var templateReview: some View {
        if draft.templateUnresolved == true {
            Section("Clock-time review") {
                Label("Repeated shift needs your review", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(LinePayColor.review)
                Text(
                    "Daylight-saving changes can make a local clock time occur twice or not exist. LinePaycheck will not silently turn that copied clock time into a work fact."
                )
                .font(.footnote)

                ForEach(reviewPoints) { point in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(point.label).font(.headline)
                        Text(point.wallTime).font(.callout.monospaced())
                        if point.candidates.isEmpty {
                            Text(
                                "This local time does not exist on the selected date. Edit the actual time below, then confirm the manual time review."
                            )
                            .font(.footnote)
                            .foregroundStyle(LinePayColor.review)
                        } else {
                            Picker("Occurrence", selection: choiceBinding(point.key)) {
                                Text("Choose occurrence").tag(Optional<RepeatedTimeChoice>.none)
                                Text("First occurrence").tag(Optional(RepeatedTimeChoice.first))
                                Text("Second occurrence").tag(Optional(RepeatedTimeChoice.last))
                            }
                            .accessibilityIdentifier("repeat.occurrence.\(point.key)")
                            ForEach(Array(point.candidates.enumerated()), id: \.offset) { index, date in
                                Text(
                                    "\(index == 0 ? "First" : "Second"): \(candidateLabel(date))"
                                )
                                .font(.footnote.monospacedDigit())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if proposal?.isResolved == true, !withinCurrentPeriod {
                    Text(
                        "The copied clock times are valid, but the resulting shift is outside this work period. Choose another New date or edit the actual times."
                    )
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.review)
                }

                if !quick && (hasNonexistentTime || proposal?.isResolved == true) {
                    Button("Confirm reviewed manual times") {
                        do {
                            try RepeatWorkDraft.confirmManualReview(
                                &draft,
                                timeZoneIdentifier: model.currentTimeZoneIdentifier,
                                window: model.activePeriod?.window)
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .frame(minHeight: 48)
                    .disabled(!canConfirmManualTimes)
                    .accessibilityIdentifier("repeat.confirm-manual-times")
                    Text(
                        "This confirmation means every unresolved copied clock time now shown is an actual fact you reviewed, not an automatic DST correction."
                    )
                    .font(.footnote)
                }
            }
        }
    }

    private func manualBinding(_ keyPath: WritableKeyPath<WorkDraft, Date>) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0 })
    }

    private func choiceBinding(_ key: String) -> Binding<RepeatedTimeChoice?> {
        Binding(
            get: { draft.repeatedTimeChoices?[key] },
            set: { choice in
                do {
                    _ = try RepeatWorkDraft.choose(
                        choice,
                        for: key,
                        draft: &draft,
                        timeZoneIdentifier: model.currentTimeZoneIdentifier,
                        window: model.activePeriod?.window)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            })
    }

    private func moveRepeat(to date: Date) {
        do {
            _ = try RepeatWorkDraft.move(
                &draft,
                to: date,
                timeZoneIdentifier: model.currentTimeZoneIdentifier,
                window: model.activePeriod?.window)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func candidateLabel(_ date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "−"
        let absolute = abs(seconds)
        let hours = absolute / 3_600
        let minutes = (absolute % 3_600) / 60
        return String(
            format: "%@ · UTC%@%02d:%02d", clock(date), sign, hours, minutes)
    }

    private func persistDraft() {
        guard !isClosing else { return }
        do { try model.saveWorkDraft(draft) } catch {
            errorMessage = "Draft could not be saved. Your earlier records are unchanged."
        }
    }

    private func keepDraft() {
        do {
            isClosing = true
            try model.saveWorkDraft(draft)
            dismiss()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard draft.templateUnresolved != true else {
            errorMessage = "Resolve or manually review the copied clock times before saving."
            return
        }
        guard withinCurrentPeriod else {
            errorMessage = "The repeated shift must stay inside the current work period."
            return
        }
        guard conflict == nil else {
            errorMessage = "Review the conflicting work entry before saving."
            return
        }
        do {
            isClosing = true
            let extra = try draft.additionalBreaks.map {
                try WorkBreak(
                    id: $0.id,
                    startEpochSeconds: Int64($0.start.timeIntervalSince1970.rounded()),
                    endEpochSeconds: Int64($0.end.timeIntervalSince1970.rounded()))
            }
            try model.addWork(
                start: draft.start,
                end: draft.end,
                kind: draft.kind,
                note: draft.note,
                unpaidBreakStart: draft.hasUnpaidBreak ? draft.breakStart : nil,
                unpaidBreakEnd: draft.hasUnpaidBreak ? draft.breakEnd : nil,
                additionalBreaks: extra)
            dismiss()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }

    private static func fallbackDraft(source: WorkEntry, periodID: UUID) -> WorkDraft {
        let start = Date(timeIntervalSince1970: TimeInterval(source.interval.startEpochSeconds))
        let end = Date(timeIntervalSince1970: TimeInterval(source.interval.endEpochSeconds))
        let first = source.interval.unpaidBreaks.first
        return WorkDraft(
            periodID: periodID,
            editingEntryID: nil,
            start: start,
            end: end,
            kind: source.interval.kind,
            note: source.note,
            hasUnpaidBreak: first != nil,
            breakStart: first.map { Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds)) }
                ?? start.addingTimeInterval(4 * 3_600),
            breakEnd: first.map { Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds)) }
                ?? start.addingTimeInterval(4.5 * 3_600),
            copiedFrom: start,
            templateSource: source.interval,
            templateDay: Date(),
            repeatedTimeChoices: [:],
            templateUnresolved: true,
            additionalBreaks: source.interval.unpaidBreaks.dropFirst().map {
                BreakDraft(
                    id: $0.id,
                    start: Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds)),
                    end: Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds)))
            })
    }

    private static func emptyDraft(periodID: UUID) -> WorkDraft {
        let start = Date()
        return WorkDraft(
            periodID: periodID,
            editingEntryID: nil,
            start: start,
            end: start.addingTimeInterval(8 * 3_600),
            kind: .regular,
            note: "",
            hasUnpaidBreak: false,
            breakStart: start.addingTimeInterval(4 * 3_600),
            breakEnd: start.addingTimeInterval(4.5 * 3_600),
            copiedFrom: nil,
            templateUnresolved: true)
    }
}
