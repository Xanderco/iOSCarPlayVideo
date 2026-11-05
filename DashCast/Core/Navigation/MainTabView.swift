import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(PassengerSafetyNotice.acceptedKey) private var passengerNoticeAccepted = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.dashBackground.ignoresSafeArea()

            ZStack {
                CastHomeView()
                    .opacity(appState.selectedTab == .cast ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .cast)

                DriveHomeView()
                    .opacity(appState.selectedTab == .drive ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .drive)

                WidgetsHomeView()
                    .opacity(appState.selectedTab == .widgets ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .widgets)

                SoundsHomeView()
                    .opacity(appState.selectedTab == .sounds ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .sounds)

                MeHomeView()
                    .opacity(appState.selectedTab == .me ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .me)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LiquidCapsuleTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $appState.showPaywall) {
            LifetimePaywallView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !passengerNoticeAccepted && !PassengerSafetyNotice.shouldSkip },
            set: { _ in }
        )) {
            PassengerSafetyNoticeView { passengerNoticeAccepted = true }
        }
    }
}
