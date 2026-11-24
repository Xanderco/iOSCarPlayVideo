import XCTest
import SwiftUI
@testable import DashCast

@MainActor
final class PassengerSplitScreenTests: XCTestCase {

    func testInitialSplitModeIsSplitSidebar() {
        let manager = PassengerSplitScreenManager()
        XCTAssertEqual(manager.currentMode, .splitSidebar)
        XCTAssertFalse(manager.isSafetyBannerDismissed)
    }

    func testModeCyclingOrder() {
        let manager = PassengerSplitScreenManager()
        XCTAssertEqual(manager.currentMode, .splitSidebar)

        manager.cycleMode()
        XCTAssertEqual(manager.currentMode, .fullVideo)

        manager.cycleMode()
        XCTAssertEqual(manager.currentMode, .fullTelemetry)

        manager.cycleMode()
        XCTAssertEqual(manager.currentMode, .splitSidebar)
    }

    func testSetModeDirectly() {
        let manager = PassengerSplitScreenManager()
        manager.setMode(.fullVideo)
        XCTAssertEqual(manager.currentMode, .fullVideo)

        manager.setMode(.fullTelemetry)
        XCTAssertEqual(manager.currentMode, .fullTelemetry)
    }

    func testSafetyNoticeBannerDismissalAndReset() {
        let manager = PassengerSplitScreenManager()
        XCTAssertFalse(manager.isSafetyBannerDismissed)

        manager.dismissSafetyBanner()
        XCTAssertTrue(manager.isSafetyBannerDismissed)

        manager.resetSafetyBanner()
        XCTAssertFalse(manager.isSafetyBannerDismissed)
    }

    func testSplitModeIconsAndIdentifiers() {
        for mode in PassengerSplitScreenManager.SplitMode.allCases {
            XCTAssertFalse(mode.id.isEmpty)
            XCTAssertFalse(mode.icon.isEmpty)
            XCTAssertFalse(mode.rawValue.isEmpty)
        }
    }

    func testCarPlayExternalDisplayViewInstantiatesWithoutCrashing() {
        let view = CarPlayExternalDisplayView()
        XCTAssertNotNil(view.body)
    }
}
