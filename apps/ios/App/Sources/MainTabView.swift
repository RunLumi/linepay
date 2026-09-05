import SwiftUI

struct MainTabView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore

    var body: some View {
        TabView {
            TodayView(model: model)
                .tabItem {
                    Label("Today", systemImage: "clock")
                }

            PayLedgerView(
                model: model,
                subscriptionStore: subscriptionStore
            )
            .tabItem {
                Label("Pay", systemImage: "dollarsign")
            }

            HistoryView(model: model)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView(
                model: model,
                subscriptionStore: subscriptionStore
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(LinePayColor.brandPrimary)
    }
}
