import XCTest
@testable import DashCast

/// DI-76: Up-Next channel navigation and the parked-session sleep timer.
final class UpNextSleepTimerTests: XCTestCase {
    private func channel(_ n: Int) -> ChannelModel {
        ChannelModel(id: "ch\(n)", name: "Channel \(n)",
                     streamURL: URL(string: "https://example.com/\(n).m3u8")!)
    }

    private var three: [ChannelModel] { [channel(1), channel(2), channel(3)] }

    // MARK: - Queue navigation

    func testNextAdvancesAndWrapsAtEnd() {
        let list = three
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: list[0], in: list, offset: 1)?.id, "ch2")
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: list[2], in: list, offset: 1)?.id, "ch1")
    }

    func testPreviousGoesBackAndWrapsAtStart() {
        let list = three
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: list[1], in: list, offset: -1)?.id, "ch1")
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: list[0], in: list, offset: -1)?.id, "ch3")
    }

    func testAdjacentChannelBounds() {
        XCTAssertNil(VideoPlayerService.adjacentChannel(from: channel(1), in: [], offset: 1),
                     "An empty queue has no next channel")
        XCTAssertNil(VideoPlayerService.adjacentChannel(from: channel(1), in: [channel(1)], offset: 1),
                     "A single-channel queue must not reload the same channel")
        XCTAssertNil(VideoPlayerService.adjacentChannel(from: channel(1), in: three, offset: 0))
    }

    func testUnknownCurrentStartsAtFirstOrLast() {
        let outsider = channel(99)
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: outsider, in: three, offset: 1)?.id, "ch1")
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: outsider, in: three, offset: -1)?.id, "ch3")
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: nil, in: three, offset: 1)?.id, "ch1")
    }

    func testMatchingFallsBackToStreamURL() {
        let list = three
        let sameStreamDifferentID = ChannelModel(id: "other", name: "Dup", streamURL: list[1].streamURL)
        XCTAssertEqual(VideoPlayerService.adjacentChannel(from: sameStreamDifferentID, in: list, offset: 1)?.id, "ch3")
    }

    func testNavigationQueuePicksListContainingCurrent() {
        let playlist = three
        let locals = [channel(10), channel(11)]
        XCTAssertEqual(VideoPlayerService.navigationQueue(for: channel(11), candidates: [playlist, locals]).map(\.id),
                       ["ch10", "ch11"])
        XCTAssertEqual(VideoPlayerService.navigationQueue(for: channel(2), candidates: [playlist, locals]).count, 3)
        XCTAssertTrue(VideoPlayerService.navigationQueue(for: channel(50), candidates: [playlist, locals]).isEmpty,
                      "A channel outside every list (mirror, server item) hides the buttons")
        XCTAssertTrue(VideoPlayerService.navigationQueue(for: nil, candidates: [playlist]).isEmpty)
    }

    @MainActor
    func testPlayNextLoadsAdjacentChannel() {
        let service = VideoPlayerService()
        let list = three
        service.load(channel: list[2])
        let next = service.playNext(in: list)
        XCTAssertEqual(next?.id, "ch1")
        XCTAssertEqual(service.currentChannel?.id, "ch1")
        XCTAssertEqual(service.playPrevious(in: list)?.id, "ch3")
        XCTAssertEqual(service.currentChannel?.id, "ch3")
        XCTAssertNil(service.playNext(in: []))
        XCTAssertEqual(service.currentChannel?.id, "ch3", "An empty queue leaves the current channel alone")
        service.stop()
    }

    // MARK: - Sleep timer

    func testPresetDurations() {
        XCTAssertNil(SleepTimerPreset.off.duration)
        XCTAssertEqual(SleepTimerPreset.fifteen.duration, 900)
        XCTAssertEqual(SleepTimerPreset.thirty.duration, 1800)
        XCTAssertEqual(SleepTimerPreset.sixty.duration, 3600)
        XCTAssertEqual(SleepTimerPreset.allCases.map(\.labelKey), ["Off", "15 min", "30 min", "60 min"])
    }

    func testRemainingNeverNegative() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(VideoPlayerService.sleepTimerRemaining(deadline: start.addingTimeInterval(60), now: start), 60)
        XCTAssertEqual(VideoPlayerService.sleepTimerRemaining(deadline: start, now: start.addingTimeInterval(5)), 0)
    }

    @MainActor
    func testSleepTimerCountsDownFromWallClock() {
        let service = VideoPlayerService()
        let start = Date()
        service.setSleepTimer(.fifteen, now: start)
        XCTAssertEqual(service.sleepTimerPreset, .fifteen)
        XCTAssertEqual(service.sleepTimerRemaining, 900)

        service.tickSleepTimer(now: start.addingTimeInterval(300))
        XCTAssertEqual(service.sleepTimerRemaining ?? -1, 600, accuracy: 0.001)
        XCTAssertEqual(service.sleepTimerPreset, .fifteen)
        service.cancelSleepTimer()
    }

    @MainActor
    func testSleepTimerExpiryPausesAndClears() {
        let service = VideoPlayerService()
        service.load(channel: channel(1))
        let start = Date()
        service.setSleepTimer(.thirty, now: start)

        // Simulates returning from a locked screen long after the deadline.
        service.tickSleepTimer(now: start.addingTimeInterval(1801))

        XCTAssertFalse(service.isPlaybackRequested, "Expiry must pause playback")
        XCTAssertNil(service.sleepTimerRemaining)
        XCTAssertNil(service.sleepTimerDeadline)
        XCTAssertNil(service.sleepTimerTicker, "Expiry must invalidate the ticker")
        XCTAssertEqual(service.sleepTimerPreset, .off)
        service.stop()
    }

    @MainActor
    func testOffPresetAndStopCancelTimer() {
        let service = VideoPlayerService()
        service.setSleepTimer(.sixty)
        XCTAssertNotNil(service.sleepTimerTicker)
        service.setSleepTimer(.off)
        XCTAssertNil(service.sleepTimerRemaining)
        XCTAssertNil(service.sleepTimerTicker)

        service.setSleepTimer(.fifteen)
        service.stop()
        XCTAssertNil(service.sleepTimerRemaining, "Closing the player clears the sleep timer")
        XCTAssertEqual(service.sleepTimerPreset, .off)
    }

    @MainActor
    func testReselectingPresetRestartsTimer() {
        let service = VideoPlayerService()
        let start = Date()
        service.setSleepTimer(.fifteen, now: start)
        service.setSleepTimer(.sixty, now: start.addingTimeInterval(100))
        XCTAssertEqual(service.sleepTimerPreset, .sixty)
        XCTAssertEqual(service.sleepTimerRemaining, 3600)
        service.tickSleepTimer(now: start.addingTimeInterval(1000))
        XCTAssertEqual(service.sleepTimerRemaining ?? -1, 2700, accuracy: 0.001)
        service.cancelSleepTimer()
    }
}
