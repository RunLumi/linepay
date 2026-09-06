import SwiftUI

struct RootView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore

    var body: some View {
        Group {
            if model.persistenceIssue != nil {
                DataRecoveryView(model: model)
            } else if !model.isOnboarded && model.pendingDeletionCount > 0 {
                PendingRemovalView(model: model)
            } else if model.isOnboarded {
                if model.onboardingProgress == .firstWork {
                    FirstWorkIntroductionView(model: model)
                } else if model.onboardingProgress == .proof {
                    FirstPayResultView(model: model, subscriptionStore: subscriptionStore)
                } else {
                    MainTabView(model: model, subscriptionStore: subscriptionStore)
                }
            } else {
                OnboardingFlowView(model: model) {}
            }
        }
        .tint(LinePayColor.actionText)
        .background(LinePayColor.canvas.ignoresSafeArea())
    }
}

#Preview {
    RootView(
        model: AppModel(),
        subscriptionStore: SubscriptionStore()
    )
}

struct PendingRemovalView: View {
    let model: AppModel
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            List {
                Text("Local deletion needs attention").font(.title2.bold())
                Text(
                    "Some original files could not be removed. Their deletion remains queued; no success is being reported prematurely."
                )
                Button("Retry deletion") {
                    do { try model.resetAllData() } catch {
                        errorMessage = error.localizedDescription
                    }
                }.buttonStyle(LinePayPrimaryButtonStyle())
                if let errorMessage { Text(errorMessage).foregroundStyle(LinePayColor.review) }
            }.navigationTitle("Data cleanup")
        }
    }
}
