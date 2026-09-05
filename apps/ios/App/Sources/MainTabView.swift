import SwiftUI

struct MainTabView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(model: model) { selectedTab = 1 }
                .tabItem {
                    Label("Today", systemImage: "clock")
                }
                .tag(0)

            PayLedgerView(
                model: model,
                subscriptionStore: subscriptionStore
            )
            .tabItem {
                Label("Pay", systemImage: "dollarsign")
            }
            .tag(1)

            HistoryView(model: model)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)

            SettingsView(
                model: model,
                subscriptionStore: subscriptionStore
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
        .tint(LinePayColor.actionText)
    }
}
