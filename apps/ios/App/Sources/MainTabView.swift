import SwiftUI
import UIKit

struct MainTabView: View {
    enum Destination: Hashable { case today, pay, history, settings }
    let model: AppModel
    let subscriptionStore: SubscriptionStore
    @State private var selection: Destination = .today

    init(model: AppModel, subscriptionStore: SubscriptionStore) {
        self.model = model
        self.subscriptionStore = subscriptionStore
        UITabBar.appearance().unselectedItemTintColor = LinePayColor.tabBarUnselected
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayView(
                model: model, onOpenHistory: { selection = .history },
                onOpenPay: { selection = .pay }
            )
            .tabItem { Label("Today", systemImage: "clock") }.tag(Destination.today)
            PayLedgerView(model: model, subscriptionStore: subscriptionStore)
                .tabItem { Label("Pay", systemImage: "banknote") }.tag(Destination.pay)
            HistoryView(
                model: model, subscriptionStore: subscriptionStore,
                onOpenCurrent: { selection = .pay }
            )
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(
                Destination.history)
            SettingsView(model: model, subscriptionStore: subscriptionStore)
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(Destination.settings)
        }
        .tint(LinePayColor.actionText)
        .toolbarBackground(LinePayColor.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
