import SwiftUI

struct RootView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore

    var body: some View {
        Group {
            if model.persistenceIssue != nil {
                DataRecoveryView(model: model)
            } else if model.isOnboarded {
                MainTabView(
                    model: model,
                    subscriptionStore: subscriptionStore
                )
            } else {
                OnboardingFlowView(model: model) {}
            }
        }
        .background(LinePayColor.canvas.ignoresSafeArea())
    }
}

#Preview {
    RootView(
        model: AppModel(),
        subscriptionStore: SubscriptionStore()
    )
}
