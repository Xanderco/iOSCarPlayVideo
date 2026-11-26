import XCTest
@testable import DashCast

final class MiniPlayerBarStateTests: XCTestCase {
    private func makeChannel(
        id: String = "ch-1",
        name: String = "Night Drive",
        groupTitle: String = "Demo Videos"
    ) -> ChannelModel {
        ChannelModel(
            id: id,
            name: name,
            streamURL: URL(string: "https://stub.dashcast.test/stream.m3u8")!,
            groupTitle: groupTitle,
            logoURL: URL(string: "https://stub.dashcast.test/logo.png")
        )
    }

    func testShouldShowOnlyWhenChannelLoadedAndOffCastTab() {
        let channel = makeChannel()

        for tab in AppState.TabItem.allCases {
            XCTAssertFalse(
                MiniPlayerBarState.shouldShow(currentChannel: nil, selectedTab: tab),
                "MiniPlayerBar should remain hidden when no channel is loaded on \(tab.rawValue)"
            )
        }

        XCTAssertFalse(MiniPlayerBarState.shouldShow(currentChannel: channel, selectedTab: .cast))
        XCTAssertTrue(MiniPlayerBarState.shouldShow(currentChannel: channel, selectedTab: .drive))
        XCTAssertTrue(MiniPlayerBarState.shouldShow(currentChannel: channel, selectedTab: .widgets))
        XCTAssertTrue(MiniPlayerBarState.shouldShow(currentChannel: channel, selectedTab: .sounds))
        XCTAssertTrue(MiniPlayerBarState.shouldShow(currentChannel: channel, selectedTab: .me))
    }

    func testMakeStateMapsLiveAndVODProgress() {
        let liveChannel = makeChannel(name: "News Live", groupTitle: "News")
        let liveState = MiniPlayerBarState.make(
            channel: liveChannel,
            isPlaying: true,
            isBuffering: false,
            currentTime: 12,
            duration: 0
        )

        XCTAssertEqual(liveState.title, "News Live")
        XCTAssertEqual(liveState.subtitle, "News")
        XCTAssertTrue(liveState.isPlaying)
        XCTAssertTrue(liveState.isLive)
        XCTAssertFalse(liveState.isBuffering)
        XCTAssertNil(liveState.progress)

        let vodChannel = makeChannel(name: "Track Lap", groupTitle: "   ")
        let vodState = MiniPlayerBarState.make(
            channel: vodChannel,
            isPlaying: false,
            isBuffering: true,
            currentTime: 30,
            duration: 120
        )

        XCTAssertEqual(vodState.title, "Track Lap")
        XCTAssertNil(vodState.subtitle)
        XCTAssertFalse(vodState.isPlaying)
        XCTAssertFalse(vodState.isLive)
        XCTAssertTrue(vodState.isBuffering)
        XCTAssertEqual(vodState.progress ?? -1, 0.25, accuracy: 0.0001)

        let clampedState = MiniPlayerBarState.make(
            channel: vodChannel,
            isPlaying: true,
            isBuffering: false,
            currentTime: 200,
            duration: 100
        )
        XCTAssertEqual(clampedState.progress, 1.0)
    }

    @MainActor
    func testVideoPlayerServiceAndAppStateMiniPlayerLifecycle() {
        let service = VideoPlayerService(handlesRemoteCommands: false)
        let appState = AppState(isProLifetimeUnlocked: false)
        appState.selectedTab = .drive

        XCTAssertFalse(
            MiniPlayerBarState.shouldShow(
                currentChannel: service.currentChannel,
                selectedTab: appState.selectedTab
            )
        )

        let channel = makeChannel()
        service.load(channel: channel)
        XCTAssertEqual(service.currentChannel?.id, channel.id)
        XCTAssertTrue(service.isPlaybackRequested)
        XCTAssertTrue(
            MiniPlayerBarState.shouldShow(
                currentChannel: service.currentChannel,
                selectedTab: appState.selectedTab
            )
        )

        service.togglePlayPause()
        XCTAssertFalse(service.isPlaybackRequested)

        service.togglePlayPause()
        XCTAssertTrue(service.isPlaybackRequested)

        // Expanding the mini-player returns to .cast and hides the mini-player bar
        appState.selectedTab = .cast
        XCTAssertFalse(
            MiniPlayerBarState.shouldShow(
                currentChannel: service.currentChannel,
                selectedTab: appState.selectedTab
            )
        )

        appState.selectedTab = .me
        XCTAssertTrue(
            MiniPlayerBarState.shouldShow(
                currentChannel: service.currentChannel,
                selectedTab: appState.selectedTab
            )
        )

        service.stop()
        XCTAssertNil(service.currentChannel)
        XCTAssertFalse(service.isPlaybackRequested)
        XCTAssertFalse(
            MiniPlayerBarState.shouldShow(
                currentChannel: service.currentChannel,
                selectedTab: appState.selectedTab
            )
        )
    }
}
