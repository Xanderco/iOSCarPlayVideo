import SwiftUI

@main
struct DashCastApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Start the StoreKit listener and entitlement check at launch, not when the paywall first opens.
        _ = StoreKitManager.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    ExternalDisplayManager.shared.checkForExistingExternalDisplay()
                }
        }
    }
}
