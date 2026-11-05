import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.dashBackground.ignoresSafeArea()

            ZStack {
                CastHomeView()
                    .opacity(appState.selectedTab == .cast ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .cast)
                    .accessibilityHidden(appState.selectedTab != .cast)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Screen_Cast")

                DriveHomeView()
                    .opacity(appState.selectedTab == .drive ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .drive)
                    .accessibilityHidden(appState.selectedTab != .drive)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Screen_Drive")

                WidgetsHomeView()
                    .opacity(appState.selectedTab == .widgets ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .widgets)
                    .accessibilityHidden(appState.selectedTab != .widgets)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Screen_Widgets")

                SoundsHomeView()
                    .opacity(appState.selectedTab == .sounds ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .sounds)
                    .accessibilityHidden(appState.selectedTab != .sounds)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Screen_Sounds")

                MeHomeView()
                    .opacity(appState.selectedTab == .me ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .me)
                    .accessibilityHidden(appState.selectedTab != .me)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Screen_Me")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidCapsuleTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $appState.showPaywall) {
            LifetimePaywallView()
        }
    }
}
