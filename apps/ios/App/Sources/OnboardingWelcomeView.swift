import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                LineGapMark()

                VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                    Text("Know what your work should pay.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(LinePayColor.textPrimary)

                    Text(
                        "Track the hours and pay rules that matter. LinePaycheck calculates expected "
                            + "pay and helps you check the paycheck against your work."
                    )
                    .font(.title3)
                    .foregroundStyle(LinePayColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                    trustRow(
                        icon: "person.crop.circle.badge.xmark",
                        title: "No account",
                        detail: "Start using LinePaycheck without an email or password."
                    )
                    trustRow(
                        icon: "iphone",
                        title: "Private by default",
                        detail: "Your hours, pay rules, and paycheck data stay on this iPhone."
                    )
                    trustRow(
                        icon: "equal.circle",
                        title: "Explainable pay",
                        detail: "See how your confirmed rules turn worked hours into expected pay."
                    )
                }
            }
            .padding(LinePaySpacing.section)
            .padding(.top, LinePaySpacing.section)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Set up my pay") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(LinePayColor.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, LinePaySpacing.section)
            .padding(.vertical, LinePaySpacing.standard)
            .background(LinePayColor.canvas)
            .accessibilityIdentifier("onboarding.set-up-pay")
            .accessibilityHint("Continues to your pay rule setup")
        }
        .background(LinePayColor.canvas.ignoresSafeArea())
    }

    private func trustRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: LinePaySpacing.standard) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LinePayColor.brandPrimary)
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
