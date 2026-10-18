import SwiftUI
import UniformTypeIdentifiers

struct AgreementDocumentReviewView: View {
    let model: AppModel
    let documentID: UUID
    let onPrepared: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var review = AgreementImportReview()
    @State private var errorMessage: String?
    @State private var retry = 0
    @State private var preparing = false
    @State private var prepareTask: Task<Void, Never>?
    @State private var replaceDraft = false
    @State private var removeOriginal = false
    @State private var deleteImport = false
    @State private var reattaching = false

    var body: some View {
        Form {
            if let document = model.agreementDocument(id: documentID) {
                Section {
                    Text(document.filename).font(.headline)
                    Text(
                        "Proposed rules need your review. Nothing is active yet."
                    )
                    .font(.subheadline)
                    NavigationLink("Read retained original") {
                        AgreementOriginalView(model: model, documentID: documentID)
                    }
                    .accessibilityIdentifier("agreement.open-original")
                    if let notice = document.extractionNotice {
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LinePayColor.review)
                    }
                }
                if let candidates = document.candidates {
                    Section("Candidate clauses") {
                        if candidates.isEmpty {
                            Text(
                                "No safe candidate mapping was found. You can prepare a manual setup with this document as a reference after reviewing applicability and dates."
                            )
                        }
                        ForEach(candidates) { candidate in
                            if let index = review.rules.firstIndex(where: {
                                $0.candidateID == candidate.id
                            }) {
                                NavigationLink {
                                    AgreementCandidateReviewView(
                                        model: model, documentID: documentID,
                                        candidate: candidate, review: $review.rules[index])
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(candidate.kind.title).font(.headline)
                                        Text(
                                            "PDF page \(candidate.page + 1) · \(review.rules[index].decision.title)"
                                        )
                                        .font(.subheadline)
                                        if let value = candidate.value {
                                            Text(
                                                "Original reading: \(value)\(candidate.multiplier.map { " at \($0)×" } ?? "")"
                                            )
                                            .monospacedDigit()
                                        }
                                        if candidate.status == .conflicting {
                                            Label(
                                                "Conflicting clauses",
                                                systemImage: "exclamationmark.triangle"
                                            )
                                            .font(.caption).foregroundStyle(LinePayColor.review)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(
                                    "agreement.candidate.\(candidate.kind.rawValue)")
                            }
                        }
                    }
                    applicability
                    dates
                    Section {
                        Text(
                            "Preparing only creates an editable draft. Other existing rule categories are kept. Review every rule and its scope in the editor before saving; current work and history stay unchanged until that confirmation."
                        )
                        .font(.footnote)
                        if selectsDailyTiers {
                            Toggle(
                                "Replace the draft's daily overtime tiers with the selected clauses",
                                isOn: $review.dailyTierReplacementConfirmed
                            )
                            .accessibilityIdentifier("agreement.confirm-tier-replacement")
                        }
                        Button("Review complete rule setup") {
                            if model.setupDraft != nil {
                                replaceDraft = true
                            } else {
                                prepare(replace: false)
                            }
                        }
                        .linePayRowAction()
                        .disabled(!ready || preparing)
                        .accessibilityIdentifier("agreement.prepare-setup")
                        if preparing { ProgressView("Preparing reviewed draft") }
                    }
                } else {
                    Section {
                        if let errorMessage {
                            Text(errorMessage)
                            Button("Retry reading") { retry += 1 }
                        } else {
                            ProgressView("Finding candidate clauses on this device")
                        }
                        Text(
                            "The original is already saved. Leaving cancels reading and keeps it available for a later retry."
                        )
                        .font(.footnote)
                    }
                }
                if let errorMessage, document.candidates != nil {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle") }
                }
                Section("Source record") {
                    Text("Recorded PDF fingerprint").font(.caption)
                    Text(document.sha256).font(.caption.monospaced()).textSelection(.enabled)
                    Text(
                        "A fingerprint binds retained bytes to a citation. It is not verification, endorsement or permission to republish the agreement."
                    )
                    .font(.footnote)
                    if document.evidence != nil {
                        Button("Remove retained original", role: .destructive) {
                            removeOriginal = true
                        }
                    } else {
                        Label("Original not retained", systemImage: "doc.badge.exclamationmark")
                        Button("Reattach exact original") { reattaching = true }
                    }
                    if model.canDeleteAgreementImport(id: documentID) {
                        Button("Delete unused import", role: .destructive) { deleteImport = true }
                    }
                }
            } else {
                ContentUnavailableView("Agreement unavailable", systemImage: "doc")
            }
        }
        .linePayCanvas()
        .linePayKeyboardDismiss()
        .navigationTitle("Review agreement").navigationBarTitleDisplayMode(.inline)
        .task(id: retry) { await readAndRestoreReview() }
        .onChange(of: review) { _, value in
            guard model.agreementDocument(id: documentID)?.candidates != nil,
                model.agreementDocument(id: documentID)?.review != value
            else { return }
            do { try model.saveAgreementReview(id: documentID, review: value) } catch {
                errorMessage = agreementImportMessage(error)
            }
        }
        .onDisappear { prepareTask?.cancel() }
        .confirmationDialog(
            "Replace unfinished rule setup?", isPresented: $replaceDraft, titleVisibility: .visible
        ) {
            Button("Replace draft and review", role: .destructive) { prepare(replace: true) }
        } message: {
            Text(
                "Only the unfinished setup is replaced. Saved pay rules and work are not changed by preparing this import."
            )
        }
        .confirmationDialog(
            "Remove this original PDF?", isPresented: $removeOriginal, titleVisibility: .visible
        ) {
            Button("Remove original", role: .destructive) {
                guard let evidence = model.agreementDocument(id: documentID)?.evidence else {
                    return
                }
                do { try model.removeEvidence(id: evidence.id) } catch {
                    errorMessage = agreementImportMessage(error)
                }
            }
        } message: {
            Text(
                "Saved citations and rule snapshots remain, but their original will be unavailable. Exported copies are not deleted. Reattachment requires the exact PDF."
            )
        }
        .confirmationDialog(
            "Delete this unused import?", isPresented: $deleteImport, titleVisibility: .visible
        ) {
            Button("Delete import", role: .destructive) {
                do {
                    try model.deleteUnusedAgreementImport(id: documentID)
                    dismiss()
                } catch { errorMessage = agreementImportMessage(error) }
            }
        } message: {
            Text(
                "This removes its local review and original. Imports cited by saved rules or a rule draft cannot be deleted this way."
            )
        }
        .fileImporter(isPresented: $reattaching, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            prepareTask = Task {
                do {
                    let data = try await AgreementDocumentService.read(url)
                    try Task.checkCancellation()
                    try model.reattachAgreementOriginal(id: documentID, data: data)
                    errorMessage = nil
                    retry += 1
                } catch is CancellationError { return } catch {
                    errorMessage = agreementImportMessage(error)
                }
            }
        }
    }

    private var applicability: some View {
        Section("Applicability") {
            Text(
                "Check employer, classification, workplace, amendments and dates against the complete original. LinePaycheck does not certify this agreement or your legal entitlements."
            )
            .font(.footnote)
            Toggle(
                "I checked that this agreement applies to my work",
                isOn: $review.applicabilityConfirmed
            )
            .accessibilityIdentifier("agreement.confirm-applicability")
            Picker(
                "Pay currency",
                selection: Binding(
                    get: { review.currencyCode },
                    set: {
                        review.currencyCode = $0
                        review.currencyConfirmed = false
                    })
            ) {
                ForEach(PayProfileDraft.supportedCurrencyCodes, id: \.self) { Text($0).tag($0) }
            }
            .disabled(model.profile != nil)
            Picker(
                "Payroll timezone",
                selection: Binding(
                    get: { review.timeZoneIdentifier },
                    set: { new in
                        let old = review.timeZoneIdentifier
                        review.startDate = rebased(review.startDate, from: old, to: new)
                        review.endDate = rebased(review.endDate, from: old, to: new)
                        review.timeZoneIdentifier = new
                        review.datesConfirmed = false
                    })
            ) {
                ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) {
                    Text(LinePayFormat.timeZoneName($0)).tag($0)
                }
            }
            Toggle(
                "I checked the currency of the selected amounts", isOn: $review.currencyConfirmed
            )
            .accessibilityIdentifier("agreement.confirm-currency")
        }
    }

    private var dates: some View {
        Section("Effective dates for my work") {
            Toggle(
                "Set applicable start date",
                isOn: Binding(
                    get: { review.startDate != nil },
                    set: {
                        review.startDate = $0 ? Date() : nil
                        review.datesConfirmed = false
                    }))
            if review.startDate != nil {
                DatePicker(
                    "Starts applying",
                    selection: Binding(
                        get: { review.startDate ?? Date() },
                        set: {
                            review.startDate = $0
                            review.datesConfirmed = false
                        }), displayedComponents: .date)
            }
            Toggle(
                "An end date is specified",
                isOn: Binding(
                    get: { review.endDate != nil },
                    set: {
                        review.endDate = $0 ? (review.startDate ?? Date()) : nil
                        review.datesConfirmed = false
                        review.noEndDateSpecified = false
                    }))
            if review.endDate != nil {
                DatePicker(
                    "Ends applying",
                    selection: Binding(
                        get: { review.endDate ?? Date() },
                        set: {
                            review.endDate = $0
                            review.datesConfirmed = false
                        }), displayedComponents: .date)
            } else {
                Toggle(
                    "I checked that no end date is specified",
                    isOn: Binding(
                        get: { review.noEndDateSpecified },
                        set: {
                            review.noEndDateSpecified = $0
                            review.datesConfirmed = false
                        })
                )
                .accessibilityIdentifier("agreement.confirm-no-end")
            }
            Toggle(
                "I checked these effective dates against the original", isOn: $review.datesConfirmed
            )
            .accessibilityIdentifier("agreement.confirm-dates")
            Text(
                "A missing date is unresolved. A proposed date is not confirmed just because it was extracted."
            )
            .font(.footnote)
        }
        .environment(\.timeZone, TimeZone(identifier: review.timeZoneIdentifier) ?? .gmt)
    }

    private var selectsDailyTiers: Bool {
        let ids = Set(review.rules.filter { $0.decision == .confirmed }.map(\.candidateID))
        return model.agreementDocument(id: documentID)?.candidates?.contains {
            ids.contains($0.id) && [.dailyOvertime, .dailyDoubleTime].contains($0.kind)
        } ?? false
    }

    private var ready: Bool {
        review.applicabilityConfirmed && review.currencyConfirmed && review.datesConfirmed
            && review.startDate != nil && (review.endDate != nil || review.noEndDateSpecified)
            && review.rules.allSatisfy { $0.decision != .unreviewed }
            && (!selectsDailyTiers || review.dailyTierReplacementConfirmed)
    }

    private func readAndRestoreReview() async {
        guard let document = model.agreementDocument(id: documentID) else { return }
        errorMessage = nil
        do {
            if document.candidates == nil {
                guard let evidence = document.evidence, let url = model.evidenceURL(for: evidence)
                else {
                    throw AppModelError.invalidField("Reattach the original to finish reading")
                }
                let data = try await AgreementDocumentService.read(url)
                guard AgreementDocumentService.digest(data) == document.sha256 else {
                    throw AppModelError.invalidField("The retained original has changed")
                }
                let result = try await AgreementDocumentService().extract(data)
                try Task.checkCancellation()
                try model.finishAgreementExtraction(id: documentID, result: result)
            }
            guard let current = model.agreementDocument(id: documentID) else { return }
            if let saved = current.review {
                review = saved
            } else {
                var initial = AgreementImportReview()
                initial.currencyCode =
                    model.profile?.agreement.hourlyRate.currencyCode
                    ?? PayProfileDraft.suggestedCurrencyCode
                initial.timeZoneIdentifier =
                    model.profile?.timeZoneIdentifier ?? TimeZone.current.identifier
                initial.rules = (current.candidates ?? []).map(ImportedRuleReview.init)
                for kind in [ImportedRuleKind.effectiveStart, .effectiveEnd] {
                    let dates = (current.candidates ?? []).filter {
                        $0.kind == kind && $0.status == .suggested
                    }
                    if dates.count == 1, let value = dates.first?.value,
                        let date = Self.date(value, zone: initial.timeZoneIdentifier)
                    {
                        if kind == .effectiveStart {
                            initial.startDate = date
                        } else {
                            initial.endDate = date
                        }
                    }
                }
                review = initial
                try model.saveAgreementReview(id: documentID, review: initial)
            }
        } catch is CancellationError { return } catch {
            errorMessage = agreementImportMessage(error)
        }
    }

    private func prepare(replace: Bool) {
        do { try model.saveAgreementReview(id: documentID, review: review) } catch {
            errorMessage = agreementImportMessage(error)
            return
        }
        preparing = true
        prepareTask = Task {
            defer { preparing = false }
            do {
                try await model.prepareImportedAgreement(
                    id: documentID, replaceExistingDraft: replace)
                errorMessage = nil
                onPrepared()
            } catch is CancellationError { return } catch {
                errorMessage = agreementImportMessage(error)
            }
        }
    }

    private func rebased(_ date: Date?, from old: String, to new: String) -> Date? {
        guard let date, let oldZone = TimeZone(identifier: old),
            let newZone = TimeZone(identifier: new)
        else { return date }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = oldZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        calendar.timeZone = newZone
        return calendar.date(from: parts)
    }

    private static func date(_ iso: String, zone: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let timezone = TimeZone(identifier: zone) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

private struct AgreementCandidateReviewView: View {
    let model: AppModel
    let documentID: UUID
    let candidate: ImportedRuleCandidate
    @Binding var review: ImportedRuleReview
    @State private var saveError: String?
    @FocusState private var editingField: String?

    private var canConfirm: Bool {
        candidate.status != .unsupported
            && (candidate.kind.canPreparePayRule
                || [.effectiveStart, .effectiveEnd].contains(candidate.kind))
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { review.value },
            set: {
                review.value = $0
                review.decision = .unreviewed
            })
    }

    private var multiplierBinding: Binding<String> {
        Binding(
            get: { review.multiplier },
            set: {
                review.multiplier = $0
                review.decision = .unreviewed
            })
    }

    var body: some View {
        Form {
            Section("Source excerpt · PDF page \(candidate.page + 1)") {
                Text(candidate.quote).textSelection(.enabled)
                if let confidence = candidate.recognitionConfidence {
                    LabeledContent("Text recognition confidence") {
                        Text(confidence, format: .percent.precision(.fractionLength(0)))
                    }
                } else {
                    Text("Read from the PDF text layer; not verified.").font(.footnote)
                }
                NavigationLink("Read original page") {
                    AgreementOriginalView(
                        model: model, documentID: documentID, page: candidate.page)
                }
                .accessibilityIdentifier("agreement.candidate-source")
                if let reason = candidate.reason {
                    Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(
                        LinePayColor.review)
                }
            }
            Section("Supported behavior") { Text(candidate.kind.behavior) }
            if canConfirm && candidate.kind.canPreparePayRule {
                Section("Values I reviewed") {
                    LinePayTextField(
                        candidate.kind.valueLabel, text: valueBinding, focus: $editingField,
                        identifier: "agreement.candidate-value"
                    ).linePayNumberEntry()
                    if [.dailyOvertime, .dailyDoubleTime].contains(candidate.kind) {
                        LinePayTextField(
                            "Multiplier", text: multiplierBinding, focus: $editingField,
                            identifier: "agreement.candidate-multiplier"
                        ).linePayNumberEntry()
                    }
                    Text("You can correct the reading from the original. Nothing is applied here.")
                        .font(.footnote)
                }
            }
            if let saveError { Section { Text(saveError).foregroundStyle(LinePayColor.review) } }
            Section("My decision") {
                ForEach(ImportedRuleDecision.allCases.filter { canConfirm || $0 != .confirmed }) {
                    decision in
                    Button {
                        review.decision = decision
                    } label: {
                        Label(
                            decision.title,
                            systemImage: review.decision == decision
                                ? "checkmark.circle.fill" : "circle")
                    }
                    .linePayRowAction()
                    .accessibilityValue(review.decision == decision ? "Selected" : "Not selected")
                    .accessibilityIdentifier("agreement.decision.\(decision.rawValue)")
                }
                Text(
                    "Not applicable is your recorded judgement about this clause, not a waiver or legal finding. Keep uncertainty unresolved rather than forcing a rule."
                )
                .font(.footnote)
            }
        }
        .linePayCanvas().linePayKeyboardDismiss()
        .navigationTitle(candidate.kind.title).navigationBarTitleDisplayMode(.inline)
        .onChange(of: review) { _, value in
            guard var stored = model.agreementDocument(id: documentID)?.review,
                let index = stored.rules.firstIndex(where: { $0.candidateID == value.candidateID }),
                stored.rules[index] != value
            else { return }
            stored.rules[index] = value
            do {
                try model.saveAgreementReview(id: documentID, review: stored)
                saveError = nil
            } catch { saveError = agreementImportMessage(error) }
        }
    }
}
