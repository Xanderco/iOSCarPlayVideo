import SwiftUI

@main
struct DashCastApp: App {
    @StateObject private var appState: AppState

    init() {
        // Test hooks (-uiTesting, -stubNetwork, -seedDemoData) must run before any shared store loads.
        LaunchConfiguration.applyIfNeeded()
        _appState = StateObject(wrappedValue: AppState.shared)
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
