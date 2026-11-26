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

    func testSoundsHomeCatalogFilterAndSlotCopy() {
        let sounds = SoundCatalogService.shared.sounds

        let recommended = SoundsHomeCatalogFilter.filter(sounds: sounds, category: "Recommend", searchText: "")
        XCTAssertEqual(recommended.count, sounds.count)

        let all = SoundsHomeCatalogFilter.filter(sounds: sounds, category: "All", searchText: "  ")
        XCTAssertEqual(all.count, sounds.count)

        let engineOnly = SoundsHomeCatalogFilter.filter(sounds: sounds, category: "Engine", searchText: "")
        XCTAssertFalse(engineOnly.isEmpty)
        XCTAssertTrue(engineOnly.allSatisfy { $0.category == .engine })

        let searched = SoundsHomeCatalogFilter.filter(sounds: sounds, category: "All", searchText: "  jet ")
        XCTAssertTrue(searched.contains { $0.id == "jet_startup" })
        XCTAssertFalse(searched.contains { $0.id == "v8_supercharged" })

        let emptySearch = SoundsHomeCatalogFilter.filter(sounds: sounds, category: "Voices", searchText: "nonexistent_sound_xyz")
        XCTAssertTrue(emptySearch.isEmpty)

        XCTAssertEqual(SoundsHomeCatalogFilter.sheetTitleString(for: "disconnection"), SoundsHomeCopy.selectDisconnectionSoundString)
        XCTAssertEqual(SoundsHomeCatalogFilter.sheetTitleString(for: "arrival"), SoundsHomeCopy.selectConnectionSoundString)
        XCTAssertEqual(SoundsHomeCatalogFilter.sheetTitleString(for: "connection"), SoundsHomeCopy.selectConnectionSoundString)

        XCTAssertEqual(SoundsHomeCatalogFilter.setActionTitleString(for: "connection"), SoundsHomeCopy.setAsConnectionSoundString)
        XCTAssertEqual(SoundsHomeCatalogFilter.setActionTitleString(for: "disconnection"), SoundsHomeCopy.setAsDisconnectionSoundString)
        XCTAssertEqual(SoundsHomeCatalogFilter.setActionTitleString(for: "arrival"), SoundsHomeCopy.setAsArrivalSoundString)
    }

    func testSoundsHomeCopyLocalizationKeysComplete() throws {
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

        for key in SoundsHomeCopy.allLocalizationKeys {
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
