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

    func testWidgetsHomeDefaults() {
        let defaultWidget = WidgetsHomeDefaults.defaultWidget
        XCTAssertEqual(defaultWidget.carBrand, "Porsche")
        XCTAssertEqual(defaultWidget.carModelName, "911 GT3 RS")
        XCTAssertEqual(defaultWidget.carImageName, "car_porsche_911")
        XCTAssertEqual(defaultWidget.driverGreeting, "Welcome, Driver")

        let starters = WidgetsHomeDefaults.starterWidgets
        XCTAssertEqual(starters.count, 3)
        XCTAssertEqual(starters.map(\.carBrand), ["Porsche", "Toyota", "Chevrolet"])
        XCTAssertEqual(starters.map(\.stickerId), ["turbo", "paw", "route66"])
        XCTAssertTrue(starters.allSatisfy { $0.showWatermark })
    }

    func testWidgetsHomeCopyLocalizationKeysComplete() throws {
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

        for key in WidgetsHomeCopy.allLocalizationKeys {
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
