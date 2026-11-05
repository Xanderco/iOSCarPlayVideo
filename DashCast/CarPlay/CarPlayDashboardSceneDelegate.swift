import CarPlay
import UIKit

/// CarPlay delivers scene-delegate callbacks on the main thread, but the SDK protocol is not
/// annotated `@MainActor`. `@preconcurrency` states that contract and keeps the class main-actor
/// isolated without the "conformance crosses into main actor-isolated code" warning.
@MainActor
public final class CarPlayDashboardSceneDelegate: UIResponder, @preconcurrency CPTemplateApplicationDashboardSceneDelegate {
    public func templateApplicationDashboardScene(
        _ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene,
        didConnect dashboardController: CPDashboardController,
        to window: UIWindow
    ) {
        let button = CPDashboardButton(
            titleVariants: ["DashCast", "Cast"],
            subtitleVariants: ["Stream on car screen", "Open"],
            image: UIImage(systemName: "car.fill") ?? UIImage()
        ) { _ in
            // Action when tapped on CarPlay dashboard shortcut
        }
        dashboardController.shortcutButtons = [button]
    }
}
