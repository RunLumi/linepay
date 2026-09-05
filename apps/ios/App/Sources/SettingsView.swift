import SwiftUI

struct SettingsView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore

    @State private var showingRuleEditor = false
    @State private var showingPaywall = false
    @State private var showingDeleteAllConfirmation = false
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

                        Button("Edit pay rules") {
                            showingRuleEditor = true
                        }
                    }

                    Section("Confirmed rules") {
                        ruleSummary(profile)
                    }
                }

                Section("LinePaycheck Pro") {
                    LabeledContent("Status", value: subscriptionStatus)

                    if !subscriptionStore.isPro {
                        Button("View LinePaycheck Pro") {
                            showingPaywall = true
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await subscriptionStore.restorePurchases() }
                    }
                    .disabled(!SubscriptionStore.commerceEnabled)

                    if let message = subscriptionStore.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(LinePayColor.textSecondary)
                    }
                }

                Section {
                    Label("No LinePaycheck account", systemImage: "person.crop.circle.badge.xmark")
                    Label(
                        "No LinePaycheck backend stores your paycheck", systemImage: "server.rack")
                    Label("No ad or tracking SDK", systemImage: "eye.slash")
                    Label("Paystub OCR runs on this device", systemImage: "iphone")
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(
                        "App Store purchases and Files providers may use the network. Pay data stays "
                            + "local by default. Choosing iCloud backup or another export location "
                            + "sends a copy to that provider, not to a LinePaycheck server."
                    )
                }

                Section("Your data") {
                    BackupRestoreEntryPoint()

                    if let currentEvidence = model.currentPaystub?.evidence {
                        Button(role: .destructive) {
                            removeCurrentEvidence(currentEvidence)
                        } label: {
                            Label("Remove current original paystub", systemImage: "doc.badge.minus")
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label("Delete all LinePaycheck data", systemImage: "trash")
                    }
                }

                Section("About") {
                    LabeledContent("Architecture", value: "Local-first")
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
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingRuleEditor) {
            PayProfileSetupView(model: model)
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(store: subscriptionStore) {
                showingPaywall = false
            }
        }
        .confirmationDialog(
            "Delete all LinePaycheck data?",
            isPresented: $showingDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently deletes pay rules, work history, audit results, and stored paystub evidence from this iPhone. App Store purchases are not cancelled. Backups in iCloud Drive or Files are not deleted."
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

    private func removeCurrentEvidence(_ evidence: PaystubEvidence) {
        do {
            _ = evidence
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
