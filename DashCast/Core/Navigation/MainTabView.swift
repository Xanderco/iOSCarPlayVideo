import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(PassengerSafetyNotice.acceptedKey) private var passengerNoticeAccepted = false

    public init() {}

    public var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                // Native system tab bar: on iOS 26 it is rendered by the system in Liquid Glass
                // (translucency, morphing selection, minimise-on-scroll) at no CPU cost to us.
                TabView(selection: $appState.selectedTab) {
                    Tab(AppState.TabItem.cast.rawValue, systemImage: AppState.TabItem.cast.iconName, value: AppState.TabItem.cast) {
                        screen(.cast)
                    }
                    Tab(AppState.TabItem.drive.rawValue, systemImage: AppState.TabItem.drive.iconName, value: AppState.TabItem.drive) {
                        screen(.drive)
                    }
                    Tab(AppState.TabItem.widgets.rawValue, systemImage: AppState.TabItem.widgets.iconName, value: AppState.TabItem.widgets) {
                        screen(.widgets)
                    }
                    Tab(AppState.TabItem.sounds.rawValue, systemImage: AppState.TabItem.sounds.iconName, value: AppState.TabItem.sounds) {
                        screen(.sounds)
                    }
                    Tab(AppState.TabItem.me.rawValue, systemImage: AppState.TabItem.me.iconName, value: AppState.TabItem.me) {
                        screen(.me)
                    }
                }
                .tint(Color.dashYellow)
            } else {
                legacyTabs
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $appState.showPaywall) {
            LifetimePaywallView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { (!passengerNoticeAccepted && !PassengerSafetyNotice.shouldSkip) || ScreenshotLaunch.showOnboarding },
            set: { _ in }
        )) {
            // First-run walkthrough; includes the required passenger-only acknowledgement.
            WelcomeOnboardingView { passengerNoticeAccepted = true }
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func screen(_ item: AppState.TabItem) -> some View {
        switch item {
        case .cast: CastHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Cast")
        case .drive: DriveHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Drive")
        case .widgets: WidgetsHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Widgets")
        case .sounds: SoundsHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Sounds")
        case .me: MeHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Me")
        }
    }

    /// iOS 17 fallback: the previous floating capsule bar.
    private var legacyTabs: some View {
        ZStack(alignment: .bottom) {
            Color.dashBackground.ignoresSafeArea()
            ZStack {
                ForEach(AppState.TabItem.allCases) { item in
                    screen(item)
                        .opacity(appState.selectedTab == item ? 1 : 0)
                        .allowsHitTesting(appState.selectedTab == item)
                        .accessibilityHidden(appState.selectedTab != item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            LiquidCapsuleTabBar(selectedTab: $appState.selectedTab)
        }
    }
}
