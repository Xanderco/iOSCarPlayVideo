import XCTest
import AppIntents
@testable import DashCast

final class AppIntentsTests: XCTestCase {

    @MainActor
    func testStartTripRecordingIntent() async throws {
        let intent = StartTripRecordingIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
        XCTAssertEqual(AppState.shared.selectedTab, .drive)
    }

    @MainActor
    func testResumeLastCastIntent() async throws {
        let intent = ResumeLastCastIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
        XCTAssertEqual(AppState.shared.selectedTab, .cast)
    }

    @MainActor
    func testToggleNightHUDIntent() async throws {
        let intent = ToggleNightHUDIntent()
        let initial = UserDefaults.standard.bool(forKey: "dashcast_oled_night_hud_active")
        let result = try await intent.perform()
        XCTAssertNotNil(result)
        let toggled = UserDefaults.standard.bool(forKey: "dashcast_oled_night_hud_active")
        XCTAssertEqual(toggled, !initial)

        // Restore
        _ = try await intent.perform()
    }

    @MainActor
    func testPlayCarChimeIntent() async throws {
        let intent = PlayCarChimeIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    func testAppShortcutsProviderConfiguration() {
        let shortcuts = DashCastShortcutsProvider.appShortcuts
        XCTAssertEqual(shortcuts.count, 4)
    }

    func testDashCastLinksAutomationDestinations() {
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://start-trip")!), .startTrip)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://resume-cast")!), .resumeCast)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://night-hud")!), .nightHUD)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://play-chime")!), .playChime)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast://automations")!), .automations)
    }

    @MainActor
    func testAppStateDeepLinkHandlingForAutomations() {
        let state = AppState.shared

        XCTAssertTrue(state.handleDeepLink(URL(string: "dashcast://start-trip")!))
        XCTAssertEqual(state.selectedTab, .drive)

        XCTAssertTrue(state.handleDeepLink(URL(string: "dashcast://resume-cast")!))
        XCTAssertEqual(state.selectedTab, .cast)

        XCTAssertTrue(state.handleDeepLink(URL(string: "dashcast://automations")!))
        XCTAssertTrue(state.showingAutomationsGuide)
    }

    @MainActor
    func testAutomationServiceExecutionLog() {
        let service = DashCastAutomationService.shared
        service.recordExecution(intentName: "TestIntent", summary: "Automated test execution")

        XCTAssertEqual(service.lastExecutedIntentName, "TestIntent")
        XCTAssertNotNil(service.lastExecutionTimestamp)
        XCTAssertFalse(service.executionLog.isEmpty)
        XCTAssertEqual(service.executionLog.first?.intentName, "TestIntent")
    }
}
