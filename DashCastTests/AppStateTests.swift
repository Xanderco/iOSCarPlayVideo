import XCTest
@testable import DashCast

final class AppStateTests: XCTestCase {
    @MainActor
    func testInitialAppStateDefaults() {
        let state = AppState(isProLifetimeUnlocked: false)
        XCTAssertEqual(state.selectedTab, .cast)
        XCTAssertFalse(state.isProLifetimeUnlocked)
        XCTAssertFalse(state.showPaywall)
        XCTAssertFalse(state.isDriveActive)
    }

    @MainActor
    func testUnlockProLifetime() {
        let state = AppState(isProLifetimeUnlocked: false)
        state.showPaywall = true
        state.unlockProLifetime()
        XCTAssertTrue(state.isProLifetimeUnlocked)
        XCTAssertFalse(state.showPaywall)
    }

    @MainActor
    func testSpeedUnitToggle() {
        let state = AppState()
        state.setSpeedUnit(milesPerHour: true)
        XCTAssertTrue(state.useMilesPerHour)

        state.setSpeedUnit(milesPerHour: false)
        XCTAssertFalse(state.useMilesPerHour)
    }

    func testTabItemProperties() {
        XCTAssertEqual(AppState.TabItem.cast.rawValue, "Cast")
        XCTAssertEqual(AppState.TabItem.drive.rawValue, "Drive")
        XCTAssertEqual(AppState.TabItem.widgets.rawValue, "Widgets")
        XCTAssertEqual(AppState.TabItem.sounds.rawValue, "Sounds")
        XCTAssertEqual(AppState.TabItem.me.rawValue, "Me")

        for item in AppState.TabItem.allCases {
            XCTAssertFalse(item.iconName.isEmpty)
        }
    }
}
