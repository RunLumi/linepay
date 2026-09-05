import SwiftUI

struct RootView: View {
    @State private var model = AppModel()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView(model: model)
            } else {
                OnboardingFlowView(
                    model: model,
                    store: subscriptionStore
                ) {
                    hasCompletedOnboarding = true
                }
            }
        }
        .background(LinePayColor.canvas.ignoresSafeArea())
    }
}

#Preview {
    RootView()
}
