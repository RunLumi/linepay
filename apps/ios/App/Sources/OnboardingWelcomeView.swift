import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    let onImportAgreement: (() -> Void)?
    let onImportCrewRules: (() -> Void)?

    init(
        onImportAgreement: (() -> Void)? = nil, onImportCrewRules: (() -> Void)? = nil,
        onContinue: @escaping () -> Void
    ) {
        self.onContinue = onContinue
        self.onImportAgreement = onImportAgreement
        self.onImportCrewRules = onImportCrewRules
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                LineGapMark()

                VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                    Text("Is your paycheck correct?")
                        .font(.largeTitle.bold())
                        .foregroundStyle(LinePayColor.textPrimary)

                    Text(
                        "Track what you worked. Compare expected pay with your paystub. "
                            + "Understand possible differences."
                    )
                    .font(.title3)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                    trustRow(
                        icon: "person.crop.circle.badge.xmark",
                        title: "No account",
                        detail: "No email, password, or employer payroll login."
                    )
                    trustRow(
                        icon: "iphone",
                        title: "Private by default",
                        detail:
                            "Your pay data stays on this iPhone unless you choose to export or back it up."
                    )
                    trustRow(
                        icon: "equal.circle",
                        title: "Explainable pay",
                        detail:
                            "See how the hourly rate and rules you confirm turn worked hours into expected pay."
                    )
                }
                if onImportAgreement != nil || onImportCrewRules != nil {
                    Text("Have your pay rules in writing?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LinePayColor.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                }
                if let onImportAgreement {
                    Button("Import an agreement PDF", action: onImportAgreement)
                        .buttonStyle(LinePaySecondaryButtonStyle())
                        .accessibilityIdentifier("onboarding.import-agreement")
                }
                if let onImportCrewRules {
                    Button("Open a shared rule draft", action: onImportCrewRules)
                        .buttonStyle(LinePaySecondaryButtonStyle())
                        .accessibilityIdentifier("onboarding.import-crew-rules")
                }
                BackupRestoreEntryPoint(title: "Restore from iCloud Drive")
            }
            .padding(LinePaySpacing.section)
            .padding(.top, LinePaySpacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Check my paycheck") {
                onContinue()
            }
            .buttonStyle(LinePayPrimaryButtonStyle())
            .padding(.horizontal, LinePaySpacing.section)
            .padding(.vertical, LinePaySpacing.standard)
            .background(LinePayColor.canvas)
            .accessibilityIdentifier("onboarding.set-up-pay")
            .accessibilityHint("Starts a short setup of your hourly rate and pay period")
        }
        .background(LinePayColor.canvas.ignoresSafeArea())
    }

    private func trustRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LinePayColor.actionText)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(LinePayColor.textPrimary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
