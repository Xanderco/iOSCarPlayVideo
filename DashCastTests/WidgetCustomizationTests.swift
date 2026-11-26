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

    func testDashCastWidgetsLocalizationCatalogComplete() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCastWidgets")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], "DashCastWidgets/Localizable.xcstrings must be valid JSON")
        XCTAssertEqual(json["sourceLanguage"] as? String, "en")
        XCTAssertEqual(json["version"] as? String, "1.0")

        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
        let expectedKeys = [
            // CarWidget
            "My Car",
            "Your car, its name and licence plate.",
            "Show licence plate",
            "Your car photo, name and plate.",
            // TripStatsWidget
            "Units",
            "Same as app",
            "Kilometres",
            "Miles",
            "Last Trip",
            "Distance, score and date of your latest drive.",
            "Distance, driving score and when you drove.",
            "No trips yet",
            "Start a drive in DashCast",
            "mi",
            "km",
            "Score %lld",
            // DoodleWidget
            "Photo / Doodle",
            "A photo or a doodle you drew in DashCast.",
            "Draw or pick a photo",
            "Open DashCast to set up",
            // QuickCastWidget
            "Quick Cast",
            "Jump straight to casting to your car.",
            "DashCast",
            "Tap to cast",
            "Cast to car",
            "Cast",
            "Video to your car"
        ]

        for key in expectedKeys {
            let entry = try XCTUnwrap(strings[key], "Missing DashCastWidgets catalog entry for: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String, "Missing \(lang) string value for: \(key)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
