import SwiftUI

@main
struct DashCastApp: App {
    @StateObject private var appState = AppState.shared
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.dark.rawValue

    init() {
        // Start the StoreKit listener and entitlement check at launch, not when the paywall first opens.
        _ = StoreKitManager.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme((AppearancePreference(rawValue: appearanceRaw) ?? .dark).colorScheme)
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
                .onAppear {
                    ExternalDisplayManager.shared.checkForExistingExternalDisplay()
                }
        }
    }
}
