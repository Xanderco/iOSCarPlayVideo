import SwiftUI

@main
struct DashCastApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    ExternalDisplayManager.shared.checkForExistingExternalDisplay()
                    AutoDriveDetectionService.shared.startMonitoringIfEnabled()
                }
        }
    }
}
