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
        XCTAssertEqual(state.selectedTab, .drive)
    }
}
