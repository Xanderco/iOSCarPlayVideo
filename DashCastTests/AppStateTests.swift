import XCTest
@testable import DashCast

final class AppStateTests: XCTestCase {
    @MainActor
    func testInitialAppStateDefaults() {
        let state = AppState(isProLifetimeUnlocked: false)
        XCTAssertEqual(state.selectedTab, .home)
        XCTAssertFalse(state.isProLifetimeUnlocked)
        XCTAssertFalse(state.showPaywall)
        XCTAssertNil(state.settingsDeepLink)
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

    func testTabsMatchRedesignSpec() {
        XCTAssertEqual(AppState.TabItem.allCases.map(\.rawValue), ["Home", "Library", "Cast", "Drive", "Settings"])
        for item in AppState.TabItem.allCases {
            XCTAssertFalse(item.iconName.isEmpty)
        }
    }

    func testLaunchArgumentMappingIncludingLegacyTabs() {
        XCTAssertEqual(AppState.TabItem.resolve(launchValue: "home")?.tab, .home)
        XCTAssertEqual(AppState.TabItem.resolve(launchValue: "Library")?.tab, .library)
        XCTAssertEqual(AppState.TabItem.resolve(launchValue: "cast")?.tab, .cast)
        XCTAssertNil(AppState.TabItem.resolve(launchValue: "cast")?.route)
        XCTAssertEqual(AppState.TabItem.resolve(launchValue: "me")?.tab, .settings)

        let drive = AppState.TabItem.resolve(launchValue: "drive")
        XCTAssertEqual(drive?.tab, .drive)
        XCTAssertNil(drive?.route)
        XCTAssertEqual(AppState.TabItem.resolve(launchValue: "widgets")?.route, .carScreen)
        XCTAssertEqual(AppState.TabItem.resolve(launchValue: "sounds")?.route, .chime)
        XCTAssertNil(AppState.TabItem.resolve(launchValue: "territory"))
    }

    @MainActor
    func testOpenExtraSwitchesToSettings() {
        let state = AppState()
        state.open(.chime)
        XCTAssertEqual(state.selectedTab, .settings)
        XCTAssertEqual(state.settingsDeepLink, .chime)
    }
}
