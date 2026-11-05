import UIKit
import SwiftUI
import AVKit

/// Tracks a wired (HDMI/USB-C) or AirPlay-mirrored external screen and renders
/// `CarPlayExternalDisplayView` on it.
///
/// iOS only hands the app a dedicated external-display scene when Info.plist declares a
/// `UIWindowSceneSessionRoleExternalDisplayNonInteractive` configuration (see
/// `ExternalDisplaySceneDelegate`). Without it the screen is simply mirrored. The old
/// implementation relied on `UIScreen.didConnectNotification` + `window.screen = …`, which is
/// ignored in scene-based apps, and it created a new window on every scene activation.
///
/// Note: the CarPlay head unit itself is NOT an external display. Third-party apps cannot draw
/// video on CarPlay; CarPlay scenes are `CPTemplateApplicationScene`s and are excluded here.
@MainActor
public final class ExternalDisplayManager: ObservableObject {
    public static let shared = ExternalDisplayManager()

    @Published public private(set) var isExternalDisplayConnected: Bool = false
    @Published public private(set) var externalDisplayResolution: CGSize = .zero

    private var externalWindow: UIWindow?
    private weak var externalScene: UIWindowScene?

    public init() {}

    /// Whether a scene session role is a non-interactive external display.
    nonisolated public static func isExternalDisplayRole(_ role: UISceneSession.Role) -> Bool {
        role == .windowExternalDisplayNonInteractive
    }

    /// Picks up an external display scene that connected before this manager was created.
    public func checkForExistingExternalDisplay() {
        guard externalScene == nil else { return }
        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes
        where Self.isExternalDisplayRole(windowScene.session.role) {
            attach(to: windowScene)
            return
        }
    }

    /// Called by `ExternalDisplaySceneDelegate` when the system connects the external screen.
    public func attach(to windowScene: UIWindowScene) {
        if externalScene === windowScene, externalWindow != nil { return }
        externalWindow?.isHidden = true

        let window = UIWindow(windowScene: windowScene)
        let hostingController = UIHostingController(
            rootView: CarPlayExternalDisplayView()
                .preferredColorScheme(.dark)
        )
        window.rootViewController = hostingController
        window.isHidden = false

        externalWindow = window
        externalScene = windowScene
        isExternalDisplayConnected = true
        externalDisplayResolution = windowScene.coordinateSpace.bounds.size
    }

    /// Called when the external display scene disconnects.
    public func detach(from windowScene: UIWindowScene?) {
        if let windowScene, let current = externalScene, current !== windowScene { return }
        externalWindow?.isHidden = true
        externalWindow = nil
        externalScene = nil
        isExternalDisplayConnected = false
        externalDisplayResolution = .zero
    }
}

/// Scene delegate for `UIWindowSceneSessionRoleExternalDisplayNonInteractive`, registered in Info.plist.
public final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        MainActor.assumeIsolated {
            ExternalDisplayManager.shared.attach(to: windowScene)
        }
    }

    public func sceneDidDisconnect(_ scene: UIScene) {
        let windowScene = scene as? UIWindowScene
        MainActor.assumeIsolated {
            ExternalDisplayManager.shared.detach(from: windowScene)
        }
    }
}
