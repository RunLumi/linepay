import LinePayDomain
import SwiftUI

struct PayProfileSetupView: View {
    let model: AppModel
    let showsIntro: Bool
    let onSaved: (() -> Void)?
    let onPortableReviewed: ((PayProfileDraft, Set<String>, Bool) throws -> Void)?
    let portableSource: PortableWorkSnapshot?
    let portableInheritedScope: String
    @State private var portableConfirmations = Set<String>()
    @State private var portableMakeDefaultForFuture = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: PayProfileDraft
    @State private var errorMessage: String?
    @State private var showingUnsupported = false
    @State private var changePreview: ProfileChangePreview?
    @State private var showingChangeConfirmation = false
    @State private var isClosing = false
    @FocusState private var editingField: String?

    init(
        model: AppModel, showsIntro: Bool = true, onSaved: (() -> Void)? = nil,
        initialDraft: PayProfileDraft? = nil, portableSource: PortableWorkSnapshot? = nil,
        portableInheritedScope: String = "",
        onPortableReviewed: ((PayProfileDraft, Set<String>, Bool) throws -> Void)? = nil
    ) {
        self.model = model
        self.showsIntro = showsIntro
        self.onSaved = onSaved
        self.onPortableReviewed = onPortableReviewed
        self.portableSource = portableSource
        self.portableInheritedScope = portableInheritedScope
        _draft = State(
            initialValue: initialDraft ?? model.setupDraft ?? model.profile.map {
                PayProfileDraft(profile: $0, activePeriod: model.activePeriod)
            } ?? PayProfileDraft())
    }
    private var editing: Bool { model.profile != nil && onPortableReviewed == nil }
    private var currencySelection: Binding<String> {
        Binding(get: { draft.resolvedCurrencyCode }, set: { draft.currencyCode = $0 })
    }
    private var rateExample: String {
        draft.resolvedCurrencyCode == "VND"
            ? "45000" : "58\(NumberEntry.decimalSeparator)40"
    }
    /// "Canadian dollar (CAD)": the name a worker recognises, with the code printed on paystubs.
    static func currencyName(_ code: String) -> String {
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return name == code ? code : "\(name.prefix(1).uppercased() + name.dropFirst()) (\(code))"
    }
    private var zone: TimeZone { TimeZone(identifier: draft.timeZoneIdentifier) ?? .current }
    private var step: Int { min(3, max(0, draft.setupStep)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(["Pay basics", "Pay period", "Your rules", "Confirm rules"][step])
                            .font(.title2.bold())
                        Text(stepPurpose)
                            .font(.subheadline).foregroundStyle(LinePayColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                if draft.crewRuleAdoption != nil {
                    Section("Worker-provided draft") {
                        Text(
                            "The original draft and your reviewed amount choices will be retained with the new rule version. For an existing profile these rules apply only to future periods. To change the imported terms, return to Crew rule drafts and prepare them again."
                        )
                        .font(.footnote)
                    }
                }
                switch step {
                case 0: basics
                case 1: period
                case 2: rules
                default: review
                }
            }
            // A new identity per step starts each step at its top instead of inheriting the
            // previous step's scroll position.
            .id(step)
            .linePayKeyboardDismiss()
            .linePayCanvas()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LinePayBottomBar {
                    if let errorMessage {
                        // Beside the action that failed, never hidden under the keyboard.
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(LinePayColor.review)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("pay-profile.error")
                    }
                    if step < 3 {
                        Button("Continue") { advance() }
                            .buttonStyle(LinePayPrimaryButtonStyle())
                            .accessibilityIdentifier("pay-profile.continue")
                            .accessibilityValue("step-\(step)")
                    } else {
                        Button(editing ? "Save reviewed rules" : "Use these rules") { advance() }
                            .buttonStyle(LinePayPrimaryButtonStyle())
                            .accessibilityIdentifier("pay-profile.save")
                            .accessibilityValue("step-\(step)")
                    }
                }
            }
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
            }
        }
        .environment(\.timeZone, zone)
        .tint(LinePayColor.actionText)
        .onAppear { model.localActivity.record(.profileStarted, once: .once) }
        .onChange(of: draft) { _, value in
            portableConfirmations = []
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
                .linePayCanvas()
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
            if editing {
                LabeledContent("Pay currency", value: draft.resolvedCurrencyCode)
                    .accessibilityIdentifier("pay-profile.currency")
            } else {
                Picker("Pay currency", selection: currencySelection) {
                    ForEach(PayProfileDraft.supportedCurrencyCodes, id: \.self) { code in
                        Text(Self.currencyName(code)).tag(code)
                    }
                }
                .accessibilityIdentifier("pay-profile.currency")
            }
            LinePayTextField(
                "Base hourly rate, \(draft.resolvedCurrencyCode)", text: $draft.hourlyRate,
                focus: $editingField, identifier: "pay-profile.hourly-rate"
            )
            .linePayNumberEntry()
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                    Text("Payroll timezone")
                    Menu {
                        Picker("Payroll timezone", selection: $draft.timeZoneIdentifier) {
                            ForEach(timeZones, id: \.self) {
                                Text(LinePayFormat.timeZoneName($0)).tag($0)
                            }
                        }
                    } label: {
                        HStack(alignment: .top) {
                            Text(LinePayFormat.timeZoneName(draft.timeZoneIdentifier))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: LinePaySpacing.compact)
                            Image(systemName: "chevron.up.chevron.down")
                        }
                    }
                    .accessibilityLabel("Payroll timezone")
                    .accessibilityValue(LinePayFormat.timeZoneName(draft.timeZoneIdentifier))
                    .accessibilityIdentifier("pay-profile.selected-timezone")
                }
            } else {
                Picker("Payroll timezone", selection: $draft.timeZoneIdentifier) {
                    ForEach(timeZones, id: \.self) { Text(LinePayFormat.timeZoneName($0)).tag($0) }
                }
            }
            LinePayTextField(
                "Profile name", text: $draft.name, focus: $editingField,
                identifier: "pay-profile.name")
        } footer: {
            Text(
                "Your straight-time rate before any premium, for example \(rateExample). The payroll timezone decides which day a shift counts on, not where your phone is."
            )
        }
        .task {
            // The rate is the one required fact; put the cursor there on first setup once the
            // form has finished its appearance transition and the field can take focus.
            guard !editing, draft.hourlyRate.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(450))
            editingField = "pay-profile.hourly-rate"
        }
    }

    private var period: some View {
        Section {
            Picker("Pay cadence", selection: $draft.preferredCadence) {
                ForEach(PayPeriodCadence.allCases) { Text($0.title).tag($0) }
            }.accessibilityIdentifier("pay-profile.cadence")
            if !editing {
                DatePicker(
                    "First day of this pay period", selection: $draft.periodStartDate,
                    displayedComponents: .date)
                if draft.preferredCadence == .manual {
                    DatePicker(
                        "Current period ends", selection: $draft.manualPeriodEndDate,
                        displayedComponents: .date)
                }
                LabeledContent("This period", value: periodPreview).monospacedDigit()
            } else {
                Text(
                    "Cadence changes apply to future periods. Correct current dates separately in Settings; no entered date will be silently ignored."
                )
            }
        } footer: {
            Text(
                "Check a recent paystub for the dates it covers. Shifts must fall inside the period to count. When a period ends, you can keep logging the next one while its paycheck is pending."
            )
        }
    }

    @ViewBuilder private var rules: some View {
        Section {
            ruleToggle(
                "Daily overtime", detail: "A higher rate after a set number of hours in one day.",
                isOn: $draft.useDailyOvertime)
            if draft.useDailyOvertime {
                number("After this many hours in a day", $draft.overtimeAfterHours)
                number("Multiplier (1.5 = time and a half)", $draft.overtimeMultiplier)
                ForEach($draft.additionalOvertimeTiers) { $tier in
                    VStack(alignment: .leading) {
                        number("Then after this many hours", $tier.afterHours)
                        number("Multiplier (2 = double time)", $tier.multiplier)
                        Button("Remove tier", role: .destructive) {
                            draft.additionalOvertimeTiers.removeAll { $0.id == tier.id }
                        }
                    }
                }
                Button("Add another overtime tier") {
                    draft.additionalOvertimeTiers.append(OvertimeTierDraft())
                }
            }
            ruleToggle(
                "Sunday premium", detail: "A multiplier for every hour worked on Sunday.",
                isOn: $draft.useSundayPremium)
            if draft.useSundayPremium { number("Sunday multiplier", $draft.sundayMultiplier) }
        } header: {
            Text("Overtime and premiums")
        } footer: {
            Text(
                "Everything starts off. Turn on only what your employer or pay agreement actually pays; anything left off is not configured, not ruled out."
            )
        }
        Section {
            ruleToggle(
                "Callout minimum", detail: "Guaranteed paid hours when you are called out.",
                isOn: $draft.useCalloutMinimum)
            if draft.useCalloutMinimum {
                number("Minimum paid hours", $draft.calloutMinimumHours)
                Text(
                    "This isolated minimum is evaluated once per confirmed physical callout event. Keep actual worked time separate; adjacent Callout rows are not automatically the same event."
                )
                .font(.footnote)
                .foregroundStyle(LinePayColor.textSecondary)
            }
            ruleToggle(
                "Flat per diem",
                detail: "A fixed allowance for each day you work, kept apart from wages.",
                isOn: $draft.usePerDiem)
            if draft.usePerDiem {
                number("\(draft.resolvedCurrencyCode) per worked date", $draft.perDiemAmount)
            }
        } header: {
            Text("Advanced rules")
        } footer: {
            Text(
                "Optional rules for callouts and per diem, common in utility and field work. They stay off unless you confirm them."
            )
        }
        Section {
            ruleToggle(
                "Weekly overtime review",
                detail:
                    "Checks hours over 40 in a complete workweek, in a separate review on the Pay screen.",
                isOn: $draft.useWeeklyOvertime)
            if draft.useWeeklyOvertime {
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
        Section {
            DisclosureGroup("Where these rules come from (optional)") {
                sourceFields
            }
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

    @ViewBuilder private var sourceFields: some View {
        Group {
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
    }

    @ViewBuilder private var review: some View {
        if let agreement = try? model.previewAgreement(draft) {
            if let source = portableSource {
                Section("Create a new native interpretation") {
                    Text(
                        "These are newly confirmed rules and copied work facts. Missing source facts remain missing in the original evidence. Original saved results will not be changed or recalculated."
                    )
                    if !portableInheritedScope.isEmpty {
                        Label(
                            "Unresolved weekly review stays attached to the new configuration. An equal gross total will still need review.",
                            systemImage: "exclamationmark.triangle")
                        DisclosureGroup("Source review references") {
                            Text(portableInheritedScope).textSelection(.enabled)
                        }
                    }
                    ForEach(source.work, id: \.id) { work in
                        VStack(alignment: .leading) {
                            Text(
                                "\(work.startEpochSeconds)–\(work.endEpochSeconds) · \(work.timeZone)"
                            ).monospacedDigit()
                            Text("Work kind: " + work.kind)
                            ForEach(work.unpaidBreaks, id: \.id) { rest in
                                Text(
                                    "Unpaid break: \(rest.startEpochSeconds)–\(rest.endEpochSeconds)"
                                ).monospacedDigit()
                            }
                            Text(
                                work.note
                                    ?? "Source note was not recorded; the new copy will have a blank note."
                            )
                        }
                    }
                    portableCheck(
                        "payRules",
                        "I independently confirmed the base rate, currency, and the selected pay rules below"
                    )
                    portableCheck(
                        "scheduleAndPremiums",
                        "I confirmed the schedule, daily overtime, premiums, callout minimum, and per diem choices, including choices left off"
                    )
                    Picker("New rounding scale", selection: portableScale) {
                        ForEach(0...8, id: \.self) { Text("\($0) decimal places").tag($0) }
                    }
                    Picker("New rounding mode", selection: portableMode) {
                        Text("Half up").tag(MoneyRoundingMode.halfUp)
                        Text("Ties to even").tag(MoneyRoundingMode.bankers)
                        Text("Down").tag(MoneyRoundingMode.down)
                        Text("Up").tag(MoneyRoundingMode.up)
                    }
                    Picker("New rounding scope", selection: portableScope) {
                        Text("Once per pay category").tag(PayRoundingScope.payCategory)
                        Text("Each legacy segment").tag(PayRoundingScope.legacySegments)
                    }
                    portableCheck(
                        "rounding",
                        "I independently confirmed this displayed rounding scale, mode, and scope for the new records"
                    )
                    portableCheck(
                        "periodContext",
                        "I confirmed the displayed new pay-period dates, cadence, and payroll timezone"
                    )
                    portableCheck(
                        "workFacts",
                        "I confirmed every displayed work interval, break, kind, and note for the new copies"
                    )
                    Toggle(
                        "Also use these new rules as the default for future pay periods",
                        isOn: $portableMakeDefaultForFuture
                    )
                    .accessibilityIdentifier("portable.future-default")
                    Text(
                        "This separate choice is off by default. Keeping it off preserves the transfer's saved future default, which may still need review before a new period can start."
                    )
                    .font(.footnote)

                }
            }
            Section("What LinePaycheck will calculate") {
                AgreementSummaryView(agreement: agreement)
                LabeledContent(
                    "Payroll timezone", value: LinePayFormat.timeZoneName(draft.timeZoneIdentifier))
                LabeledContent("Pay cadence", value: draft.preferredCadence.title)
                if !editing { LabeledContent("First period", value: periodPreview) }
                Text(
                    "Where premiums overlap, the highest applicable multiplier wins; premiums are not added together. A callout top-up uses the highest worked multiplier. Confirm these semantics match your agreement."
                )
                .font(.footnote)
            }
            .labeledContentStyle(LinePayValueStyle())
            if editing {
                Section("Apply this change") {
                    if draft.crewRuleAdoption != nil {
                        LabeledContent("Scope", value: editScopeTitle)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Scope")
                            .accessibilityValue(editScopeTitle)
                            .accessibilityIdentifier("pay-profile.fixed-scope")
                    } else {
                        Menu {
                            Button("Future work periods only") { draft.editScope = .futurePeriods }
                                .accessibilityIdentifier("pay-profile.scope.future")
                            Button("New rules from a date") { draft.editScope = .datedChange }
                                .accessibilityIdentifier("pay-profile.scope.dated")
                            Button("Recalculate this entire current period") {
                                draft.editScope = .currentPeriod
                            }
                            .accessibilityIdentifier("pay-profile.scope.current")
                        } label: {
                            let layout =
                                dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                : AnyLayout(HStackLayout(spacing: 12))
                            layout {
                                Text("Scope")
                                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(editScopeTitle)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.footnote.weight(.semibold))
                                }
                                .foregroundStyle(LinePayColor.actionText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Scope")
                        .accessibilityValue(editScopeTitle)
                        .accessibilityIdentifier("pay-profile.change-scope")
                    }
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
                        LabeledContent("Current rate", value: LinePayFormat.rate(old.hourlyRate))
                        LabeledContent(
                            "Reviewed rate", value: LinePayFormat.rate(agreement.hourlyRate))
                    }
                    Text(changeExplanation)
                        .accessibilityIdentifier("pay-profile.scope-explanation")
                        .accessibilityLabel(changeExplanation)
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

    private var editScopeTitle: String {
        switch draft.editScope {
        case .futurePeriods: "Future work periods only"
        case .datedChange: "New rules from a date"
        case .currentPeriod: "Recalculate this entire current period"
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
            if let onPortableReviewed {
                guard portableConfirmations == PortableNativeAdoption.requiredFields else {
                    throw AppModelError.invalidField(
                        "Independently review each material choice before adopting copied work")
                }
                var confirmed = draft
                confirmed.roundingRule = portableRounding
                try onPortableReviewed(
                    confirmed, portableConfirmations, portableMakeDefaultForFuture)
            } else {
                try model.saveProfile(draft, scope: selectedScope)
            }
            onSaved?()
            if onSaved == nil { dismiss() }
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }

    private var portableRounding: MoneyRoundingRule { draft.roundingRule ?? MoneyRoundingRule() }
    private var portableScale: Binding<Int> {
        Binding(
            get: { portableRounding.scale },
            set: {
                draft.roundingRule = MoneyRoundingRule(
                    scale: $0, mode: portableRounding.mode, scope: portableRounding.scope)
            })
    }
    private var portableMode: Binding<MoneyRoundingMode> {
        Binding(
            get: { portableRounding.mode },
            set: {
                draft.roundingRule = MoneyRoundingRule(
                    scale: portableRounding.scale, mode: $0, scope: portableRounding.scope)
            })
    }
    private var portableScope: Binding<PayRoundingScope> {
        Binding(
            get: { portableRounding.scope },
            set: {
                draft.roundingRule = MoneyRoundingRule(
                    scale: portableRounding.scale, mode: portableRounding.mode, scope: $0)
            })
    }

    private func portableCheck(_ key: String, _ title: String) -> some View {
        ConfirmationCheckRow(
            title,
            isOn: Binding(
                get: { portableConfirmations.contains(key) },
                set: { value in
                    if value {
                        portableConfirmations.insert(key)
                    } else {
                        portableConfirmations.remove(key)
                    }
                })
        ).accessibilityIdentifier("portable.confirm." + key)
    }

    private var stepPurpose: String {
        switch step {
        case 0: "Your base pay. Everything else builds on it."
        case 1: "The dates your paycheck covers."
        case 2: "Turn on only the extras your employer or pay agreement actually pays."
        default:
            editing
                ? "Check the change and choose which work it applies to."
                : "Check the summary. You can change these rules later in Settings."
        }
    }

    private func ruleToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.footnote).foregroundStyle(LinePayColor.textSecondary)
            }
        }
    }

    private func number(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline)
            TextField(label, text: binding).linePayNumberEntry()
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
    /// The payroll zones of the storefronts LinePaycheck is sold in (U.S., Canada, Vietnam), plus
    /// whatever zone is already chosen.
    private var timeZones: [String] {
        Array(
            Set([
                draft.timeZoneIdentifier, "America/Los_Angeles", "America/Denver",
                "America/Phoenix", "America/Chicago", "America/New_York", "America/Anchorage",
                "Pacific/Honolulu", "America/St_Johns", "America/Halifax", "America/Toronto",
                "America/Winnipeg", "America/Regina", "America/Edmonton", "America/Vancouver",
                "Asia/Ho_Chi_Minh",
            ])
        ).sorted()
    }
    private var periodPreview: String {
        guard
            let window = try? PayPeriodSchedule.window(
                cadence: draft.preferredCadence, startDate: draft.periodStartDate,
                manualEndDate: draft.manualPeriodEndDate,
                timeZoneIdentifier: draft.timeZoneIdentifier)
        else { return "Choose valid dates; twice-monthly periods start on the 1st or 16th." }
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = zone
        return formatter.string(from: window.startDate, to: window.displayEndDate)
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
        LabeledContent("Base rate", value: "\(LinePayFormat.rate(agreement.hourlyRate))/hr")
        ForEach(Array(agreement.dailyOvertimeTiers.enumerated()), id: \.offset) { _, tier in
            LabeledContent(
                "Daily overtime after \(LinePayFormat.hours(tier.afterHours)) h",
                value: "\(LinePayFormat.decimal(tier.multiplier))×")
        }
        ForEach(Array(agreement.weekdayPremiums.enumerated()), id: \.offset) { _, premium in
            LabeledContent(
                "\(Calendar(identifier: .gregorian).weekdaySymbols[premium.weekday.rawValue - 1]) premium",
                value: "\(LinePayFormat.decimal(premium.multiplier))×")
        }
        ForEach(Array(agreement.datePremiums.enumerated()), id: \.offset) { _, premium in
            LabeledContent(
                "Premium date \(LinePayFormat.localDate(premium.date))",
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
            LabeledContent(
                "Per diem per worked date", value: LinePayFormat.money(rule.amountPerWorkDate))
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
