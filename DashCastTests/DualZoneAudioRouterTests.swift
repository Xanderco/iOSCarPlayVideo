import XCTest
import AVFoundation
@testable import DashCast

private final class MockAudioSessionAdapter: AudioSessionApplying {
    var snapshot: AudioRouteSnapshot
    var appliedPlans: [(plan: AudioSessionConfigurationPlan, activate: Bool)] = []
    var shouldThrowOnApply = false

    init(snapshot: AudioRouteSnapshot = .empty) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> AudioRouteSnapshot {
        snapshot
    }

    func apply(plan: AudioSessionConfigurationPlan, activate: Bool) throws {
        if shouldThrowOnApply {
            throw NSError(domain: NSOSStatusErrorDomain, code: -50)
        }
        appliedPlans.append((plan, activate))
    }
}

final class DualZoneAudioRouterTests: XCTestCase {

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "DualZoneAudioRouterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (defaults, suite)
    }

    private func makeEndpoint(id: String, name: String, port: AVAudioSession.Port) -> AudioOutputEndpoint {
        AudioOutputEndpoint(
            id: id,
            name: name,
            portTypeRaw: port.rawValue,
            kind: DualZoneAudioRouter.classify(portType: port)
        )
    }

    // MARK: - Port Classification & Snapshot Detection

    func testPortClassificationCoversHeadphonesCarPlayAirPlayAndSpeaker() {
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .bluetoothA2DP), .headphones)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .bluetoothLE), .headphones)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .bluetoothHFP), .headphones)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .headphones), .headphones)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .usbAudio), .headphones)

        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .carAudio), .carAudio)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .airPlay), .airPlay)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .builtInSpeaker), .speaker)
        XCTAssertEqual(DualZoneAudioRouter.classify(portType: .builtInReceiver), .speaker)
    }

    func testRouteSnapshotDetectsHeadphonesAndCarAudioSimultaneously() {
        let airpods = makeEndpoint(id: "bt-1", name: "Passenger AirPods Pro", port: .bluetoothA2DP)
        let carplay = makeEndpoint(id: "car-1", name: "CarPlay Head Unit", port: .carAudio)
        let snapshot = AudioRouteSnapshot(outputs: [carplay, airpods])

        XCTAssertTrue(snapshot.hasHeadphonesConnected)
        XCTAssertTrue(snapshot.hasCarAudioConnected)
        XCTAssertEqual(snapshot.headphoneOutputs, [airpods])
        XCTAssertEqual(snapshot.cabinOutputs, [carplay])
        XCTAssertEqual(snapshot.activePrimaryEndpoint, airpods)
    }

    // MARK: - Session Plan & Cabin Coexistence

    func testSessionPlanUsesMixWithOthersAndIndependentPolicyWhenDualZoneEnabled() {
        let airpods = makeEndpoint(id: "bt-1", name: "AirPods", port: .bluetoothA2DP)
        let snapshot = AudioRouteSnapshot(outputs: [airpods])

        let plan = DualZoneAudioRouter.buildSessionPlan(
            isDualZoneEnabled: true,
            mode: .autoDualZone,
            preserveCabinNavigation: true,
            duckCabinAudio: false,
            snapshot: snapshot
        )

        XCTAssertEqual(plan.category, .playback)
        XCTAssertEqual(plan.mode, .moviePlayback)
        XCTAssertTrue(plan.options.contains(.mixWithOthers))
        XCTAssertFalse(plan.options.contains(.allowBluetoothA2DP))
        XCTAssertFalse(plan.options.contains(.allowBluetoothHFP))
        XCTAssertFalse(plan.options.contains(.allowAirPlay))
        XCTAssertEqual(plan.routeSharingPolicy, .independent)
    }

    func testSessionPlanExclusiveCabinSharedOmitsMixWithOthersWhenCabinPreservationDisabled() {
        let carplay = makeEndpoint(id: "car-1", name: "CarPlay", port: .carAudio)
        let snapshot = AudioRouteSnapshot(outputs: [carplay])

        let plan = DualZoneAudioRouter.buildSessionPlan(
            isDualZoneEnabled: true,
            mode: .cabinShared,
            preserveCabinNavigation: false,
            duckCabinAudio: false,
            snapshot: snapshot
        )

        XCTAssertEqual(plan.category, .playback)
        XCTAssertFalse(plan.options.contains(.mixWithOthers))
        XCTAssertEqual(plan.routeSharingPolicy, .default)
    }

    func testSessionPlanWhenDualZoneDisabledMatchesStandardExclusivePlayback() {
        let airpods = makeEndpoint(id: "bt-1", name: "AirPods", port: .bluetoothA2DP)
        let snapshot = AudioRouteSnapshot(outputs: [airpods])

        let plan = DualZoneAudioRouter.buildSessionPlan(
            isDualZoneEnabled: false,
            mode: .autoDualZone,
            preserveCabinNavigation: true,
            duckCabinAudio: false,
            snapshot: snapshot
        )

        XCTAssertEqual(plan.category, .playback)
        XCTAssertEqual(plan.mode, .moviePlayback)
        XCTAssertTrue(plan.options.isEmpty)
        XCTAssertEqual(plan.routeSharingPolicy, .default)
    }

    // MARK: - Route Switching & Disconnect Fallback Logic

    @MainActor
    func testHeadphoneConnectActivatesPassengerZoneAndDisconnectMutesToProtectCabinNav() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let carplay = makeEndpoint(id: "car-1", name: "CarPlay", port: .carAudio)
        let airpods = makeEndpoint(id: "bt-1", name: "Passenger AirPods", port: .bluetoothA2DP)

        let adapter = MockAudioSessionAdapter(snapshot: AudioRouteSnapshot(outputs: [carplay]))
        let router = DualZoneAudioRouter(defaults: defaults, sessionAdapter: adapter, autoObserveNotifications: false)

        var receivedActions: [(AudioSessionRouteAction, Float)] = []
        router.onPlayerDirective = { action, volume in
            receivedActions.append((action, volume))
        }

        XCTAssertEqual(router.activeZone, .cabinCoexistence)
        XCTAssertFalse(router.isSafetyMuted)

        // Passenger connects Bluetooth headphones while CarPlay is connected
        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay, airpods])
        router.handleRouteChange(to: adapter.snapshot, reason: .newDeviceAvailable)

        XCTAssertEqual(router.activeZone, .passengerHeadphones)
        XCTAssertTrue(router.isHeadphoneZoneActive)
        XCTAssertFalse(router.isSafetyMuted)

        // Passenger headphones disconnect -> safety mute protects CarPlay navigation/radio
        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay])
        router.handleRouteChange(to: adapter.snapshot, reason: .oldDeviceUnavailable)

        XCTAssertEqual(router.activeZone, .mutedSafetyGuard)
        XCTAssertTrue(router.isSafetyMuted)
        XCTAssertEqual(router.effectivePlayerVolume, 0.0)
        XCTAssertNotNil(router.safetyMuteBannerMessage)
        if case .muteVideo = receivedActions.last?.0 {
            XCTAssertEqual(receivedActions.last?.1, 0.0)
        } else {
            XCTFail("Expected muteVideo action on headphone disconnect")
        }

        // Headphones reconnect -> auto-restores unmute & passenger volume
        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay, airpods])
        router.handleRouteChange(to: adapter.snapshot, reason: .newDeviceAvailable)

        XCTAssertEqual(router.activeZone, .passengerHeadphones)
        XCTAssertFalse(router.isSafetyMuted)
        XCTAssertNil(router.safetyMuteBannerMessage)
        XCTAssertEqual(receivedActions.last?.0, .restoreUnmute)
        XCTAssertEqual(receivedActions.last?.1, 1.0)
    }

    @MainActor
    func testDisconnectFallbackPausePlaybackAndFallbackToCabin() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let carplay = makeEndpoint(id: "car-1", name: "CarPlay", port: .carAudio)
        let wired = makeEndpoint(id: "hp-1", name: "USB-C Headset", port: .headphones)

        let adapter = MockAudioSessionAdapter(snapshot: AudioRouteSnapshot(outputs: [carplay, wired]))
        let router = DualZoneAudioRouter(defaults: defaults, sessionAdapter: adapter, autoObserveNotifications: false)

        var lastAction: AudioSessionRouteAction = .none
        router.onPlayerDirective = { action, _ in lastAction = action }

        // 1. Pause Playback fallback
        router.disconnectFallback = .pausePlayback
        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay])
        router.handleRouteChange(to: adapter.snapshot, reason: .oldDeviceUnavailable)

        if case .pauseVideo = lastAction {
            XCTAssertEqual(router.activeZone, .mutedSafetyGuard)
        } else {
            XCTFail("Expected pauseVideo action when disconnectFallback == .pausePlayback")
        }

        // Reconnect and test Fallback to Cabin
        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay, wired])
        router.handleRouteChange(to: adapter.snapshot, reason: .newDeviceAvailable)
        router.disconnectFallback = .fallbackToCabin

        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay])
        router.handleRouteChange(to: adapter.snapshot, reason: .oldDeviceUnavailable)

        XCTAssertEqual(router.activeZone, .cabinCoexistence)
        XCTAssertFalse(router.isSafetyMuted)
        XCTAssertEqual(lastAction, .restoreUnmute)
    }

    @MainActor
    func testOverrideSafetyMuteToCabinClearsMuteAndSwitchesOutOfLockedHeadphoneMode() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let carplay = makeEndpoint(id: "car-1", name: "CarPlay", port: .carAudio)
        let airpods = makeEndpoint(id: "bt-1", name: "AirPods", port: .bluetoothA2DP)
        let adapter = MockAudioSessionAdapter(snapshot: AudioRouteSnapshot(outputs: [carplay, airpods]))
        let router = DualZoneAudioRouter(defaults: defaults, sessionAdapter: adapter, autoObserveNotifications: false)
        router.routingMode = .passengerHeadphones

        adapter.snapshot = AudioRouteSnapshot(outputs: [carplay])
        router.handleRouteChange(to: adapter.snapshot, reason: .oldDeviceUnavailable)
        XCTAssertTrue(router.isSafetyMuted)

        router.overrideSafetyMuteToCabin()
        XCTAssertFalse(router.isSafetyMuted)
        XCTAssertNil(router.safetyMuteBannerMessage)
        XCTAssertEqual(router.routingMode, .autoDualZone)
        XCTAssertEqual(router.activeZone, .cabinCoexistence)
    }

    @MainActor
    func testPassengerVolumeTrimClampingAndPersistence() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let adapter = MockAudioSessionAdapter(snapshot: .empty)
        let router = DualZoneAudioRouter(defaults: defaults, sessionAdapter: adapter, autoObserveNotifications: false)

        router.passengerVolumeTrim = 1.8
        XCTAssertEqual(router.passengerVolumeTrim, 1.0, accuracy: 0.001)

        router.passengerVolumeTrim = -0.3
        XCTAssertEqual(router.passengerVolumeTrim, 0.0, accuracy: 0.001)

        router.passengerVolumeTrim = 0.65
        router.routingMode = .passengerHeadphones
        router.preserveCabinNavigation = false

        let reloaded = DualZoneAudioRouter(defaults: defaults, sessionAdapter: adapter, autoObserveNotifications: false)
        XCTAssertEqual(reloaded.passengerVolumeTrim, 0.65, accuracy: 0.001)
        XCTAssertEqual(reloaded.routingMode, .passengerHeadphones)
        XCTAssertFalse(reloaded.preserveCabinNavigation)
    }

    @MainActor
    func testSessionErrorIsCapturedGracefullyWithoutThrowing() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let adapter = MockAudioSessionAdapter(snapshot: .empty)
        adapter.shouldThrowOnApply = true
        let router = DualZoneAudioRouter(defaults: defaults, sessionAdapter: adapter, autoObserveNotifications: false)

        router.applyCurrentSessionPolicy(activate: true)
        XCTAssertNotNil(router.lastConfigurationError)
    }
}
