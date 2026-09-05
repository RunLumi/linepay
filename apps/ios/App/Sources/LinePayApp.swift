import SwiftUI

@main
struct LinePayApp: App {
    @State private var model = AppModel.production()
    @State private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            RootView(
                model: model,
                subscriptionStore: subscriptionStore
            )
            .task {
                await subscriptionStore.start()
            }
        }
    }
}
