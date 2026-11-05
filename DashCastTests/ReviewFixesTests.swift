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

    /// Most IPTV playlists/streams (e.g. iptv-org) and home Jellyfin/Emby servers are plain http.
    /// Reads the bundled Info.plist file as well as the processed dictionary.
    func testATSAllowsUserSuppliedHTTPSources() throws {
        let plistURL = try XCTUnwrap(Bundle.main.url(forResource: "Info", withExtension: "plist"))
        let raw = try XCTUnwrap(NSDictionary(contentsOf: plistURL) as? [String: Any])
        for dict in [raw, info] {
            let ats = try XCTUnwrap(dict["NSAppTransportSecurity"] as? [String: Any],
                                    "Without ATS exceptions http playlists and streams fail with -1022")
            XCTAssertEqual(ats["NSAllowsArbitraryLoads"] as? Bool, true)
            // On iOS 10+ any of these keys makes the system ignore NSAllowsArbitraryLoads.
            for overriding in ["NSAllowsArbitraryLoadsForMedia",
                               "NSAllowsArbitraryLoadsInWebContent",
                               "NSAllowsLocalNetworking"] {
                XCTAssertNil(ats[overriding], "\(overriding) would disable NSAllowsArbitraryLoads")
            }
        }
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

    // MARK: Remote commands are owned by exactly one player

    @MainActor
    func testOnlySharedPlayerRegistersRemoteCommands() {
        XCTAssertEqual(VideoPlayerService.shared.remoteCommandTargetCount, 3)
        XCTAssertEqual(VideoPlayerService().remoteCommandTargetCount, 0,
                       "Extra instances must not add duplicate MPRemoteCommandCenter targets")
    }
}
