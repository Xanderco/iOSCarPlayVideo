import XCTest
@testable import DashCast

final class SoundEngineTests: XCTestCase {
    func testSoundCatalogItems() {
        let catalog = SoundCatalogService.shared
        XCTAssertGreaterThan(catalog.sounds.count, 10)

        for sound in catalog.sounds {
            XCTAssertFalse(sound.id.isEmpty)
            XCTAssertFalse(sound.title.isEmpty)
            XCTAssertGreaterThan(sound.frequencyHz, 50)
            XCTAssertLessThan(sound.frequencyHz, 5000)
        }
    }

    func testCategoryFiltering() {
        let catalog = SoundCatalogService.shared
        let engineSounds = catalog.sounds(for: .engine)
        XCTAssertGreaterThan(engineSounds.count, 0)
        for s in engineSounds {
            XCTAssertEqual(s.category, .engine)
        }

        let voiceSounds = catalog.sounds(for: .voices)
        XCTAssertGreaterThan(voiceSounds.count, 0)
        for s in voiceSounds {
            XCTAssertEqual(s.category, .voices)
        }
    }

    func testPreferencesSoundAssignments() {
        let prefs = UserPreferences(
            connectionSoundId: "jet_startup",
            disconnectionSoundId: "airline_dingy",
            homeArrivalSoundId: "welcome_sir"
        )

        let encoded = try? JSONEncoder().encode(prefs)
        XCTAssertNotNil(encoded)

        let decoded = try? JSONDecoder().decode(UserPreferences.self, from: encoded!)
        XCTAssertEqual(decoded?.connectionSoundId, "jet_startup")
        XCTAssertEqual(decoded?.disconnectionSoundId, "airline_dingy")
        XCTAssertEqual(decoded?.homeArrivalSoundId, "welcome_sir")
    }
}
