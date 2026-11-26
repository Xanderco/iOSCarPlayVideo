import XCTest
@testable import DashCast

@MainActor
final class PlayerControlsVisibilityTests: XCTestCase {
    private actor SleepGate {
        private var continuations: [(id: UUID, delay: TimeInterval, continuation: CheckedContinuation<Void, Error>)] = []
        private var cancelledIDs: Set<UUID> = []
        private(set) var cancelledCount: Int = 0

        var pendingCount: Int { continuations.count }
        var lastRequestedDelay: TimeInterval? { continuations.last?.delay }

        func wait(delay: TimeInterval) async throws {
            try Task.checkCancellation()
            let id = UUID()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    if cancelledIDs.remove(id) != nil {
                        cancelledCount += 1
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuations.append((id: id, delay: delay, continuation: continuation))
                    }
                }
            } onCancel: {
                Task { await self.cancel(id: id) }
            }
        }

        func fireOldest() {
            guard !continuations.isEmpty else { return }
            let entry = continuations.removeFirst()
            entry.continuation.resume()
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

    private func pumpMainRunLoop() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }

    func testAutoHidesAfterDelayWhilePlaying() async {
        let gate = SleepGate()
        let model = PlayerControlsVisibilityModel(autoHideDelay: 4.0) { delay in
            try await gate.wait(delay: delay)
        }

        XCTAssertTrue(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)

        model.updatePlaybackState(isPlaying: true, hasError: false)
        await pumpMainRunLoop()

        XCTAssertTrue(model.isAutoHideScheduled)
        let delay = await gate.lastRequestedDelay
        XCTAssertEqual(delay ?? 0, 4.0, accuracy: 0.001)
        XCTAssertTrue(model.showControls)

        await gate.fireLatest()
        await pumpMainRunLoop()

        XCTAssertFalse(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)
    }

    func testStaysVisibleWhenPausedAndReappearsOnPause() async {
        let gate = SleepGate()
        let model = PlayerControlsVisibilityModel(autoHideDelay: 4.0) { delay in
            try await gate.wait(delay: delay)
        }

        // Start playing and let controls auto-hide
        model.updatePlaybackState(isPlaying: true, hasError: false)
        await pumpMainRunLoop()
        await gate.fireLatest()
        await pumpMainRunLoop()
        XCTAssertFalse(model.showControls)

        // Pausing restores controls and keeps auto-hide disabled
        model.updatePlaybackState(isPlaying: false, hasError: false)
        await pumpMainRunLoop()
        XCTAssertTrue(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)
    }

    func testStaysVisibleWhenErrored() async {
        let gate = SleepGate()
        let model = PlayerControlsVisibilityModel(autoHideDelay: 4.0) { delay in
            try await gate.wait(delay: delay)
        }

        model.updatePlaybackState(isPlaying: true, hasError: false)
        await pumpMainRunLoop()
        XCTAssertTrue(model.isAutoHideScheduled)

        // Playback error cancels timer and keeps controls visible; taps cannot hide it
        model.updatePlaybackState(isPlaying: true, hasError: true)
        await pumpMainRunLoop()
        XCTAssertTrue(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)

        model.handleTap()
        XCTAssertTrue(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)
    }

    func testTapTogglesControlsAndResetsCountdown() async {
        let gate = SleepGate()
        let model = PlayerControlsVisibilityModel(autoHideDelay: 4.0) { delay in
            try await gate.wait(delay: delay)
        }

        model.updatePlaybackState(isPlaying: true, hasError: false)
        await pumpMainRunLoop()
        XCTAssertTrue(model.showControls)
        XCTAssertTrue(model.isAutoHideScheduled)

        // First tap hides immediately and cancels timer
        model.handleTap()
        await pumpMainRunLoop()
        XCTAssertFalse(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)

        // Second tap shows controls and arms a fresh countdown
        model.handleTap()
        await pumpMainRunLoop()
        XCTAssertTrue(model.showControls)
        XCTAssertTrue(model.isAutoHideScheduled)

        await gate.fireLatest()
        await pumpMainRunLoop()
        XCTAssertFalse(model.showControls)
    }

    func testSeekingCancelsAutoHideUntilSeekEnds() async {
        let gate = SleepGate()
        let model = PlayerControlsVisibilityModel(autoHideDelay: 4.0) { delay in
            try await gate.wait(delay: delay)
        }

        model.updatePlaybackState(isPlaying: true, hasError: false)
        await pumpMainRunLoop()
        XCTAssertTrue(model.isAutoHideScheduled)

        model.beginSeeking()
        await pumpMainRunLoop()
        XCTAssertTrue(model.isSeeking)
        XCTAssertTrue(model.showControls)
        XCTAssertFalse(model.isAutoHideScheduled)

        model.endSeeking()
        await pumpMainRunLoop()
        XCTAssertFalse(model.isSeeking)
        XCTAssertTrue(model.showControls)
        XCTAssertTrue(model.isAutoHideScheduled)

        await gate.fireLatest()
        await pumpMainRunLoop()
        XCTAssertFalse(model.showControls)
    }

    func testRegisterInteractionCancelsPreviousTimerAndRearms() async {
        let gate = SleepGate()
        let model = PlayerControlsVisibilityModel(autoHideDelay: 4.0) { delay in
            try await gate.wait(delay: delay)
        }

        model.updatePlaybackState(isPlaying: true, hasError: false)
        await pumpMainRunLoop()

        // User interacts -> previous timer cancelled, new timer armed
        model.registerInteraction()
        await pumpMainRunLoop()
        XCTAssertTrue(model.showControls)
        XCTAssertTrue(model.isAutoHideScheduled)
        let pending = await gate.pendingCount
        let cancelled = await gate.cancelledCount
        XCTAssertEqual(pending, 1)
        XCTAssertEqual(cancelled, 1)

        // Firing the newly armed timer hides controls
        await gate.fireLatest()
        await pumpMainRunLoop()
        XCTAssertFalse(model.showControls)
    }

    func testPlayerLocalizationKeysExistInCatalog() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])

        let expectedKeys = [
            "Close player",
            "Enter fullscreen",
            "Exit fullscreen",
            "Play",
            "Pause",
            "Skip back 10 seconds",
            "Skip forward 10 seconds"
        ]

        for key in expectedKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            let enValue = (localizations["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            let esValue = (localizations["es"]?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertFalse(enValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty EN value for \(key)")
            XCTAssertFalse(esValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Empty ES value for \(key)")
        }
    }
}
