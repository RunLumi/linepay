import LinePayDomain
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @State private var editor = false
    @State private var paywall = false
    var body: some View {
        NavigationStack {
            List {
                if let profile = model.profile {
                    Section("Pay") {
                        NavigationLink("Pay profile: \(profile.name)") {
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
                                                    "v\(change.agreement.version) · \(LinePayFormat.money(change.agreement.hourlyRate))/hr"
                                            )
                                        }
                                        Text(
                                            "The ledger shows the exact snapshot applied to each work date."
                                        ).font(.footnote)
                                    }
                                }
                                Section {
                                    Text("Timezone: \(profile.timeZoneIdentifier)")
                                    Button("Edit and review rules") { editor = true }.frame(
                                        minHeight: 48)
                                    Text(
                                        "Editing defaults to future periods. Existing work changes only after an explicit current-period review."
                                    ).font(.footnote)
                                }
                            }.navigationTitle("Pay profile")
                        }
                        Button("Edit pay rules") { editor = true }.accessibilityIdentifier(
                            "settings.edit-rules")
                        NavigationLink("Pay period: \(profile.preferredCadence.title)") {
                            PayPeriodSettingsView(model: model)
                        }
                        NavigationLink("Rule sources") {
                            RuleSourcesView(agreement: profile.agreement)
                        }
                    }
                }
                Section("LinePaycheck Pro") {
                    LabeledContent(
                        "Status",
                        value: subscriptionStore.isPro
                            ? (subscriptionStore.isTrial ? "Pro trial active" : "Pro active")
                            : model.hasUsedFreeAudit ? "First audit used" : "First audit free")
                    if let notice = subscriptionStore.notice { Text(notice).font(.footnote) }
                    if let date = subscriptionStore.renewalDate {
                        LabeledContent(subscriptionStore.willAutoRenew == true ? "Renews" : "Ends")
                        {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    Button("View Pro options") { paywall = true }
                        .frame(minHeight: 48).accessibilityIdentifier("settings.view-pro")
                    Button("Restore Purchases") {
                        Task { await subscriptionStore.restorePurchases() }
                    }
                    Link("Manage subscription", destination: AppLinks.subscriptions).frame(
                        minHeight: 44)
                    if let error = subscriptionStore.errorMessage {
                        Text(error).foregroundStyle(LinePayColor.review).font(.footnote)
                    }
                }
                Section("Your data") {
                    NavigationLink("Privacy and local data") { PrivacyDataView(model: model) }
                    BackupRestoreEntryPoint(title: "Backup and restore")
                    NavigationLink("Export data") { ExportDataView(model: model) }
                    if model.pendingDeletionCount > 0 {
                        Text(
                            "\(model.pendingDeletionCount) original(s) awaiting deletion. Retry from Privacy and local data."
                        ).foregroundStyle(LinePayColor.review)
                    }
                }
                Section("About") {
                    NavigationLink("About LinePaycheck") { AboutLinePayView() }
                        .accessibilityIdentifier("settings.about")
                    Link("Support", destination: AppLinks.support).accessibilityIdentifier(
                        "settings.support")
                    Link("Privacy policy", destination: AppLinks.privacy).accessibilityIdentifier(
                        "settings.privacy-policy")
                    Link("Terms of use", destination: AppLinks.terms)
                }
            }
            .navigationTitle("Settings")
            .labeledContentStyle(LinePayValueStyle())
            .scrollContentBackground(.hidden).background(LinePayColor.canvas)
        }
        .sheet(isPresented: $editor) { PayProfileSetupView(model: model) }
        .sheet(isPresented: $paywall) {
            ProPaywallView(store: subscriptionStore) { paywall = false }
        }
    }
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
                    Text("Timezone: \(model.currentTimeZoneIdentifier)")
                    Button("Correct current dates") { correcting = true }.frame(minHeight: 48)
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
                NavigationLink("Read privacy policy") { LegalTextView(kind: .privacy) }
            }
            Section("Original paystubs") {
                ForEach(model.retainedEvidence) { evidence in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(evidence.originalFilename)
                        Button("Remove original", role: .destructive) {
                            selectedEvidence = evidence
                        }.frame(minHeight: 44)
                    }
                }
                if model.retainedEvidence.isEmpty { Text("No original paystubs retained.") }
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
                "Deletes local work, rules, drafts, audits and originals. Export a backup first. External backups and subscriptions stay; used free-audit access is not reset."
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
                    "Audit PDF: open the required period in History or Pay, then Prepare audit report. Original pages are excluded."
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
        }.navigationTitle("Export data").navigationBarTitleDisplayMode(.inline)
    }
}
