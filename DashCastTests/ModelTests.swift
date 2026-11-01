import XCTest
@testable import DashCast

final class ModelTests: XCTestCase {
    func testTripModelCalculations() {
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1600) // 600s = 10m

        let trip = TripModel(
            id: UUID(),
            startTime: start,
            endTime: end,
            distanceMeters: 5000,
            averageSpeedKmh: 30,
            maxSpeedKmh: 65,
            drivingScore: 92
        )

        XCTAssertEqual(trip.durationSeconds, 600)
        XCTAssertEqual(trip.distanceKilometers, 5.0, accuracy: 0.001)
        XCTAssertEqual(trip.distanceMiles, 5000 * 0.000621371, accuracy: 0.001)
        XCTAssertEqual(trip.drivingScore, 92)
    }

    func testChannelModelInitialization() {
        let url = URL(string: "https://example.com/stream.m3u8")!
        let channel = ChannelModel(
            name: "AutoRacing TV",
            streamURL: url,
            groupTitle: "Sports",
            isFavorite: true
        )

        XCTAssertEqual(channel.name, "AutoRacing TV")
        XCTAssertEqual(channel.streamURL, url)
        XCTAssertEqual(channel.groupTitle, "Sports")
        XCTAssertTrue(channel.isFavorite)
    }

    func testWidgetConfigModelDefaults() {
        let config = WidgetConfigModel()
        XCTAssertEqual(config.carBrand, "Porsche")
        XCTAssertEqual(config.carModelName, "911 GT3 RS")
        XCTAssertTrue(config.showWatermark)
    }
}
