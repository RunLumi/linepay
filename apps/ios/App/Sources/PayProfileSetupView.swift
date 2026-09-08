import LinePayDomain
import SwiftUI

struct PayProfileSetupView: View {
    let model: AppModel
    let showsIntro: Bool
    let onSaved: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PayProfileDraft
    @State private var errorMessage: String?
    @State private var showingUnsupported = false
    @State private var changePreview: ProfileChangePreview?
    @State private var showingChangeConfirmation = false
    @State private var isClosing = false
    @FocusState private var editingField: String?

    init(model: AppModel, showsIntro: Bool = true, onSaved: (() -> Void)? = nil) {
        self.model = model
        self.showsIntro = showsIntro
        self.onSaved = onSaved
        _draft = State(
            initialValue: model.setupDraft ?? model.profile.map {
                PayProfileDraft(profile: $0, activePeriod: model.activePeriod)
            } ?? PayProfileDraft())
    }
    private var editing: Bool { model.profile != nil }
    private var zone: TimeZone { TimeZone(identifier: draft.timeZoneIdentifier) ?? .current }
    private var step: Int { min(3, max(0, draft.setupStep)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(["Pay basics", "Pay period", "Your rules", "Confirm rules"][step])
                        .font(.title2.bold())
                    Text("Step \(step + 1) of 4. Your unfinished setup is saved on this device.")
                        .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                }
                switch step {
                case 0: basics
                case 1: period
                case 2: rules
                default: review
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LinePayColor.review)
                    }
                }
                if step < 3 || !editing {
                    Section {
                        Button(
                            step == 3 ? "Use these rules" : "Continue"
                        ) {
                            advance()
                        }
                        .buttonStyle(LinePayPrimaryButtonStyle())
                        .accessibilityIdentifier(
                            step == 3
                                ? "pay-profile.save"
                                : "pay-profile.continue"
                        )
                        .accessibilityValue("step-\(step)")
                    }
                }
            }
            .linePayKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .navigationTitle(editing ? "Edit pay rules" : "Set up my pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // The in-form header scrolls away at the largest text sizes; the
                    // toolbar keeps the rendered step visible wherever the worker is.
                    Text("Step \(step + 1) of 4")
                        .font(.footnote)
                        .foregroundStyle(LinePayColor.textSecondary)
                        .accessibilityIdentifier("pay-profile.step-indicator")
                }
                ToolbarItem(placement: .cancellationAction) {
                    if step > 0 {
                        Button("Back") { draft.setupStep -= 1 }
                    } else if editing {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if step == 3, editing {
                        Button("Save reviewed rules") {
                            advance()
                        }
                        .accessibilityIdentifier("pay-profile.save")
                    }
                }
            }
        }
        .environment(\.timeZone, zone)
        .tint(LinePayColor.actionText)
        .onChange(of: draft) { _, value in
            guard !isClosing else { return }
            do { try model.saveSetupDraft(value) } catch {
                errorMessage =
                    "This draft could not be saved. Keep this screen open and free device storage."
            }
        }
        .onChange(of: draft.timeZoneIdentifier) { old, new in rebase(from: old, to: new) }
        .alert("Review rule change", isPresented: $showingChangeConfirmation) {
            Button("Confirm rule change") { commitProfile() }
                .accessibilityIdentifier("pay-profile.confirm-change")
            Button("Cancel", role: .cancel) {}
        } message: {
            if let preview = changePreview {
                Text(
                    "\(selectedScope.title). \(changeExplanation) Open-period total, including per diem: \(preview.before.map(LinePayFormat.money) ?? "Unavailable") → \(preview.after.map(LinePayFormat.money) ?? "Unavailable"). \(preview.workCount) saved work entries. Earlier audit revisions remain unchanged."
                )
            }
        }
        .sheet(isPresented: $showingUnsupported) {
            NavigationStack {
                Form {
                    Section("Do not force a close-enough rule") {
                        Text(
                            "Weekly overtime, rest-period premiums, unusual stacking, meal penalties and travel guarantees are not automatically inferred. Record anything missing below."
                        )
                        TextField(
                            "Rule or source to check", text: $draft.unsupportedRuleNotes,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        Text(
                            "A nonempty note marks this agreement and its audits as incomplete. LinePaycheck will not call an incomplete audit a clean match."
                        )
                        .font(.footnote)
                    }
                }
                .navigationTitle("Missing rule")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingUnsupported = false }
                    }
                }
            }
        }
    }

    private var basics: some View {
        Section {
            LinePayTextField(
                "Profile name", text: $draft.name, focus: $editingField,
                identifier: "pay-profile.name")
            LinePayTextField(
                "Base hourly rate, USD", text: $draft.hourlyRate, focus: $editingField,
                identifier: "pay-profile.hourly-rate"
            )
            .keyboardType(.numbersAndPunctuation).monospacedDigit()
            Picker("Payroll timezone", selection: $draft.timeZoneIdentifier) {
                ForEach(timeZones, id: \.self) { Text($0).tag($0) }
            }
        } footer: {
            Text(
                "Use a decimal point for numbers, for example 58.40. Payroll timezone determines day and premium boundaries, not where your phone happens to be."
            )
        }
    }

    private var period: some View {
        Section {
            Picker("Pay cadence", selection: $draft.preferredCadence) {
                ForEach(PayPeriodCadence.allCases) { Text($0.title).tag($0) }
            }.accessibilityIdentifier("pay-profile.cadence")
            if !editing {
                DatePicker(
                    "Current period starts", selection: $draft.periodStartDate,
                    displayedComponents: .date)
                if draft.preferredCadence == .manual {
                    DatePicker(
                        "Current period ends", selection: $draft.manualPeriodEndDate,
                        displayedComponents: .date)
                }
                Text("Preview: \(periodPreview)").font(.callout)
            } else {
                Text(
                    "Cadence changes apply to future periods. Correct current dates separately in Settings; no entered date will be silently ignored."
                )
            }
        } footer: {
            Text(
                "You can close a work period and keep logging the next one while its paycheck is pending. Audit the earlier paycheck from History when it arrives."
            )
        }
    }

    @ViewBuilder private var rules: some View {
        Section("Common rules; off unless confirmed") {
            Toggle("Daily overtime", isOn: $draft.useDailyOvertime)
            if draft.useDailyOvertime {
                number("After worked hours", $draft.overtimeAfterHours)
                number("Multiplier", $draft.overtimeMultiplier)
                ForEach($draft.additionalOvertimeTiers) { $tier in
                    VStack(alignment: .leading) {
                        number("Additional threshold", $tier.afterHours)
                        number("Additional multiplier", $tier.multiplier)
                        Button("Remove tier", role: .destructive) {
                            draft.additionalOvertimeTiers.removeAll { $0.id == tier.id }
                        }
                    }
                }
                Button("Add another overtime tier") {
                    draft.additionalOvertimeTiers.append(OvertimeTierDraft())
                }
            }
            Toggle("Sunday premium", isOn: $draft.useSundayPremium)
            if draft.useSundayPremium { number("Sunday multiplier", $draft.sundayMultiplier) }
            Toggle("Callout minimum", isOn: $draft.useCalloutMinimum)
            if draft.useCalloutMinimum {
                number("Minimum paid hours", $draft.calloutMinimumHours)
                Text(
                    "This isolated minimum is evaluated once per confirmed physical callout event. Keep actual worked time separate; adjacent Callout rows are not automatically the same event."
                )
                .font(.footnote)
                .foregroundStyle(LinePayColor.textSecondary)
            }
            Toggle("Flat per diem", isOn: $draft.usePerDiem)
            if draft.usePerDiem { number("USD per worked date", $draft.perDiemAmount) }
        }
        DisclosureGroup("Weekly overtime (restricted)", isExpanded: $draft.useWeeklyOvertime) {
            Picker("Workweek starts", selection: $draft.weeklyWorkweekStart) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(weekdayName(day)).tag(day)
                }
            }
            Toggle(
                "Covered, nonexempt hourly work confirmed",
                isOn: $draft.weeklyApplicabilityConfirmed)
            Text(
                "This restricted layer requires a complete single-employer workweek. It does not establish state, public-agency, or CBA coverage, and unknown weeks remain needs review."
            ).font(.footnote)
        }
        Section("Additional rules") {
            DisclosureGroup("Other weekdays") {
                ForEach($draft.additionalWeekdayPremiums) { $premium in
                    Picker("Weekday", selection: $premium.weekday) {
                        ForEach(Weekday.allCases.filter { $0 != .sunday }, id: \.self) {
                            Text(weekdayName($0)).tag($0)
                        }
                    }
                    number("Multiplier", $premium.multiplier)
                    Button("Remove weekday", role: .destructive) {
                        draft.additionalWeekdayPremiums.removeAll { $0.id == premium.id }
                    }
                }
                Button("Add weekday premium") {
                    draft.additionalWeekdayPremiums.append(WeekdayPremiumDraft())
                }
            }
            DisclosureGroup("Outside-schedule pay") {
                Toggle("Use regular schedule", isOn: $draft.useRegularSchedule)
                if draft.useRegularSchedule {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Toggle(
                            weekdayName(day),
                            isOn: Binding(
                                get: { draft.regularWeekdays.contains(day) },
                                set: {
                                    if $0 {
                                        draft.regularWeekdays.insert(day)
                                    } else {
                                        draft.regularWeekdays.remove(day)
                                    }
                                }))
                    }
                    DatePicker(
                        "Schedule starts", selection: $draft.regularStartTime,
                        displayedComponents: .hourAndMinute)
                    DatePicker(
                        "Schedule ends", selection: $draft.regularEndTime,
                        displayedComponents: .hourAndMinute)
                    number("Outside-schedule multiplier", $draft.outsideScheduleMultiplier)
                    Text(
                        "This setup uses the same daytime schedule on selected days. Overnight schedule windows are unsupported; do not approximate them."
                    ).font(.footnote)
                }
            }
            DisclosureGroup("Holidays and specific dates") {
                ForEach($draft.datePremiums) { $premium in
                    DatePicker("Premium date", selection: $premium.date, displayedComponents: .date)
                    number("Date multiplier", $premium.multiplier)
                    Button("Remove date", role: .destructive) {
                        draft.datePremiums.removeAll { $0.id == premium.id }
                    }
                }
                Button("Add premium date") { draft.datePremiums.append(DatePremiumDraft()) }
            }
            DisclosureGroup("Agreement effective dates") {
                Toggle("Effective start", isOn: $draft.useEffectiveStart)
                if draft.useEffectiveStart {
                    DatePicker(
                        "Starts", selection: $draft.effectiveStartDate, displayedComponents: .date)
                }
                Toggle("Effective end", isOn: $draft.useEffectiveEnd)
                if draft.useEffectiveEnd {
                    DatePicker(
                        "Ends", selection: $draft.effectiveEndDate, displayedComponents: .date)
                }
            }
        }
        Section("Source references, optional") {
            TextField("Source title", text: $draft.sourceTitle)
            TextField("Source URL", text: $draft.sourceURL).keyboardType(.URL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Section or note", text: $draft.sourceSection)
            sourceRulePicker($draft.sourceRuleKey)
            ForEach($draft.additionalSources) { $source in
                DisclosureGroup(source.title.isEmpty ? "Additional source" : source.title) {
                    TextField("Title", text: $source.title)
                    TextField("URL", text: $source.url).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Section", text: $source.section)
                    sourceRulePicker($source.ruleKey)
                    Button("Remove source", role: .destructive) {
                        draft.additionalSources.removeAll { $0.id == source.id }
                    }
                }
            }
            Button("Add source") { draft.additionalSources.append(RuleSourceDraft()) }
            Text("A reference you enter is not independently verified by LinePaycheck.").font(
                .footnote)
        }
        Section {
            Button("I don't see my rule") { showingUnsupported = true }.accessibilityIdentifier(
                "pay-profile.unsupported")
            if !draft.unsupportedRuleNotes.isEmpty {
                Label("Incomplete rule coverage", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(LinePayColor.review)
                Text(draft.unsupportedRuleNotes)
            }
        }
    }

    @ViewBuilder private var review: some View {
        if let agreement = try? model.previewAgreement(draft) {
            Section("What LinePaycheck will calculate") {
                AgreementSummaryView(agreement: agreement)
                LabeledContent("Payroll timezone", value: draft.timeZoneIdentifier)
                LabeledContent("Pay cadence", value: draft.preferredCadence.title)
                Text(
                    "Where premiums overlap, the highest applicable multiplier wins; premiums are not added together. A callout top-up uses the highest worked multiplier. Confirm these semantics match your agreement."
                )
                .font(.footnote)
            }
            .labeledContentStyle(LinePayValueStyle())
            if editing {
                Section("Apply this change") {
                    Picker("Scope", selection: $draft.editScope) {
                        Text("Future work periods only")
                            .accessibilityIdentifier("pay-profile.scope.future")
                            .tag(RuleEditScope.futurePeriods)
                        Text("New rules from a date")
                            .accessibilityIdentifier("pay-profile.scope.dated")
                            .tag(RuleEditScope.datedChange)
                        Text("Recalculate this entire current period")
                            .accessibilityIdentifier("pay-profile.scope.current")
                            .tag(RuleEditScope.currentPeriod)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("pay-profile.change-scope")
                    if draft.editScope == .datedChange {
                        DatePicker(
                            "New rules start",
                            selection: Binding(
                                get: {
                                    ruleChangeDate
                                },
                                set: { draft.changeEffectiveDate = $0 }), displayedComponents: .date
                        )
                        .accessibilityIdentifier("pay-profile.change-date")
                        Text(
                            "Starts at midnight in the frozen payroll timezone, after the last recorded work date. Spanning callout guarantees may require review."
                        ).font(.footnote)
                    }
                    if let old = model.activePeriod?.agreement {
                        DisclosureGroup("Previous current-period rules") {
                            AgreementSummaryView(agreement: old)
                        }
                        LabeledContent("Current rate", value: LinePayFormat.money(old.hourlyRate))
                        LabeledContent(
                            "Reviewed rate", value: LinePayFormat.money(agreement.hourlyRate))
                    }
                    Text(changeExplanation)
                        .accessibilityIdentifier("pay-profile.scope-explanation")
                        .foregroundStyle(LinePayColor.review)
                    Text("Closed work periods and their calculation snapshots are not changed.")
                        .font(.footnote)
                }
            }
            Section { ComparisonScopeView(showDetails: true) }
            Section("Confirmation") {
                Text(
                    "These are the rules you entered, not rules inferred from your union or employer. Review the summary before using them."
                )
                if agreement.sources.isEmpty {
                    Text("Confirmed by you; no source attached.").font(.footnote)
                }
            }
        }
    }

    private func advance() {
        do {
            _ = try model.previewAgreement(draft)
            if step < 3 {
                draft.setupStep += 1
            } else {
                if editing {
                    changePreview = try model.previewProfileChange(draft, scope: selectedScope)
                    showingChangeConfirmation = true
                } else {
                    commitProfile()
                }
            }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    private var ruleChangeDate: Date {
        draft.changeEffectiveDate
            ?? (draft.useEffectiveStart
                ? draft.effectiveStartDate
                : model.activePeriod?.window.endDate ?? draft.periodStartDate)
    }
    private var changeExplanation: String {
        RuleChangeConsent.explanation(
            scope: draft.editScope, effectiveDate: ruleChangeDate,
            timeZoneIdentifier: model.currentTimeZoneIdentifier,
            workCount: model.activePeriod?.workEntries.count ?? 0)
    }

    private var selectedScope: RuleChangeScope {
        switch draft.editScope {
        case .futurePeriods: .futurePeriods
        case .datedChange: .prospective
        case .currentPeriod: .correctCurrentPeriod
        }
    }

    private func commitProfile() {
        do {
            isClosing = true
            try model.saveProfile(draft, scope: selectedScope)
            onSaved?()
            if onSaved == nil { dismiss() }
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }

    private func number(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline)
            TextField(label, text: binding).keyboardType(.numbersAndPunctuation).monospacedDigit()
        }
    }
    private func sourceRulePicker(_ selection: Binding<PayRuleKey?>) -> some View {
        Picker("Applies to", selection: selection) {
            Text("Agreement-level reference").tag(PayRuleKey?.none)
            ForEach(PayRuleKey.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
        }
    }
    private func weekdayName(_ day: Weekday) -> String {
        Calendar(identifier: .gregorian).weekdaySymbols[day.rawValue - 1]
    }
    private var timeZones: [String] {
        Array(
            Set([
                draft.timeZoneIdentifier, "America/Los_Angeles", "America/Denver",
                "America/Phoenix", "America/Chicago", "America/New_York", "America/Anchorage",
                "Pacific/Honolulu",
            ])
        ).sorted()
    }
    private var periodPreview: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let end =
            draft.preferredCadence == .manual
            ? draft.manualPeriodEndDate
            : calendar.date(
                byAdding: .day, value: draft.preferredCadence == .weekly ? 6 : 13,
                to: draft.periodStartDate) ?? draft.periodStartDate
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = zone
        return "\(formatter.string(from: draft.periodStartDate)) to \(formatter.string(from: end))"
    }
    private func rebase(from old: String, to new: String) {
        guard let oldZone = TimeZone(identifier: old), let newZone = TimeZone(identifier: new)
        else { return }
        var a = Calendar(identifier: .gregorian)
        a.timeZone = oldZone
        var b = Calendar(identifier: .gregorian)
        b.timeZone = newZone
        func change(_ date: Date) -> Date {
            var parts = a.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            parts.timeZone = newZone
            return b.date(from: parts) ?? date
        }
        draft.periodStartDate = change(draft.periodStartDate)
        draft.manualPeriodEndDate = change(draft.manualPeriodEndDate)
        draft.regularStartTime = change(draft.regularStartTime)
        draft.regularEndTime = change(draft.regularEndTime)
        draft.effectiveStartDate = change(draft.effectiveStartDate)
        draft.effectiveEndDate = change(draft.effectiveEndDate)
        for index in draft.datePremiums.indices {
            draft.datePremiums[index].date = change(draft.datePremiums[index].date)
        }
    }
}

struct AgreementSummaryView: View {
    let agreement: AgreementSnapshot
    var body: some View {
        LabeledContent("Base rate", value: "\(LinePayFormat.money(agreement.hourlyRate))/hr")
        ForEach(Array(agreement.dailyOvertimeTiers.enumerated()), id: \.offset) { _, tier in
            LabeledContent(
                "After \(LinePayFormat.hours(tier.afterHours)) worked h",
                value: "\(LinePayFormat.decimal(tier.multiplier))×")
        }
        ForEach(Array(agreement.weekdayPremiums.enumerated()), id: \.offset) { _, premium in
            LabeledContent(
                Calendar(identifier: .gregorian).weekdaySymbols[premium.weekday.rawValue - 1],
                value: "\(LinePayFormat.decimal(premium.multiplier))×")
        }
        ForEach(Array(agreement.datePremiums.enumerated()), id: \.offset) { _, premium in
            LabeledContent(
                LinePayFormat.localDate(premium.date),
                value: "\(LinePayFormat.decimal(premium.multiplier))×")
        }
        if let rule = agreement.calloutMinimum {
            LabeledContent(
                "Callout minimum", value: "\(LinePayFormat.hours(rule.minimumHours)) paid h")
            Text(
                "One isolated minimum per confirmed physical callout event; actual worked time stays separate."
            )
            .font(.footnote)
        }
        if let rule = agreement.flatPerDiem {
            LabeledContent("Per worked date", value: LinePayFormat.money(rule.amountPerWorkDate))
        }
        if let rule = agreement.weeklyOvertime {
            LabeledContent(
                "Weekly overtime",
                value:
                    "After \(LinePayFormat.hours(rule.thresholdHours)) h; starts \(Calendar(identifier: .gregorian).weekdaySymbols[rule.workweekStart.rawValue - 1])"
            )
            Text(
                "Restricted covered/nonexempt hourly profile; not a complete statutory or CBA determination."
            ).font(.footnote)
        }
        ForEach(Array(agreement.regularSchedule.enumerated()), id: \.offset) { _, window in
            LabeledContent(
                Calendar(identifier: .gregorian).weekdaySymbols[window.weekday.rawValue - 1],
                value: String(
                    format: "%02d:%02d to %02d:%02d", window.start.hour, window.start.minute,
                    window.end.hour, window.end.minute))
        }
        if !agreement.regularSchedule.isEmpty {
            LabeledContent(
                "Outside schedule",
                value: "\(LinePayFormat.decimal(agreement.outsideScheduleMultiplier))×")
        }
        if let date = agreement.effectiveStart {
            LabeledContent("Effective start", value: LinePayFormat.localDate(date))
        }
        if let date = agreement.effectiveEnd {
            LabeledContent("Effective end", value: LinePayFormat.localDate(date))
        }
        if let note = agreement.unsupportedRuleNotes, !note.isEmpty {
            Label("Incomplete: \(note)", systemImage: "exclamationmark.triangle").foregroundStyle(
                LinePayColor.review)
        }
    }
}
