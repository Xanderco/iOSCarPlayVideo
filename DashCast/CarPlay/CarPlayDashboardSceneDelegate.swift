import CarPlay
import Combine
import UIKit

/// CarPlay delivers scene-delegate callbacks on the main thread, but the SDK protocol is not
/// annotated `@MainActor`. `@preconcurrency` states that contract and keeps the class main-actor
/// isolated without the "conformance crosses into main actor-isolated code" warning.
@MainActor
public final class CarPlayDashboardSceneDelegate: UIResponder, @preconcurrency CPTemplateApplicationDashboardSceneDelegate {
    private weak var dashboardController: CPDashboardController?
    private var playlistObserver: NSObjectProtocol?
    private var playerCancellable: AnyCancellable?

    public func templateApplicationDashboardScene(
        _ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene,
        didConnect dashboardController: CPDashboardController,
        to window: UIWindow
    ) {
        self.dashboardController = dashboardController
        refreshShortcutButtons()

        playlistObserver = NotificationCenter.default.addObserver(
            forName: PlaylistStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshShortcutButtons()
            }
        }

        let player = VideoPlayerService.shared
        playerCancellable = player.$currentChannel
            .combineLatest(player.$isPlaying)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.refreshShortcutButtons()
                }
            }
    }

    public func templateApplicationDashboardScene(
        _ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene,
        didDisconnect dashboardController: CPDashboardController,
        from window: UIWindow
    ) {
        if let playlistObserver {
            NotificationCenter.default.removeObserver(playlistObserver)
        }
        playlistObserver = nil
        playerCancellable = nil
        self.dashboardController = nil
    }

    public func refreshShortcutButtons() {
        let player = VideoPlayerService.shared
        let store = PlaylistStore.shared
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: player.currentChannel,
            isPlaying: player.isPlaying,
            favoriteChannels: store.favoriteChannels,
            allChannels: store.allChannels
        )
        dashboardController?.shortcutButtons = CarPlayDashboardShortcutProvider.makeButtons(from: specs) { action in
            CarPlayDashboardShortcutProvider.perform(action, on: VideoPlayerService.shared)
        }
    }
}
