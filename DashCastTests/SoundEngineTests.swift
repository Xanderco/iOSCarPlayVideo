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

    func testShortcutsGuideConnectionSoundResolutionAndFallback() {
        let configuredPrefs = UserPreferences(connectionSoundId: "v8_supercharged")
        let configured = ShortcutsGuideSoundResolver.resolveConnectionSound(from: configuredPrefs)
        XCTAssertEqual(configured?.id, "v8_supercharged")

        let nilPrefs = UserPreferences(connectionSoundId: nil)
        let nilFallback = ShortcutsGuideSoundResolver.resolveConnectionSound(from: nilPrefs)
        XCTAssertEqual(nilFallback?.id, "jet_startup")

        let unknownPrefs = UserPreferences(connectionSoundId: "nonexistent_sound_id")
        let unknownFallback = ShortcutsGuideSoundResolver.resolveConnectionSound(from: unknownPrefs)
        XCTAssertEqual(unknownFallback?.id, "jet_startup")
    }

    func testShortcutsGuideLocalizationKeysPresentWithSpanish() throws {
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

        for key in ShortcutsGuideSoundResolver.localizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing localization key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            let enValue = (localizations["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = (localizations["es"]?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse((enValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty EN for: \(key)")
            XCTAssertFalse((esValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty ES for: \(key)")
        }
    }
}
