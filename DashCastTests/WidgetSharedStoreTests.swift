import XCTest
@testable import DashCast

final class WidgetSharedStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WidgetSharedStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testEncodeDecodeRoundTrip() throws {
        let payload = WidgetSharedPayload(
            car: SharedCarSnapshot(name: "Blue Bolt", brand: "Mazda", model: "MX-5", plate: "KXY-482",
                                   photoData: Data([0xFF, 0xD8, 0x01]), accentHex: "#40D9BF"),
            lastTrip: SharedTripSnapshot(distanceMeters: 18_250, score: 87,
                                         date: Date(timeIntervalSince1970: 1_790_000_000), durationSeconds: 1_500),
            usesMiles: true,
            updatedAt: Date(timeIntervalSince1970: 1_790_000_100))
        let decoded = try WidgetSharedStore.decode(WidgetSharedStore.encode(payload))
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.version, WidgetSharedPayload.currentVersion)
        XCTAssertEqual(decoded.lastTrip!.distanceKm, 18.25, accuracy: 0.001)
    }

    func testStoreSaveAndLoad() {
        let store = WidgetSharedStore(defaults: defaults)
        XCTAssertNil(store.load().car, "Empty store returns an empty payload")
        store.update { $0.car = .placeholder }
        store.update { $0.lastTrip = .placeholder }
        let loaded = store.load()
        XCTAssertEqual(loaded.car, .placeholder)
        XCTAssertEqual(loaded.lastTrip, .placeholder)
    }

    func testCorruptDataFallsBackToEmptyPayload() {
        defaults.set(Data("not json".utf8), forKey: WidgetSharedStore.payloadKey)
        let store = WidgetSharedStore(defaults: defaults)
        XCTAssertNil(store.load().car)
        XCTAssertNil(store.load().lastTrip)
    }

    func testSnapshotFromWidgetConfig() {
        let config = WidgetConfigModel(carBrand: "Toyota", carModelName: "Supra",
                                       driverGreeting: "  ", plateText: "SUP-001")
        let car = WidgetSharedPublisher.snapshot(from: config)
        XCTAssertEqual(car.brand, "Toyota")
        XCTAssertEqual(car.name, "Supra", "Blank greeting falls back to the model name")
        XCTAssertEqual(car.plate, "SUP-001")
        XCTAssertNil(car.photoData)
    }

    func testPublishWritesToStore() {
        let store = WidgetSharedStore(defaults: defaults)
        WidgetSharedPublisher.publishWidgets([WidgetConfigModel(carBrand: "Kia", carModelName: "EV6")], store: store)
        let trip = TripModel(startTime: Date(timeIntervalSince1970: 100), endTime: Date(timeIntervalSince1970: 700),
                             distanceMeters: 5_000, drivingScore: 74)
        WidgetSharedPublisher.publishTrips([trip], store: store)
        let loaded = store.load()
        XCTAssertEqual(loaded.car?.model, "EV6")
        XCTAssertEqual(loaded.lastTrip?.score, 74)
        XCTAssertEqual(loaded.lastTrip?.durationSeconds ?? 0, 600, accuracy: 0.1)
    }

    func testDestinationParsing() {
        XCTAssertEqual(DashCastLinks.destination(for: DashCastLinks.cast), .cast)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "DASHCAST://Drive")!), .drive)
        XCTAssertEqual(DashCastLinks.destination(for: URL(string: "dashcast:///cast")!), .cast)
        XCTAssertNil(DashCastLinks.destination(for: URL(string: "otherapp://cast")!))
    }

    @MainActor
    func testDeepLinkSelectsTab() {
        let state = AppState()
        state.selectedTab = .me
        XCTAssertTrue(state.handleDeepLink(DashCastLinks.cast))
        XCTAssertEqual(state.selectedTab, .cast)
        XCTAssertTrue(state.handleDeepLink(DashCastLinks.drive))
        XCTAssertEqual(state.selectedTab, .drive)
        XCTAssertFalse(state.handleDeepLink(URL(string: "https://example.com/cast")!))
        XCTAssertFalse(state.handleDeepLink(URL(string: "dashcast://nowhere")!))
        XCTAssertFalse(state.handleDeepLink(URL(string: "dashcast://widgets")!))
        XCTAssertEqual(state.selectedTab, .drive)
    }

    // MARK: - CarPlay / glanceability contrast

    func testBrandAccentIsReadableOnBackdrop() {
        let accent = WidgetColorMath.components(hex: WidgetColorMath.fallbackAccentHex)!
        let backdrop = WidgetColorMath.components(hex: WidgetColorMath.backdropHex)!
        XCTAssertGreaterThanOrEqual(WidgetColorMath.contrastRatio(accent, backdrop), 7.0)
        let white = (r: 1.0, g: 1.0, b: 1.0)
        XCTAssertGreaterThanOrEqual(WidgetColorMath.contrastRatio(white, backdrop), 15.0)
    }

    func testContrastRatioKnownValues() {
        let black = (r: 0.0, g: 0.0, b: 0.0), white = (r: 1.0, g: 1.0, b: 1.0)
        XCTAssertEqual(WidgetColorMath.contrastRatio(black, white), 21, accuracy: 0.01)
        XCTAssertEqual(WidgetColorMath.contrastRatio(white, white), 1, accuracy: 0.0001)
    }

    func testReadableAccentFallsBackForDarkOrInvalidColours() {
        XCTAssertEqual(WidgetColorMath.readableAccentHex("#FFD60A"), "#FFD60A", "Bright yellow is readable")
        XCTAssertEqual(WidgetColorMath.readableAccentHex("#1A1A40"), WidgetColorMath.fallbackAccentHex, "Navy is unreadable on dark")
        XCTAssertEqual(WidgetColorMath.readableAccentHex("#FFFFFF"), WidgetColorMath.fallbackAccentHex, "White = default text colour")
        XCTAssertEqual(WidgetColorMath.readableAccentHex("nope"), WidgetColorMath.fallbackAccentHex)
        XCTAssertEqual(WidgetColorMath.readableAccentHex(nil), WidgetColorMath.fallbackAccentHex)
    }

    // MARK: - Photo / Doodle

    func testDoodleRoundTripAndLegacyPayloadDecodes() throws {
        let doodle = SharedDoodle(kind: .doodle, imageData: Data([0x89, 0x50, 0x4E, 0x47]), caption: "Road trip!")
        let payload = WidgetSharedPayload(doodle: doodle, updatedAt: Date(timeIntervalSince1970: 1_790_000_000))
        XCTAssertEqual(try WidgetSharedStore.decode(WidgetSharedStore.encode(payload)).doodle, doodle)

        // Payloads written before the doodle field existed must still decode.
        let legacy = Data(#"{"version":1,"usesMiles":false,"updatedAt":1790000000}"#.utf8)
        let decoded = try WidgetSharedStore.decode(legacy)
        XCTAssertNil(decoded.doodle)
        XCTAssertNil(decoded.car)
    }

    func testPublishDoodleKeepsOtherFields() {
        let store = WidgetSharedStore(defaults: defaults)
        store.update { $0.car = .placeholder }
        WidgetSharedPublisher.publishDoodle(SharedDoodle(kind: .photo, imageData: Data([1, 2, 3])), store: store)
        XCTAssertEqual(store.load().car, .placeholder)
        XCTAssertEqual(store.load().doodle?.kind, .photo)
        WidgetSharedPublisher.publishDoodle(nil, store: store)
        XCTAssertNil(store.load().doodle)
    }
}
