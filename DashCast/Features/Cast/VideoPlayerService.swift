import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
public final class VideoPlayerService: ObservableObject {
    public static let shared: VideoPlayerService = {
        let service = VideoPlayerService()
        service.entitlementGate = .shared
        return service
    }()

    /// Free-tier casting allowance. `nil` (tests, previews) means unrestricted.
    public var entitlementGate: EntitlementGate?
    private var lastCastingTick: Date?
    private var pendingCastingSeconds: TimeInterval = 0

    @Published public private(set) var currentChannel: ChannelModel?
    /// Mirrors the player's real `timeControlStatus` (not just the last button tap).
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var isBuffering: Bool = false
    /// Human readable reason the current item failed to load/play, if any.
    @Published public private(set) var playbackError: String?
    /// False while the app is in the background. Views must detach the player from their
    /// AVPlayerLayer then, otherwise iOS pauses video items and audio stops when the phone locks.
    @Published public private(set) var isVideoLayerAttached: Bool = true
    @Published public var isMuted: Bool = false {
        didSet { player.isMuted = isMuted }
    }

    public let player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var itemObservers: [NSKeyValueObservation] = []
    private var timeControlObserver: NSKeyValueObservation?
    private var itemNotificationTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var wantsToPlay = false

    public init() {
        player.allowsExternalPlayback = true
        setupTimeObserver()
        observeTimeControlStatus()
        observeAppLifecycleAndInterruptions()
        setupRemoteCommands()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    // MARK: - Audio session

    /// The audio session options used for video playback.
    /// `.allowBluetoothHFP` / `.allowAirPlay` / `.allowBluetoothA2DP` are only valid for
    /// `.playAndRecord`; passing them with `.playback` makes `setCategory` throw (-50), which left
    /// the app on the default `.soloAmbient` category: no background audio, muted by the silent switch.
    /// `.playback` already routes to AirPlay, A2DP and CarPlay by default.
    nonisolated public static let audioSessionOptions: AVAudioSession.CategoryOptions = []

    /// Sets the category without activating the session (activation interrupts other audio, e.g.
    /// the user's music, so it is deferred until playback actually starts).
    nonisolated public static func configureAudioSessionCategory(_ session: AVAudioSession = .sharedInstance()) throws {
        try session.setCategory(.playback, mode: .moviePlayback, options: audioSessionOptions)
    }

    public func configureAudioSession() {
        Task.detached(priority: .userInitiated) {
            do {
                try VideoPlayerService.configureAudioSessionCategory()
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to configure audio session: \(error)")
            }
        }
    }

    // MARK: - Loading

    public func load(channel: ChannelModel) {
        currentChannel = channel
        playbackError = nil
        currentTime = 0
        duration = 0
        isBuffering = true

        let playerItem = AVPlayerItem(asset: AVURLAsset(url: channel.streamURL))
        observe(item: playerItem)

        player.replaceCurrentItem(with: playerItem)
        updateNowPlayingInfo()
        UsageMetricsManager.shared.recordVideoPlayed()
        play()
    }

    private func observe(item: AVPlayerItem) {
        itemObservers.forEach { $0.invalidate() }
        itemNotificationTokens.forEach { NotificationCenter.default.removeObserver($0) }

        itemObservers = [
            item.observe(\.status, options: [.new]) { [weak self] item, _ in
                let status = item.status
                let seconds = item.duration.seconds
                let message = item.error.map(VideoPlayerService.describe)
                Task { @MainActor [weak self] in
                    guard let self, self.player.currentItem === item else { return }
                    switch status {
                    case .readyToPlay:
                        self.duration = seconds.isFinite ? seconds : 0
                        self.updateNowPlayingInfo()
                    case .failed:
                        self.handleFailure(message ?? "This video could not be played.")
                    default:
                        break
                    }
                }
            }
        ]

        let center = NotificationCenter.default
        itemNotificationTokens = [
            center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main) { [weak self] note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                let message = error.map(VideoPlayerService.describe) ?? "Playback stopped unexpectedly."
                Task { @MainActor [weak self] in self?.handleFailure(message) }
            },
            center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.wantsToPlay = false
                    self?.player.pause()
                }
            }
        ]
    }

    private func handleFailure(_ message: String) {
        wantsToPlay = false
        isBuffering = false
        isPlaying = false
        playbackError = message
        player.pause()
    }

    nonisolated static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return "Network error: \(underlying.localizedDescription)"
        }
        if ns.domain == NSURLErrorDomain {
            return "Network error: \(ns.localizedDescription)"
        }
        return ns.localizedFailureReason ?? ns.localizedDescription
    }

    // MARK: - Transport

    public func play() {
        guard player.currentItem != nil else { return }
        // Free users get a daily casting allowance; Pro is unlimited.
        if let gate = entitlementGate, !gate.request(.startCasting) {
            pause()
            return
        }
        wantsToPlay = true
        configureAudioSession()
        player.play()
        lastCastingTick = Date()
    }

    /// Charges elapsed playback time to the free-tier allowance and stops playback when it runs out.
    private func trackCastingTime() {
        guard let gate = entitlementGate, isPlaying, player.rate > 0 else {
            lastCastingTick = nil
            return
        }
        let now = Date()
        defer { lastCastingTick = now }
        guard let last = lastCastingTick else { return }
        pendingCastingSeconds += min(max(now.timeIntervalSince(last), 0), 5)
        let remaining = gate.remainingCastingSeconds
        // Flush every few seconds, or immediately when the allowance is about to run out.
        guard pendingCastingSeconds >= 5 || pendingCastingSeconds >= remaining else { return }
        let seconds = pendingCastingSeconds
        pendingCastingSeconds = 0
        if !gate.recordCasting(seconds: seconds) {
            pause()
        }
    }

    public func pause() {
        wantsToPlay = false
        player.pause()
    }

    public func togglePlayPause() {
        if isPlaying || wantsToPlay {
            pause()
        } else {
            if let item = player.currentItem,
               item.duration.isNumeric,
               player.currentTime() >= item.duration {
                seek(to: 0)
            }
            play()
        }
    }

    public func stop() {
        wantsToPlay = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObservers.forEach { $0.invalidate() }
        itemObservers = []
        currentChannel = nil
        playbackError = nil
        isBuffering = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func skip(seconds: Double) {
        let current = player.currentTime().seconds
        guard current.isFinite else { return }
        seek(to: Self.clampedSkipTarget(current: current, delta: seconds, duration: duration))
    }

    /// Pure helper so the clamp logic is unit-testable. A duration of 0 means live/unknown.
    nonisolated public static func clampedSkipTarget(current: Double, delta: Double, duration: Double) -> Double {
        let target = current + delta
        if duration > 0 {
            return max(0, min(target, duration))
        }
        return max(0, target)
    }

    // MARK: - Observation

    private func observeTimeControlStatus() {
        timeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = status == .playing
                self.isBuffering = status == .waitingToPlayAtSpecifiedRate
                self.updateNowPlayingInfo()
            }
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                if time.seconds.isFinite { self.currentTime = time.seconds }
                self.trackCastingTime()
                if let item = self.player.currentItem, item.duration.seconds.isFinite {
                    self.duration = item.duration.seconds
                }
            }
        }
    }

    private func observeAppLifecycleAndInterruptions() {
        let center = NotificationCenter.default
        center.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.isVideoLayerAttached = false }
            }
            .store(in: &cancellables)

        center.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.isVideoLayerAttached = true }
            }
            .store(in: &cancellables)

        center.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let info = note.userInfo,
                      let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
                let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if type == .ended,
                       AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume),
                       self.wantsToPlay {
                        self.player.play()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lock screen / CarPlay Now Playing

    private func setupRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let channel = currentChannel else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: channel.name,
            MPMediaItemPropertyAlbumTitle: channel.groupTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: duration <= 0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
