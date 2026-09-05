import SwiftUI

struct MainTabView: View {
    let model: AppModel

    var body: some View {
        TabView {
            TodayView(model: model)
                .tabItem {
                    Label("Today", systemImage: "clock")
                }

            PayLedgerView(model: model)
                .tabItem {
                    Label("Pay", systemImage: "dollarsign")
                }

            HistoryView(model: model)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView(model: model)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(LinePayColor.brandPrimary)
    }
}
