import SwiftUI

/// Root: Home · Library · Cast · Drive · Settings. Car Extras (Car Screen, Car Chime) live in Settings.
///
/// - iOS 26+: native `TabView` with the `Tab` API, so the system draws the Liquid Glass tab bar
///   (minimizes on scroll).
/// - iOS 17–25: the lightweight floating `LiquidCapsuleTabBar` over a ZStack of live tab screens.
public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false

    public init() {}

    public var body: some View {
        tabs
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

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 26, *) {
            nativeTabs
        } else {
            capsuleTabs
        }
    }

    // MARK: iOS 26+: system Liquid Glass

    @available(iOS 26, *)
    private var nativeTabs: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(AppState.TabItem.allCases) { item in
                Tab(item.rawValue, systemImage: item.iconName, value: item) {
                    screen(for: item)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("Screen_\(item.rawValue)")
                }
                // System tab buttons are found by label in UI tests (`app.tabBars.buttons["Home"]`).
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.dcAccent)
    }

    // MARK: iOS 17–25: floating capsule

    private var capsuleTabs: some View {
        ZStack(alignment: .bottom) {
            Color.dcBackground.ignoresSafeArea()

            ZStack {
                ForEach(AppState.TabItem.allCases) { item in
                    capsuleScreen(item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidCapsuleTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }

    /// All tabs stay alive (state and scroll position survive tab switches); only the selected one is visible.
    private func capsuleScreen(_ item: AppState.TabItem) -> some View {
        let isSelected = appState.selectedTab == item
        return screen(for: item)
            .safeAreaInset(edge: .bottom) {
                // Home and Drive already pad for the floating bar.
                if item != .home && item != .drive {
                    Color.clear.frame(height: 72).allowsHitTesting(false)
                }
            }
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("Screen_\(item.rawValue)")
    }

    // MARK: Screens

    @ViewBuilder
    private func screen(for item: AppState.TabItem) -> some View {
        switch item {
        case .home: CastHomeView()
        case .library: MediaServersHomeView()
        case .cast: CastMirrorView()
        case .drive: DriveHomeView() // owned by the Drive session
        case .settings: SettingsView()
        }
    }
}
