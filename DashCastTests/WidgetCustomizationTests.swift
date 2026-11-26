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

    // MARK: VideoTrimmerLogic

    func testVideoTrimmerLogicZeroWidthAndInvalidInputs() {
        XCTAssertEqual(
            VideoTrimmerLogic.trimStartTime(
                forLocationX: 50,
                containerWidth: 0,
                windowWidth: 0,
                duration: 10,
                maxTrimDuration: 3
            ),
            0
        )
        XCTAssertEqual(
            VideoTrimmerLogic.trimStartTime(
                forLocationX: 50,
                containerWidth: 100,
                windowWidth: 120,
                duration: 10,
                maxTrimDuration: 3
            ),
            0
        )
        XCTAssertEqual(
            VideoTrimmerLogic.trimStartTime(
                forLocationX: .nan,
                containerWidth: 200,
                windowWidth: 70,
                duration: 10,
                maxTrimDuration: 3
            ),
            0
        )
        XCTAssertEqual(
            VideoTrimmerLogic.normalizedOffset(trimStartTime: .nan, duration: 10, maxTrimDuration: 3),
            0
        )
    }

    func testVideoTrimmerLogicShortClipClampsToZero() {
        XCTAssertEqual(VideoTrimmerLogic.effectiveWindowDuration(duration: 2.0, maxTrimDuration: 3.0), 2.0, accuracy: 0.001)
        XCTAssertEqual(VideoTrimmerLogic.effectiveWindowDuration(duration: 0.0, maxTrimDuration: 3.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(VideoTrimmerLogic.effectiveWindowDuration(duration: -1.0, maxTrimDuration: 3.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(VideoTrimmerLogic.normalizedOffset(trimStartTime: 1.5, duration: 2.5, maxTrimDuration: 3.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(
            VideoTrimmerLogic.trimStartTime(
                forLocationX: 120,
                containerWidth: 200,
                windowWidth: 70,
                duration: 2.5,
                maxTrimDuration: 3.0
            ),
            0.0,
            accuracy: 0.001
        )
    }

    func testVideoTrimmerLogicDragClampingAndNormalizedOffset() {
        // containerWidth = 200, windowWidth = 70 -> maxOffset = 130, span = 7.0 (10 - 3)
        let leftEdge = VideoTrimmerLogic.trimStartTime(
            forLocationX: 0,
            containerWidth: 200,
            windowWidth: 70,
            duration: 10,
            maxTrimDuration: 3
        )
        XCTAssertEqual(leftEdge, 0.0, accuracy: 0.001)

        let midpoint = VideoTrimmerLogic.trimStartTime(
            forLocationX: 100,
            containerWidth: 200,
            windowWidth: 70,
            duration: 10,
            maxTrimDuration: 3
        )
        XCTAssertEqual(midpoint, 3.5, accuracy: 0.001)

        let rightEdge = VideoTrimmerLogic.trimStartTime(
            forLocationX: 250,
            containerWidth: 200,
            windowWidth: 70,
            duration: 10,
            maxTrimDuration: 3
        )
        XCTAssertEqual(rightEdge, 7.0, accuracy: 0.001)

        XCTAssertEqual(VideoTrimmerLogic.normalizedOffset(trimStartTime: -2, duration: 10, maxTrimDuration: 3), 0.0, accuracy: 0.001)
        XCTAssertEqual(VideoTrimmerLogic.normalizedOffset(trimStartTime: 3.5, duration: 10, maxTrimDuration: 3), 0.5, accuracy: 0.001)
        XCTAssertEqual(VideoTrimmerLogic.normalizedOffset(trimStartTime: 12, duration: 10, maxTrimDuration: 3), 1.0, accuracy: 0.001)
    }

    func testVideoTrimmerLogicDurationBadgeText() {
        XCTAssertEqual(VideoTrimmerLogic.durationBadgeText(duration: 10.0, maxTrimDuration: 3.0), "3.0s")
        XCTAssertEqual(VideoTrimmerLogic.durationBadgeText(duration: 1.8, maxTrimDuration: 3.0), "1.8s")
        XCTAssertEqual(VideoTrimmerLogic.durationBadgeText(duration: 0.0, maxTrimDuration: 3.0), "0.0s")
    }

    @MainActor
    func testVideoTrimmerLocalizationKeysExistInCatalog() throws {
        _ = VideoTrimmerLogic.titleKey

        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = Bundle(for: WidgetCustomizationTests.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? projectDir
                .appendingPathComponent("DashCast")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in VideoTrimmerLogic.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing key in Localizable.xcstrings: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = ((localizations["es"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing EN for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Missing ES for \(key)")
        }
    }
}
