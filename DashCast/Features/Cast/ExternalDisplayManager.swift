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
        setupSceneNotifications()
        checkForExistingExternalScene()
    }

    private func setupSceneNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let scene = notification.object as? UIWindowScene else { return }
            Task { @MainActor [weak self] in
                self?.handleSceneActivation(scene)
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIScene.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let scene = notification.object as? UIWindowScene else { return }
            Task { @MainActor [weak self] in
                self?.handleSceneDisconnect(scene)
            }
        }
    }

    private func checkForExistingExternalScene() {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene, isExternalRole(windowScene.session.role) {
                connectExternalScene(windowScene)
                break
            }
        }
    }

    private func handleSceneActivation(_ scene: UIWindowScene) {
        if isExternalRole(scene.session.role) {
            connectExternalScene(scene)
        }
    }

    private func handleSceneDisconnect(_ scene: UIWindowScene) {
        if isExternalRole(scene.session.role) {
            disconnectExternalScreen()
        }
    }

    private func isExternalRole(_ role: UISceneSession.Role) -> Bool {
        return role == .windowExternalDisplayNonInteractive
    }

    private func connectExternalScene(_ windowScene: UIWindowScene) {
        self.isExternalDisplayConnected = true
        self.externalDisplayResolution = windowScene.coordinateSpace.bounds.size

        let window = UIWindow(windowScene: windowScene)
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
