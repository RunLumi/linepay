import SwiftUI

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if model.profile == nil {
                PayProfileSetupView(model: model)
            } else {
                MainTabView(model: model)
            }
        }
        .background(LinePayColor.canvas.ignoresSafeArea())
    }
}

#Preview {
    RootView()
}
