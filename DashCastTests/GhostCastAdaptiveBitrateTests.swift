import XCTest
@testable import DashCast

final class GhostCastAdaptiveBitrateTests: XCTestCase {

    func testInitialGhostCastProfileIs1080p60() {
        let controller = GhostCastAdaptiveBitrateController()
        XCTAssertEqual(controller.activeProfile, .high1080p60)
        XCTAssertEqual(controller.activeProfile.resolution.width, 1920)
        XCTAssertEqual(controller.activeProfile.resolution.height, 1080)
        XCTAssertEqual(controller.activeProfile.framesPerSecond, 60)
        XCTAssertEqual(controller.activeProfile.bitRate, 6_000_000)
        XCTAssertFalse(controller.isCongestionDetected)
    }

    /// Requirement 2: Dynamically downscale H.264 encode profile from 1080p@60fps (6 Mbps)
    /// to 720p@30fps (2.5 Mbps) when write queue depth exceeds 3 frames.
    func testDownscaleOnQueueDepthExceedingThreeFrames() {
        let controller = GhostCastAdaptiveBitrateController()
        var reportedProfile: GhostCastProfile?
        controller.onProfileChanged = { profile in
            reportedProfile = profile
        }

        // Write queue depth <= 3 should not trigger downgrade under low RTT
        controller.recordSample(queueDepth: 3, rtt: 0.020)
        XCTAssertEqual(controller.activeProfile, .high1080p60)
        XCTAssertNil(reportedProfile)

        // Queue depth > 3 (4 frames) triggers immediate downscale to 720p@30fps (2.5 Mbps)
        let newProfile = controller.recordSample(queueDepth: 4, rtt: 0.025)
        XCTAssertEqual(newProfile, .medium720p30)
        XCTAssertEqual(controller.activeProfile, .medium720p30)
        XCTAssertEqual(reportedProfile, .medium720p30)
        XCTAssertTrue(controller.isCongestionDetected)
        XCTAssertEqual(controller.activeProfile.resolution.width, 1280)
        XCTAssertEqual(controller.activeProfile.resolution.height, 720)
        XCTAssertEqual(controller.activeProfile.framesPerSecond, 30)
        XCTAssertEqual(controller.activeProfile.bitRate, 2_500_000)
        XCTAssertEqual(controller.totalAdaptationEvents, 1)
    }

    /// Requirement 1 & 3: Network jitter / high RTT triggers downscale even if queue depth is low.
    func testDownscaleOnNetworkJitterAndHighRTT() {
        let controller = GhostCastAdaptiveBitrateController()

        // Latency exceeds 150 ms threshold (simulated Wi-Fi jitter over wireless CarPlay)
        let profile = controller.recordSample(queueDepth: 1, rtt: 0.175)
        XCTAssertEqual(profile, .medium720p30)
        XCTAssertEqual(controller.activeProfile, .medium720p30)
        XCTAssertTrue(controller.isCongestionDetected)
        XCTAssertEqual(controller.currentRTT, 0.175)
    }

    func testSevereCongestionDownscalesToLowProfile() {
        let controller = GhostCastAdaptiveBitrateController()

        // Critical packet backlog (queue depth >= 6)
        controller.recordSample(queueDepth: 7, rtt: 0.250)
        XCTAssertEqual(controller.activeProfile, .low540p24)
        XCTAssertEqual(controller.activeProfile.resolution.width, 960)
        XCTAssertEqual(controller.activeProfile.resolution.height, 540)
        XCTAssertEqual(controller.activeProfile.framesPerSecond, 24)
        XCTAssertEqual(controller.activeProfile.bitRate, 1_200_000)
    }

    func testStabilizationWindowRequiredForUpgrade() {
        let controller = GhostCastAdaptiveBitrateController(initialProfile: .medium720p30)
        XCTAssertEqual(controller.activeProfile, .medium720p30)

        // First healthy sample: queue depth <= 1 and RTT <= 50 ms
        controller.recordSample(queueDepth: 1, rtt: 0.030)
        XCTAssertEqual(controller.activeProfile, .medium720p30, "Must not upgrade on single sample")

        // Second healthy sample
        controller.recordSample(queueDepth: 0, rtt: 0.025)
        XCTAssertEqual(controller.activeProfile, .medium720p30, "Must not upgrade before full window")

        // Third consecutive healthy sample: triggers upgrade back to 1080p@60fps
        let upgraded = controller.recordSample(queueDepth: 1, rtt: 0.020)
        XCTAssertEqual(upgraded, .high1080p60)
        XCTAssertEqual(controller.activeProfile, .high1080p60)
    }

    /// Requirement 1: Monitor frame delivery round-trip time in CarPlayVideoServer.
    func testCarPlayVideoServerRTTAndQueueDepthMonitoring() {
        let controller = GhostCastAdaptiveBitrateController()
        let server = CarPlayVideoServer(port: 9099, controller: controller)

        server.registerMockClient()
        XCTAssertEqual(server.connectedClientCount, 1)

        // Simulate frame delivery metrics: latency 45 ms, queue depth 4
        server.simulateDelivery(queueDepth: 4, latency: 0.045)
        XCTAssertEqual(server.currentQueueDepth, 4)
        XCTAssertEqual(server.lastMeasuredRTT, 0.045)
        XCTAssertGreaterThan(server.averageRTT, 0)

        // Server automatically adapted profile to 720p@30fps
        XCTAssertEqual(server.activeProfile, .medium720p30)
    }

    @MainActor
    func testVideoPlayerServiceDynamicBufferTuning() {
        let service = VideoPlayerService()
        XCTAssertEqual(service.activeGhostCastProfile, .high1080p60)
        XCTAssertFalse(service.isGhostCastCongested)

        // Simulate network jitter and queue depth spike reported to VideoPlayerService
        service.updateGhostCastMetrics(queueDepth: 5, rtt: 0.165)

        XCTAssertEqual(service.activeGhostCastProfile, .medium720p30)
        XCTAssertTrue(service.isGhostCastCongested)
        XCTAssertEqual(service.ghostCastQueueDepth, 5)
        XCTAssertEqual(service.ghostCastRTT, 0.165)
    }

    func testMirrorEncoderConfigGhostCastProfiles() {
        let config1080 = MirrorEncoderConfig.ghostCast1080p60
        XCTAssertEqual(config1080.maxLongSide, 1920)
        XCTAssertEqual(config1080.maxShortSide, 1080)
        XCTAssertEqual(config1080.framesPerSecond, 60)
        XCTAssertEqual(config1080.averageBitRate, 6_000_000)

        let config720 = MirrorEncoderConfig.ghostCast720p30
        XCTAssertEqual(config720.maxLongSide, 1280)
        XCTAssertEqual(config720.maxShortSide, 720)
        XCTAssertEqual(config720.framesPerSecond, 30)
        XCTAssertEqual(config720.averageBitRate, 2_500_000)

        let server = CarPlayVideoServer(port: 9098)
        var callbackConfig: MirrorEncoderConfig?
        server.onProfileChange = { profile in
            callbackConfig = profile.encoderConfig
        }
        server.simulateDelivery(queueDepth: 4, latency: 0.020)
        XCTAssertEqual(callbackConfig, config720)
        XCTAssertEqual(callbackConfig?.averageBitRate, 2_500_000)
        XCTAssertEqual(GhostCastProfile.high1080p60.encoderConfig, config1080)
    }
}
