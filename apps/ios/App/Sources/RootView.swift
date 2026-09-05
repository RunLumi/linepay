import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Know what your work should pay.")
                    .font(.largeTitle.bold())

                Text(
                    "LinePay records your work, applies the pay rules you confirm, "
                        + "and helps flag possible paycheck differences."
                )
                .font(.body)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Set up my pay rules") {
                    // First real flow will replace this shell.
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Begins setup of your pay rules")
            }
            .padding()
            .navigationTitle("LinePay")
        }
    }
}

#Preview {
    RootView()
}
