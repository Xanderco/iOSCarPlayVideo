import XCTest
@testable import DashCast

final class SoundEngineTests: XCTestCase {
    func testSoundCatalogItems() {
        let catalog = SoundCatalogService.shared
        XCTAssertGreaterThan(catalog.sounds.count, 10)

        let ids = catalog.sounds.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Chime ids must be unique")

        for sound in catalog.sounds {
            XCTAssertFalse(sound.id.isEmpty)
            XCTAssertFalse(sound.title.isEmpty)
            XCTAssertNotEqual(sound.category, .all)
            XCTAssertFalse(sound.notes.isEmpty)
            for note in sound.notes {
                XCTAssertGreaterThan(note, 50)
                XCTAssertLessThan(note, 5000)
            }
            XCTAssertGreaterThan(sound.duration, 0)
        }
    }

    func testCategoryFiltering() {
        let catalog = SoundCatalogService.shared
        XCTAssertEqual(catalog.sounds(for: .all).count, catalog.sounds.count)

        for category in SoundCategory.pickable {
            let items = catalog.sounds(for: category)
            XCTAssertGreaterThan(items.count, 0, "\(category.rawValue) should not be empty")
            XCTAssertTrue(items.allSatisfy { $0.category == category })
        }
        XCTAssertFalse(SoundCategory.pickable.contains(.all))
    }

    func testDefaultAndSelectedChime() {
        let catalog = SoundCatalogService.shared
        XCTAssertNotNil(catalog.sound(withId: SoundCatalogService.defaultSoundId))
        XCTAssertNil(catalog.sound(withId: nil))

        let prefs = UserPreferences(connectionSoundId: "quick_ping")
        XCTAssertEqual(catalog.selectedSound(preferences: prefs).id, "quick_ping")

        let unset = UserPreferences(connectionSoundId: nil)
        XCTAssertEqual(catalog.selectedSound(preferences: unset).id, SoundCatalogService.defaultSoundId)
    }

    func testPreferencesChimeRoundTrip() throws {
        let prefs = UserPreferences(connectionSoundId: "glass_bell")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(decoded.connectionSoundId, "glass_bell")
    }
}
