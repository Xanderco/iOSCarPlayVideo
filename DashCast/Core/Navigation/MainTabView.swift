import SwiftUI

/// Root: Home · Library · Cast · Settings (redesign spec §3). Car Extras live in Settings.
public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.dcBackground.ignoresSafeArea()

            ZStack {
                tabScreen(.home) { CastHomeView() } // pads itself for the tab bar
                tabScreen(.library) { MediaServersHomeView().safeAreaInset(edge: .bottom) { tabBarClearance } }
                tabScreen(.cast) { CastMirrorView().safeAreaInset(edge: .bottom) { tabBarClearance } }
                tabScreen(.settings) { SettingsView().safeAreaInset(edge: .bottom) { tabBarClearance } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidCapsuleTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $appState.showPaywall) {
            LifetimePaywallView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding && !OnboardingView.shouldSkipForLaunch },
            set: { _ in }
        )) {
            OnboardingView()
                .environmentObject(appState)
        }
    }

    private var tabBarClearance: some View {
        Color.clear.frame(height: 72).allowsHitTesting(false)
    }

    /// All tabs stay alive (state and scroll position survive tab switches); only the selected one is visible.
    private func tabScreen<Content: View>(_ tab: AppState.TabItem, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = appState.selectedTab == tab
        return content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("Screen_\(tab.rawValue)")
    }
}
