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

    func testCarPlayDashboardMockupFormatter() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        let date = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: utc,
            year: 2026,
            month: 8,
            day: 3,
            hour: 9,
            minute: 41
        )))

        let enLocale = Locale(identifier: "en_US_POSIX")
        let esLocale = Locale(identifier: "es_ES")

        XCTAssertEqual(
            CarPlayDashboardMockupFormatter.monthName(for: date, locale: enLocale, calendar: calendar),
            "August"
        )
        XCTAssertEqual(
            CarPlayDashboardMockupFormatter.monthName(for: date, locale: esLocale, calendar: calendar),
            "Agosto"
        )
        XCTAssertEqual(
            CarPlayDashboardMockupFormatter.dayNumber(for: date, calendar: calendar),
            "03"
        )
        XCTAssertFalse(
            CarPlayDashboardMockupFormatter.timeString(for: date, locale: enLocale, timeZone: utc).isEmpty
        )
        XCTAssertEqual(CarPlayDashboardMockupFormatter.countdownDisplayValue(for: nil), "10")
        XCTAssertEqual(CarPlayDashboardMockupFormatter.countdownDisplayValue(for: "   "), "10")
        XCTAssertEqual(CarPlayDashboardMockupFormatter.countdownDisplayValue(for: " 25 "), "25")
    }
}
