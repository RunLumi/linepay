import SwiftUI

struct SettingsView: View {
    let model: AppModel

    @State private var showingRuleEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    if let profile = model.profile {
                        payProfileSection(profile)
                    }

                    privacySection
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingRuleEditor) {
            if let profile = model.profile {
                PayProfileSetupView(
                    model: model,
                    draft: PayProfileDraft(profile: profile),
                    isEditing: true
                )
            }
        }
    }

    private func payProfileSection(_ profile: PayProfile) -> some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("PAY PROFILE")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            LabeledContent("Name", value: profile.name)
            LabeledContent("Hourly rate") {
                Text(LinePayFormat.money(profile.agreement.hourlyRate))
                    .monospacedDigit()
            }
            LabeledContent("Timezone", value: profile.timeZoneIdentifier)
            LabeledContent("Rule version", value: profile.agreement.version)

            Divider()

            Button("Edit pay rules") {
                showingRuleEditor = true
            }
            .frame(minHeight: 44)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("PRIVACY")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            Label("No LinePaycheck account", systemImage: "person.crop.circle.badge.xmark")
            Label("Pay data stays on device by default", systemImage: "iphone")
            Label("No ad or tracking SDK", systemImage: "eye.slash")

            Text(
                "Paystub scanning and durable local history will be added without changing the "
                    + "local-first architecture."
            )
            .font(.footnote)
            .foregroundStyle(LinePayColor.textSecondary)
        }
    }
}
