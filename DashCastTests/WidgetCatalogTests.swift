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

    func testTemplateCatalogPresetsForAllCategories() {
        for category in WidgetTemplateCategory.allCases where category != .carBrands {
            let presets = WidgetTemplateCatalog.presets(for: category)
            XCTAssertGreaterThanOrEqual(presets.count, 3, "Category \(category.rawValue) should expose multiple presets")
            let ids = Set(presets.map(\.id))
            XCTAssertEqual(ids.count, presets.count, "Preset IDs must be unique in \(category.rawValue)")

            if let first = presets.first {
                let freshA = first.makeFreshConfig()
                let freshB = first.makeFreshConfig()
                XCTAssertNotEqual(freshA.id, freshB.id, "Selecting a preset should mint a fresh widget ID")
                XCTAssertEqual(freshA.carBrand, first.templateConfig.carBrand)
                XCTAssertEqual(freshA.plateText, first.templateConfig.plateText)
            }
        }
    }

    func testBrandPresetResolutionForKnownAndFallbackBrands() {
        let catalog = VehicleCatalogService.shared
        let toyota = catalog.brands.first { $0.id == "toyota" }!
        let toyotaConfig = WidgetTemplateCatalog.presetConfig(for: toyota, catalog: catalog)
        XCTAssertEqual(toyotaConfig.carBrand, "Toyota")
        XCTAssertEqual(toyotaConfig.carImageName, "car_toyota_rav4")

        let tesla = catalog.brands.first { $0.id == "tesla" }!
        let teslaConfig = WidgetTemplateCatalog.presetConfig(for: tesla, catalog: catalog)
        XCTAssertEqual(teslaConfig.carBrand, "Tesla")
        XCTAssertEqual(teslaConfig.carModelName, "Tesla")
        XCTAssertEqual(teslaConfig.carImageName, "car_porsche_911")
    }

    func testSavedWidgetsUpsertActivateDeleteAndSharedSync() throws {
        let suiteName = "WidgetCatalogTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let sharedDefaults = try XCTUnwrap(UserDefaults(suiteName: "\(suiteName).shared"))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            sharedDefaults.removePersistentDomain(forName: "\(suiteName).shared")
        }

        let persistence = PersistenceController(userDefaults: defaults)
        XCTAssertFalse(persistence.hasStoredWidgets)

        var widgets = WidgetTemplateCatalog.defaultStarterWidgets
        persistence.saveWidgets(widgets)
        XCTAssertTrue(persistence.hasStoredWidgets)

        // Activate second widget -> moves to index 0 and updates WidgetSharedPublisher
        let second = widgets[1]
        widgets = WidgetTemplateCatalog.activate(second.id, in: widgets)
        XCTAssertEqual(widgets.first?.id, second.id)
        persistence.saveWidgets(widgets)

        let sharedStore = WidgetSharedStore(defaults: sharedDefaults)
        WidgetSharedPublisher.publishWidgets(widgets, store: sharedStore)
        XCTAssertEqual(sharedStore.load().car?.brand, second.carBrand)

        // Edit existing widget -> updates in place without duplicating
        var edited = second
        edited.driverGreeting = "Road Trip Ready"
        widgets = WidgetTemplateCatalog.upsert(edited, in: widgets)
        XCTAssertEqual(widgets.count, 3)
        XCTAssertEqual(widgets.first?.driverGreeting, "Road Trip Ready")

        // Insert brand new widget -> placed at index 0
        let brandNew = WidgetConfigModel(carBrand: "BMW", carModelName: "M4 Competition", driverGreeting: "Apex")
        widgets = WidgetTemplateCatalog.upsert(brandNew, in: widgets)
        XCTAssertEqual(widgets.count, 4)
        XCTAssertEqual(widgets.first?.id, brandNew.id)

        // Delete active widget -> next widget becomes active and persists
        widgets = WidgetTemplateCatalog.delete(brandNew.id, from: widgets)
        XCTAssertEqual(widgets.count, 3)
        XCTAssertEqual(widgets.first?.id, second.id)

        persistence.saveWidgets([])
        XCTAssertTrue(persistence.hasStoredWidgets, "Explicitly saving empty array keeps stored marker")
        XCTAssertTrue(persistence.loadWidgets().isEmpty)
    }
}
