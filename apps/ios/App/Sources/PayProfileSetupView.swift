import LinePayDomain
import SwiftUI

struct PayProfileSetupView: View {
    let model: AppModel
    let showsIntro: Bool
    let onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PayProfileDraft
    @State private var errorMessage: String?

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

                Section("Pay profile") {
                    TextField("Profile name", text: $draft.name)
                    TextField("Base hourly rate", text: $draft.hourlyRate)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()

                    Picker("Payroll timezone", selection: $draft.timeZoneIdentifier) {
                        ForEach(Self.usTimeZones, id: \.identifier) { option in
                            Text(option.name).tag(option.identifier)
                        }
                    }
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
                        Text("Choose the boundary that matches the paycheck you are currently earning.")
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
                        TextField(
                            "Outside-schedule multiplier",
                            text: $draft.outsideScheduleMultiplier
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
                        TextField("After hours", text: $draft.overtimeAfterHours)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                        TextField("Multiplier", text: $draft.overtimeMultiplier)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Daily overtime")
                } footer: {
                    Text("LinePay will not assume an overtime threshold unless you enable it.")
                }

                Section {
                    Toggle("Sunday premium", isOn: $draft.useSundayPremium)
                    if draft.useSundayPremium {
                        TextField("Sunday multiplier", text: $draft.sundayMultiplier)
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
                                TextField("Multiplier", text: $premium.multiplier)
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
                        TextField("Minimum paid hours", text: $draft.calloutMinimumHours)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Callout")
                } footer: {
                    Text(
                        "LinePay keeps actual worked time unchanged and derives any minimum-pay "
                            + "guarantee as a separate ledger line."
                    )
                }

                Section {
                    Toggle("Flat per diem", isOn: $draft.usePerDiem)
                    if draft.usePerDiem {
                        TextField("Amount per worked date", text: $draft.perDiemAmount)
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
                    TextField("Source title", text: $draft.sourceTitle)
                    TextField("Source URL", text: $draft.sourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Section / note", text: $draft.sourceSection)
                } header: {
                    Text("Rule source (optional)")
                } footer: {
                    Text(
                        "A source helps you trace the rule later. LinePay does not treat a typed URL "
                            + "as independently verified."
                    )
                }

                Section {
                    Label("No LinePay account", systemImage: "person.crop.circle.badge.xmark")
                    Label("Pay data stays on this iPhone", systemImage: "iphone.and.arrow.forward")
                } header: {
                    Text("Privacy")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(model.profile == nil ? "Set up pay" : "Edit pay rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.profile != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .environment(\.timeZone, selectedTimeZone)
        .tint(LinePayColor.brandPrimary)
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
