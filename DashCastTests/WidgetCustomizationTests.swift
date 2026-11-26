import SwiftUI
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
        // Verify persistence
        XCTAssertEqual(first?.plateText, "CORVETTE-1")
        XCTAssertEqual(first?.textColorHex, "#FF9500")
        XCTAssertEqual(first?.fontName, "Mono")
    }

    func testDoodleEditorCaptionNormalization() {
        XCTAssertNil(DoodleEditorLogic.normalizedCaption(""))
        XCTAssertNil(DoodleEditorLogic.normalizedCaption("   \n\t  "))
        XCTAssertEqual(DoodleEditorLogic.normalizedCaption("  Road Trip  "), "Road Trip")

        let exact24 = "123456789012345678901234"
        XCTAssertEqual(DoodleEditorLogic.normalizedCaption(exact24), exact24)

        let over24 = "123456789012345678901234567890"
        XCTAssertEqual(DoodleEditorLogic.normalizedCaption("  \(over24)  "), exact24)
    }

    func testDoodleEditorCanvasPointClamping() {
        XCTAssertEqual(DoodleEditorLogic.clampedPoint(CGPoint(x: -25, y: 450), canvasSide: 300), CGPoint(x: 0, y: 300))
        XCTAssertEqual(DoodleEditorLogic.clampedPoint(CGPoint(x: 120, y: 180), canvasSide: 300), CGPoint(x: 120, y: 180))
        XCTAssertEqual(DoodleEditorLogic.clampedPoint(CGPoint(x: CGFloat.nan, y: CGFloat.infinity), canvasSide: 300), .zero)
        XCTAssertEqual(DoodleEditorLogic.clampedPoint(CGPoint(x: 50, y: 50), canvasSide: 0), .zero)
        XCTAssertEqual(DoodleEditorLogic.clampedPoint(CGPoint(x: 50, y: 50), canvasSide: -10), .zero)
    }

    func testDoodleEditorCanSaveValidation() {
        XCTAssertFalse(DoodleEditorLogic.canSave(mode: .doodle, strokeCount: 0, hasPhoto: false))
        XCTAssertFalse(DoodleEditorLogic.canSave(mode: .doodle, strokeCount: 0, hasPhoto: true))
        XCTAssertTrue(DoodleEditorLogic.canSave(mode: .doodle, strokeCount: 1, hasPhoto: false))

        XCTAssertFalse(DoodleEditorLogic.canSave(mode: .photo, strokeCount: 3, hasPhoto: false))
        XCTAssertTrue(DoodleEditorLogic.canSave(mode: .photo, strokeCount: 0, hasPhoto: true))
    }

    @MainActor
    func testDoodleEditorLocalizationKeysInCatalog() throws {
        for mode in DoodleEditorLogic.Mode.allCases {
            XCTAssertNotNil(mode.titleKey)
        }

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

        for key in DoodleEditorLogic.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing catalog entry for key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String, "Missing \(lang) string value for: \(key)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
