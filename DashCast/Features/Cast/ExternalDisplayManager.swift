import UIKit
import SwiftUI
import AVKit

@MainActor
public final class ExternalDisplayManager: ObservableObject {
    public static let shared = ExternalDisplayManager()

    @Published public private(set) var isExternalDisplayConnected: Bool = false
    @Published public private(set) var externalDisplayResolution: CGSize = .zero

    private var externalWindow: UIWindow?

    public init() {
        setupScreenNotifications()
        checkForExistingExternalScreen()
    }

    private func setupScreenNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let newScreen = notification.object as? UIScreen else { return }
            self.connectExternalScreen(newScreen)
        }

        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.disconnectExternalScreen()
        }
    }

    private func checkForExistingExternalScreen() {
        if UIScreen.screens.count > 1 {
            let externalScreen = UIScreen.screens[1]
            connectExternalScreen(externalScreen)
        }
    }

    private func connectExternalScreen(_ screen: UIScreen) {
        self.isExternalDisplayConnected = true
        self.externalDisplayResolution = screen.bounds.size

        let window = UIWindow(frame: screen.bounds)
        window.screen = screen

        let playerVC = AVPlayerViewController()
        playerVC.player = VideoPlayerService.shared.player
        playerVC.showsPlaybackControls = false
        playerVC.videoGravity = .resizeAspect

        window.rootViewController = playerVC
        window.isHidden = false
        self.externalWindow = window
    }

    private func disconnectExternalScreen() {
        self.isExternalDisplayConnected = false
        self.externalDisplayResolution = .zero
        self.externalWindow?.isHidden = true
        self.externalWindow = nil
    }
}
