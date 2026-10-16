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
    @State private var importingAgreement = false

    var body: some View {
        Group {
            switch step {
            case .welcome:
                OnboardingWelcomeView(onImportAgreement: { importingAgreement = true }) {
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
        .sheet(isPresented: $importingAgreement) {
            NavigationStack {
                AgreementDocumentsView(model: model) {
                    importingAgreement = false
                    step = .paySetup
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { importingAgreement = false }
                    }
                }
            }
        }
    }
}
