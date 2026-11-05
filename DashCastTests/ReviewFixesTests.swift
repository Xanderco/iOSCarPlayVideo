import XCTest
@testable import DashCast

/// Regression tests for the independent review of 2026-11-05 (Docs/Review-2026-11-05.md).
final class ReviewFixesTests: XCTestCase {

    // MARK: Info.plist (unit tests are hosted in the app, so Bundle.main is DashCast.app)

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    private func nonEmptyString(_ key: String) -> Bool {
        !((info[key] as? String) ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    func testUsageDescriptionsExistForUsedAPIs() {
        // Camera (QR import), location (Drive), local network (Jellyfin/Emby on the LAN).
        for key in ["NSCameraUsageDescription",
                    "NSLocationWhenInUseUsageDescription",
                    "NSLocationAlwaysAndWhenInUseUsageDescription",
                    "NSLocalNetworkUsageDescription"] {
            XCTAssertTrue(nonEmptyString(key), "\(key) missing or empty in Info.plist")
        }
    }

    func testATSAllowsHTTPMediaAndLocalServersOnly() throws {
        let ats = try XCTUnwrap(info["NSAppTransportSecurity"] as? [String: Any],
                                "http IPTV streams and LAN media servers are blocked by ATS without exceptions")
        XCTAssertEqual(ats["NSAllowsArbitraryLoadsForMedia"] as? Bool, true)
        XCTAssertEqual(ats["NSAllowsLocalNetworking"] as? Bool, true)
        // Keep the exception narrow; a blanket opt-out needs an owner decision + review justification.
        XCTAssertNil(ats["NSAllowsArbitraryLoads"])
    }

    func testDeclaredSceneDelegatesExist() throws {
        let manifest = try XCTUnwrap(info["UIApplicationSceneManifest"] as? [String: Any])
        let configs = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: [[String: Any]]])
        XCTAssertFalse(configs.isEmpty)
        for (role, entries) in configs {
            for entry in entries {
                let name = try XCTUnwrap(entry["UISceneDelegateClassName"] as? String, role)
                XCTAssertNotNil(NSClassFromString(name), "Scene delegate \(name) for \(role) does not exist")
            }
        }
    }

    func testBackgroundAudioModeDeclared() {
        let modes = info["UIBackgroundModes"] as? [String] ?? []
        XCTAssertTrue(modes.contains("audio"))
    }

    // MARK: VideoPlayerService observer cleanup

    @MainActor
    func testStopRemovesAllItemObservers() {
        let service = VideoPlayerService()
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("review-\(UUID().uuidString).mp4")
        service.load(channel: ChannelModel(name: "Item", streamURL: file))
        XCTAssertGreaterThan(service.activeItemObserverCount, 0)

        service.stop()
        XCTAssertEqual(service.activeItemObserverCount, 0,
                       "stop() must also remove the NotificationCenter observers of the released item")
        XCTAssertNil(service.currentChannel)
        XCTAssertNil(service.player.currentItem)
    }
}
