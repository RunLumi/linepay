import Foundation
import LinePayDomain
import SwiftUI

struct RepeatWorkView: View {
    let model: AppModel
    let source: WorkEntry?
    /// Fixed when the sheet first appears; see `AddWorkView.resumesPendingWork`.
    @State private var resumesPendingWork: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkDraft
    @State private var quick: Bool
    @State private var errorMessage: String?
    @State private var discardConfirmation = false
    @State private var viewingConflict: WorkEntry?
    @State private var isClosing = false
    @State private var cancelConfirmation = false
    /// The proposal as first shown. Leaving it untouched must not strand a draft that blocks
    /// editing other shifts.
    @State private var initialDraft: WorkDraft?

    init(model: AppModel, source: WorkEntry? = nil) {
        self.model = model
        self.source = source
        let periodID = model.activePeriod?.id ?? UUID()
        let saved = model.workDraft
        let savedRepeat = saved?.periodID == periodID && saved?.templateSource != nil
        _resumesPendingWork = State(initialValue: savedRepeat)

        if savedRepeat, let saved {
            _draft = State(initialValue: saved)
            _quick = State(initialValue: true)
            _errorMessage = State(initialValue: nil)
        } else if let source {
            do {
                let value = try Self.firstOpenRepeat(
                    model: model, source: source, periodID: periodID, from: Date())
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
                initialValue:
                    "The repeated-shift draft is unavailable. Return to Today and choose Repeat last shift again."
            )
        }
    }

    /// Repeats `source` on the first day, from `from` onward within the open period, where the
    /// copy would not overlap logged work. Repeating today's shift therefore proposes tomorrow
    /// instead of opening in conflict. Falls back to the clamped requested day.
    static func firstOpenRepeat(
        model: AppModel, source: WorkEntry, periodID: UUID, from: Date
    ) throws -> WorkDraft {
        let zoneID = model.currentTimeZoneIdentifier
        let window = model.activePeriod?.window
        let first = try RepeatWorkDraft.make(
            source: source, periodID: periodID, day: from, timeZoneIdentifier: zoneID,
            window: window)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zoneID) ?? .current
        var day = first.templateDay ?? calendar.startOfDay(for: from)
        var candidate = first
        for _ in 0..<31 {
            let free =
                model.conflictingWork(start: candidate.start, end: candidate.end, excluding: nil)
                == nil
            if free, window?.contains(start: candidate.start, end: candidate.end) ?? true {
                return candidate
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day),
                window.map({ next <= $0.displayEndDate }) ?? true
            else { break }
            day = next
            candidate = try RepeatWorkDraft.make(
                source: source, periodID: periodID, day: day, timeZoneIdentifier: zoneID,
                window: window)
        }
        return first
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
        guard !isClosing else { return nil }
        return model.conflictingWork(start: draft.start, end: draft.end, excluding: nil)
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
                            "Start", selection: manualBinding("start", \.start),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityIdentifier("repeat.start")
                        DatePicker(
                            "End", selection: manualBinding("end", \.end),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityIdentifier("repeat.end")
                        Text(
                            "An overnight shift uses the next date. Changing one field does not move another."
                        ).font(.footnote)
                    }
                    Section("Unpaid breaks") {
                        Toggle("Unpaid break", isOn: firstBreakToggle)
                        if draft.hasUnpaidBreak {
                            DatePicker(
                                "Break starts",
                                selection: manualBinding("break.0.start", \.breakStart))
                            DatePicker(
                                "Break ends",
                                selection: manualBinding("break.0.end", \.breakEnd))
                        }
                        ForEach(draft.additionalBreaks) { item in
                            DatePicker(
                                "Additional break starts",
                                selection: additionalBreakBinding(
                                    id: item.id, endpoint: .start))
                            DatePicker(
                                "Additional break ends",
                                selection: additionalBreakBinding(
                                    id: item.id, endpoint: .end))
                            Button("Remove break", role: .destructive) {
                                markSourceBreakReview(id: item.id, endpoint: .start)
                                markSourceBreakReview(id: item.id, endpoint: .end)
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
                    if conflict == nil, withinCurrentPeriod, draft.templateUnresolved != true,
                        draft.end > draft.start,
                        let change = model.expectedWagesChange(saving: draft)
                    {
                        LabeledContent("Adds to expected wages") {
                            Text(LinePayFormat.money(change)).font(.headline).monospacedDigit()
                        }
                        .accessibilityIdentifier("repeat.wages-preview")
                    }
                    Text(
                        "Payroll timezone: \(LinePayFormat.timeZoneName(model.currentTimeZoneIdentifier))"
                    ).font(.footnote)
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
                            "Overlaps a logged shift: \(LinePayFormat.shiftTimes(conflict.interval)). Choose another date or time.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(LinePayColor.review)
                        Button("View that shift") { viewingConflict = conflict }
                    }
                }

                if resumesPendingWork {
                    Section {
                        Button("Discard this draft", role: .destructive) {
                            discardConfirmation = true
                        }
                        .frame(minHeight: 44)
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
                    }
                    Button(quick ? "Save same shift" : "Save work") { save() }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .disabled(
                            conflict != nil || draft.end <= draft.start || !withinCurrentPeriod
                                || draft.templateUnresolved == true
                        )
                        .accessibilityIdentifier("repeat.save")
                }
            }
            .navigationTitle(quick ? "Repeat shift" : "Review repeated shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let initialDraft, draft != initialDraft {
                            cancelConfirmation = true
                        } else {
                            closeUnchanged()
                        }
                    }
                    .accessibilityIdentifier("repeat.keep-draft")
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .environment(\.timeZone, zone)
        .tint(LinePayColor.actionText)
        .interactiveDismissDisabled()
        .onAppear {
            if initialDraft == nil { initialDraft = draft }
            persistDraft()
        }
        .confirmationDialog(
            "Keep your changes?", isPresented: $cancelConfirmation, titleVisibility: .visible
        ) {
            Button("Keep as draft") { keepDraft() }
            Button("Discard changes", role: .destructive) {
                do {
                    isClosing = true
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
                Label(
                    "Repeated shift needs your review", systemImage: "clock.badge.exclamationmark"
                )
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
                            ForEach(Array(point.candidates.enumerated()), id: \.offset) {
                                index, date in
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

    private enum BreakEndpoint {
        case start, end
    }

    private var firstBreakToggle: Binding<Bool> {
        Binding(
            get: { draft.hasUnpaidBreak },
            set: { enabled in
                draft.hasUnpaidBreak = enabled
                if !enabled {
                    RepeatWorkDraft.markManualReview("break.0.start", draft: &draft)
                    RepeatWorkDraft.markManualReview("break.0.end", draft: &draft)
                }
            })
    }

    private func manualBinding(
        _ key: String,
        _ keyPath: WritableKeyPath<WorkDraft, Date>
    ) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                draft[keyPath: keyPath] = value
                RepeatWorkDraft.markManualReview(key, draft: &draft)
            })
    }

    private func additionalBreakBinding(id: UUID, endpoint: BreakEndpoint) -> Binding<Date> {
        Binding(
            get: {
                guard let item = draft.additionalBreaks.first(where: { $0.id == id }) else {
                    return draft.start
                }
                return endpoint == .start ? item.start : item.end
            },
            set: { value in
                guard let index = draft.additionalBreaks.firstIndex(where: { $0.id == id }) else {
                    return
                }
                switch endpoint {
                case .start:
                    draft.additionalBreaks[index].start = value
                case .end:
                    draft.additionalBreaks[index].end = value
                }
                markSourceBreakReview(id: id, endpoint: endpoint)
            })
    }

    private func markSourceBreakReview(id: UUID, endpoint: BreakEndpoint) {
        guard let source = draft.templateSource,
            let index = source.unpaidBreaks.firstIndex(where: { $0.id == id })
        else { return }
        let suffix = endpoint == .start ? "start" : "end"
        RepeatWorkDraft.markManualReview("break.\(index).\(suffix)", draft: &draft)
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

    private func closeUnchanged() {
        do {
            isClosing = true
            // A resumed draft stays as it was saved; an untouched new proposal leaves nothing.
            if !resumesPendingWork { try model.saveWorkDraft(nil) }
            dismiss()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
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
            breakStart: first.map {
                Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds))
            }
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
