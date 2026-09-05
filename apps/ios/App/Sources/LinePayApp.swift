import SwiftUI

@main
struct LinePayApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = AppSession.production()
    @State private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            RootView(model: session.model, subscriptionStore: subscriptionStore)
                .id(session.revision)
                .environment(\.linePaySession, session)
                .disabled(session.isBusy)
                .task { await subscriptionStore.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await subscriptionStore.refreshEntitlements() } }
                }
                .alert(
                    "Backup restore",
                    isPresented: Binding(
                        get: { session.restoreNotice != nil },
                        set: { if !$0 { session.restoreNotice = nil } }
                    )
                ) {
                    Button("OK") { session.restoreNotice = nil }
                } message: {
                    Text(session.restoreNotice ?? "")
                }
        }
    }
}
