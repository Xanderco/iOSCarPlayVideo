import XCTest
import AVFoundation
@testable import DashCast

@MainActor
final class AudioSyncOffsetTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "AudioSyncOffsetTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    func testInitialStateAndDefaults() {
        let service = AudioSyncOffsetService(defaults: testDefaults)
        XCTAssertEqual(service.offsetMilliseconds, 0.0)
        XCTAssertEqual(service.offsetSeconds, 0.0)
        XCTAssertEqual(service.offsetMicroseconds, 0)
        XCTAssertFalse(service.isOffsetActive)
        XCTAssertEqual(service.formattedOffset, "0 ms")
        XCTAssertEqual(service.selectedPreset, .wired)
        XCTAssertTrue(service.autoRouteSyncEnabled)
    }

    func testPresetApplication() {
        let service = AudioSyncOffsetService(defaults: testDefaults)

        service.applyPreset(.carplayWireless)
        XCTAssertEqual(service.offsetMilliseconds, 180.0)
        XCTAssertEqual(service.offsetSeconds, 0.180, accuracy: 0.001)
        XCTAssertEqual(service.offsetMicroseconds, 180_000)
        XCTAssertTrue(service.isOffsetActive)
        XCTAssertEqual(service.formattedOffset, "+180 ms")
        XCTAssertEqual(service.selectedPreset, .carplayWireless)

        service.applyPreset(.bluetoothInDash)
        XCTAssertEqual(service.offsetMilliseconds, 350.0)
        XCTAssertEqual(service.offsetSeconds, 0.350, accuracy: 0.001)
        XCTAssertEqual(service.offsetMicroseconds, 350_000)
        XCTAssertTrue(service.isOffsetActive)
        XCTAssertEqual(service.formattedOffset, "+350 ms")
        XCTAssertEqual(service.selectedPreset, .bluetoothInDash)

        service.applyPreset(.wired)
        XCTAssertEqual(service.offsetMilliseconds, 0.0)
        XCTAssertFalse(service.isOffsetActive)
        XCTAssertEqual(service.formattedOffset, "0 ms")
        XCTAssertEqual(service.selectedPreset, .wired)
    }

    func testClampingBounds() {
        let service = AudioSyncOffsetService(defaults: testDefaults)

        service.setOffset(2000.0)
        XCTAssertEqual(service.offsetMilliseconds, AudioSyncOffsetService.maxOffsetMs)
        XCTAssertEqual(service.offsetMilliseconds, 1500.0)

        service.setOffset(-3000.0)
        XCTAssertEqual(service.offsetMilliseconds, AudioSyncOffsetService.minOffsetMs)
        XCTAssertEqual(service.offsetMilliseconds, -1500.0)

        service.setOffset(1490.0)
        service.adjustOffset(by: 50.0)
        XCTAssertEqual(service.offsetMilliseconds, 1500.0)

        service.setOffset(-1490.0)
        service.adjustOffset(by: -50.0)
        XCTAssertEqual(service.offsetMilliseconds, -1500.0)
    }

    func testAdjustOffsetAndPresetAutoTransition() {
        let service = AudioSyncOffsetService(defaults: testDefaults)

        service.applyPreset(.wired)
        XCTAssertEqual(service.selectedPreset, .wired)

        service.adjustOffset(by: 25.0)
        XCTAssertEqual(service.offsetMilliseconds, 25.0)
        XCTAssertEqual(service.formattedOffset, "+25 ms")
        XCTAssertEqual(service.selectedPreset, .custom)

        service.adjustOffset(by: -50.0)
        XCTAssertEqual(service.offsetMilliseconds, -25.0)
        XCTAssertEqual(service.formattedOffset, "-25 ms")
        XCTAssertEqual(service.selectedPreset, .custom)

        service.setOffset(180.0)
        XCTAssertEqual(service.selectedPreset, .carplayWireless)
    }

    func testReset() {
        let service = AudioSyncOffsetService(defaults: testDefaults)
        service.setOffset(450.0)
        XCTAssertTrue(service.isOffsetActive)

        service.reset()
        XCTAssertEqual(service.offsetMilliseconds, 0.0)
        XCTAssertFalse(service.isOffsetActive)
        XCTAssertEqual(service.selectedPreset, .wired)
    }

    func testRouteDetection() {
        let service = AudioSyncOffsetService(defaults: testDefaults)
        service.detectCurrentAudioRoute()
        XCTAssertFalse(service.detectedRouteName.isEmpty)
        XCTAssertNotNil(service.recommendedPreset)
    }

    func testPersistenceRoundtrip() {
        let service1 = AudioSyncOffsetService(defaults: testDefaults)
        service1.setOffset(425.0)
        service1.autoRouteSyncEnabled = false

        let service2 = AudioSyncOffsetService(defaults: testDefaults)
        XCTAssertEqual(service2.offsetMilliseconds, 425.0)
        XCTAssertEqual(service2.selectedPreset, .custom)
        XCTAssertFalse(service2.autoRouteSyncEnabled)
    }

    func testPlayerItemConfiguration() {
        let service = AudioSyncOffsetService(defaults: testDefaults)
        let item = AVPlayerItem(url: URL(string: "https://example.com/test.m3u8")!)
        service.apply(to: item)
        XCTAssertEqual(item.audioTimePitchAlgorithm, .timeDomain)
    }

    func testPresetProperties() {
        for preset in AudioSyncPreset.allCases {
            XCTAssertFalse(preset.id.isEmpty)
            XCTAssertFalse(preset.title.isEmpty)
            XCTAssertFalse(preset.iconName.isEmpty)
            XCTAssertFalse(preset.subtitle.isEmpty)
            XCTAssertTrue(preset.defaultOffsetMs >= 0)
        }
    }
}
