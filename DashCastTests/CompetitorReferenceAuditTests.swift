import XCTest
@testable import DashCast

final class CompetitorReferenceAuditTests: XCTestCase {
    private let forbiddenCompetitorTerms: [String] = [
        "cardash",
        "cartv",
        "playcar",
        "cartube"
    ]

    func testAppStateTabItemsHaveNoCompetitorReferences() {
        for tab in AppState.TabItem.allCases {
            let name = tab.rawValue.lowercased()
            for term in forbiddenCompetitorTerms {
                XCTAssertFalse(name.contains(term), "Tab item '\(name)' contains forbidden competitor term '\(term)'")
            }
        }
    }

    func testSoundCatalogHasNoCompetitorReferences() {
        for sound in SoundCatalogService.shared.sounds {
            let id = sound.id.lowercased()
            let title = sound.title.lowercased()
            for term in forbiddenCompetitorTerms {
                XCTAssertFalse(id.contains(term), "Sound id '\(id)' contains forbidden competitor term '\(term)'")
                XCTAssertFalse(title.contains(term), "Sound title '\(title)' contains forbidden competitor term '\(term)'")
            }
        }
    }

    func testVehicleCatalogHasNoCompetitorReferences() {
        for model in VehicleCatalogService.shared.vehicles {
            let id = model.id.lowercased()
            let name = model.name.lowercased()
            for term in forbiddenCompetitorTerms {
                XCTAssertFalse(id.contains(term), "Vehicle model '\(id)' contains forbidden competitor term '\(term)'")
                XCTAssertFalse(name.contains(term), "Vehicle name '\(name)' contains forbidden competitor term '\(term)'")
            }
        }

        for brand in VehicleCatalogService.shared.brands {
            let id = brand.id.lowercased()
            let name = brand.name.lowercased()
            for term in forbiddenCompetitorTerms {
                XCTAssertFalse(id.contains(term), "Vehicle brand '\(id)' contains forbidden competitor term '\(term)'")
                XCTAssertFalse(name.contains(term), "Vehicle brand name '\(name)' contains forbidden competitor term '\(term)'")
            }
        }
    }

    func testUserPreferencesDefaultsHaveNoCompetitorReferences() {
        let prefs = UserPreferences()
        let vehicle = prefs.driveVehicleName.lowercased()
        let image = prefs.driveVehicleImage.lowercased()

        for term in forbiddenCompetitorTerms {
            XCTAssertFalse(vehicle.contains(term), "Default vehicle name contains '\(term)'")
            XCTAssertFalse(image.contains(term), "Default vehicle image contains '\(term)'")
        }
    }
}
