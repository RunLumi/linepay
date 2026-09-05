import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Equatable {
        case welcome
        case paySetup
    }

    let model: AppModel
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
                    onSaved: onComplete
                )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: step)
    }
}
