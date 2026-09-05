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
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var cameraDenied = false
    @State private var processingTask: Task<Void, Never>?
    @State private var discardOther = false
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
                            "Choose the paycheck for this work period. Originals and unfinished reviews remain on this iPhone."
                        )
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
                            Button("Resume saved review") { showingReview = true }
                                .accessibilityIdentifier("paystub.resume")
                        } else if model.periodContext(id: periodID)?.paystub != nil {
                            Button("Correct existing facts, keep original") { manual() }
                                .accessibilityIdentifier("paystub.correct-existing")
                        }
                        if DocumentScannerView.isSupported {
                            Button("Scan paystub", systemImage: "doc.viewfinder") { scan() }
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose photo", systemImage: "photo")
                        }
                        Button("Choose PDF or image", systemImage: "folder") {
                            showingFileImporter = true
                        }
                        Button("Enter manually", systemImage: "keyboard") { manual() }
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
                    Section { ProgressView("Reading on this device. Original saved.") }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
                }
                Section {
                    Text(
                        "No account or paystub upload. Files stored in iCloud may require a connection to download before local processing."
                    ).font(.footnote)
                }
            }
            .navigationTitle("Check paycheck").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep draft and close") {
                        processingTask?.cancel()
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showingReview) {
                if let draft = model.paystubDraft, draft.targetPeriodID == periodID {
                    PaystubReviewView(
                        model: model, subscriptionStore: subscriptionStore, draft: draft
                    ) {
                        onCompleted()
                        dismiss()
                    }
                }
            }
        }
        .tint(LinePayColor.brandPrimary)
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
                processingTask?.cancel()
                processingTask = Task {
                    do {
                        let data = try await Self.readFile(url)
                        try Task.checkCancellation()
                        await process(
                            data: data, filename: url.lastPathComponent,
                            mediaType: UTType(filenameExtension: url.pathExtension)?
                                .preferredMIMEType ?? "application/octet-stream", sourceKind: .file)
                    } catch is CancellationError {} catch {
                        errorMessage = error.localizedDescription
                    }
                }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, value in
            guard let value else { return }
            processingTask?.cancel()
            processingTask = Task {
                do {
                    guard let data = try await value.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadUnknown)
                    }
                    try Task.checkCancellation()
                    let type = value.supportedContentTypes.first ?? .jpeg
                    await process(
                        data: data, filename: "Paystub.\(type.preferredFilenameExtension ?? "jpg")",
                        mediaType: type.preferredMIMEType ?? "image/jpeg", sourceKind: .photo)
                } catch is CancellationError {} catch { errorMessage = error.localizedDescription }
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
            try model.savePaystubDraft(model.paycheckDraft(for: periodID))
            showingReview = true
        } catch { errorMessage = error.localizedDescription }
    }
    private func scan() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: showingScanner = true
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showingScanner = true
                } else {
                    cameraDenied = true
                }
            default: cameraDenied = true
            }
        }
    }
    private func begin(
        _ data: Data, filename: String, mediaType: String, sourceKind: PaystubSourceKind
    ) {
        processingTask?.cancel()
        processingTask = Task {
            await process(
                data: data, filename: filename, mediaType: mediaType, sourceKind: sourceKind)
        }
    }
    private func process(
        data: Data, filename: String, mediaType: String, sourceKind: PaystubSourceKind
    ) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            var draft = try model.stagePaystub(
                data: data, filename: filename, mediaType: mediaType, kind: sourceKind,
                periodID: periodID)
            do {
                let result = try await PaystubOCRService().recognize(
                    data: data, fileExtension: URL(fileURLWithPath: filename).pathExtension)
                try Task.checkCancellation()
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
            try model.savePaystubDraft(draft)
            showingReview = true
        } catch { errorMessage = error.localizedDescription }
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
    var body: some View {
        Form {
            Section {
                Text("Confirm the facts, then compare.").font(.title2.bold())
                Text(
                    "Check each value against the original. Unconfirmed optional lines are excluded and mark the audit as limited."
                ).font(.footnote)
                if let notice = draft.processingNotice {
                    Text(notice).foregroundStyle(LinePayColor.review)
                }
            }
            Section("Minimum facts") {
                ForEach([PaystubField.periodStart, .periodEnd, .grossPay]) { field in
                    fieldRow(field)
                }
            }
            Section {
                Picker("What does gross include?", selection: $draft.grossBasis) {
                    ForEach(PaystubGrossBasis.allCases, id: \.self) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("paystub.gross-basis")
                Text(
                    "Compare wage gross with wages, not take-home pay. Confirm whether per diem is already inside this gross number; LinePaycheck does not infer tax treatment."
                ).font(.footnote)
            }
            Section("Optional confirmed lines") {
                DisclosureGroup("Review optional line details") {
                    ForEach(PaystubField.allCases.filter { !$0.isDate && $0 != .grossPay }) {
                        field in fieldRow(field)
                    }
                }
            }
            Section {
                DisclosureGroup("How earnings lines are reported") {
                    Picker("Earnings layout", selection: $draft.lineLayout) {
                        ForEach(PaystubLineLayout.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Hours mean", selection: $draft.hoursBasis) {
                        ForEach(PaystubHoursBasis.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Callout guarantee", selection: $draft.guaranteeLayout) {
                        ForEach(PaystubGuaranteeLayout.allCases, id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }
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
            Section {
                Button(
                    draft.grossBasis == .unconfirmed
                        ? "Save as not comparable" : "Audit confirmed facts"
                ) { confirm() }
                .buttonStyle(LinePayPrimaryButtonStyle())
                .disabled(
                    !draft.reviewedFields.isSuperset(of: [.periodStart, .periodEnd, .grossPay])
                )
                .accessibilityIdentifier("paystub.audit")
                Text(
                    "Your first comparable audit is free. An unknown gross basis does not consume it."
                ).font(.footnote)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .navigationTitle("Review paystub").navigationBarTitleDisplayMode(.inline)
        .environment(\.timeZone, zone)
        .onChange(of: draft) { _, value in
            do { try model.savePaystubDraft(value) } catch {
                errorMessage =
                    "This review could not be saved. Keep the screen open and retry after freeing storage."
            }
        }
    }
    private func fieldRow(_ field: PaystubField) -> some View {
        NavigationLink {
            PaystubFieldReviewView(model: model, field: field, draft: $draft, timeZone: zone)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(field.title).font(.headline)
                    Spacer()
                    Label(
                        draft.reviewedFields.contains(field) ? "Confirmed" : "Check",
                        systemImage: draft.reviewedFields.contains(field)
                            ? "checkmark.circle" : "questionmark.circle"
                    )
                    .font(.caption).foregroundStyle(
                        draft.reviewedFields.contains(field)
                            ? LinePayColor.textSecondary : LinePayColor.review)
                }
                Text(fieldValue(field)).monospacedDigit()
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
            try model.confirmPaystub(draft, hasProAccess: subscriptionStore.hasAuditAccess)
            errorMessage = nil
            onConfirmed()
        } catch { errorMessage = error.localizedDescription }
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
                    TextField(field.title, text: numberBinding).keyboardType(.decimalPad)
                        .monospacedDigit()
                        .accessibilityIdentifier("paystub.value")
                }
                Text("Confirm current-period values, not year-to-date totals.").font(.footnote)
            }
            Section {
                Button("Confirm this field") {
                    do {
                        if !field.isDate {
                            _ = try StrictDecimal.parse(
                                draft[field], maximum: field.isHours ? 10_000 : 10_000_000,
                                fractionDigits: field.isHours ? 4 : 2,
                                allowDollarSign: !field.isHours)
                        }
                        draft.reviewedFields.insert(field)
                        dismiss()
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
                        dismiss()
                    }
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayKeyboardDismiss()
        .navigationTitle(field.title).navigationBarTitleDisplayMode(.inline)
        .environment(\.timeZone, timeZone)
    }
    private var numberBinding: Binding<String> {
        Binding(
            get: { draft[field] },
            set: {
                draft[field] = $0
                draft.reviewedFields.remove(field)
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
            })
    }
}
