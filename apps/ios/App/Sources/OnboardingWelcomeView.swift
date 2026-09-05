import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
            Spacer(minLength: LinePaySpacing.section)

            LineGapMark()

            VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                Text("Know what your work should pay.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(LinePayColor.textPrimary)

                Text(
                    "Track the hours and pay rules that matter. LinePay calculates expected pay "
                        + "and helps you check the paycheck against your work."
                )
                .font(.title3)
                .foregroundStyle(LinePayColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                trustRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: "No account",
                    detail: "Start using LinePay without an email or password."
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

            Spacer()

            Button("Set up my pay") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(LinePayColor.brandPrimary)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("onboarding.set-up-pay")
            .accessibilityHint("Continues to your pay rule setup")
        }
        .padding(LinePaySpacing.section)
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
