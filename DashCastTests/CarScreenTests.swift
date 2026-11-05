import XCTest
import UIKit
@testable import DashCast

final class CarScreenTests: XCTestCase {
    func testDefaultCarScreenTextIsNeutral() {
        let config = CarScreenDefaults.neutralConfig()
        XCTAssertEqual(config.carBrand, "My Car")
        XCTAssertEqual(config.driverGreeting, "Welcome aboard")
        XCTAssertEqual(config.carModelName, "Pick something to watch")
        XCTAssertEqual(config.carImageName, "")
        XCTAssertNil(config.plateText)
    }

    func testCarScreenPersistenceCycle() {
        let suite = "CarScreenTestDefaults"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let persistence = PersistenceController(userDefaults: defaults)

        CarScreenDefaults.seedIfNeeded(persistence: persistence)
        XCTAssertEqual(persistence.loadWidgets().first?.carBrand, "My Car")

        var config = CarScreenDefaults.neutralConfig()
        config.carBrand = "Road trip"
        config.driverGreeting = "Hi, kids"
        config.carModelName = "Movie night in the back"
        persistence.saveWidgets([config])
        // Seeding again must not overwrite the user's text.
        CarScreenDefaults.seedIfNeeded(persistence: persistence)

        let loaded = persistence.loadWidgets()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.carBrand, "Road trip")
        XCTAssertEqual(loaded.first?.driverGreeting, "Hi, kids")
        XCTAssertEqual(loaded.first?.carModelName, "Movie night in the back")
        defaults.removePersistentDomain(forName: suite)
    }

    func testLegacyWidgetPayloadStillDecodes() throws {
        let legacy = """
        {"carBrand":"Old","carModelName":"Model","carImageName":"car_old","driverGreeting":"Hello","plateText":"ABC"}
        """
        let decoded = try JSONDecoder().decode(WidgetConfigModel.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.carBrand, "Old")
        XCTAssertEqual(decoded.plateText, "ABC")
        XCTAssertTrue(decoded.showWatermark)
    }

    func testTextLimitsAreSane() {
        XCTAssertGreaterThan(CarScreenDefaults.labelLimit, 0)
        XCTAssertGreaterThanOrEqual(CarScreenDefaults.textLimit, CarScreenDefaults.labelLimit)
    }

    func testPhotoDownscaling() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let data = image.pngData()!
        let resized = CarScreenDefaults.downscaledJPEG(from: data)
        XCTAssertNotNil(resized)
        let decoded = UIImage(data: resized!)!
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height), 1024.5)
        XCTAssertNil(CarScreenDefaults.downscaledJPEG(from: Data([0, 1, 2])))
    }
}
