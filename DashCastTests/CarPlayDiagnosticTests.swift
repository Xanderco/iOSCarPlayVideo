import XCTest
import UIKit
@testable import DashCast

/// Previously this test only printed diagnostics and asserted nothing (Review 2026-11-05).
final class CarPlayDiagnosticTests: XCTestCase {
    func testExternalDisplayRoleClassification() {
        XCTAssertTrue(ExternalDisplayManager.isExternalDisplayRole(.windowExternalDisplayNonInteractive))
        XCTAssertFalse(ExternalDisplayManager.isExternalDisplayRole(.windowApplication))
    }

    @MainActor
    func testNoExternalDisplayInTestHostAndDetachResetsState() {
        let manager = ExternalDisplayManager()
        manager.checkForExistingExternalDisplay()
        let hasExternalScene = UIApplication.shared.connectedScenes.contains {
            ExternalDisplayManager.isExternalDisplayRole($0.session.role)
        }
        XCTAssertEqual(manager.isExternalDisplayConnected, hasExternalScene)

        manager.detach(from: nil)
        XCTAssertFalse(manager.isExternalDisplayConnected)
        XCTAssertEqual(manager.externalDisplayResolution, .zero)
    }
}
