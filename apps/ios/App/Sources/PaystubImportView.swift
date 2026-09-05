import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PaystubImportView: View {
    let model: AppModel
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingScanner = false
    @State private var showingFileImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var reviewSession: PaystubReviewSession?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if DocumentScannerView.isSupported {
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan paystub", systemImage: "doc.viewfinder")
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose photo", systemImage: "photo")
                    }

                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose PDF or image", systemImage: "folder")
                    }

                    Button {
                        reviewSession = PaystubReviewSession(draft: manualDraft())
                    } label: {
                        Label("Enter paycheck manually", systemImage: "keyboard")
                    }
                    .accessibilityIdentifier("paystub.enter-manually")
                } header: {
                    Text("Paycheck source")
                } footer: {
                    Text(
                        "Scans and OCR stay on this iPhone. LinePaycheck treats OCR as a suggestion and "
                            + "asks you to confirm the numbers before auditing."
                    )
                }

                if isProcessing {
                    Section {
                        HStack(spacing: LinePaySpacing.standard) {
                            ProgressView()
                            Text("Reading paystub on this device…")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add paycheck")
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("paystub.cancel")
                }
            }
        }
        .tint(LinePayColor.actionText)
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView(
                onScan: { data in
                    showingScanner = false
                    Task {
                        await process(
                            data: data,
                            filename: "Scanned Paystub.pdf",
                            mediaType: "application/pdf",
                            sourceKind: .scan
                        )
                    }
                },
                onCancel: {
                    showingScanner = false
                },
                onError: { error in
                    showingScanner = false
                    errorMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $reviewSession) { session in
            PaystubReviewView(model: model, draft: session.draft) {
                reviewSession = nil
                onCompleted()
                dismiss()
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await loadFile(url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task { await loadPhoto(newValue) }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PaystubImportError.couldNotReadSource
            }
            await process(
                data: data,
                filename: "Paystub Photo.jpg",
                mediaType: item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg",
                sourceKind: .photo
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFile(_ url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let type = UTType(filenameExtension: url.pathExtension)
            await process(
                data: data,
                filename: url.lastPathComponent,
                mediaType: type?.preferredMIMEType ?? "application/octet-stream",
                sourceKind: .file
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func process(
        data: Data,
        filename: String,
        mediaType: String,
        sourceKind: PaystubSourceKind
    ) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        var draft = baseDraft()
        draft.sourceData = data
        draft.originalFilename = filename
        draft.mediaType = mediaType
        draft.sourceKind = sourceKind

        do {
            let result = try await PaystubOCRService().recognize(
                data: data,
                fileExtension: URL(fileURLWithPath: filename).pathExtension
            )
            draft.recognizedText = result.recognizedText
            draft.grossPay = result.grossPay ?? ""
            draft.regularPay = result.regularPay ?? ""
            draft.overtimePay = result.overtimePay ?? ""
            draft.doubleTimePay = result.doubleTimePay ?? ""
            draft.perDiemPay = result.perDiemPay ?? ""
        } catch {
            errorMessage =
                "Automatic reading was incomplete. Confirm the paycheck manually; the original "
                + "document will still be preserved as evidence."
        }

        reviewSession = PaystubReviewSession(draft: draft)
    }

    private func manualDraft() -> PaystubConfirmationDraft {
        var draft = baseDraft()
        draft.sourceKind = .manual
        return draft
    }

    private func baseDraft() -> PaystubConfirmationDraft {
        var draft = PaystubConfirmationDraft()
        if let window = model.activePeriod?.window {
            draft.payPeriodStartDate = window.startDate
            draft.payPeriodEndDate = window.displayEndDate
        }
        return draft
    }
}

private struct PaystubReviewSession: Identifiable {
    let id = UUID()
    let draft: PaystubConfirmationDraft
}

private enum PaystubImportError: LocalizedError {
    case couldNotReadSource

    var errorDescription: String? {
        "LinePaycheck could not read that file. Try another copy or enter the paycheck manually."
    }
}

struct PaystubReviewView: View {
    let model: AppModel
    let onConfirmed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PaystubConfirmationDraft
    @State private var errorMessage: String?
    @FocusState private var isEditing: String?

    init(
        model: AppModel,
        draft: PaystubConfirmationDraft,
        onConfirmed: @escaping () -> Void
    ) {
        self.model = model
        self.onConfirmed = onConfirmed
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Period starts",
                        selection: periodStartBinding,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "Period ends",
                        selection: periodEndBinding,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Pay period")
                } footer: {
                    Text("Confirm these dates against the paystub before auditing.")
                }

                Section {
                    moneyField("Gross pay", text: $draft.grossPay, identifier: "paystub.gross-pay")
                } header: {
                    Text("Required")
                } footer: {
                    Text("Enter decimals with a point or comma, without thousands separators.")
                }

                Section {
                    optionalNumberField("Regular hours", text: $draft.regularHours)
                    moneyField(
                        "Regular pay", text: $draft.regularPay, identifier: "paystub.regular-pay")
                    optionalNumberField("Overtime hours", text: $draft.overtimeHours)
                    moneyField(
                        "Overtime pay", text: $draft.overtimePay, identifier: "paystub.overtime-pay"
                    )
                    optionalNumberField("Double-time hours", text: $draft.doubleTimeHours)
                    moneyField("Double-time pay", text: $draft.doubleTimePay)
                    moneyField("Callout pay", text: $draft.calloutPay)
                    moneyField("Per diem", text: $draft.perDiemPay)
                } header: {
                    Text("Optional line details")
                } footer: {
                    Text(
                        "Only confirm fields you can identify on the paystub. Blank fields are not guessed."
                    )
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($isEditing, equals: "notes")
                }

                if let recognizedText = draft.recognizedText, !recognizedText.isEmpty {
                    Section {
                        DisclosureGroup("View OCR text") {
                            Text(recognizedText)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .padding(.vertical, LinePaySpacing.compact)
                        }
                    } header: {
                        Text("Source evidence")
                    } footer: {
                        Text(
                            "OCR is evidence, not truth. The fields above are what LinePaycheck will trust."
                        )
                    }
                }

            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
            .navigationTitle("Confirm paycheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isEditing = nil }
                        .accessibilityIdentifier("keyboard.done")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                        .accessibilityIdentifier("paystub.review-back")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Audit") { confirm() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("paystub.audit")
                }
            }
            .alert(
                "Paycheck needs review",
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
        .environment(\.timeZone, payrollTimeZone)
        .tint(LinePayColor.actionText)
    }

    private var payrollTimeZone: TimeZone {
        TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current
    }

    private var periodStartBinding: Binding<Date> {
        Binding(
            get: { draft.payPeriodStartDate ?? model.activePeriod?.window.startDate ?? Date() },
            set: { draft.payPeriodStartDate = $0 }
        )
    }

    private var periodEndBinding: Binding<Date> {
        Binding(
            get: { draft.payPeriodEndDate ?? model.activePeriod?.window.displayEndDate ?? Date() },
            set: { draft.payPeriodEndDate = $0 }
        )
    }

    @ViewBuilder
    private func moneyField(_ title: String, text: Binding<String>, identifier: String = "")
        -> some View
    {
        LinePayTextField("\(title) (USD)", text: text, focus: $isEditing, identifier: identifier)
            .keyboardType(.decimalPad)
            .monospacedDigit()
    }

    @ViewBuilder
    private func optionalNumberField(_ title: String, text: Binding<String>) -> some View {
        LinePayTextField(title, text: text, focus: $isEditing)
            .keyboardType(.decimalPad)
            .monospacedDigit()
    }

    private func confirm() {
        do {
            try model.confirmPaystub(draft)
            errorMessage = nil
            onConfirmed()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
