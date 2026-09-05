import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Equatable {
        case welcome
        case paySetup
    }

    let model: AppModel
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: step)
    }
}
