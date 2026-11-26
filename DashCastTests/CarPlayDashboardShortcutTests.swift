import XCTest
import CarPlay
@testable import DashCast

@MainActor
final class CarPlayDashboardShortcutTests: XCTestCase {
    private let channelA = ChannelModel(
        id: "ch-a",
        name: "Channel Alpha",
        streamURL: URL(string: "https://example.com/a.m3u8")!,
        groupTitle: "News"
    )
    private let channelB = ChannelModel(
        id: "ch-b",
        name: "Channel Beta",
        streamURL: URL(string: "https://example.com/b.m3u8")!,
        groupTitle: "Sports"
    )
    private let channelC = ChannelModel(
        id: "ch-c",
        name: "Channel Gamma",
        streamURL: URL(string: "https://example.com/c.m3u8")!,
        groupTitle: "Music"
    )

    func testEmptyPlaylistProducesFallbackShortcut() {
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: nil,
            isPlaying: false,
            favoriteChannels: [],
            allChannels: []
        )

        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].action, .none)
        XCTAssertEqual(specs[0].titleVariants.first, "DashCast")
        XCTAssertEqual(specs[0].systemImageName, "car.fill")
    }

    func testIdleWithChannelsPrioritizesFavoritesWithoutDuplicates() {
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: nil,
            isPlaying: false,
            favoriteChannels: [channelB],
            allChannels: [channelA, channelB, channelC]
        )

        XCTAssertEqual(specs.count, 2)
        XCTAssertEqual(specs[0].action, .playChannel(channelB))
        XCTAssertEqual(specs[0].systemImageName, "heart.circle.fill")
        XCTAssertEqual(specs[0].titleVariants.first, "Channel Beta")

        XCTAssertEqual(specs[1].action, .playChannel(channelA))
        XCTAssertEqual(specs[1].systemImageName, "play.tv.fill")
        XCTAssertEqual(specs[1].titleVariants.first, "Channel Alpha")
        XCTAssertEqual(specs[1].subtitleVariants.first, "News")
    }

    func testIdleWithSingleChannelProducesSingleQuickResumeShortcut() {
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: nil,
            isPlaying: false,
            favoriteChannels: [],
            allChannels: [channelA]
        )

        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].action, .playChannel(channelA))
        XCTAssertEqual(specs[0].titleVariants.first, "Channel Alpha")
    }

    func testPlayingStateProducesPauseAndQuickResumeChannel() {
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: channelA,
            isPlaying: true,
            favoriteChannels: [channelB],
            allChannels: [channelA, channelB, channelC]
        )

        XCTAssertEqual(specs.count, 2)
        XCTAssertEqual(specs[0].action, .togglePlayPause)
        XCTAssertEqual(specs[0].systemImageName, "pause.circle.fill")
        XCTAssertEqual(specs[0].subtitleVariants.first, "Channel Alpha")

        XCTAssertEqual(specs[1].action, .playChannel(channelB))
        XCTAssertEqual(specs[1].systemImageName, "heart.circle.fill")
        XCTAssertEqual(specs[1].titleVariants.first, "Channel Beta")
    }

    func testPausedStateProducesResumeAndQuickResumeChannel() {
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: channelA,
            isPlaying: false,
            favoriteChannels: [],
            allChannels: [channelA, channelC]
        )

        XCTAssertEqual(specs.count, 2)
        XCTAssertEqual(specs[0].action, .togglePlayPause)
        XCTAssertEqual(specs[0].systemImageName, "play.circle.fill")
        XCTAssertEqual(specs[0].subtitleVariants.first, "Channel Alpha")

        XCTAssertEqual(specs[1].action, .playChannel(channelC))
        XCTAssertEqual(specs[1].titleVariants.first, "Channel Gamma")
    }

    func testPlayingOnlyChannelProducesSingleToggleShortcut() {
        let specs = CarPlayDashboardShortcutProvider.buildShortcuts(
            currentChannel: channelA,
            isPlaying: true,
            favoriteChannels: [channelA],
            allChannels: [channelA]
        )

        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].action, .togglePlayPause)
    }

    func testMakeButtonsCapsAtTwoDashboardButtons() {
        let specs = [
            CarPlayDashboardShortcutSpec(
                titleVariants: ["One", "1"],
                subtitleVariants: ["Sub 1"],
                systemImageName: "play.circle.fill",
                action: .togglePlayPause
            ),
            CarPlayDashboardShortcutSpec(
                titleVariants: ["Two", "2"],
                subtitleVariants: ["Sub 2"],
                systemImageName: "play.tv.fill",
                action: .playChannel(channelB)
            ),
            CarPlayDashboardShortcutSpec(
                titleVariants: ["Three", "3"],
                subtitleVariants: ["Sub 3"],
                systemImageName: "car.fill",
                action: .none
            )
        ]

        let buttons = CarPlayDashboardShortcutProvider.makeButtons(from: specs) { _ in }
        XCTAssertEqual(buttons.count, 2)
        XCTAssertEqual(buttons[0].titleVariants, ["One", "1"])
        XCTAssertEqual(buttons[0].subtitleVariants, ["Sub 1"])
        XCTAssertEqual(buttons[1].titleVariants, ["Two", "2"])
    }

    func testPerformActionControlsVideoPlayerService() {
        let player = VideoPlayerService(handlesRemoteCommands: false)
        defer { player.stop() }

        CarPlayDashboardShortcutProvider.perform(.none, on: player)
        XCTAssertNil(player.currentChannel)
        XCTAssertFalse(player.isPlaybackRequested)

        CarPlayDashboardShortcutProvider.perform(.playChannel(channelA), on: player)
        XCTAssertEqual(player.currentChannel, channelA)
        XCTAssertTrue(player.isPlaybackRequested)

        CarPlayDashboardShortcutProvider.perform(.togglePlayPause, on: player)
        XCTAssertFalse(player.isPlaybackRequested)

        CarPlayDashboardShortcutProvider.perform(.togglePlayPause, on: player)
        XCTAssertTrue(player.isPlaybackRequested)
    }

    func testDashboardLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])

        let expectedKeys = [
            "Pause",
            "Play",
            "Resume",
            "Playing",
            "Paused",
            "Quick Play",
            "Quick Resume",
            "Quick Resume · Favorite",
            "Favorite",
            "Channel",
            "No channels yet"
        ]

        for key in expectedKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = (localizations["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = (localizations["es"]?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty EN value for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty ES value for \(key)")
        }
    }
}
