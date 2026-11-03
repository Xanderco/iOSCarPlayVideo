import XCTest
@testable import DashCast

final class WidgetCustomizationTests: XCTestCase {
    func testWidgetConfigDefaultsAndCustomization() {
        var config = WidgetConfigModel()
        XCTAssertEqual(config.plateText, "ABC-1234")
        XCTAssertEqual(config.textColorHex, "#FFFFFF")
        XCTAssertEqual(config.fontName, "Default")
        XCTAssertTrue(config.showWatermark)

        config.plateText = "SPEED-99"
        config.textColorHex = "#FFE600"
        config.fontName = "BEBAS"
        config.showWatermark = false
        config.carScale = 1.3
        config.carVerticalOffset = 15.0
        config.carHorizontalOffset = -10.0

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(config) else {
            XCTFail("Failed to encode WidgetConfigModel")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(WidgetConfigModel.self, from: data) else {
            XCTFail("Failed to decode WidgetConfigModel")
            return
        }

        XCTAssertEqual(decoded.plateText, "SPEED-99")
        XCTAssertEqual(decoded.textColorHex, "#FFE600")
        XCTAssertEqual(decoded.fontName, "BEBAS")
        XCTAssertFalse(decoded.showWatermark)
        XCTAssertEqual(decoded.carScale, 1.3, accuracy: 0.01)
        XCTAssertEqual(decoded.carVerticalOffset, 15.0, accuracy: 0.01)
        XCTAssertEqual(decoded.carHorizontalOffset, -10.0, accuracy: 0.01)
    }

    func testPersistenceControllerWidgetsCycle() {
        let defaults = UserDefaults(suiteName: "WidgetCustomizationTestSuite")!
        let persistence = PersistenceController(userDefaults: defaults)

        let widget = WidgetConfigModel(
            carBrand: "Chevrolet",
            carModelName: "Corvette Stingray",
            carImageName: "car_chevrolet_corvette",
            driverGreeting: "Apex Driver",
            showWatermark: true,
            stickerId: "racing_flag",
            plateText: "CORVETTE-1",
            textColorHex: "#FF9500",
            fontName: "Mono"
        )

        persistence.saveWidgets([widget])
        let loaded = persistence.loadWidgets()

        XCTAssertEqual(loaded.count, 1)
        let first = loaded.first
        XCTAssertEqual(first?.carBrand, "Chevrolet")
        XCTAssertEqual(first?.carModelName, "Corvette Stingray")
        XCTAssertEqual(first?.plateText, "CORVETTE-1")
        XCTAssertEqual(first?.textColorHex, "#FF9500")
        XCTAssertEqual(first?.fontName, "Mono")
    }
}
