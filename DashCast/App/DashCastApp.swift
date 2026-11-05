import SwiftUI

@main
struct DashCastApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Start the StoreKit listener and entitlement check at launch, not when the paywall first opens.
        _ = StoreKitManager.shared
        // Automatic trip detection must start at launch: significant-location changes relaunch
        // the app in the background and nothing else would resume monitoring.
        AutoTripService.shared.refresh()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
                .onAppear {
                    ExternalDisplayManager.shared.checkForExistingExternalDisplay()
                }
        }
    }
}
