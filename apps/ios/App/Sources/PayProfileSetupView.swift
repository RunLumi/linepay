import LinePayDomain
import SwiftUI

struct PayProfileSetupView: View {
    let model: AppModel
    let showsIntro: Bool
    let onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PayProfileDraft
    @State private var errorMessage: String?
    @FocusState private var isEditing: String?

    init(
        model: AppModel,
        showsIntro: Bool = true,
        onSaved: (() -> Void)? = nil
    ) {
        self.model = model
        self.showsIntro = showsIntro
        self.onSaved = onSaved
        if let profile = model.profile {
            _draft = State(
                initialValue: PayProfileDraft(
                    profile: profile,
                    activePeriod: model.activePeriod
                )
            )
        } else {
            _draft = State(initialValue: PayProfileDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsIntro {
                    Section {
                        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                            Text("Know what your work should pay.")
                                .font(.title2.bold())
                            Text(
                                "Confirm only the rules that actually apply. Optional rules start off."
                            )
                            .foregroundStyle(LinePayColor.textSecondary)
                            lineGap
                        }
                        .padding(.vertical, LinePaySpacing.compact)
                    }
                }

                Section {
                    LinePayTextField(
                        "Profile name", text: $draft.name, focus: $isEditing,
                        identifier: "pay-profile.name")
                    LinePayTextField(
                        "Base hourly rate (USD)", text: $draft.hourlyRate, focus: $isEditing,
                        identifier: "pay-profile.hourly-rate"
                    )
                    .keyboardType(.decimalPad)
                    .monospacedDigit()

                    Picker("Payroll timezone", selection: $draft.timeZoneIdentifier) {
                        if !Self.usTimeZones.contains(where: {
                            $0.identifier == draft.timeZoneIdentifier
                        }) {
                            Text(draft.timeZoneIdentifier).tag(draft.timeZoneIdentifier)
                        }
                        ForEach(Self.usTimeZones, id: \.identifier) { option in
                            Text(option.name).tag(option.identifier)
                        }
                    }
                } header: {
                    Text("Pay profile")
                } footer: {
                    Text("Enter decimals with a point or comma, without thousands separators.")
                }

                Section {
                    Picker("Pay cadence", selection: $draft.preferredCadence) {
                        ForEach(PayPeriodCadence.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                    DatePicker(
                        model.profile == nil ? "Current period starts" : "Next period starts",
                        selection: $draft.periodStartDate,
                        displayedComponents: .date
                    )
                    if draft.preferredCadence == .manual {
                        DatePicker(
                            "Period ends",
                            selection: $draft.manualPeriodEndDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Pay period")
                } footer: {
                    if model.profile == nil {
                        Text(
                            "Choose the boundary that matches the paycheck you are currently earning."
                        )
                    } else {
                        Text(
                            "Changing cadence affects future periods only. The current and archived "
                                + "period boundaries keep their original meaning."
                        )
                    }
                }

                Section {
                    Toggle("Regular schedule", isOn: $draft.useRegularSchedule)
                    if draft.useRegularSchedule {
                        weekdaySelector
                        DatePicker(
                            "Scheduled start",
                            selection: $draft.regularStartTime,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "Scheduled end",
                            selection: $draft.regularEndTime,
                            displayedComponents: .hourAndMinute
                        )
                        LinePayTextField(
                            "Outside-schedule multiplier",
                            text: $draft.outsideScheduleMultiplier, focus: $isEditing
                        )
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Regular schedule")
                } footer: {
                    Text(
                        "Enable only if your agreement pays a different multiplier outside a defined "
                            + "schedule. Overnight schedule windows are not approximated in 1.0."
                    )
                }

                Section {
                    Toggle("Daily overtime", isOn: $draft.useDailyOvertime)
                    if draft.useDailyOvertime {
                        LinePayTextField(
                            "After hours", text: $draft.overtimeAfterHours, focus: $isEditing
                        )
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                        LinePayTextField(
                            "Multiplier", text: $draft.overtimeMultiplier, focus: $isEditing
                        )
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Daily overtime")
                } footer: {
                    Text("LinePaycheck will not assume an overtime threshold unless you enable it.")
                }

                Section {
                    Toggle("Sunday premium", isOn: $draft.useSundayPremium)
                    if draft.useSundayPremium {
                        LinePayTextField(
                            "Sunday multiplier", text: $draft.sundayMultiplier, focus: $isEditing
                        )
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Sunday")
                }

                Section {
                    ForEach($draft.datePremiums) { $premium in
                        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                            DatePicker(
                                "Premium date",
                                selection: $premium.date,
                                displayedComponents: .date
                            )
                            HStack {
                                LinePayTextField(
                                    "Multiplier", text: $premium.multiplier, focus: $isEditing,
                                    identifier: "pay-profile.date-multiplier.\(premium.id)"
                                )
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                                Button(role: .destructive) {
                                    draft.datePremiums.removeAll { $0.id == premium.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Remove date premium")
                            }
                        }
                    }
                    Button {
                        draft.datePremiums.append(DatePremiumDraft())
                    } label: {
                        Label("Add holiday or premium date", systemImage: "plus")
                    }
                } header: {
                    Text("Specific dates")
                } footer: {
                    Text("Use only dates and multipliers you can confirm from your agreement.")
                }

                Section {
                    Toggle("Callout minimum", isOn: $draft.useCalloutMinimum)
                    if draft.useCalloutMinimum {
                        LinePayTextField(
                            "Minimum paid hours", text: $draft.calloutMinimumHours,
                            focus: $isEditing
                        )
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Callout")
                } footer: {
                    Text(
                        "LinePaycheck keeps actual worked time unchanged and derives any minimum-pay "
                            + "guarantee as a separate ledger line."
                    )
                }

                Section {
                    Toggle("Flat per diem", isOn: $draft.usePerDiem)
                    if draft.usePerDiem {
                        LinePayTextField(
                            "Amount per worked date (USD)", text: $draft.perDiemAmount,
                            focus: $isEditing
                        )
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Per diem")
                }

                Section {
                    Toggle("Effective start", isOn: $draft.useEffectiveStart)
                    if draft.useEffectiveStart {
                        DatePicker(
                            "Starts",
                            selection: $draft.effectiveStartDate,
                            displayedComponents: .date
                        )
                    }
                    Toggle("Effective end", isOn: $draft.useEffectiveEnd)
                    if draft.useEffectiveEnd {
                        DatePicker(
                            "Ends",
                            selection: $draft.effectiveEndDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Agreement effective dates")
                }

                Section {
                    LinePayTextField("Source title", text: $draft.sourceTitle, focus: $isEditing)
                    LinePayTextField("Source URL", text: $draft.sourceURL, focus: $isEditing)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LinePayTextField(
                        "Section / note", text: $draft.sourceSection, focus: $isEditing)
                } header: {
                    Text("Rule source (optional)")
                } footer: {
                    Text(
                        "A source helps you trace the rule later. LinePaycheck does not treat a typed URL "
                            + "as independently verified."
                    )
                }

                Section {
                    Label("No LinePaycheck account", systemImage: "person.crop.circle.badge.xmark")
                    Label("Pay data stays on this iPhone", systemImage: "iphone.and.arrow.forward")
                } header: {
                    Text("Privacy")
                }

            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .navigationTitle(model.profile == nil ? "Set up pay" : "Edit pay rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isEditing = nil }
                        .accessibilityIdentifier("keyboard.done")
                }
                if model.profile != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("pay-profile.save")
                }
            }
            .alert(
                "Pay rules weren't saved",
                isPresented: Binding(
                    get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled()
        .environment(\.timeZone, selectedTimeZone)
        .onChange(of: draft.timeZoneIdentifier) { oldIdentifier, newIdentifier in
            rebaseDraftDates(from: oldIdentifier, to: newIdentifier)
        }
        .tint(LinePayColor.actionText)
    }

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
            Text("Workdays")
                .font(.subheadline)
            ForEach(Weekday.allCases, id: \.rawValue) { weekday in
                Toggle(
                    weekdayName(weekday),
                    isOn: Binding(
                        get: { draft.regularWeekdays.contains(weekday) },
                        set: { enabled in
                            if enabled {
                                draft.regularWeekdays.insert(weekday)
                            } else {
                                draft.regularWeekdays.remove(weekday)
                            }
                        }
                    )
                )
            }
        }
    }

    private var lineGap: some View {
        HStack(spacing: 7) {
            Rectangle().frame(height: 1)
            Rectangle().frame(width: 26, height: 1)
        }
        .foregroundStyle(LinePayColor.brandCopper)
        .accessibilityHidden(true)
    }

    private var selectedTimeZone: TimeZone {
        TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
    }

    private func rebaseDraftDates(from oldIdentifier: String, to newIdentifier: String) {
        guard oldIdentifier != newIdentifier else { return }
        draft.regularStartTime = rebaseTime(
            draft.regularStartTime,
            from: oldIdentifier,
            to: newIdentifier
        )
        draft.regularEndTime = rebaseTime(
            draft.regularEndTime,
            from: oldIdentifier,
            to: newIdentifier
        )
        draft.periodStartDate = rebaseDate(
            draft.periodStartDate,
            from: oldIdentifier,
            to: newIdentifier
        )
        draft.manualPeriodEndDate = rebaseDate(
            draft.manualPeriodEndDate,
            from: oldIdentifier,
            to: newIdentifier
        )
        draft.effectiveStartDate = rebaseDate(
            draft.effectiveStartDate,
            from: oldIdentifier,
            to: newIdentifier
        )
        draft.effectiveEndDate = rebaseDate(
            draft.effectiveEndDate,
            from: oldIdentifier,
            to: newIdentifier
        )
        for index in draft.datePremiums.indices {
            draft.datePremiums[index].date = rebaseDate(
                draft.datePremiums[index].date,
                from: oldIdentifier,
                to: newIdentifier
            )
        }
    }

    private func rebaseTime(
        _ date: Date,
        from oldIdentifier: String,
        to newIdentifier: String
    ) -> Date {
        var oldCalendar = Calendar(identifier: .gregorian)
        oldCalendar.timeZone = TimeZone(identifier: oldIdentifier) ?? .current
        var newCalendar = Calendar(identifier: .gregorian)
        newCalendar.timeZone = TimeZone(identifier: newIdentifier) ?? .current
        let values = oldCalendar.dateComponents([.hour, .minute], from: date)
        var components = DateComponents()
        components.timeZone = newCalendar.timeZone
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = values.hour
        components.minute = values.minute
        return newCalendar.date(from: components) ?? date
    }

    private func rebaseDate(
        _ date: Date,
        from oldIdentifier: String,
        to newIdentifier: String
    ) -> Date {
        var oldCalendar = Calendar(identifier: .gregorian)
        oldCalendar.timeZone = TimeZone(identifier: oldIdentifier) ?? .current
        var newCalendar = Calendar(identifier: .gregorian)
        newCalendar.timeZone = TimeZone(identifier: newIdentifier) ?? .current
        var components = oldCalendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = newCalendar.timeZone
        return newCalendar.date(from: components) ?? date
    }

    private func save() {
        do {
            try model.saveProfile(draft)
            errorMessage = nil
            onSaved?()
            if model.profile != nil, onSaved == nil {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func weekdayName(_ weekday: Weekday) -> String {
        switch weekday {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    private static let usTimeZones: [(name: String, identifier: String)] = [
        ("Pacific", "America/Los_Angeles"),
        ("Mountain", "America/Denver"),
        ("Arizona", "America/Phoenix"),
        ("Central", "America/Chicago"),
        ("Eastern", "America/New_York"),
        ("Alaska", "America/Anchorage"),
        ("Hawaii", "Pacific/Honolulu"),
    ]
}
