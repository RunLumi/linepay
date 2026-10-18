import LinePayDomain
import SwiftUI
import UniformTypeIdentifiers

struct BenefitAuditEditorView: View {
    let model: AppModel
    let onSaved: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var draft: BenefitAuditDraft
    @State private var step = 0
    @State private var errorMessage: String?
    @State private var formatNotice: String?
    @State private var preview: BenefitDraftPreview?
    @State private var choosingStatement = false
    @State private var readingStatement = false
    @State private var readTask: Task<Void, Never>?
    @FocusState private var editing: String?

    init(model: AppModel, draft: BenefitAuditDraft, onSaved: @escaping (UUID) -> Void) {
        self.model = model
        _draft = State(initialValue: draft)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Step \(step + 1) of 4").font(.caption)
                    Text(
                        [
                            "Fund and covered dates", "Rules and eligible units", "Statement facts",
                            "Review this check",
                        ][step]
                    ).font(.title2.bold())
                    Text(
                        "Employer contributions stay separate from wages, allowances and employee deductions."
                    ).font(.footnote)
                }
                if draft.decimalSeparator != String(NumberEntry.decimalSeparator) {
                    Section("Saved number format") {
                        Text(
                            "This draft uses \(draft.decimalSeparator) as its decimal separator. Your current region uses \(String(NumberEntry.decimalSeparator)). Complete or correct partial entries using the saved format, then convert before previewing."
                        )
                        Button("Use this region's number format") { convertNumberFormat() }
                            .linePayRowAction().accessibilityIdentifier("benefits.convert-format")
                    }
                }
                if let formatNotice { Section { Text(formatNotice).font(.footnote) } }
                switch step {
                case 0: basics
                case 1: rules
                case 2: statement
                default: review
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .accessibilityElement(children: .ignore).accessibilityLabel(
                                errorMessage
                            )
                            .accessibilityIdentifier("benefits.editor-error")
                            .foregroundStyle(LinePayColor.review)
                    }
                }
            }
            .linePayCanvas().linePayKeyboardDismiss()
            .environment(\.timeZone, TimeZone(identifier: draft.timeZoneIdentifier) ?? .gmt)
            .navigationTitle("Benefits check").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { step = max(0, step - 1) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LinePayBottomBar {
                    Button(
                        step == 3
                            ? (textSize.isAccessibilitySize
                                ? "Preview check" : "Preview benefits check") : "Continue"
                    ) {
                        do {
                            try model.keepBenefitDraft(draft)
                            if step < 3 {
                                step += 1
                            } else {
                                guard draft.decimalSeparator == String(NumberEntry.decimalSeparator)
                                else {
                                    throw AppModelError.invalidField(
                                        "Convert the saved number format before previewing")
                                }
                                preview = BenefitDraftPreview(
                                    input: draft, result: try draft.calculate())
                            }
                            errorMessage = nil
                        } catch { errorMessage = benefitErrorMessage(error) }
                    }
                    .buttonStyle(LinePayPrimaryButtonStyle())
                    .disabled(readingStatement)
                    .accessibilityIdentifier("benefits.continue")
                }
            }
        }
        .task {
            if draft.decimalSeparator != String(NumberEntry.decimalSeparator) {
                convertNumberFormat()
            } else {
                do { try model.keepBenefitDraft(draft) } catch {
                    errorMessage = benefitErrorMessage(error)
                }
            }
        }
        .onChange(of: draft) { previous, value in
            let reviewed = value.invalidatingReview(comparedTo: previous)
            if reviewed != value { draft = reviewed }
            do {
                try model.keepBenefitDraft(reviewed)
                if let saved = model.benefitAuditDraft, saved.id == draft.id, saved != draft {
                    draft = saved
                }
                errorMessage = nil
            } catch { errorMessage = benefitErrorMessage(error) }
        }
        .sheet(item: $preview) { value in
            BenefitReviewPreview(model: model, preview: value) { id in
                preview = nil
                onSaved(id)
            }
        }
        .fileImporter(isPresented: $choosingStatement, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            readingStatement = true
            readTask = Task {
                defer { readingStatement = false }
                do {
                    let data = try await AgreementDocumentService.read(url)
                    try Task.checkCancellation()
                    guard draft.hasStatement else { return }
                    try model.retainBenefitStatement(
                        data: data, filename: url.lastPathComponent, draftID: draft.id)
                    if let saved = model.benefitAuditDraft, saved.id == draft.id { draft = saved }
                    errorMessage = nil
                } catch is CancellationError { return } catch {
                    errorMessage = benefitErrorMessage(error)
                }
            }
        }
        .onDisappear { readTask?.cancel() }
    }

    private var basics: some View {
        Group {
            Section("One employer benefit fund") {
                LinePayTextField(
                    "Fund name", text: $draft.fundName, focus: $editing,
                    identifier: "benefits.fund-name")
                Picker("Benefit category", selection: $draft.kind) {
                    ForEach(BenefitKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                currency("Contribution currency", selection: $draft.currencyCode)
                Text("No fund membership, rate or eligibility is inferred from this name.").font(
                    .footnote)
            }
            Section("Work dates covered by this check") {
                DatePicker(
                    "First covered date", selection: $draft.start, displayedComponents: .date)
                DatePicker(
                    "Last covered date",
                    selection: benefitLastDate($draft.end, zone: draft.timeZoneIdentifier),
                    displayedComponents: .date)
                Picker(
                    "Payroll timezone",
                    selection: Binding(get: { draft.timeZoneIdentifier }, set: changeZone)
                ) {
                    ForEach(
                        Array(Set(TimeZone.knownTimeZoneIdentifiers + [draft.timeZoneIdentifier]))
                            .sorted(), id: \.self
                    ) {
                        Text(LinePayFormat.timeZoneName($0)).tag($0)
                    }
                }
                Text(
                    "Use the fund statement's work period, which may span several wage pay periods. Prefilled dates need your review."
                ).font(.footnote)
            }
        }
    }

    private var rules: some View {
        Group {
            Section("Date and rate segments") {
                ForEach($draft.segments) { $line in
                    NavigationLink {
                        BenefitSegmentEditor(
                            model: model, line: $line, currencyCode: draft.currencyCode,
                            zone: draft.timeZoneIdentifier, separator: draft.decimalSeparator)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(line.basis.title).font(.headline)
                            Text(
                                "Rate: \(line.rate.isEmpty ? "not entered" : line.rate) · Units: \(line.quantity.isEmpty ? "not entered" : line.quantity)"
                            ).monospacedDigit()
                            Label(
                                line.eligibilityConfirmed
                                    ? "Reviewed eligibility" : "Eligibility needs review",
                                systemImage: line.eligibilityConfirmed
                                    ? "checkmark.circle" : "circle"
                            )
                            .font(.subheadline)
                        }
                    }
                    .accessibilityIdentifier("benefits.segment")
                }
                .onDelete { indices in
                    if indices.count < draft.segments.count {
                        draft.segments.remove(atOffsets: indices)
                    }
                }
                if draft.segments.count < 64 {
                    Button("Add another date/rate segment") {
                        draft.segments.append(BenefitRuleDraft(start: draft.start, end: draft.end))
                    }
                    .linePayRowAction().accessibilityIdentifier("benefits.add-segment")
                }
                Text(
                    "A rate change needs separate nonoverlapping dates. For another fund, create another check. Eligible units may differ from clock hours or paid overtime hours."
                ).font(.footnote)
            }
            Section("Round the total for this fund") {
                Picker("Rounding method", selection: $draft.roundingMode) {
                    Text("Nearest, halves up").tag(MoneyRoundingMode.halfUp)
                    Text("Nearest, halves to even").tag(MoneyRoundingMode.bankers)
                    Text("Round down").tag(MoneyRoundingMode.down)
                    Text("Round up").tag(MoneyRoundingMode.up)
                }
                Picker("Decimal places", selection: $draft.roundingScale) {
                    ForEach(0...8, id: \.self) { Text("\($0)").tag($0) }
                }
                Text(
                    "Check the applicable rounding rule. Segment amounts are summed exactly, then rounded once for this fund; the app does not choose a legal policy for you."
                ).font(.footnote)
            }
        }
    }

    private var statement: some View {
        Group {
            Section {
                Toggle("I have an employer contribution statement", isOn: $draft.hasStatement)
                    .accessibilityIdentifier("benefits.has-statement")
                Text(
                    "An absent statement stays unverified. A deduction from your wages is not an employer contribution."
                ).font(.footnote)
            }
            if draft.hasStatement {
                Section("Statement values I read") {
                    LinePayTextField(
                        "Employer contribution amount (optional)", text: $draft.statementAmount,
                        focus: $editing, identifier: "benefits.statement-amount"
                    ).linePayNumberEntry()
                    LinePayTextField(
                        "Reported eligible units (optional)", text: $draft.statementQuantity,
                        focus: $editing, identifier: "benefits.statement-units"
                    ).linePayNumberEntry()
                    Picker("Reported unit basis", selection: $draft.statementBasis) {
                        ForEach(BenefitContributionBasis.allCases, id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }
                    currency("Statement currency", selection: $draft.statementCurrencyCode)
                    ConfirmationCheckRow(
                        "This statement is for this fund", isOn: $draft.statementMatchesFund
                    )
                    .accessibilityIdentifier("benefits.statement-fund")
                    Text("Decimal separator for this saved draft: \(draft.decimalSeparator).").font(
                        .footnote)
                    Text(
                        "Leave missing values empty. Enter zero only when you have confirmed that the statement actually reports zero."
                    ).font(.footnote)
                }
                Section("Statement work dates") {
                    DatePicker(
                        "First statement work date", selection: $draft.statementStart,
                        displayedComponents: .date)
                    DatePicker(
                        "Last statement work date",
                        selection: benefitLastDate(
                            $draft.statementEnd, zone: draft.statementTimeZoneIdentifier),
                        displayedComponents: .date)
                    Picker(
                        "Statement payroll timezone",
                        selection: Binding(
                            get: { draft.statementTimeZoneIdentifier },
                            set: { new in
                                draft.statementStart = benefitRebase(
                                    draft.statementStart, from: draft.statementTimeZoneIdentifier,
                                    to: new)
                                draft.statementEnd = benefitRebase(
                                    draft.statementEnd, from: draft.statementTimeZoneIdentifier,
                                    to: new)
                                draft.statementTimeZoneIdentifier = new
                            })
                    ) {
                        ForEach(
                            Array(
                                Set(
                                    TimeZone.knownTimeZoneIdentifiers + [
                                        draft.statementTimeZoneIdentifier
                                    ])
                            ).sorted(), id: \.self
                        ) {
                            Text(LinePayFormat.timeZoneName($0)).tag($0)
                        }
                    }
                }.environment(
                    \.timeZone, TimeZone(identifier: draft.statementTimeZoneIdentifier) ?? .gmt)
                Section("Optional original statement") {
                    Button("Retain statement PDF on this device") { choosingStatement = true }
                        .linePayRowAction().disabled(readingStatement).accessibilityIdentifier(
                            "benefits.import-statement")
                    if readingStatement { ProgressView("Reading selected file") }
                    if let evidence = draft.statementEvidence {
                        Text(evidence.originalFilename).font(.subheadline)
                        NavigationLink("Read retained statement") {
                            BenefitStatementOriginalView(model: model, origin: .draft(draft.id))
                        }.accessibilityIdentifier("benefits.draft-original")
                    } else {
                        Text(
                            "No original retained. Manual values remain your recorded observations."
                        ).font(.footnote)
                    }
                }
            }
        }
    }

    private var review: some View {
        Group {
            Section("Review source and eligibility") {
                Text(draft.fundName.isEmpty ? "Fund name still needed" : draft.fundName).font(
                    .headline)
                Text("\(draft.kind.title) · \(draft.currencyCode) · \(draft.timeZoneIdentifier)")
                Text(
                    "Decimal separator for this saved draft: \(draft.decimalSeparator). It stays fixed if the device region changes."
                ).font(.footnote)
                ForEach($draft.segments) { $line in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(line.basis.title).font(.headline)
                        Text("Rate \(line.rate) · \(line.basis.quantityTitle): \(line.quantity)")
                            .monospacedDigit()
                        Text(
                            "Eligible dates: \(benefitDateRange(line.start, line.end, zone: draft.timeZoneIdentifier))"
                        ).font(.footnote)
                        Text(
                            "Rule applies: \(benefitDateRange(line.effectiveStart, line.effectiveEnd, zone: draft.timeZoneIdentifier))"
                        ).font(.footnote)
                        if !line.reference.isEmpty { Text(line.reference).font(.footnote) }
                        ForEach(Array(line.sources.enumerated()), id: \.offset) { _, source in
                            Text(source.title).font(.footnote)
                            if let id = source.documentID {
                                NavigationLink("Read cited rule page") {
                                    AgreementOriginalView(
                                        model: model, documentID: id,
                                        page: source.documentPage ?? 0,
                                        expectedSHA256: source.documentSHA256)
                                }.buttonStyle(.borderless)
                            }
                        }
                        ConfirmationCheckRow(
                            "Eligible units reviewed",
                            isOn: $line.eligibilityConfirmed
                        )
                        .buttonStyle(.plain).accessibilityIdentifier("benefits.confirm-segment")
                    }
                }
                ConfirmationCheckRow(
                    "Rules and source reviewed",
                    isOn: $draft.rulesConfirmed
                )
                .accessibilityIdentifier("benefits.confirm-rules")
                ConfirmationCheckRow(
                    "Whole period covered",
                    isOn: $draft.completeEligibilityConfirmed
                )
                .accessibilityIdentifier("benefits.confirm-complete")
                if draft.hasStatement {
                    Text(
                        "Statement amount: \(draft.statementCurrencyCode) \(draft.statementAmount.isEmpty ? "not entered" : draft.statementAmount)"
                    ).monospacedDigit()
                    Text(
                        "Statement units: \(draft.statementQuantity.isEmpty ? "not entered" : draft.statementQuantity) · \(draft.statementBasis.title)"
                    ).monospacedDigit()
                    Text(
                        "\(benefitDateRange(draft.statementStart, draft.statementEnd, zone: draft.statementTimeZoneIdentifier)) · \(draft.statementTimeZoneIdentifier)"
                    ).font(.footnote)
                    Text(
                        draft.statementMatchesFund
                            ? "Marked as the same fund" : "Fund match not confirmed"
                    ).font(.footnote)
                    ConfirmationCheckRow(
                        "Statement facts reviewed",
                        isOn: $draft.statementConfirmed
                    )
                    .accessibilityIdentifier("benefits.confirm-statement")
                }
                LinePayTextField(
                    draft.recordID == nil
                        ? "Private note (optional)" : "Why I am correcting this check",
                    text: $draft.note, focus: $editing, identifier: "benefits.note")
                Text(
                    "A preview does not save a check. Review its scope, then explicitly save. Earlier revisions remain unchanged."
                ).font(.footnote)
            }
        }
    }

    private func convertNumberFormat() {
        do {
            let converted = try draft.convertingNumbers(to: NumberEntry.decimalSeparator)
            try model.keepBenefitDraft(converted)
            draft = model.benefitAuditDraft ?? converted
            formatNotice =
                "Numbers were reformatted for this region without changing their values. Review them again before saving."
            errorMessage = nil
        } catch { errorMessage = benefitErrorMessage(error) }
    }

    private func currency(_ label: String, selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            ForEach(PayProfileDraft.supportedCurrencyCodes, id: \.self) { Text($0).tag($0) }
        }
    }

    private func changeZone(_ new: String) {
        let old = draft.timeZoneIdentifier
        draft.start = benefitRebase(draft.start, from: old, to: new)
        draft.end = benefitRebase(draft.end, from: old, to: new)
        draft.segments = draft.segments.map { line in
            var value = line
            value.start = benefitRebase(line.start, from: old, to: new)
            value.end = benefitRebase(line.end, from: old, to: new)
            value.effectiveStart = benefitRebase(line.effectiveStart, from: old, to: new)
            value.effectiveEnd = benefitRebase(line.effectiveEnd, from: old, to: new)
            return value
        }
        draft.timeZoneIdentifier = new
    }
}

private struct BenefitDraftPreview: Identifiable {
    let input: BenefitAuditDraft
    let result: BenefitContributionResult
    var id: UUID { input.id }
}

private struct BenefitReviewPreview: View {
    let model: AppModel
    let preview: BenefitDraftPreview
    let onSaved: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(preview.input.fundName).font(.headline)
                    Text(preview.input.kind.title)
                }
                BenefitResultSections(result: preview.result)
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
                }
            }
            .labeledContentStyle(LinePayValueStyle())
            .linePayCanvas().navigationTitle("Review benefits check").navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LinePayBottomBar {
                    Button(
                        textSize.isAccessibilitySize ? "Save check" : "Save reviewed benefits check"
                    ) {
                        do { onSaved(try model.saveBenefitCheck(preview.input)) } catch {
                            errorMessage = benefitErrorMessage(error)
                        }
                    }
                    .buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                        "benefits.save-reviewed")
                }
            }
        }
    }
}
