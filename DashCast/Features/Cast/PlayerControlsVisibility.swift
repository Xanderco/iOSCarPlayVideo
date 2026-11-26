import Foundation
import Combine

/// Coordinates auto-hiding of the video player controls overlay while playing.
/// Controls hide after `autoHideDelay` (~4s) of active playback, reset on tap or seek,
/// and stay visible whenever playback is paused, stopped, or showing an error.
@MainActor
public final class PlayerControlsVisibilityModel: ObservableObject {
    public static let defaultAutoHideDelay: TimeInterval = 4.0

    @Published public private(set) var showControls: Bool = true
    @Published public private(set) var isSeeking: Bool = false

    public let autoHideDelay: TimeInterval
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    private var isPlaying: Bool = false
    private var hasError: Bool = false
    private var hideTask: Task<Void, Never>?

    public init(
        autoHideDelay: TimeInterval = PlayerControlsVisibilityModel.defaultAutoHideDelay,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.autoHideDelay = autoHideDelay
        self.sleep = sleep
    }

    /// True while a countdown is armed and awaiting auto-hide.
    public var isAutoHideScheduled: Bool { hideTask != nil }

    public func updatePlaybackState(isPlaying: Bool, hasError: Bool) {
        self.isPlaying = isPlaying
        self.hasError = hasError

        if hasError || !isPlaying {
            cancelAutoHide()
            showControls = true
            return
        }

        if showControls && !isSeeking && hideTask == nil {
            scheduleAutoHide()
        }
    }

    public func handleTap() {
        guard !hasError else {
            cancelAutoHide()
            showControls = true
            return
        }

        showControls.toggle()
        if showControls {
            rescheduleIfEligible()
        } else {
            cancelAutoHide()
        }
    }

    public func registerInteraction() {
        guard !hasError else { return }
        showControls = true
        rescheduleIfEligible()
    }

    public func beginSeeking() {
        isSeeking = true
        showControls = true
        cancelAutoHide()
    }

    public func endSeeking() {
        isSeeking = false
        rescheduleIfEligible()
    }

    public func cancelAutoHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func rescheduleIfEligible() {
        cancelAutoHide()
        guard showControls, isPlaying, !isSeeking, !hasError else { return }
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        cancelAutoHide()
        guard autoHideDelay > 0 else {
            showControls = false
            return
        }

        let delay = autoHideDelay
        let sleeper = sleep
        hideTask = Task { [weak self] in
            do {
                try await sleeper(delay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            guard self.isPlaying, !self.isSeeking, !self.hasError else {
                self.hideTask = nil
                return
            }
            self.showControls = false
            self.hideTask = nil
        }
    }
}
