import AVFoundation
import LinePayDomain
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PaystubImportView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    let periodID: UUID
    let onCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingScanner = false
    @State private var showingFileImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingReview = false
    @State private var reviewDraft: PaystubConfirmationDraft?
    @State private var operation = PaystubImportOperation()
    @State private var errorMessage: String?
    @State private var cameraDenied = false
    @State private var processingTask: Task<Void, Never>?
    @State private var discardOther = false
    private var isProcessing: Bool { operation.isProcessing }
    private var anotherDraft: Bool {
        model.paystubDraft != nil && model.paystubDraft?.targetPeriodID != periodID
    }
    var body: some View {
        NavigationStack {
            List {
                if let context = model.periodContext(id: periodID) {
                    Section {
                        Text(
                            LinePayFormat.payPeriod(
                                context.window, timeZoneIdentifier: context.timeZoneIdentifier)
                        ).font(.headline)
                        Text(
                            "Add the paycheck for this work period. Paystubs are read on this iPhone, and you confirm every value before anything is compared."
                        )
                        .foregroundStyle(LinePayColor.textSecondary)
                    }
                }
                if anotherDraft {
                    Section {
                        Text(
                            "An unfinished paycheck review belongs to a different period. Resume it from History, or explicitly discard that draft before starting another."
                        )
                        Button("Discard the other unfinished review", role: .destructive) {
                            discardOther = true
                        }
                    }
                } else {
                    Section("Paycheck source") {
                        if model.paystubDraft?.targetPeriodID == periodID {
                            Button("Resume saved review") {
                                reviewDraft = model.paystubDraft
                                showingReview = true
                            }
                            .accessibilityIdentifier("paystub.resume")
                        } else if model.periodContext(id: periodID)?.paystub != nil {
                            Button("Correct existing facts, keep original") { manual() }
                                .accessibilityIdentifier("paystub.correct-existing")
                        }
                        if DocumentScannerView.isSupported {
                            Button("Scan paystub", systemImage: "doc.viewfinder") { scan() }
                                .accessibilityIdentifier("paystub.scan")
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose photo", systemImage: "photo")
                        }
                        .accessibilityIdentifier("paystub.choose-photo")
                        Button("Choose PDF or image", systemImage: "folder") {
                            showingFileImporter = true
                        }
                        .accessibilityIdentifier("paystub.choose-file")
                        Button("Type in the gross pay", systemImage: "keyboard") { manual() }
                            .accessibilityIdentifier("paystub.manual")
                    }.disabled(isProcessing)
                }
                if cameraDenied {
                    Section {
                        Text(
                            "Camera access is disabled. Choose a photo/file, enter manually, or enable the camera in Settings."
                        )
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open iOS Settings", destination: url)
                        }
                    }
                }
                if isProcessing {
                    Section { ProgressView(operation.message) }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
                Section {
                    Text(
                        "No account, and your paystub is not uploaded. A file stored in iCloud may need a connection to download first."
                    ).font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                }
            }
            .linePayCanvas()
            .navigationTitle("Check paycheck").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Unfinished reviews are saved as they change, so closing never loses work.
                    Button("Close") {
                        operation.cancel()
                        processingTask?.cancel()
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showingReview) {
                if let draft = reviewDraft ?? model.paystubDraft,
                    draft.targetPeriodID == periodID
                {
                    PaystubReviewView(
                        model: model, subscriptionStore: subscriptionStore, draft: draft
                    ) {
                        onCompleted()
                        dismiss()
                    }
                }
            }
        }
        .tint(LinePayColor.actionText)
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView(
                onScan: { data in
                    showingScanner = false
                    begin(
                        data, filename: "Scanned Paystub.pdf", mediaType: "application/pdf",
                        sourceKind: .scan)
                }, onCancel: { showingScanner = false },
                onError: {
                    showingScanner = false
                    errorMessage = $0.localizedDescription
                }
            ).ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image]) {
            result in
            switch result {
            case .success(let url):
                guard let token = beginLoading() else { return }
                processingTask = Task {
                    defer { operation.finish(token) }
                    do {
                        let data = try await Self.readFile(url)
                        try Task.checkCancellation()
                        await process(
                            data: data, filename: url.lastPathComponent,
                            mediaType: UTType(filenameExtension: url.pathExtension)?
                                .preferredMIMEType ?? "application/octet-stream", sourceKind: .file,
                            token: token)
                    } catch is CancellationError {} catch {
                        if operation.owns(token) { errorMessage = error.localizedDescription }
                    }
                }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, value in
            guard let value, let token = beginLoading() else { return }
            processingTask = Task {
                defer { operation.finish(token) }
                do {
                    guard let data = try await value.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadUnknown)
                    }
                    try Task.checkCancellation()
                    let type = value.supportedContentTypes.first ?? .jpeg
                    await process(
                        data: data, filename: "Paystub.\(type.preferredFilenameExtension ?? "jpg")",
                        mediaType: type.preferredMIMEType ?? "image/jpeg", sourceKind: .photo,
                        token: token)
                } catch is CancellationError {} catch {
                    if operation.owns(token) { errorMessage = error.localizedDescription }
                }
            }
        }
        .confirmationDialog(
            "Discard the other unfinished review?", isPresented: $discardOther,
            titleVisibility: .visible
        ) {
            Button("Discard review draft", role: .destructive) {
                do {
                    try model.savePaystubDraft(nil)
                    try model.retryEvidenceDeletion()
                } catch { errorMessage = error.localizedDescription }
            }
        } message: {
            Text(
                "Confirmed audits remain. A new original used only by that unfinished review will be removed, or queued for deletion."
            )
        }
    }
    private func manual() {
        do {
            let draft = try model.paycheckDraft(for: periodID)
            try model.savePaystubDraft(draft)
            reviewDraft = draft
            showingReview = true
        } catch { errorMessage = error.localizedDescription }
    }
    private func beginLoading() -> UUID? {
        guard let token = operation.begin() else { return nil }
        errorMessage = nil
        return token
    }
    private func scan() {
        guard let token = beginLoading() else { return }
        processingTask = Task {
            defer { operation.finish(token) }
            let allowed: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: allowed = true
            case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
            default: allowed = false
            }
            guard operation.owns(token), !Task.isCancelled else { return }
            showingScanner = allowed
            cameraDenied = !allowed
        }
    }
    private func begin(
        _ data: Data, filename: String, mediaType: String, sourceKind: PaystubSourceKind
    ) {
        guard let token = beginLoading() else { return }
        processingTask = Task {
            defer { operation.finish(token) }
            await process(
                data: data, filename: filename, mediaType: mediaType, sourceKind: sourceKind,
                token: token)
        }
    }
    private func process(
        data: Data, filename: String, mediaType: String, sourceKind: PaystubSourceKind,
        token: UUID
    ) async {
        guard operation.owns(token), !Task.isCancelled else { return }
        do {
            var draft = try model.stagePaystub(
                data: data, filename: filename, mediaType: mediaType, kind: sourceKind,
                periodID: periodID)
            operation.didSaveOriginal(token)
            do {
                let result = try await PaystubOCRService().recognize(
                    data: data, fileExtension: URL(fileURLWithPath: filename).pathExtension)
                try Task.checkCancellation()
                guard operation.owns(token) else { return }
                draft.suggestions = result.suggestions
                draft.recognizedText = result.recognizedText
                draft.processingNotice = result.notice
                draft.sourcePageCount = result.pageCount
                draft.hasAdditionalUnmappedPay = result.notice != nil
                for (field, suggestion) in result.suggestions {
                    guard let value = suggestion.value else { continue }
                    if field.isDate {
                        let parts = value.split(separator: "-").compactMap { Int($0) }
                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone =
                            TimeZone(
                                identifier: model.periodContext(id: periodID)?.timeZoneIdentifier
                                    ?? "") ?? .current
                        if parts.count == 3,
                            let date = calendar.date(
                                from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
                            )
                        {
                            if field == .periodStart {
                                draft.payPeriodStartDate = date
                            } else {
                                draft.payPeriodEndDate = date
                            }
                        }
                    } else {
                        draft[field] = value
                    }
                }
            } catch is CancellationError { return } catch {
                draft.processingNotice =
                    "Automatic reading was incomplete. The original is saved. Review and enter the values manually."
            }
            guard operation.owns(token), !Task.isCancelled else { return }
            try model.savePaystubDraft(draft)
            reviewDraft = draft
            showingReview = true
        } catch {
            if operation.owns(token) { errorMessage = error.localizedDescription }
        }
    }
    private static func readFile(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let stream = InputStream(url: url) else { throw CocoaError(.fileReadUnknown) }
            stream.open()
            defer { stream.close() }
            var bytes = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                try Task.checkCancellation()
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
                if count == 0 { break }
                guard bytes.count + count <= 25 * 1024 * 1024 else {
                    throw PaystubOCRError.oversizedDocument
                }
                bytes.append(contentsOf: buffer.prefix(count))
            }
            return bytes
        }.value
    }
}

struct PaystubReviewView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    let onConfirmed: () -> Void
    @State private var draft: PaystubConfirmationDraft
    @State private var errorMessage: String?
    @State private var isClosing = false
    @State private var selectedField: PaystubField?
    init(
        model: AppModel, subscriptionStore: SubscriptionStore, draft: PaystubConfirmationDraft,
        onConfirmed: @escaping () -> Void
    ) {
        self.model = model
        self.subscriptionStore = subscriptionStore
        self.onConfirmed = onConfirmed
        _draft = State(initialValue: draft)
    }
    private var zone: TimeZone {
        TimeZone(
            identifier: model.periodContext(id: draft.targetPeriodID)?.timeZoneIdentifier ?? "")
            ?? .current
    }
    private var minimumConfirmed: Bool {
        draft.reviewedFields.isSuperset(of: [.periodStart, .periodEnd, .grossPay])
    }
    private var readyToCompare: Bool {
        draft.grossBasis != .unconfirmed && draft.workComplete == true
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.sourceEvidence == nil ? "Enter your paystub" : "Check what was read")
                        .font(.title2.bold())
                    Text(
                        draft.sourceEvidence == nil
                            ? "Three facts are enough to compare: the dates it covers and its gross pay."
                            : "Compare each value with the original. Nothing counts until you confirm it."
                    )
                    .font(.subheadline).foregroundStyle(LinePayColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                if let notice = draft.processingNotice {
                    Text(notice).foregroundStyle(LinePayColor.review)
                }
            }
            minimumFacts
            Section {
                ConfirmationCheckRow(
                    "My work log covers this whole pay period",
                    isOn: Binding(
                        get: { draft.workComplete == true }, set: { draft.workComplete = $0 })
                )
                .accessibilityIdentifier("paystub.complete-work")
            } footer: {
                Text(
                    "Include every shift and unpaid break. A partial work log cannot show whether the paycheck for the full work period is short."
                )
            }
            Section {
                ForEach([PaystubGrossBasis.wagesOnly, .wagesAndPerDiem], id: \.self) { basis in
                    Button {
                        draft.grossBasis = basis
                    } label: {
                        HStack(spacing: LinePaySpacing.standard - 4) {
                            Image(
                                systemName: draft.grossBasis == basis
                                    ? "checkmark.circle.fill" : "circle"
                            )
                            .foregroundStyle(
                                draft.grossBasis == basis
                                    ? LinePayColor.actionText : LinePayColor.lineStrong
                            )
                            .accessibilityHidden(true)
                            Text(basis.title).foregroundStyle(LinePayColor.textPrimary)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(draft.grossBasis == basis ? .isSelected : [])
                    .accessibilityIdentifier("paystub.gross-basis.\(basis.rawValue)")
                }
            } header: {
                Text("What does the gross pay include?")
                    .accessibilityIdentifier("paystub.gross-basis")
            } footer: {
                Text(
                    "Compare gross wages, not take-home pay. If your paystub shows no per diem, choose wages only. LinePaycheck does not infer tax treatment."
                )
            }
            Section {
                DisclosureGroup("Hours and earnings lines") {
                    ForEach(PaystubField.allCases.filter { !$0.isDate && $0 != .grossPay }) {
                        field in fieldRow(field)
                    }
                }
            } header: {
                Text("Optional confirmed lines")
            } footer: {
                Text(
                    "Unconfirmed optional lines are left out, and the check is marked as limited."
                )
            }
            Section {
                DisclosureGroup("How earnings lines are reported") {
                    Picker("Earnings layout", selection: $draft.lineLayout) {
                        ForEach(PaystubLineLayout.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("paystub.line-layout")
                    Picker("Hours mean", selection: $draft.hoursBasis) {
                        ForEach(PaystubHoursBasis.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.navigationLink)
                    Picker("Callout guarantee", selection: $draft.guaranteeLayout) {
                        ForEach(PaystubGuaranteeLayout.allCases, id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }.pickerStyle(.navigationLink)
                    Text(
                        "Full-rate example: 8 h × $50 = $400 regular; 2 h × $75 = $150 OT. Premium-only example: all 10 h × $50 = $500 base; 2 h × $25 = $50 extra OT. Choose only the layout your paystub uses."
                    ).font(.footnote)
                }
                Toggle(
                    "Other pay lines or rules remain unmapped",
                    isOn: $draft.hasAdditionalUnmappedPay)
            }
            Section("Note") {
                TextField("What still needs checking?", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle("Review paystub").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedField) { field in
            PaystubFieldReviewView(model: model, field: field, draft: $draft, timeZone: zone)
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
                Group {
                    // Saving without comparing is legitimate but not the next step a worker should
                    // take by reflex, so it does not wear the primary fill until both answers exist.
                    if readyToCompare {
                        Button("Compare with expected pay") { confirm() }
                            .buttonStyle(LinePayPrimaryButtonStyle())
                    } else {
                        Button("Save without comparing") { confirm() }
                            .buttonStyle(LinePaySecondaryButtonStyle())
                    }
                }
                .disabled(!minimumConfirmed)
                .accessibilityIdentifier("paystub.audit")
                Text(actionHint)
                    .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .environment(\.timeZone, zone)
        .onChange(of: draft) { _, value in
            guard !isClosing else { return }
            do { try model.savePaystubDraft(value) } catch {
                errorMessage =
                    "This review could not be saved. Keep the screen open and retry after freeing storage."
            }
        }
    }

    private var actionHint: String {
        if !minimumConfirmed {
            return "Confirm the paystub dates and gross pay to continue."
        }
        if !readyToCompare {
            // Name exactly what is left; the questions sit above this bar, in the form.
            let remaining = [
                draft.workComplete == true ? nil : "confirm your work log covers the period",
                draft.grossBasis == .unconfirmed ? "choose what the gross pay includes" : nil,
            ].compactMap { $0 }.joined(separator: " and ")
            return
                "To compare, \(remaining). Saving without comparing does not use your free check."
        }
        return model.hasUsedFreeAudit
            ? "Compares these confirmed facts with the expected pay for this period."
            : "Your first comparable paycheck check is free."
    }

    @ViewBuilder private var minimumFacts: some View {
        Section {
            DatePicker(
                "Pay period starts", selection: dateBinding(.periodStart),
                displayedComponents: .date
            )
            .accessibilityIdentifier("paystub.inline.periodStart")
            DatePicker(
                "Pay period ends", selection: dateBinding(.periodEnd), displayedComponents: .date
            )
            .accessibilityIdentifier("paystub.inline.periodEnd")
            ConfirmationCheckRow(
                "These dates match the paystub",
                isOn: Binding(
                    get: { draft.reviewedFields.isSuperset(of: [.periodStart, .periodEnd]) },
                    set: { confirmed in
                        if confirmed, draft.payPeriodStartDate != nil,
                            draft.payPeriodEndDate != nil
                        {
                            draft.reviewedFields.formUnion([.periodStart, .periodEnd])
                        } else {
                            draft.reviewedFields.subtract([.periodStart, .periodEnd])
                        }
                    })
            )
            .accessibilityIdentifier("paystub.confirm-dates")
            HStack(alignment: .firstTextBaseline, spacing: LinePaySpacing.standard) {
                Text("Gross pay")
                TextField("Amount", text: grossBinding)
                    .linePayNumberEntry()
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("Gross pay")
                    .accessibilityIdentifier("paystub.inline.gross")
            }
            .frame(minHeight: 48)
            grossStatus
            if let evidence = draft.sourceEvidence, let url = model.evidenceURL(for: evidence) {
                NavigationLink("View the original paystub") {
                    SourceEvidenceView(url: url, region: draft.suggestions[.grossPay]?.region)
                }
                .accessibilityIdentifier("paystub.view-original")
            }
        } header: {
            Text("From your paystub")
        } footer: {
            Text(
                "Use this period's gross pay, before taxes and deductions. Not year-to-date, and not take-home pay."
            )
        }
    }

    @ViewBuilder private var grossStatus: some View {
        let value = draft.grossPay
        if draft.reviewedFields.contains(.grossPay) {
            Label(
                draft.suggestions[.grossPay]?.value == value
                    ? "Read from the paystub and confirmed by you" : "Entered by you",
                systemImage: "checkmark.circle"
            )
            .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
        } else if !value.isEmpty, Self.isValidAmount(value, currencyCode: currency) {
            // A machine-read value counts only after the worker checks it.
            Button("Confirm \(value) matches the paystub") {
                draft.reviewedFields.insert(.grossPay)
            }
            .linePayRowAction(minHeight: 44)
            .accessibilityIdentifier("paystub.confirm-gross")
            if let reason = draft.suggestions[.grossPay]?.reason {
                Text(reason).font(.footnote)
            }
        } else if !value.isEmpty {
            let comma = NumberEntry.decimalSeparator == ","
            let example =
                NumberEntry.amountFractionDigits(currencyCode: currency) == 0
                ? (comma ? "15.000.000" : "15,000,000") : (comma ? "1.250,00" : "1,250.00")
            Text("Use a complete amount such as \(example), with no other text.")
                .font(.footnote).foregroundStyle(LinePayColor.review)
        }
    }

    private var grossBinding: Binding<String> {
        Binding(
            get: { draft.grossPay },
            set: { value in
                draft.grossPay = value
                // Typing the amount is the worker's own confirmation; an untouched OCR reading
                // still needs an explicit check above.
                if Self.isValidAmount(value, currencyCode: currency),
                    draft.suggestions[.grossPay]?.value != value
                {
                    draft.reviewedFields.insert(.grossPay)
                } else {
                    draft.reviewedFields.remove(.grossPay)
                }
            })
    }

    private func dateBinding(_ field: PaystubField) -> Binding<Date> {
        Binding(
            get: {
                (field == .periodStart ? draft.payPeriodStartDate : draft.payPeriodEndDate)
                    ?? Date()
            },
            set: {
                if field == .periodStart {
                    draft.payPeriodStartDate = $0
                } else {
                    draft.payPeriodEndDate = $0
                }
                draft.reviewedFields.remove(field)
            })
    }

    static func isValidAmount(_ text: String, currencyCode: String) -> Bool {
        (try? NumberEntry.amount(text, currencyCode: currencyCode)) != nil
    }

    /// Paystub amounts are in the pay profile's currency.
    private var currency: String { model.profile?.agreement.hourlyRate.currencyCode ?? "USD" }

    private func fieldRow(_ field: PaystubField) -> some View {
        Button {
            selectedField = field
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(field.title).font(.headline)
                        .foregroundStyle(LinePayColor.textPrimary)
                    Spacer()
                    // An empty optional line is not a problem to resolve; only a value that has
                    // not been checked against the paystub asks for review.
                    let reviewed = draft.reviewedFields.contains(field)
                    let empty = !field.isDate && draft[field].isEmpty
                    Label(
                        reviewed ? "Confirmed" : empty ? "Optional" : "Review",
                        systemImage: reviewed
                            ? "checkmark.circle" : empty ? "plus.circle" : "questionmark.circle"
                    )
                    .font(.caption).foregroundStyle(
                        reviewed || empty ? LinePayColor.textSecondary : LinePayColor.review)
                }
                Text(fieldValue(field)).monospacedDigit()
                    .foregroundStyle(
                        !field.isDate && draft[field].isEmpty
                            ? LinePayColor.textSecondary : LinePayColor.textPrimary)
                if let reason = draft.suggestions[field]?.reason { Text(reason).font(.footnote) }
            }.padding(.vertical, 4)
        }.accessibilityIdentifier("paystub.field.\(field.rawValue)")
    }
    private func fieldValue(_ field: PaystubField) -> String {
        if field.isDate {
            guard
                let date = field == .periodStart ? draft.payPeriodStartDate : draft.payPeriodEndDate
            else { return "Not entered" }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeZone = zone
            return formatter.string(from: date)
        }
        return draft[field].isEmpty ? "Not entered" : draft[field]
    }
    private func confirm() {
        do {
            isClosing = true
            try model.confirmPaystub(draft, hasProAccess: subscriptionStore.hasAuditAccess)
            errorMessage = nil
            onConfirmed()
        } catch {
            isClosing = false
            errorMessage = error.localizedDescription
        }
    }
}

struct PaystubFieldReviewView: View {
    let model: AppModel
    let field: PaystubField
    @Binding var draft: PaystubConfirmationDraft
    let timeZone: TimeZone
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    var body: some View {
        Form {
            if let evidence = draft.sourceEvidence, let url = model.evidenceURL(for: evidence) {
                Section("Source") {
                    if let suggestion = draft.suggestions[field] {
                        Text(suggestion.sourceText).font(.body.monospaced()).textSelection(.enabled)
                        NavigationLink("View original field, page \(suggestion.region.page + 1)") {
                            SourceEvidenceView(
                                url: url, region: suggestion.region,
                                sourceText: suggestion.sourceText)
                        }
                    } else {
                        NavigationLink("View original paystub") {
                            SourceEvidenceView(url: url, region: nil)
                        }
                    }
                }
            }
            Section("Value shown on the paystub") {
                if field.isDate {
                    DatePicker(field.title, selection: dateBinding, displayedComponents: .date)
                } else {
                    TextField(field.title, text: numberBinding).linePayNumberEntry()
                        .accessibilityIdentifier("paystub.value")
                }
                Text("Confirm current-period values, not year-to-date totals.").font(.footnote)
            }
            Section {
                Button("Confirm this field") {
                    do {
                        if !field.isDate {
                            _ =
                                try field.isHours
                                ? NumberEntry.hours(draft[field])
                                : NumberEntry.amount(
                                    draft[field],
                                    currencyCode: model.profile?.agreement.hourlyRate.currencyCode
                                        ?? "USD")
                        }
                        draft.reviewedFields.insert(field)
                        if persistDraft() { dismiss() }
                    } catch {
                        errorMessage =
                            "Use a complete nonnegative number such as 1,250.00. No text or ambiguous separators."
                    }
                }.buttonStyle(LinePayPrimaryButtonStyle()).accessibilityIdentifier(
                    "paystub.confirm-field")
                if !field.isDate && field != .grossPay {
                    Button("Exclude this unconfirmed line") {
                        draft[field] = ""
                        draft.reviewedFields.remove(field)
                        draft.hasAdditionalUnmappedPay = true
                        if persistDraft() { dismiss() }
                    }
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayKeyboardDismiss()
        .navigationTitle(field.title).navigationBarTitleDisplayMode(.inline)
        .linePayCanvas()
        .environment(\.timeZone, timeZone)
    }
    private var numberBinding: Binding<String> {
        Binding(
            get: { draft[field] },
            set: {
                draft[field] = $0
                draft.reviewedFields.remove(field)
                _ = persistDraft()
            })
    }
    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                (field == .periodStart ? draft.payPeriodStartDate : draft.payPeriodEndDate)
                    ?? Date()
            },
            set: {
                if field == .periodStart {
                    draft.payPeriodStartDate = $0
                } else {
                    draft.payPeriodEndDate = $0
                }
                draft.reviewedFields.remove(field)
                _ = persistDraft()
            })
    }

    private func persistDraft() -> Bool {
        // The review-list view is inactive while this pushed field editor is visible.
        // Save here so interruption never depends on the parent's onChange running.
        do {
            try model.savePaystubDraft(draft)
            errorMessage = nil
            return true
        } catch {
            errorMessage =
                "This field could not be saved. Keep it open and free storage before leaving."
            return false
        }
    }
}
