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
        setupNotifications()
        checkForExistingExternalDisplay()
    }

    private func setupNotifications() {
        // Scene Notifications (iOS 13+)
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

        // Screen Notifications Fallback (for CarPlay and direct video displays)
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let screen = notification.object as? UIScreen else { return }
            Task { @MainActor [weak self] in
                self?.connectExternalScreen(screen)
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.disconnectExternalDisplay()
            }
        }
    }

    public func checkForExistingExternalDisplay() {
        // Check window scenes first
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene, isExternalScene(windowScene) {
                connectExternalScene(windowScene)
                return
            }
        }

        // Check connected screens fallback
        if UIScreen.screens.count > 1 {
            let externalScreen = UIScreen.screens[1]
            connectExternalScreen(externalScreen)
        }
    }

    private func handleSceneActivation(_ scene: UIWindowScene) {
        if isExternalScene(scene) {
            connectExternalScene(scene)
        }
    }

    private func handleSceneDisconnect(_ scene: UIWindowScene) {
        if isExternalScene(scene) {
            disconnectExternalDisplay()
        }
    }

    private func isExternalScene(_ windowScene: UIWindowScene) -> Bool {
        if windowScene.session.role == .windowExternalDisplayNonInteractive { return true }
        if windowScene.session.role.rawValue.contains("CarPlay") { return true }
        if windowScene.screen != UIScreen.main { return true }
        return false
    }

    private func connectExternalScene(_ windowScene: UIWindowScene) {
        self.isExternalDisplayConnected = true
        self.externalDisplayResolution = windowScene.coordinateSpace.bounds.size

        let window = UIWindow(windowScene: windowScene)
        let hostingController = UIHostingController(
            rootView: CarPlayExternalDisplayView()
                .preferredColorScheme(.dark)
        )

        window.rootViewController = hostingController
        window.isHidden = false
        window.makeKeyAndVisible()
        self.externalWindow = window
    }

    private func connectExternalScreen(_ screen: UIScreen) {
        self.isExternalDisplayConnected = true
        self.externalDisplayResolution = screen.bounds.size

        let window = UIWindow(frame: screen.bounds)
        window.screen = screen

        let hostingController = UIHostingController(
            rootView: CarPlayExternalDisplayView()
                .preferredColorScheme(.dark)
        )

        window.rootViewController = hostingController
        window.isHidden = false
        window.makeKeyAndVisible()
        self.externalWindow = window
    }

    private func disconnectExternalDisplay() {
        self.isExternalDisplayConnected = false
        self.externalDisplayResolution = .zero
        self.externalWindow?.isHidden = true
        self.externalWindow = nil
    }
}
