import LinePayDomain
import SwiftUI
import UniformTypeIdentifiers

struct CrewRulesView: View {
    let model: AppModel
    var onPrepared: (() -> Void)? = nil
    @State private var title = "Shared pay rules"
    @State private var revision = "1"
    @State private var includeAmounts = false
    @State private var rightsConfirmed = false
    @State private var prepared: CrewRuleFileDocument?
    @State private var exportPacket: CrewRuleTemplate?
    @State private var exporting = false
    @State private var importing = false
    @State private var inspectedData: Data?
    @State private var inspected: CrewRuleTemplate?
    @State private var hourlyRate = ""
    @State private var perDiemAmount = ""
    @State private var perDiemChoice: CrewRuleTemplate.PerDiemChoice = .unreviewed
    @State private var timeZoneIdentifier = ""
    @State private var applicabilityConfirmed = false
    @State private var valuesConfirmed = false
    @State private var replaceDraft = false
    @State private var showingSetup = false
    @State private var reading = false
    @State private var task: Task<Void, Never>?
    private enum MessageArea: Equatable { case exportFile, inspectDraft, prepareSetup }
    @State private var message: String?
    @State private var messageArea: MessageArea = .inspectDraft

    var body: some View {
        Form {
            Section {
                Text(
                    "Exchange selected rules without copying work, paycheck history or original documents. A worker-provided draft is not an official agreement or a verified source."
                )
            }
            if model.profile != nil { exportSection }
            Section("Inspect a rule draft") {
                Button("Choose rule draft file") { importing = true }
                    .linePayRowAction().disabled(reading)
                    .accessibilityIdentifier("crew-rules.choose-file")
                Text(
                    "Select a .linepayrules file, up to 64 KB. Opening it does not change your rules or work history."
                )
                .font(.footnote)
                if reading { ProgressView("Reading selected draft") }
                messageRow(.inspectDraft)
            }
            if let inspected { importSections(inspected) }
            if !model.crewRuleOrigins.isEmpty {
                Section("Retained draft references") {
                    ForEach(model.crewRuleOrigins.indices, id: \.self) { index in
                        let origin = model.crewRuleOrigins[index]
                        if let packet = try? CrewRuleTemplate.decode(origin.adoption.templateData) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(packet.title).font(.headline)
                                Text(
                                    "Draft revision \(packet.revision) · confirmed for \(LinePayFormat.timeZoneName(origin.timeZoneIdentifier))"
                                )
                                Text(
                                    "Worker-confirmed rate: \(LinePayFormat.money(origin.adoption.hourlyRate))/hour"
                                )
                                .monospacedDigit()
                                Text(
                                    "Original draft and recipient choices retained locally. This reference is not source approval."
                                )
                                .font(.footnote)
                            }
                        }
                    }
                }
            }
        }
        .linePayCanvas().linePayKeyboardDismiss()
        .navigationTitle("Crew rule drafts").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if timeZoneIdentifier.isEmpty { timeZoneIdentifier = model.currentTimeZoneIdentifier }
        }
        .onChange(of: title) { _, _ in invalidateExport() }
        .onChange(of: revision) { _, _ in invalidateExport() }
        .onChange(of: includeAmounts) { _, _ in invalidateExport() }
        .onChange(of: hourlyRate) { _, _ in invalidateImportReview() }
        .onChange(of: perDiemAmount) { _, _ in invalidateImportReview() }
        .onChange(of: perDiemChoice) { _, _ in invalidateImportReview() }
        .onChange(of: timeZoneIdentifier) { _, _ in invalidateImportReview() }
        .onDisappear { task?.cancel() }
        .sheet(isPresented: $showingSetup) { PayProfileSetupView(model: model) }
        .fileExporter(
            isPresented: $exporting, document: prepared, contentType: .linePayCrewRules,
            defaultFilename: "Crew rules"
        ) { result in
            messageArea = .exportFile
            switch result {
            case .success:
                message =
                    "Saved to the selected location. Confirm any cloud upload in Files. Copies you save or send elsewhere remain under your control."
            case .failure:
                message = "The draft was not saved. Check the selected destination and retry."
            }
        }
        .fileImporter(
            isPresented: $importing, allowedContentTypes: [.linePayCrewRules, .json]
        ) { result in
            messageArea = .inspectDraft
            message = nil
            guard case .success(let url) = result else {
                message =
                    "The file could not be selected. Saved rules and history are unchanged. Retry from Files."
                return
            }
            task?.cancel()
            inspected = nil
            inspectedData = nil
            invalidateImportReview()
            reading = true
            task = Task {
                defer { reading = false }
                do {
                    let bytes = try await CrewRuleFileIO().read(url)
                    try Task.checkCancellation()
                    let packet = try CrewRuleTemplate.decode(bytes)
                    inspectedData = bytes
                    inspected = packet
                    hourlyRate = ""
                    perDiemAmount = ""
                    perDiemChoice = packet.rules.perDiem.configured ? .unreviewed : .notConfigured
                    replaceDraft = false
                    messageArea = .inspectDraft
                    message =
                        "Draft inspected. No pay rules or work records changed. Enter and confirm your own amounts."
                } catch is CancellationError {
                    return
                } catch {
                    messageArea = .inspectDraft
                    message =
                        "This draft could not be read safely. Saved rules and history are unchanged. Use a supported rule draft or enter confirmed rules manually."
                }
            }
        }
    }

    private var exportSection: some View {
        Section("Prepare a rule draft") {
            LabeledContent("Draft title") {
                TextField("Title", text: $title).accessibilityIdentifier("crew-rules.title")
            }
            LabeledContent("Draft revision") {
                TextField("Revision", text: $revision).textInputAutocapitalization(.never)
                    .accessibilityIdentifier("crew-rules.revision")
            }
            Toggle("Include hourly and per-diem amounts", isOn: $includeAmounts)
                .accessibilityIdentifier("crew-rules.include-amounts")
            Text(
                "Amounts are omitted by default. The title and conditions may still identify your group. Schedules, weekly rules, date premiums and effective-date limits cannot be exported in this format."
            )
            .font(.footnote)
            Toggle(
                "I have permission to share these selected rules and this title",
                isOn: $rightsConfirmed
            )
            .accessibilityIdentifier("crew-rules.rights")
            Button("Review exact rule draft") { prepareExport() }
                .linePayRowAction().disabled(!rightsConfirmed)
                .accessibilityIdentifier("crew-rules.review-export")
            if let exportPacket, let prepared {
                CrewRuleSummary(packet: exportPacket)
                DisclosureGroup("Exact file contents") {
                    Text(String(decoding: prepared.data, as: UTF8.self)).font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                Button("Save reviewed draft to Files") { exporting = true }
                    .linePayRowAction().disabled(!rightsConfirmed)
                    .accessibilityIdentifier("crew-rules.export")
            }
            messageRow(.exportFile)
        }
    }

    @ViewBuilder private func importSections(_ packet: CrewRuleTemplate) -> some View {
        Section("Selected draft") { CrewRuleSummary(packet: packet) }
            .accessibilityIdentifier("crew-rules.selected-summary")
        Section("Confirm for your own work") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your confirmed hourly rate (\(packet.rules.currency)/hour)")
                TextField("Amount", text: $hourlyRate).keyboardType(.decimalPad)
                    .accessibilityLabel("Your confirmed hourly rate")
                    .accessibilityIdentifier("crew-rules.hourly-rate")
            }
            if packet.rules.perDiem.configured {
                Picker("Per diem for my work", selection: $perDiemChoice) {
                    Text("Not reviewed").tag(CrewRuleTemplate.PerDiemChoice.unreviewed)
                    Text("Confirmed amount").tag(CrewRuleTemplate.PerDiemChoice.confirmedAmount)
                    Text("Not applicable to my work").tag(
                        CrewRuleTemplate.PerDiemChoice.notApplicable)
                }
                .accessibilityIdentifier("crew-rules.per-diem-choice")
                if perDiemChoice == .confirmedAmount {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            "Your confirmed per diem (\(packet.rules.currency) per worked local date)"
                        )
                        TextField("Amount", text: $perDiemAmount).keyboardType(.decimalPad)
                            .accessibilityLabel("Your confirmed per-diem amount")
                            .accessibilityIdentifier("crew-rules.per-diem-amount")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Payroll timezone")
                TextField("Area/City", text: $timeZoneIdentifier).textInputAutocapitalization(
                    .never
                )
                .autocorrectionDisabled().accessibilityLabel("Payroll timezone")
                .accessibilityIdentifier("crew-rules.time-zone")
            }
            Toggle(
                "I checked these rules against my work, classification and dates",
                isOn: $applicabilityConfirmed
            )
            .accessibilityIdentifier("crew-rules.confirm-applicability")
            Toggle(
                "I confirmed my amounts, currency, rounding and highest-premium rule",
                isOn: $valuesConfirmed
            )
            .accessibilityIdentifier("crew-rules.confirm-values")
            if model.setupDraft != nil {
                Toggle("Replace my unfinished rule setup draft", isOn: $replaceDraft)
                    .accessibilityIdentifier("crew-rules.replace-draft")
            }
            Text(
                "This format includes no weekly overtime, schedule, holiday or effective-date coverage. Unconfigured obligations are not waived. The next editor reviews your period and save scope; existing history stays unchanged."
            )
            .font(.footnote)
            Button("Prepare my rule setup") { prepareImport() }
                .linePayRowAction().disabled(!applicabilityConfirmed || !valuesConfirmed || reading)
                .accessibilityIdentifier("crew-rules.prepare-setup")
            messageRow(.prepareSetup)
        }
    }

    @ViewBuilder private func messageRow(_ area: MessageArea) -> some View {
        if messageArea == area, let message {
            Label(message, systemImage: "info.circle")
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("crew-rules.message")
        }
    }

    private func invalidateExport() {
        if messageArea == .exportFile { message = nil }
        prepared = nil
        exportPacket = nil
        rightsConfirmed = false
    }
    private func invalidateImportReview() {
        if messageArea == .prepareSetup { message = nil }
        applicabilityConfirmed = false
        valuesConfirmed = false
    }
    private func prepareExport() {
        messageArea = .exportFile
        do {
            guard rightsConfirmed, let agreement = model.profile?.agreement else { return }
            let packet = try CrewRuleTemplate.sharing(
                agreement, templateID: UUID(), revision: revision, title: title,
                includeAmounts: includeAmounts)
            prepared = CrewRuleFileDocument(data: try packet.encoded())
            exportPacket = packet
            message = nil
        } catch {
            prepared = nil
            exportPacket = nil
            message =
                "These rules cannot be exported in this format, or the title/revision needs review. No partial rule draft was created."
        }
    }
    private func prepareImport() {
        messageArea = .prepareSetup
        do {
            guard let inspectedData else { return }
            let draft = try CrewRuleDraftBuilder.build(
                data: inspectedData, hourlyRate: hourlyRate, perDiemChoice: perDiemChoice,
                perDiemAmount: perDiemAmount, applicabilityConfirmed: applicabilityConfirmed,
                valuesConfirmed: valuesConfirmed, timeZoneIdentifier: timeZoneIdentifier,
                profile: model.profile, activePeriod: model.activePeriod)
            try model.prepareCrewRuleDraft(draft, replaceExistingDraft: replaceDraft)
            if let onPrepared { onPrepared() } else { showingSetup = true }
            message =
                "Rule setup draft saved locally. Review and save it in the editor before any new rules apply."
        } catch {
            message =
                "The draft could not be prepared. Confirm your own amounts and applicability, compatible currency/rounding and any replacement of unfinished setup. Saved rules and history are unchanged."
        }
    }
}

private struct CrewRuleSummary: View {
    let packet: CrewRuleTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(packet.title).font(.headline)
            Text("Draft revision \(packet.revision) · \(packet.rules.currency)")
            Text("Sender hourly amount: \(packet.rules.hourlyRate ?? "omitted; enter your own")")
                .monospacedDigit()
            ForEach(packet.rules.dailyOvertimeTiers.indices, id: \.self) { index in
                let tier = packet.rules.dailyOvertimeTiers[index]
                Text("After \(tier.afterHours) worked hours per local day: \(tier.multiplier)×")
            }
            ForEach(packet.rules.weekdayPremiums.indices, id: \.self) { index in
                let premium = packet.rules.weekdayPremiums[index]
                Text("\(premium.weekday.capitalized): \(premium.multiplier)×")
            }
            if let minimum = packet.rules.calloutMinimumHours {
                Text("Isolated callout minimum: \(minimum) hours")
            }
            Text(
                packet.rules.perDiem.configured
                    ? "Per diem per worked local date: \(packet.rules.perDiem.amount ?? "amount omitted")"
                    : "Per diem not configured")
            Text(
                "Rounding: \(packet.rules.rounding.scale) decimal places, \(packet.rules.rounding.mode.rawValue), per pay category. Highest applicable premium wins; premiums do not multiply together."
            )
            .font(.footnote)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
