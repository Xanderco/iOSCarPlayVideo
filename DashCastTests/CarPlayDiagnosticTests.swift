import XCTest
@testable import DashCast

final class CarPlayDiagnosticTests: XCTestCase {
    @MainActor
    func testExternalDisplayDetection() {
        print("DIAGNOSTIC: UIScreen.screens.count = \(UIScreen.screens.count)")
        for (i, s) in UIScreen.screens.enumerated() {
            print("  Screen [\(i)]: bounds=\(s.bounds), scale=\(s.scale)")
        }

        print("DIAGNOSTIC: UIApplication.shared.connectedScenes.count = \(UIApplication.shared.connectedScenes.count)")
        for s in UIApplication.shared.connectedScenes {
            print("  Scene: \(s.session.role), title=\(s.title ?? "none")")
        }

        ExternalDisplayManager.shared.checkForExistingExternalDisplay()
        print("DIAGNOSTIC: isExternalDisplayConnected = \(ExternalDisplayManager.shared.isExternalDisplayConnected)")
    }
}
