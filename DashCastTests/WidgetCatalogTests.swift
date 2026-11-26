import XCTest
@testable import DashCast

final class WidgetCatalogTests: XCTestCase {
    func testBrandsListNotEmpty() {
        let catalog = VehicleCatalogService.shared
        XCTAssertGreaterThan(catalog.brands.count, 5)

        for brand in catalog.brands {
            XCTAssertFalse(brand.name.isEmpty)
            XCTAssertFalse(brand.id.isEmpty)
        }
    }

    func testVehiclesFiltering() {
        let catalog = VehicleCatalogService.shared
        let toyotaVehicles = catalog.vehicles(for: "toyota")

        XCTAssertGreaterThan(toyotaVehicles.count, 0)
        for car in toyotaVehicles {
            XCTAssertEqual(car.brandId, "toyota")
        }
    }

    func testStickersList() {
        let catalog = VehicleCatalogService.shared
        XCTAssertGreaterThan(catalog.stickers.count, 3)
        XCTAssertTrue(catalog.stickers.contains(where: { $0.id == "route66" }))
    }

    func testWidgetConfigPersistenceCycle() {
        let defaults = UserDefaults(suiteName: "WidgetTestDefaults")!
        let persistence = PersistenceController(userDefaults: defaults)

        let widget = WidgetConfigModel(
            carBrand: "Porsche",
            carModelName: "911 GT3 RS",
            driverGreeting: "Apex Hunter",
            showWatermark: true,
            stickerId: "turbo"
        )

        persistence.saveWidgets([widget])
        let loaded = persistence.loadWidgets()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.carBrand, "Porsche")
        XCTAssertEqual(loaded.first?.carModelName, "911 GT3 RS")
        XCTAssertEqual(loaded.first?.driverGreeting, "Apex Hunter")
    }

    func testWidgetEditorConfigValidator() {
        XCTAssertNil(WidgetEditorConfigValidator.normalizePlate(nil))
        XCTAssertNil(WidgetEditorConfigValidator.normalizePlate("   \n\t "))
        XCTAssertEqual(WidgetEditorConfigValidator.normalizePlate("  abc-1234 "), "ABC-1234")

        XCTAssertEqual(WidgetEditorConfigValidator.clampScale(0.1), 0.6)
        XCTAssertEqual(WidgetEditorConfigValidator.clampScale(2.5), 1.6)
        XCTAssertEqual(WidgetEditorConfigValidator.clampScale(1.15), 1.15)
        XCTAssertEqual(WidgetEditorConfigValidator.clampScale(.nan), 1.0)

        XCTAssertEqual(WidgetEditorConfigValidator.clampOffset(-99), -50)
        XCTAssertEqual(WidgetEditorConfigValidator.clampOffset(99), 50)
        XCTAssertEqual(WidgetEditorConfigValidator.clampOffset(12.5), 12.5)
        XCTAssertEqual(WidgetEditorConfigValidator.clampOffset(.infinity), 0.0)

        let raw = WidgetConfigModel(
            carScale: 3.0,
            carVerticalOffset: -120,
            carHorizontalOffset: 80,
            plateText: "  xy-987 "
        )
        let sanitized = WidgetEditorConfigValidator.sanitizedConfig(raw)
        XCTAssertEqual(sanitized.plateText, "XY-987")
        XCTAssertEqual(sanitized.carScale, 1.6)
        XCTAssertEqual(sanitized.carVerticalOffset, -50)
        XCTAssertEqual(sanitized.carHorizontalOffset, 50)
    }

    func testWidgetEditorCopyLocalizationKeysComplete() throws {
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

        for key in WidgetEditorCopy.allLocalizationKeys {
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
