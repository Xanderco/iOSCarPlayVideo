import SwiftUI

@main
struct DashCastApp: App {
    @StateObject private var appState = AppState.shared
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.dark.rawValue

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme((AppearancePreference(rawValue: appearanceRaw) ?? .dark).colorScheme)
                .onAppear {
                    ExternalDisplayManager.shared.checkForExistingExternalDisplay()
                }
        }
    }
}
