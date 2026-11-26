import XCTest
@testable import DashCast

final class CarVideoOutputTests: XCTestCase {

    // MARK: Parked-only evaluator

    func testUnknownUntilFirstSample() {
        let evaluator = ParkedStateEvaluator()
        XCTAssertEqual(evaluator.state, .unknown)
        XCTAssertFalse(evaluator.blocksVideo)
    }

    func testSlowSpeedIsParkedImmediatelyFromUnknown() {
        var evaluator = ParkedStateEvaluator()
        XCTAssertEqual(evaluator.update(speedKmh: 0.5, automotiveMoving: nil, at: Date()), .parked)
    }

    func testFastSpeedIsMovingAndBlocksVideo() {
        var evaluator = ParkedStateEvaluator()
        XCTAssertEqual(evaluator.update(speedKmh: 30, automotiveMoving: nil, at: Date()), .moving)
        XCTAssertTrue(evaluator.blocksVideo)
    }

    func testAutomotiveActivityWithoutGPSIsMoving() {
        var evaluator = ParkedStateEvaluator()
        XCTAssertEqual(evaluator.update(speedKmh: nil, automotiveMoving: true, at: Date()), .moving)
    }

    func testGPSStandstillOverridesAutomotiveActivity() {
        var evaluator = ParkedStateEvaluator()
        XCTAssertEqual(evaluator.update(speedKmh: 0, automotiveMoving: true, at: Date()), .parked)
    }

    func testHysteresisAfterMoving() {
        var evaluator = ParkedStateEvaluator(parkedHoldSeconds: 10)
        let t0 = Date()
        evaluator.update(speedKmh: 40, automotiveMoving: nil, at: t0)
        // Brief stop (red light) keeps video blocked.
        XCTAssertEqual(evaluator.update(speedKmh: 0, automotiveMoving: nil, at: t0.addingTimeInterval(1)), .moving)
        XCTAssertEqual(evaluator.update(speedKmh: 0, automotiveMoving: nil, at: t0.addingTimeInterval(6)), .moving)
        // Stopped long enough: parked.
        XCTAssertEqual(evaluator.update(speedKmh: 0, automotiveMoving: nil, at: t0.addingTimeInterval(11.5)), .parked)
    }

    func testCreepingRestartsHoldTimer() {
        var evaluator = ParkedStateEvaluator(parkedHoldSeconds: 10)
        let t0 = Date()
        evaluator.update(speedKmh: 40, automotiveMoving: nil, at: t0)
        evaluator.update(speedKmh: 0, automotiveMoving: nil, at: t0.addingTimeInterval(1))
        evaluator.update(speedKmh: 5, automotiveMoving: nil, at: t0.addingTimeInterval(5)) // between thresholds
        XCTAssertEqual(evaluator.update(speedKmh: 0, automotiveMoving: nil, at: t0.addingTimeInterval(12)), .moving)
        XCTAssertEqual(evaluator.update(speedKmh: 0, automotiveMoving: nil, at: t0.addingTimeInterval(22.5)), .parked)
    }

    // MARK: MJPEG / HTTP

    func testRouting() {
        XCTAssertEqual(MJPEGStream.route(forRequest: Data("GET / HTTP/1.1\r\nHost: x\r\n\r\n".utf8)), .page)
        XCTAssertEqual(MJPEGStream.route(forRequest: Data("GET /stream?t=123 HTTP/1.1\r\n\r\n".utf8)), .stream)
        XCTAssertEqual(MJPEGStream.route(forRequest: Data("GET /favicon.ico HTTP/1.1\r\n\r\n".utf8)), .notFound)
        XCTAssertEqual(MJPEGStream.route(forRequest: Data("POST / HTTP/1.1\r\n\r\n".utf8)), .notFound)
        XCTAssertEqual(MJPEGStream.route(forRequest: Data()), .notFound)
    }

    func testFramePartFraming() {
        let jpeg = Data([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9])
        let part = MJPEGStream.framePart(jpeg: jpeg)
        let header = "--\(MJPEGStream.boundary)\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\n\r\n"
        XCTAssertEqual(part.prefix(header.utf8.count), Data(header.utf8))
        XCTAssertEqual(part.suffix(2), Data("\r\n".utf8))
        XCTAssertEqual(part.count, header.utf8.count + jpeg.count + 2)
    }

    func testStreamHeaderAdvertisesBoundary() {
        let header = String(decoding: MJPEGStream.streamResponseHeader(), as: UTF8.self)
        XCTAssertTrue(header.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(header.contains("multipart/x-mixed-replace; boundary=\(MJPEGStream.boundary)"))
        XCTAssertTrue(header.hasSuffix("\r\n\r\n"))
    }

    func testViewerPageReferencesStream() {
        let page = String(decoding: MJPEGStream.viewerPage(), as: UTF8.self)
        XCTAssertTrue(page.contains("/stream"))
        let response = String(decoding: MJPEGStream.httpResponse(status: "200 OK", contentType: "text/html", body: MJPEGStream.viewerPage()), as: UTF8.self)
        XCTAssertTrue(response.contains("Content-Length: \(MJPEGStream.viewerPage().count)"))
    }

    // MARK: Local network address

    func testAddressPrefersHotspotThenWiFi() {
        XCTAssertEqual(LocalNetworkAddress.pick(from: [
            (name: "en0", address: "192.168.1.20"),
            (name: "bridge100", address: "172.20.10.1"),
        ]), "172.20.10.1")
        XCTAssertEqual(LocalNetworkAddress.pick(from: [
            (name: "pdp_ip0", address: "10.1.2.3"),
            (name: "en0", address: "192.168.1.20"),
        ]), "192.168.1.20")
        XCTAssertNil(LocalNetworkAddress.pick(from: [(name: "en0", address: "169.254.3.4")]))
        XCTAssertNil(LocalNetworkAddress.pick(from: [(name: "pdp_ip0", address: "10.1.2.3")]))
        XCTAssertEqual(LocalNetworkAddress.viewerURL(address: "172.20.10.1"), "http://172.20.10.1:8088")
    }

    // MARK: Shared state

    func testBroadcastStatusRoundTrip() throws {
        let suite = "CarVideoOutputTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(BroadcastStatus.load(from: defaults), .idle)

        let status = BroadcastStatus(state: .live, startedAt: Date(timeIntervalSince1970: 100), viewerURL: "http://172.20.10.1:8088", viewerCount: 2, message: nil, updatedAt: Date(timeIntervalSince1970: 200))
        status.save(to: defaults)
        XCTAssertEqual(BroadcastStatus.load(from: defaults), status)
        XCTAssertTrue(BroadcastStatus.load(from: defaults).isLive)
    }

    func testVehicleMovingFlag() throws {
        let suite = "CarVideoOutputTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(CarCastShared.isVehicleMoving(in: defaults))
        CarCastShared.setVehicleMoving(true, in: defaults)
        XCTAssertTrue(CarCastShared.isVehicleMoving(in: defaults))
        CarCastShared.setVehicleMoving(false, in: defaults)
        XCTAssertFalse(CarCastShared.isVehicleMoving(in: defaults))
    }

    func testBroadcastExtensionBundleID() {
        XCTAssertEqual(CarCastShared.broadcastExtensionBundleID(hostBundleID: "com.xanderco.dashcast"), "com.xanderco.dashcast.broadcast")
    }

    // MARK: Player configuration

    @MainActor
    func testSharedPlayerAllowsExternalVideoPlayback() {
        let player = VideoPlayerService.shared.player
        XCTAssertTrue(player.allowsExternalPlayback)
        XCTAssertTrue(player.usesExternalPlaybackWhileExternalScreenIsActive)
        XCTAssertTrue(CarVideoOutputController.shared.canStartVideoOutput())
    }

    // MARK: CarPlay Mirror Display State & Localization

    func testCarMirrorDisplayStateResolution() {
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: false, vehicleMoving: false, lastFrameAge: 0.1), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: false, vehicleMoving: true, lastFrameAge: 0.1), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: true, lastFrameAge: 0.1), .pausedWhileMoving)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: false, lastFrameAge: nil), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: false, lastFrameAge: CarMirrorDisplayState.staleFrameInterval), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: false, lastFrameAge: 0.5), .mirroring)
    }

    func testCarPlayMirrorCopyLocalizedFallbacks() {
        let testBundle = Bundle(for: CarVideoOutputTests.self)
        XCTAssertEqual(CarPlayMirrorCopy.localizedInstructions(bundle: testBundle), CarPlayMirrorCopy.instructionsKey)
        XCTAssertEqual(CarPlayMirrorCopy.localizedMoving(bundle: testBundle), CarPlayMirrorCopy.movingKey)
        XCTAssertEqual(CarPlayMirrorCopy.allLocalizationKeys, [
            CarPlayMirrorCopy.instructionsKey,
            CarPlayMirrorCopy.movingKey
        ])
    }

    func testCarPlayMirrorCopyLocalizationKeysComplete() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in CarPlayMirrorCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings entry for: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String)
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
