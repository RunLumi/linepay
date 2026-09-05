import LinePayDomain
import SwiftUI

struct AddWorkView: View {
    let model: AppModel
    let existingEntry: WorkEntry?
    let template: WorkEntry?

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var kind: WorkKind
    @State private var note: String
    @State private var hasUnpaidBreak: Bool
    @State private var breakStart: Date
    @State private var breakEnd: Date
    @State private var errorMessage: String?

    init(
        model: AppModel,
        existingEntry: WorkEntry? = nil,
        template: WorkEntry? = nil
    ) {
        self.model = model
        self.existingEntry = existingEntry
        self.template = template

        if let existingEntry {
            let interval = existingEntry.interval
            let startDate = Date(timeIntervalSince1970: TimeInterval(interval.startEpochSeconds))
            let endDate = Date(timeIntervalSince1970: TimeInterval(interval.endEpochSeconds))
            let firstBreak = interval.unpaidBreaks.first

            _start = State(initialValue: startDate)
            _end = State(initialValue: endDate)
            _kind = State(initialValue: interval.kind)
            _note = State(initialValue: existingEntry.note)
            _hasUnpaidBreak = State(initialValue: firstBreak != nil)
            _breakStart = State(
                initialValue: firstBreak.map {
                    Date(timeIntervalSince1970: TimeInterval($0.startEpochSeconds))
                } ?? startDate.addingTimeInterval(4 * 60 * 60)
            )
            _breakEnd = State(
                initialValue: firstBreak.map {
                    Date(timeIntervalSince1970: TimeInterval($0.endEpochSeconds))
                } ?? startDate.addingTimeInterval(4.5 * 60 * 60)
            )
        } else if let template {
            let repeated = Self.repeatDates(template.interval, timeZone: Self.timeZone(for: model))
            _start = State(initialValue: repeated.start)
            _end = State(initialValue: repeated.end)
            _kind = State(initialValue: template.interval.kind)
            _note = State(initialValue: template.note)

            if let firstBreak = template.interval.unpaidBreaks.first {
                let breakStartOffset =
                    firstBreak.startEpochSeconds - template.interval.startEpochSeconds
                let breakEndOffset =
                    firstBreak.endEpochSeconds - template.interval.startEpochSeconds
                _hasUnpaidBreak = State(initialValue: true)
                _breakStart = State(
                    initialValue: repeated.start.addingTimeInterval(TimeInterval(breakStartOffset))
                )
                _breakEnd = State(
                    initialValue: repeated.start.addingTimeInterval(TimeInterval(breakEndOffset))
                )
            } else {
                _hasUnpaidBreak = State(initialValue: false)
                _breakStart = State(initialValue: repeated.start.addingTimeInterval(4 * 60 * 60))
                _breakEnd = State(initialValue: repeated.start.addingTimeInterval(4.5 * 60 * 60))
            }
        } else {
            let now = Date()
            _start = State(initialValue: now)
            _end = State(initialValue: now.addingTimeInterval(8 * 60 * 60))
            _kind = State(initialValue: .regular)
            _note = State(initialValue: "")
            _hasUnpaidBreak = State(initialValue: false)
            _breakStart = State(initialValue: now.addingTimeInterval(4 * 60 * 60))
            _breakEnd = State(initialValue: now.addingTimeInterval(4.5 * 60 * 60))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Start",
                        selection: $start,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "End",
                        selection: $end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("Actual clock time")
                } footer: {
                    Text("Record what actually happened. Overnight work should use the next date.")
                }

                Section("Work type") {
                    Picker("Work type", selection: $kind) {
                        Text("Regular").tag(WorkKind.regular)
                        Text("Callout").tag(WorkKind.callout)
                        Text("Other").tag(WorkKind.other)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Unpaid break", isOn: $hasUnpaidBreak)
                    if hasUnpaidBreak {
                        DatePicker(
                            "Break starts",
                            selection: $breakStart,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        DatePicker(
                            "Break ends",
                            selection: $breakEnd,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("Break")
                } footer: {
                    Text(
                        "LinePaycheck removes only the exact break span you enter. It never shortens the "
                            + "shift or guesses where a break happened."
                    )
                }

                Section("Note") {
                    TextField("Storm, crew, location, ticket…", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Preview") {
                    LabeledContent("Clock span") {
                        Text("\(LinePayFormat.hours(clockSpanHours)) h")
                            .monospacedDigit()
                    }
                    LabeledContent("Paid worked time") {
                        Text("\(LinePayFormat.hours(paidWorkedHours)) h")
                            .monospacedDigit()
                    }
                    if let profile = model.profile {
                        LabeledContent("Payroll timezone") {
                            Text(profile.timeZoneIdentifier)
                                .foregroundStyle(LinePayColor.textSecondary)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .environment(\.timeZone, payrollTimeZone)
        .tint(LinePayColor.brandPrimary)
    }

    private var screenTitle: String {
        if existingEntry != nil { return "Edit work" }
        if template != nil { return "Repeat shift" }
        return "Add work"
    }

    private var payrollTimeZone: TimeZone {
        Self.timeZone(for: model)
    }

    private var clockSpanHours: Decimal {
        max(0, Decimal(end.timeIntervalSince(start)) / 3_600)
    }

    private var paidWorkedHours: Decimal {
        let breakHours: Decimal =
            hasUnpaidBreak
            ? max(0, Decimal(breakEnd.timeIntervalSince(breakStart)) / 3_600)
            : 0
        return max(0, clockSpanHours - breakHours)
    }

    private func save() {
        do {
            if let existingEntry {
                try model.updateWork(
                    id: existingEntry.id,
                    start: start,
                    end: end,
                    kind: kind,
                    note: note,
                    unpaidBreakStart: hasUnpaidBreak ? breakStart : nil,
                    unpaidBreakEnd: hasUnpaidBreak ? breakEnd : nil
                )
            } else {
                try model.addWork(
                    start: start,
                    end: end,
                    kind: kind,
                    note: note,
                    unpaidBreakStart: hasUnpaidBreak ? breakStart : nil,
                    unpaidBreakEnd: hasUnpaidBreak ? breakEnd : nil
                )
            }
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func timeZone(for model: AppModel) -> TimeZone {
        guard let identifier = model.profile?.timeZoneIdentifier,
            let timeZone = TimeZone(identifier: identifier)
        else {
            return .current
        }
        return timeZone
    }

    private static func repeatDates(
        _ interval: WorkInterval,
        timeZone: TimeZone
    ) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let originalStart = Date(timeIntervalSince1970: TimeInterval(interval.startEpochSeconds))
        let originalComponents = calendar.dateComponents(
            [.hour, .minute, .second], from: originalStart)
        let today = calendar.dateComponents([.year, .month, .day], from: Date())

        var components = DateComponents()
        components.timeZone = timeZone
        components.year = today.year
        components.month = today.month
        components.day = today.day
        components.hour = originalComponents.hour
        components.minute = originalComponents.minute
        components.second = originalComponents.second

        let repeatedStart = calendar.date(from: components) ?? Date()
        let elapsed = interval.endEpochSeconds - interval.startEpochSeconds
        return (
            repeatedStart,
            repeatedStart.addingTimeInterval(TimeInterval(elapsed))
        )
    }
}
