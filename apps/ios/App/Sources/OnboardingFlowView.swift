import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Equatable {
        case welcome
        case paySetup
        case softPaywall
    }

    let model: AppModel
    let store: SubscriptionStore
    let onComplete: () -> Void

    @State private var step: Step = .welcome

    var body: some View {
        Group {
            switch step {
            case .welcome:
                OnboardingWelcomeView {
                    step = .paySetup
                }

            case .paySetup:
                PayProfileSetupView(
                    model: model,
                    showsIntro: false,
                    onSaved: handlePaySetupCompleted
                )

            case .softPaywall:
                OnboardingPaywallView(
                    model: model,
                    store: store,
                    onContinueFree: onComplete,
                    onPurchaseCompleted: onComplete
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: step)
    }

    private func handlePaySetupCompleted() {
        if shouldPresentPaywall {
            step = .softPaywall
        } else {
            onComplete()
        }
    }

    private var shouldPresentPaywall: Bool {
        #if DEBUG
            true
        #else
            SubscriptionStore.commerceEnabled
        #endif
    }
}
