import XCTest
import AVFoundation
@testable import DashCast

final class StreamReconnectAndPlayerLockTests: XCTestCase {

    // MARK: - Policy & Backoff

    func testExponentialBackoffSchedule() {
        let policy = StreamReconnectPolicy(
            maxAttempts: 4,
            baseDelaySeconds: 1.0,
            maxDelaySeconds: 5.0,
            stallGraceSeconds: 2.0
        )

        XCTAssertEqual(policy.delay(forAttempt: 1), 1.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4.0, accuracy: 0.001)
        XCTAssertEqual(policy.delay(forAttempt: 4), 5.0, accuracy: 0.001)
    }

    func testShouldAutoReconnectSkipsLocalFilesAndMirrorChannel() {
        let policy = StreamReconnectPolicy.default
        let localChannel = ChannelModel(
            name: "Local Clip",
            streamURL: URL(fileURLWithPath: "/tmp/clip.mp4")
        )
        let mirrorChannel = ChannelModel(
            id: CarPlayMirrorPlayback.channelID,
            name: "Car Mirror",
            streamURL: URL(string: "http://127.0.0.1:8080/mirror.m3u8")!
        )
        let remoteChannel = ChannelModel(
            name: "Live News",
            streamURL: URL(string: "https://example.com/live.m3u8")!
        )

        XCTAssertFalse(policy.shouldAutoReconnect(for: nil, attempt: 0, isNetworkAvailable: true))
        XCTAssertFalse(policy.shouldAutoReconnect(for: localChannel, attempt: 0, isNetworkAvailable: true))
        XCTAssertFalse(policy.shouldAutoReconnect(for: mirrorChannel, attempt: 0, isNetworkAvailable: true))
        XCTAssertFalse(policy.shouldAutoReconnect(for: remoteChannel, attempt: 0, isNetworkAvailable: false))
        XCTAssertFalse(policy.shouldAutoReconnect(for: remoteChannel, attempt: 3, isNetworkAvailable: true))
        XCTAssertTrue(policy.shouldAutoReconnect(for: remoteChannel, attempt: 0, isNetworkAvailable: true))
        XCTAssertTrue(policy.shouldAutoReconnect(for: remoteChannel, attempt: 2, isNetworkAvailable: true))
    }

    func testTransientNetworkErrorClassification() {
        XCTAssertTrue(StreamReconnectPolicy.isTransientNetworkError(URLError(.timedOut)))
        XCTAssertTrue(StreamReconnectPolicy.isTransientNetworkError(URLError(.networkConnectionLost)))
        XCTAssertTrue(StreamReconnectPolicy.isTransientNetworkError(URLError(.notConnectedToInternet)))
        XCTAssertFalse(StreamReconnectPolicy.isTransientNetworkError(URLError(.badURL)))
        XCTAssertFalse(StreamReconnectPolicy.isTransientNetworkError(URLError(.unsupportedURL)))
        XCTAssertFalse(StreamReconnectPolicy.isTransientNetworkError(URLError(.cancelled)))
    }

    // MARK: - Service Lifecycle, Keep-Awake & Controls Lock

    @MainActor
    func testControlsLockAndAspectModeToggleAndResetOnStop() {
        let idleController = MockIdleTimerController()
        let service = VideoPlayerService(
            handlesRemoteCommands: false,
            idleTimerController: idleController
        )

        XCTAssertFalse(service.isControlsLocked)
        XCTAssertEqual(service.videoAspectMode, .fit)

        service.toggleControlsLock()
        XCTAssertTrue(service.isControlsLocked)

        service.toggleVideoAspectMode()
        XCTAssertEqual(service.videoAspectMode, .fill)
        XCTAssertEqual(service.videoAspectMode.avLayerGravity, .resizeAspectFill)

        service.stop()
        XCTAssertFalse(service.isControlsLocked, "stop() should reset passenger controls lock")
        XCTAssertEqual(service.streamHealth, .idle)
        XCTAssertFalse(idleController.isIdleTimerDisabled)
    }

    @MainActor
    func testReconnectSchedulesOnTransientDropAndReleasesIdleTimerOnPauseAndStop() async throws {
        let idleController = MockIdleTimerController()
        let monitor = MockNetworkPathMonitor(isConnected: true)
        let policy = StreamReconnectPolicy(
            maxAttempts: 2,
            baseDelaySeconds: 0.1,
            maxDelaySeconds: 0.4,
            stallGraceSeconds: 0.05
        )
        let service = VideoPlayerService(
            handlesRemoteCommands: false,
            reconnectPolicy: policy,
            idleTimerController: idleController,
            networkMonitor: monitor
        )
        let remote = ChannelModel(
            name: "Highway Radio TV",
            streamURL: URL(string: "https://example.com/stream.m3u8")!
        )

        service.load(channel: remote)
        service.simulatePlaybackFailureForTesting(URLError(.networkConnectionLost))

        XCTAssertEqual(service.reconnectAttempt, 1)
        XCTAssertEqual(service.streamHealth, .reconnecting(attempt: 1, maxAttempts: 2))
        XCTAssertNil(service.playbackError)
        XCTAssertTrue(idleController.isIdleTimerDisabled, "Screen must stay awake while reconnecting")

        service.pause()
        XCTAssertFalse(service.streamHealth.isReconnecting)
        XCTAssertFalse(idleController.isIdleTimerDisabled, "pause() must release screen keep-awake")

        // Exhaust retries cleanly
        service.load(channel: remote)
        service.simulatePlaybackFailureForTesting(URLError(.timedOut))
        XCTAssertEqual(service.reconnectAttempt, 1)
        service.simulatePlaybackFailureForTesting(URLError(.timedOut))
        XCTAssertEqual(service.reconnectAttempt, 2)
        service.simulatePlaybackFailureForTesting(URLError(.timedOut))

        XCTAssertEqual(service.streamHealth, .failed("Network error: The request timed out."))
        XCTAssertNotNil(service.playbackError)
        XCTAssertFalse(idleController.isIdleTimerDisabled)

        service.stop()
        XCTAssertEqual(service.reconnectAttempt, 0)
        XCTAssertEqual(service.streamHealth, .idle)
        XCTAssertFalse(idleController.isIdleTimerDisabled)
    }

    @MainActor
    func testNetworkRestorationTriggersImmediateReconnectAfterNetworkFailure() async throws {
        let idleController = MockIdleTimerController()
        let monitor = MockNetworkPathMonitor(isConnected: false)
        let service = VideoPlayerService(
            handlesRemoteCommands: false,
            reconnectPolicy: StreamReconnectPolicy(maxAttempts: 3, baseDelaySeconds: 1.0, maxDelaySeconds: 4.0, stallGraceSeconds: 1.0),
            idleTimerController: idleController,
            networkMonitor: monitor
        )
        let remote = ChannelModel(
            name: "Road Trip Stream",
            streamURL: URL(string: "https://example.com/road.m3u8")!
        )

        service.load(channel: remote)
        XCTAssertFalse(service.isNetworkAvailable)

        service.simulatePlaybackFailureForTesting(URLError(.notConnectedToInternet))
        XCTAssertTrue(service.streamHealth.isFailed)
        XCTAssertNotNil(service.playbackError)

        // Simulate LTE/Wi-Fi coming back online
        monitor.setConnected(true)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(service.isNetworkAvailable)
        XCTAssertNil(service.playbackError, "Network recovery should clear the error and reload the stream")
        XCTAssertTrue(service.isPlaybackRequested)

        service.stop()
    }

    @MainActor
    func testBackgroundReleasesIdleTimerWhileReconnecting() {
        let idleController = MockIdleTimerController()
        let monitor = MockNetworkPathMonitor(isConnected: true)
        let service = VideoPlayerService(
            handlesRemoteCommands: false,
            reconnectPolicy: StreamReconnectPolicy(maxAttempts: 2, baseDelaySeconds: 5.0, maxDelaySeconds: 5.0, stallGraceSeconds: 5.0),
            idleTimerController: idleController,
            networkMonitor: monitor
        )
        let remote = ChannelModel(
            name: "Live Stream",
            streamURL: URL(string: "https://example.com/live.m3u8")!
        )

        service.load(channel: remote)
        service.simulatePlaybackFailureForTesting(URLError(.networkConnectionLost))
        XCTAssertTrue(idleController.isIdleTimerDisabled)

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(service.isVideoLayerAttached)
        XCTAssertFalse(idleController.isIdleTimerDisabled, "Backgrounding must release idle timer")

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertTrue(service.isVideoLayerAttached)
        XCTAssertTrue(idleController.isIdleTimerDisabled)

        service.stop()
    }
}

// MARK: - Mocks

@MainActor
private final class MockIdleTimerController: IdleTimerControlling {
    var isIdleTimerDisabled: Bool = false
}

private final class MockNetworkPathMonitor: NetworkPathMonitoring {
    private(set) var isConnected: Bool
    var onStatusChange: (@Sendable (Bool) -> Void)?

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }

    func start() {}
    func stop() {}

    func setConnected(_ connected: Bool) {
        guard isConnected != connected else { return }
        isConnected = connected
        onStatusChange?(connected)
    }
}
