import AVFoundation
import XCTest
@testable import DashCast

final class SoundEngineTests: XCTestCase {
    private final class MockSoundAudioSession: SoundAudioSessionControlling {
        struct SetCategoryCall: Equatable {
            let category: AVAudioSession.Category
            let mode: AVAudioSession.Mode
            let options: AVAudioSession.CategoryOptions
        }

        struct SetActiveCall: Equatable {
            let active: Bool
            let options: AVAudioSession.SetActiveOptions
        }

        var categoryCalls: [SetCategoryCall] = []
        var activeCalls: [SetActiveCall] = []

        func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            options: AVAudioSession.CategoryOptions
        ) throws {
            categoryCalls.append(SetCategoryCall(category: category, mode: mode, options: options))
        }

        func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
            activeCalls.append(SetActiveCall(active: active, options: options))
        }
    }

    private actor SleepGate {
        private var continuations: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []
        private var cancelledIDs: Set<UUID> = []
        private(set) var cancelledCount: Int = 0

        var pendingCount: Int { continuations.count }

        func wait() async throws {
            try Task.checkCancellation()
            let id = UUID()
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    if cancelledIDs.remove(id) != nil {
                        cancelledCount += 1
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuations.append((id: id, continuation: continuation))
                    }
                }
            }, onCancel: {
                Task { await self.cancel(id: id) }
            })
        }

        func fireLatest() {
            guard let entry = continuations.popLast() else { return }
            entry.continuation.resume()
        }

        private func cancel(id: UUID) {
            if let index = continuations.firstIndex(where: { $0.id == id }) {
                let entry = continuations.remove(at: index)
                cancelledCount += 1
                entry.continuation.resume(throwing: CancellationError())
            } else {
                cancelledIDs.insert(id)
            }
        }
    }

    private func waitUntil(
        timeoutSeconds: TimeInterval = 2.0,
        _ condition: () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

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

    @MainActor
    func testInitDoesNotActivateAudioSession() {
        let session = MockSoundAudioSession()
        let engine = SoundPlayerEngine(
            audioSession: session,
            toneSynthesizer: { _, _ in },
            recordPlaybackMetric: {}
        )

        XCTAssertFalse(engine.isAudioSessionActive)
        XCTAssertNil(engine.currentlyPlayingId)
        XCTAssertTrue(session.categoryCalls.isEmpty)
        XCTAssertTrue(session.activeCalls.isEmpty)
    }

    @MainActor
    func testPlayActivatesAndCompletionDeactivatesWithNotifyOthers() async throws {
        let session = MockSoundAudioSession()
        let gate = SleepGate()
        let sound = try XCTUnwrap(SoundCatalogService.shared.sounds.first)

        let engine = SoundPlayerEngine(
            audioSession: session,
            sleepHandler: { _ in try await gate.wait() },
            toneSynthesizer: { _, _ in },
            recordPlaybackMetric: {}
        )

        engine.play(sound: sound)
        XCTAssertEqual(engine.currentlyPlayingId, sound.id)
        XCTAssertTrue(engine.isAudioSessionActive)
        XCTAssertEqual(session.categoryCalls.count, 1)
        XCTAssertEqual(session.categoryCalls.first?.category, .playback)
        XCTAssertEqual(session.categoryCalls.first?.options, [.duckOthers])
        XCTAssertEqual(session.activeCalls, [.init(active: true, options: [])])

        await waitUntil { await gate.pendingCount == 1 }
        await gate.fireLatest()
        await waitUntil { engine.currentlyPlayingId == nil && !engine.isAudioSessionActive }

        XCTAssertNil(engine.currentlyPlayingId)
        XCTAssertFalse(engine.isAudioSessionActive)
        XCTAssertEqual(session.activeCalls, [
            .init(active: true, options: []),
            .init(active: false, options: .notifyOthersOnDeactivation)
        ])
    }

    @MainActor
    func testStopDeactivatesSessionOnceAndIgnoresRepeatedStop() async throws {
        let session = MockSoundAudioSession()
        let gate = SleepGate()
        let sound = try XCTUnwrap(SoundCatalogService.shared.sounds.first)

        let engine = SoundPlayerEngine(
            audioSession: session,
            sleepHandler: { _ in try await gate.wait() },
            toneSynthesizer: { _, _ in },
            recordPlaybackMetric: {}
        )

        engine.play(sound: sound)
        await waitUntil { await gate.pendingCount == 1 }
        XCTAssertTrue(engine.isAudioSessionActive)

        engine.stop()
        await waitUntil { await gate.cancelledCount == 1 }
        XCTAssertNil(engine.currentlyPlayingId)
        XCTAssertFalse(engine.isAudioSessionActive)
        XCTAssertEqual(session.activeCalls, [
            .init(active: true, options: []),
            .init(active: false, options: .notifyOthersOnDeactivation)
        ])

        // Calling stop() when already idle should not deactivate again.
        engine.stop()
        XCTAssertEqual(session.activeCalls.count, 2)
    }

    @MainActor
    func testRapidPlayKeepsSessionActiveUntilLatestChimeCompletes() async throws {
        let session = MockSoundAudioSession()
        let gate = SleepGate()
        let sounds = SoundCatalogService.shared.sounds
        XCTAssertGreaterThanOrEqual(sounds.count, 2)
        let first = sounds[0]
        let second = sounds[1]

        let engine = SoundPlayerEngine(
            audioSession: session,
            sleepHandler: { _ in try await gate.wait() },
            toneSynthesizer: { _, _ in },
            recordPlaybackMetric: {}
        )

        engine.play(sound: first)
        await waitUntil { await gate.pendingCount == 1 }

        engine.play(sound: second)
        await waitUntil {
            let cancelled = await gate.cancelledCount
            let pending = await gate.pendingCount
            return cancelled == 1 && pending == 1
        }

        XCTAssertEqual(engine.currentlyPlayingId, second.id)
        XCTAssertTrue(engine.isAudioSessionActive)
        XCTAssertEqual(session.activeCalls, [.init(active: true, options: [])])

        await gate.fireLatest()
        await waitUntil { engine.currentlyPlayingId == nil && !engine.isAudioSessionActive }

        XCTAssertEqual(session.activeCalls, [
            .init(active: true, options: []),
            .init(active: false, options: .notifyOthersOnDeactivation)
        ])
    }
}
