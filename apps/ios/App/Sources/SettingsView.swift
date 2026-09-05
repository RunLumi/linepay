import SwiftUI

struct SettingsView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore

    @State private var showingRuleEditor = false
    @State private var showingPaywall = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showingRemoveEvidenceConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let profile = model.profile {
                    Section("Pay profile") {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Hourly rate") {
                            Text(LinePayFormat.money(profile.agreement.hourlyRate))
                                .monospacedDigit()
                        }
                        LabeledContent("Timezone", value: profile.timeZoneIdentifier)
                        LabeledContent("Pay cadence", value: profile.preferredCadence.title)
                        LabeledContent("Rule version", value: profile.agreement.version)

                        Button {
                            showingRuleEditor = true
                        } label: {
                            Text("Edit pay rules")
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("settings.edit-pay-rules")
                    }

                    Section("Confirmed rules") {
                        ruleSummary(profile)
                    }
                }

                Section("LinePaycheck Pro") {
                    LabeledContent("Status", value: subscriptionStatus)

                    if !subscriptionStore.isPro {
                        Button {
                            showingPaywall = true
                        } label: {
                            Text("View LinePaycheck Pro")
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("settings.view-pro")
                    }

                    Button("Restore Purchases") {
                        Task { await subscriptionStore.restorePurchases() }
                    }
                    .disabled(!SubscriptionStore.commerceEnabled)

                    Link(
                        "Manage subscription",
                        destination: URL(string: "https://apps.apple.com/account/subscriptions")!)

                    if let message = subscriptionStore.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(LinePayColor.textSecondary)
                    }
                }

                Section("Your data") {
                    BackupRestoreEntryPoint()

                    if model.currentPaystub?.evidence != nil {
                        Button(role: .destructive) {
                            showingRemoveEvidenceConfirmation = true
                        } label: {
                            Label("Remove current original paystub", systemImage: "doc.badge.minus")
                        }
                        .accessibilityIdentifier("settings.remove-original")
                    }

                    Button(role: .destructive) {
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label("Delete all LinePaycheck data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("settings.delete-all")
                }

                Section {
                    Text("No account required")
                    Text("No ads or tracking")
                    Text("Paystub scanning stays on this device")
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(
                        "Pay data stays on your iPhone by default. Purchases use Apple services. "
                            + "Choosing iCloud backup or another Files location sends a copy "
                            + "to that provider, not to a LinePaycheck server."
                    )
                }

                Section("About") {
                    Link("Support", destination: AppLinks.support)
                        .accessibilityIdentifier("settings.support")
                    Link("Privacy policy", destination: AppLinks.privacy)
                        .accessibilityIdentifier("settings.privacy-policy")
                    Link("Terms of use", destination: AppLinks.terms)
                    Text(
                        "LinePaycheck estimates expected pay and flags possible differences. It is not "
                            + "payroll software, legal advice, or a determination of wages legally owed."
                    )
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LinePayColor.difference)
                    }
                }
            }
            .navigationTitle("Settings")
            .labeledContentStyle(LinePayValueStyle())
            .scrollContentBackground(.hidden)
            .background(LinePayColor.canvas)
        }
        .sheet(isPresented: $showingRuleEditor) {
            PayProfileSetupView(model: model)
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(store: subscriptionStore) {
                showingPaywall = false
            }
        }
        .alert(
            "Remove the original paystub?",
            isPresented: $showingRemoveEvidenceConfirmation
        ) {
            Button("Remove original paystub", role: .destructive) { removeCurrentEvidence() }
                .accessibilityIdentifier("settings.confirm-remove-original")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "The original image/PDF and its OCR text will be deleted. Confirmed paycheck "
                    + "values and audit results remain."
            )
        }
        .alert(
            "Delete all LinePaycheck data?",
            isPresented: $showingDeleteAllConfirmation
        ) {
            Button("Delete everything", role: .destructive) { deleteAll() }
                .accessibilityIdentifier("settings.confirm-delete-all")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Deletes local rules, work, audits, and paystub originals. Purchases and backups remain."
            )
        }
    }

    private var subscriptionStatus: String {
        if subscriptionStore.isPro { return "Pro active" }
        if !SubscriptionStore.commerceEnabled { return "Debug access" }
        return model.hasUsedFreeAudit ? "Free audit used" : "First audit free"
    }

    @ViewBuilder
    private func ruleSummary(_ profile: PayProfile) -> some View {
        let agreement = profile.agreement

        if agreement.regularSchedule.isEmpty {
            LabeledContent("Regular schedule", value: "Not set")
        } else {
            LabeledContent("Regular schedule", value: "\(agreement.regularSchedule.count) workdays")
            LabeledContent("Outside schedule") {
                Text("\(LinePayFormat.decimal(agreement.outsideScheduleMultiplier))×")
                    .monospacedDigit()
            }
        }

        if let overtime = agreement.dailyOvertimeTiers.first {
            LabeledContent("Daily OT") {
                Text(
                    "after \(LinePayFormat.hours(overtime.afterHours)) h · "
                        + "\(LinePayFormat.decimal(overtime.multiplier))×"
                )
                .monospacedDigit()
            }
        } else {
            LabeledContent("Daily OT", value: "Off")
        }

        if let sunday = agreement.weekdayPremiums.first(where: { $0.weekday == .sunday }) {
            LabeledContent("Sunday") {
                Text("\(LinePayFormat.decimal(sunday.multiplier))×").monospacedDigit()
            }
        }

        if !agreement.datePremiums.isEmpty {
            LabeledContent("Premium dates", value: "\(agreement.datePremiums.count)")
        }

        if let callout = agreement.calloutMinimum {
            LabeledContent("Callout minimum") {
                Text("\(LinePayFormat.hours(callout.minimumHours)) h").monospacedDigit()
            }
        }

        if let perDiem = agreement.flatPerDiem {
            LabeledContent("Per diem") {
                Text(LinePayFormat.money(perDiem.amountPerWorkDate)).monospacedDigit()
            }
        }

        if agreement.sources.isEmpty {
            LabeledContent("Rule source", value: "Not saved")
        } else {
            LabeledContent("Rule source", value: agreement.sources[0].title)
        }
    }

    private func removeCurrentEvidence() {
        do {
            try model.removeCurrentPaystubEvidence()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        do {
            try model.resetAllData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
