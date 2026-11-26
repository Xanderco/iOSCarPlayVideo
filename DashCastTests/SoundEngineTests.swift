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

    func testSoundTriggerSlotMetadataAndDefaultsAreDistinct() {
        let slots = SoundTriggerSlot.allCases
        XCTAssertEqual(slots, [.connection, .disconnection, .arrival])
        XCTAssertEqual(Set(slots.map(\.rawValue)), ["connection", "disconnection", "arrival"])

        let catalogIds = Set(SoundCatalogService.shared.sounds.map(\.id))
        let defaultIds = slots.map(\.defaultSoundId)
        XCTAssertEqual(Set(defaultIds).count, slots.count)
        for defaultId in defaultIds {
            XCTAssertTrue(catalogIds.contains(defaultId), "Missing default sound '\(defaultId)' in catalog")
        }
    }

    func testUserPreferencesSoundSlotMutationIsolation() {
        var prefs = UserPreferences()
        XCTAssertEqual(prefs.soundId(for: .connection), "jet_startup")
        XCTAssertEqual(prefs.soundId(for: .disconnection), "airline_dingy")
        XCTAssertEqual(prefs.soundId(for: .arrival), "welcome_sir")

        prefs.setSoundId("hyperspace", for: .connection)
        XCTAssertEqual(prefs.connectionSoundId, "hyperspace")
        XCTAssertEqual(prefs.disconnectionSoundId, "airline_dingy")
        XCTAssertEqual(prefs.homeArrivalSoundId, "welcome_sir")

        prefs.setSoundId("crystal_ping", for: .disconnection)
        XCTAssertEqual(prefs.connectionSoundId, "hyperspace")
        XCTAssertEqual(prefs.disconnectionSoundId, "crystal_ping")
        XCTAssertEqual(prefs.homeArrivalSoundId, "welcome_sir")

        prefs.setSoundId("luxury_chime", for: .arrival)
        XCTAssertEqual(prefs.connectionSoundId, "hyperspace")
        XCTAssertEqual(prefs.disconnectionSoundId, "crystal_ping")
        XCTAssertEqual(prefs.homeArrivalSoundId, "luxury_chime")

        prefs.setSoundId(nil, for: .connection)
        XCTAssertNil(prefs.soundId(for: .connection))
        XCTAssertEqual(prefs.soundId(for: .disconnection), "crystal_ping")
        XCTAssertEqual(prefs.soundId(for: .arrival), "luxury_chime")
    }

    func testPersistenceControllerSoundSlotRoundTrip() {
        let suiteName = "DashCastSoundSlotTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = PersistenceController(userDefaults: defaults)
        XCTAssertEqual(persistence.soundId(for: .connection), SoundTriggerSlot.connection.defaultSoundId)
        XCTAssertEqual(persistence.soundId(for: .disconnection), SoundTriggerSlot.disconnection.defaultSoundId)
        XCTAssertEqual(persistence.soundId(for: .arrival), SoundTriggerSlot.arrival.defaultSoundId)

        persistence.setSoundId("turbo_spool", for: .connection)
        persistence.setSoundId("crystal_ping", for: .disconnection)
        persistence.setSoundId("ready_for_launch", for: .arrival)

        let reloaded = PersistenceController(userDefaults: defaults)
        XCTAssertEqual(reloaded.soundId(for: .connection), "turbo_spool")
        XCTAssertEqual(reloaded.soundId(for: .disconnection), "crystal_ping")
        XCTAssertEqual(reloaded.soundId(for: .arrival), "ready_for_launch")
    }
}
