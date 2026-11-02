import CarPlay
import UIKit

public final class CarPlayDashboardSceneDelegate: UIResponder, CPTemplateApplicationDashboardSceneDelegate {
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
