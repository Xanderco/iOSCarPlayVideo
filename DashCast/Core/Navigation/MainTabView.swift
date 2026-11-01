import SwiftUI
import UIKit

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    public init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
        appearance.shadowColor = UIColor(red: 0.20, green: 0.23, blue: 0.29, alpha: 0.8)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        TabView(selection: $appState.selectedTab) {
            CastHomeView()
                .tabItem {
                    Label(AppState.TabItem.cast.rawValue, systemImage: AppState.TabItem.cast.iconName)
                }
                .tag(AppState.TabItem.cast)

            DriveHomeView()
                .tabItem {
                    Label(AppState.TabItem.drive.rawValue, systemImage: AppState.TabItem.drive.iconName)
                }
                .tag(AppState.TabItem.drive)

            TerritoryHomeView()
                .tabItem {
                    Label(AppState.TabItem.territory.rawValue, systemImage: AppState.TabItem.territory.iconName)
                }
                .tag(AppState.TabItem.territory)

            WidgetsHomeView()
                .tabItem {
                    Label(AppState.TabItem.widgets.rawValue, systemImage: AppState.TabItem.widgets.iconName)
                }
                .tag(AppState.TabItem.widgets)

            SoundsHomeView()
                .tabItem {
                    Label(AppState.TabItem.sounds.rawValue, systemImage: AppState.TabItem.sounds.iconName)
                }
                .tag(AppState.TabItem.sounds)
        }
        .tint(.dashCyan)
        .sheet(isPresented: $appState.showPaywall) {
            LifetimePaywallView()
        }
    }
}
