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
                }
                .onOpenURL { url in
                    guard url.scheme == "dashcast" else { return }
                    if url.host == "tab" {
                        let tabName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        appState.selectTabByName(tabName)
                    } else if url.host == "unlock-pro" {
                        appState.unlockProLifetime()
                    }
                }
        }
    }
}
