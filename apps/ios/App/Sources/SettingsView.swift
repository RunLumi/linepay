import LinePayDomain
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editor = false
    @State private var paywall = false
    @State private var path = [SettingsDestination]()
    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let profile = model.profile {
                    Section(header: settingsSectionHeader("Pay")) {
                        settingsNavigationRow(
                            "Pay profile: \(profile.name)", destination: .payProfile)
                        Button("Edit pay rules") { editor = true }
                            .linePayRowAction()
                            .accessibilityIdentifier("settings.edit-rules")
                        settingsNavigationRow(
                            "Pay period: \(profile.preferredCadence.title)",
                            destination: .payPeriod)
                        settingsNavigationRow("Rule sources", destination: .ruleSources)
                    }
                }
                Section(header: settingsSectionHeader("Local diagnostics")) {
                    settingsNavigationRow(
                        "Device-local activity", identifier: "settings.local-activity",
                        destination: .localActivity)
                }
                Section(header: settingsSectionHeader("Employer benefits")) {
                    settingsNavigationRow(
                        "Employer contribution checks", identifier: "settings.benefits",
                        destination: .benefits)
                }
                Section(header: settingsSectionHeader("Agreements")) {
                    settingsNavigationRow(
                        "Agreement documents", identifier: "settings.agreements",
                        destination: .agreements)
                    settingsNavigationRow(
                        "Crew rule drafts", identifier: "settings.crew-rules",
                        destination: .crewRules)
                }
                Section(header: settingsSectionHeader("LinePaycheck Pro")) {
                    LabeledContent {
                        Text(
                            subscriptionStore.isPro
                                ? (subscriptionStore.isTrial ? "Pro trial active" : "Pro active")
                                : model.hasUsedFreeAudit ? "Free check used" : "First check free"
                        ).foregroundStyle(LinePayColor.textPrimary)
                    } label: {
                        Text("Status").foregroundStyle(LinePayColor.textPrimary)
                    }
                    if let notice = subscriptionStore.notice { Text(notice).font(.footnote) }
                    if let date = subscriptionStore.renewalDate {
                        LabeledContent(subscriptionStore.willAutoRenew == true ? "Renews" : "Ends")
                        {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    Button {
                        paywall = true
                    } label: {
                        Text(
                            subscriptionStore.isPro
                                ? "View Pro options"
                                : subscriptionStore.annualTrialDuration.map {
                                    "Try Pro free for \($0)"
                                } ?? "View Pro options"
                        )
                    }
                    .linePayRowAction()
                    .accessibilityIdentifier("settings.view-pro")
                    Button("Restore Purchases") {
                        Task { await subscriptionStore.restorePurchases() }
                    }.linePayRowAction()
                        .accessibilityIdentifier("settings.restore-purchases")
                    Link("Manage subscription", destination: AppLinks.subscriptions)
                        .linePayRowAction()
                        .accessibilityIdentifier("settings.manage-subscription")
                    if let error = subscriptionStore.errorMessage {
                        Text(error).foregroundStyle(LinePayColor.review).font(.footnote)
                    }
                }
                Section(header: settingsSectionHeader("Your data")) {
                    settingsNavigationRow(
                        "Privacy and local data", identifier: "settings.privacy-data",
                        destination: .privacyData)
                    BackupRestoreEntryPoint(title: "Backup and restore")
                    settingsNavigationRow("Export data", destination: .exportData)
                    if model.pendingDeletionCount > 0 {
                        Text(
                            model.pendingDeletionCount == 1
                                ? "1 original is waiting to be deleted. Retry from Privacy and local data."
                                : "\(model.pendingDeletionCount) originals are waiting to be deleted. Retry from Privacy and local data."
                        ).foregroundStyle(LinePayColor.review)
                    }
                }
                Section(header: settingsSectionHeader("About")) {
                    settingsNavigationRow(
                        "About Paycheck Audit", identifier: "settings.about", destination: .about)
                    Link("Support", destination: AppLinks.support).accessibilityIdentifier(
                        "settings.support")
                    Link("Privacy policy", destination: AppLinks.privacy).accessibilityIdentifier(
                        "settings.privacy-policy")
                    Link("Terms of use", destination: AppLinks.terms)
                        .accessibilityIdentifier("settings.terms")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(
                dynamicTypeSize.isAccessibilitySize ? .inline : .large
            )
            .labeledContentStyle(LinePayValueStyle())
            .linePayCanvas()
            .navigationDestination(for: SettingsDestination.self) { destination in
                settingsDestination(destination)
            }
        }
        .sheet(isPresented: $editor) { PayProfileSetupView(model: model) }
        .sheet(isPresented: $paywall) {
            ProPaywallView(store: subscriptionStore) { paywall = false }
        }
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .textCase(nil)
            .foregroundStyle(LinePayColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func settingsNavigationRow(
        _ title: String,
        identifier: String? = nil,
        destination: SettingsDestination
    ) -> some View {
        Button {
            path.append(destination)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: LinePaySpacing.standard) {
                Text(title)
                    .foregroundStyle(LinePayColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LinePayColor.textPrimary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "settings.\(destination.rawValue)")
    }

    @ViewBuilder private func settingsDestination(_ destination: SettingsDestination) -> some View {
        switch destination {
        case .payProfile:
            if let profile = model.profile {
                List {
                    Section("Latest entered rules") {
                        AgreementSummaryView(agreement: profile.agreement)
                    }
                    if let changes = profile.agreementChanges, !changes.isEmpty {
                        Section("Dated rule versions") {
                            ForEach(changes, id: \.effectiveDate) { change in
                                LabeledContent(
                                    LinePayFormat.localDate(change.effectiveDate),
                                    value:
                                        "Version \(change.agreement.version) · \(LinePayFormat.money(change.agreement.hourlyRate))/hr"
                                )
                            }
                            Text(
                                "The ledger shows the exact snapshot applied to each work date."
                            ).font(.footnote)
                        }
                    }
                    Section {
                        Text(
                            "Payroll timezone: \(LinePayFormat.timeZoneName(profile.timeZoneIdentifier))"
                        )
                        Button("Edit and review rules") { editor = true }
                            .linePayRowAction()
                        Text(
                            "Editing defaults to future periods. Existing work changes only after an explicit current-period review."
                        ).font(.footnote)
                    }
                }
                .labeledContentStyle(LinePayValueStyle())
                .linePayCanvas()
                .navigationTitle("Pay profile")
            } else {
                Text("Set up a pay profile to view these rules.")
            }
        case .payPeriod:
            PayPeriodSettingsView(model: model)
        case .ruleSources:
            if let profile = model.profile {
                RuleSourcesView(agreement: profile.agreement, model: model)
            } else {
                Text("Set up a pay profile to review its rule sources.")
            }
        case .localActivity:
            LocalDiagnosticsView(ledger: model.localActivity)
        case .benefits:
            BenefitAuditsView(model: model)
        case .agreements:
            AgreementDocumentsView(model: model)
        case .crewRules:
            CrewRulesView(model: model)
        case .privacyData:
            PrivacyDataView(model: model)
        case .exportData:
            ExportDataView(model: model)
        case .about:
            AboutLinePayView()
        }
    }

}

private enum SettingsDestination: String, Hashable {
    case payProfile
    case payPeriod
    case ruleSources
    case localActivity
    case benefits
    case agreements
    case crewRules
    case privacyData
    case exportData
    case about
}

struct PayPeriodSettingsView: View {
    let model: AppModel
    @State private var correcting = false
    var body: some View {
        List {
            if let period = model.activePeriod {
                Section("Current work period") {
                    Text(
                        LinePayFormat.payPeriod(
                            period.window, timeZoneIdentifier: model.currentTimeZoneIdentifier))
                    Text(
                        "Payroll timezone: \(LinePayFormat.timeZoneName(model.currentTimeZoneIdentifier))"
                    )
                    Button("Correct current dates") { correcting = true }.linePayRowAction()
                        .accessibilityIdentifier("period.correct-dates")
                }
                Section("Next work period") {
                    Text(
                        "Starts after the current period closes. Future cadence: \(model.profile?.preferredCadence.title ?? "Not set")."
                    )
                    Text(
                        "Change future cadence in the pay-rule editor. Closed periods are not rewritten."
                    ).font(.footnote)
                }
            } else {
                Text("Start a new manual work period from Today.")
            }
        }
        .linePayCanvas()
        .navigationTitle("Pay period").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $correcting) { CorrectPeriodDatesView(model: model) }
    }
}

struct CorrectPeriodDatesView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var errorMessage: String?
    init(model: AppModel) {
        self.model = model
        _start = State(initialValue: model.activePeriod?.window.startDate ?? Date())
        _end = State(initialValue: model.activePeriod?.window.displayEndDate ?? Date())
    }
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Starts", selection: $start, displayedComponents: .date)
                DatePicker("Ends, inclusive", selection: $end, displayedComponents: .date)
                Text(
                    "All logged work must remain inside these dates, and closed periods cannot overlap. Previous audit revisions retain their original dates; a current audit must be reviewed again."
                ).font(.footnote)
                Button("Save corrected dates") {
                    do {
                        try model.correctCurrentPeriod(start: start, end: end)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }.buttonStyle(LinePayPrimaryButtonStyle())
                if let errorMessage { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
            .linePayCanvas()
            .navigationTitle("Correct current dates").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }.environment(\.timeZone, TimeZone(identifier: model.currentTimeZoneIdentifier) ?? .current)
    }
}

struct PrivacyDataView: View {
    let model: AppModel
    @State private var deleteAll = false
    @State private var selectedEvidence: PaystubEvidence?
    @State private var errorMessage: String?
    var body: some View {
        List {
            Section("Local by default") {
                Text(
                    "No LinePaycheck account, employer connection, analytics SDK or central pay-data backend. OCR and calculations run on this device."
                )
                Text(
                    "App Store purchases and Files providers may use the network. You choose exports and iCloud Drive backups. iOS may also back up app data according to your device settings."
                )
                Text(
                    "Optional device-local activity stores closed milestone counts and usage days. Review, disable, clear or manually export it from Settings → Device-local activity; nothing is sent to a collector."
                )
                Text(
                    "Voice work drafts request microphone and speech permission for temporary on-device recognition. If local recognition is unavailable, enter work manually; no server fallback is used."
                )
                NavigationLink("Read privacy policy") { LegalTextView(kind: .privacy) }
            }
            Section("Original documents") {
                ForEach(model.retainedEvidence) { evidence in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(evidence.originalFilename)
                        Button("Remove original", role: .destructive) {
                            selectedEvidence = evidence
                        }.frame(minHeight: 44)
                    }
                }
                if model.retainedEvidence.isEmpty { Text("No original documents retained.") }
            }
            Section("Deletion and recovery") {
                if model.pendingDeletionCount > 0 {
                    Text("\(model.pendingDeletionCount) original(s) queued for removal.")
                }
                Button("Retry original cleanup") {
                    do {
                        try model.retryEvidenceDeletion()
                        errorMessage = nil
                    } catch { errorMessage = error.localizedDescription }
                }
                BackupRestoreEntryPoint(title: "Backup and restore")
                Button("Delete all local data", role: .destructive) { deleteAll = true }
                    .accessibilityIdentifier("settings.delete-all")
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayCanvas()
        .navigationTitle("Privacy and data").navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete all local pay data?", isPresented: $deleteAll
        ) {
            Button("Delete all local data", role: .destructive) {
                do { try model.resetAllData() } catch { errorMessage = error.localizedDescription }
            }.accessibilityIdentifier("settings.confirm-delete-all")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Deletes local work, rules, drafts, audits, originals and local activity. Your activity-recording preference is kept. Export a backup first. External backups and subscriptions stay; used free-audit access is not reset."
            )
        }
        .confirmationDialog(
            "Remove this original?",
            isPresented: Binding(
                get: { selectedEvidence != nil }, set: { if !$0 { selectedEvidence = nil } }),
            titleVisibility: .visible
        ) {
            if let evidence = selectedEvidence {
                Button("Remove original", role: .destructive) {
                    do { try model.removeEvidence(id: evidence.id) } catch {
                        errorMessage = error.localizedDescription
                    }
                    selectedEvidence = nil
                }
            }
        } message: {
            Text(
                "All audit revisions using this original lose access to its document and OCR excerpts. Confirmed figures remain. Exported copies are not deleted."
            )
        }
    }
}

struct ExportDataView: View {
    let model: AppModel
    @State private var url: URL?
    @State private var errorMessage: String?
    var body: some View {
        List {
            Section("Choose the appropriate export") {
                Text(
                    "Paycheck report (PDF): open the period in Pay or History, view its paycheck result, then Prepare a report to share. Original pages are excluded."
                )
                Text(
                    "Complete backup: includes saved work, rules, saved drafts, audit revisions and retained original files. It can be restored on another installation."
                )
                BackupRestoreEntryPoint(title: "Create complete backup")
            }
            Section("Structured data only") {
                Button("Prepare JSON data export") {
                    do { url = try model.exportBackupURL() } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                if let url { ShareLink("Share JSON data", item: url) }
                Text(
                    "Contains sensitive structured records and source metadata, but not original document bytes. This is a data export, not a complete restorable backup."
                ).font(.footnote)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }
        }
        .linePayCanvas()
        .navigationTitle("Export data").navigationBarTitleDisplayMode(.inline)
    }
}
