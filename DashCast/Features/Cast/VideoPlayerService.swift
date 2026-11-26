import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
public final class VideoPlayerService: ObservableObject {
    /// The only instance that owns the lock-screen / CarPlay / headset remote commands.
    public static let shared: VideoPlayerService = {
        let service = VideoPlayerService(
            handlesRemoteCommands: true,
            networkMonitor: SystemNetworkPathMonitor()
        )
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
    /// Current stream recovery / playback health state.
    @Published public private(set) var streamHealth: StreamHealthState = .idle
    @Published public private(set) var reconnectAttempt: Int = 0
    @Published public private(set) var isNetworkAvailable: Bool = true
    /// Locks player overlay transport controls to prevent accidental passenger taps.
    @Published public private(set) var isControlsLocked: Bool = false
    @Published public var videoAspectMode: VideoAspectMode = .fit
    /// False while the app is in the background. Views must detach the player from their
    /// AVPlayerLayer then, otherwise iOS pauses video items and audio stops when the phone locks.
    @Published public private(set) var isVideoLayerAttached: Bool = true
    @Published public var isMuted: Bool = false {
        didSet { player.isMuted = isMuted }
    }

    public let player: AVPlayer = AVPlayer()
    private let reconnectPolicy: StreamReconnectPolicy
    private let idleTimerController: any IdleTimerControlling
    private let networkMonitor: any NetworkPathMonitoring
    private var timeObserverToken: Any?
    private var itemObservers: [NSKeyValueObservation] = []
    private var timeControlObserver: NSKeyValueObservation?
    private var itemNotificationTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var wantsToPlay = false
    private var reconnectTask: Task<Void, Never>?
    private var stallTask: Task<Void, Never>?
    private var failedDueToNetworkDrop = false

    /// True while playback has been requested and allowed (entitlement gate, parked-only guard).
    /// `isPlaying` instead mirrors AVPlayer's asynchronous `timeControlStatus`.
    public var isPlaybackRequested: Bool { wantsToPlay }

    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    /// Number of MPRemoteCommandCenter targets this instance registered. Exposed for tests.
    var remoteCommandTargetCount: Int { remoteCommandTargets.count }

    /// - Parameter handlesRemoteCommands: only `shared` passes `true`. Every extra instance (tests,
    ///   previews) used to add its own play/pause/toggle targets to the process-wide
    ///   `MPRemoteCommandCenter`, and a toggle delivered to two targets flips twice (= no-op).
    public init(
        handlesRemoteCommands: Bool = false,
        reconnectPolicy: StreamReconnectPolicy = .default,
        idleTimerController: (any IdleTimerControlling)? = nil,
        networkMonitor: any NetworkPathMonitoring = NoopNetworkPathMonitor()
    ) {
        self.reconnectPolicy = reconnectPolicy
        self.idleTimerController = idleTimerController ?? UIApplicationIdleTimerController.shared
        self.networkMonitor = networkMonitor
        self.isNetworkAvailable = networkMonitor.isConnected

        player.allowsExternalPlayback = true
        setupTimeObserver()
        observeTimeControlStatus()
        observeAppLifecycleAndInterruptions()
        observeNetworkPath()
        if handlesRemoteCommands { setupRemoteCommands() }
        // Route video to AirPlay / car displays and enforce the parked-only guard.
        CarVideoOutputController.shared.attach(player: player) { [weak self] in
            self?.pause()
        }
    }

    deinit {
        reconnectTask?.cancel()
        stallTask?.cancel()
        networkMonitor.stop()
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
        cancelReconnectTasks()
        reconnectAttempt = 0
        failedDueToNetworkDrop = false
        currentChannel = channel
        playbackError = nil
        currentTime = 0
        duration = 0
        isBuffering = true
        streamHealth = .buffering

        preparePlayerItem(for: channel)
        UsageMetricsManager.shared.recordVideoPlayed()
        play()
    }

    /// Reloads the active channel without resetting usage metrics or clearing the current channel.
    public func reconnectNow() {
        guard let channel = currentChannel else { return }
        cancelReconnectTasks()
        reconnectAttempt = 0
        failedDueToNetworkDrop = false
        playbackError = nil
        isBuffering = true
        streamHealth = .buffering
        preparePlayerItem(for: channel)
        play()
    }

    private func preparePlayerItem(for channel: ChannelModel) {
        let playerItem = AVPlayerItem(asset: AVURLAsset(url: channel.streamURL))
        if channel.id == CarPlayMirrorPlayback.channelID {
            // Live iPhone mirror: keep the buffer (and so the delay) short.
            playerItem.preferredForwardBufferDuration = 1
        }
        observe(item: playerItem)

        player.replaceCurrentItem(with: playerItem)
        updateNowPlayingInfo()
    }

    /// Number of live per-item KVO + NotificationCenter observers. Exposed for tests.
    var activeItemObserverCount: Int { itemObservers.count + itemNotificationTokens.count }

    /// `stop()` used to invalidate only the KVO observers, leaving the NotificationCenter block
    /// observers for the released item registered until the next `load`.
    private func removeItemObservers() {
        itemObservers.forEach { $0.invalidate() }
        itemObservers = []
        itemNotificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        itemNotificationTokens = []
    }

    private func observe(item: AVPlayerItem) {
        removeItemObservers()

        itemObservers = [
            item.observe(\.status, options: [.new]) { [weak self] item, _ in
                let status = item.status
                let seconds = item.duration.seconds
                let error = item.error
                let message = error.map(VideoPlayerService.describe)
                Task { @MainActor [weak self] in
                    guard let self, self.player.currentItem === item else { return }
                    switch status {
                    case .readyToPlay:
                        self.duration = seconds.isFinite ? seconds : 0
                        self.updateNowPlayingInfo()
                    case .failed:
                        self.handlePlaybackDrop(
                            message: message ?? "This video could not be played.",
                            error: error
                        )
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
                Task { @MainActor [weak self] in
                    self?.handlePlaybackDrop(message: message, error: error)
                }
            },
            center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.cancelReconnectTasks()
                    self.wantsToPlay = false
                    self.player.pause()
                    self.streamHealth = .idle
                    self.syncIdleTimer()
                }
            },
            center.addObserver(forName: AVPlayerItem.playbackStalledNotification, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackStall()
                }
            }
        ]
    }

    private func handlePlaybackStall() {
        guard wantsToPlay,
              reconnectPolicy.shouldAutoReconnect(
                  for: currentChannel,
                  attempt: reconnectAttempt,
                  isNetworkAvailable: isNetworkAvailable
              ) else { return }
        guard stallTask == nil, reconnectTask == nil else { return }

        let graceNs = UInt64(reconnectPolicy.stallGraceSeconds * 1_000_000_000)
        stallTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: graceNs)
            guard !Task.isCancelled, let self else { return }
            self.stallTask = nil
            // If playback already resumed during the grace window, do nothing.
            guard self.wantsToPlay, !self.isPlaying else { return }
            self.scheduleReconnect(fallbackMessage: "Stream stalled.")
        }
    }

    private func handlePlaybackDrop(message: String, error: Error?) {
        let isTransient = error.map(StreamReconnectPolicy.isTransientNetworkError) ?? true
        if wantsToPlay,
           isTransient,
           reconnectPolicy.shouldAutoReconnect(
               for: currentChannel,
               attempt: reconnectAttempt,
               isNetworkAvailable: isNetworkAvailable
           ) {
            scheduleReconnect(fallbackMessage: message)
            return
        }
        handleFailure(message, dueToNetworkDrop: !isNetworkAvailable || isTransient)
    }

    private func scheduleReconnect(fallbackMessage: String) {
        guard let channel = currentChannel else { return }
        let nextAttempt = reconnectAttempt + 1
        guard reconnectPolicy.shouldAutoReconnect(
            for: channel,
            attempt: reconnectAttempt,
            isNetworkAvailable: isNetworkAvailable
        ) else {
            handleFailure(fallbackMessage, dueToNetworkDrop: !isNetworkAvailable)
            return
        }

        reconnectTask?.cancel()
        stallTask?.cancel()
        stallTask = nil
        reconnectAttempt = nextAttempt
        playbackError = nil
        isBuffering = true
        isPlaying = false
        streamHealth = .reconnecting(attempt: nextAttempt, maxAttempts: reconnectPolicy.maxAttempts)
        syncIdleTimer()

        let delayNs = UInt64(reconnectPolicy.delay(forAttempt: nextAttempt) * 1_000_000_000)
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, let self else { return }
            self.reconnectTask = nil
            guard self.wantsToPlay, self.currentChannel?.id == channel.id else { return }
            self.preparePlayerItem(for: channel)
            self.play()
        }
    }

    private func cancelReconnectTasks() {
        reconnectTask?.cancel()
        reconnectTask = nil
        stallTask?.cancel()
        stallTask = nil
    }

    private func handleFailure(_ message: String, dueToNetworkDrop: Bool = false) {
        cancelReconnectTasks()
        wantsToPlay = false
        isBuffering = false
        isPlaying = false
        failedDueToNetworkDrop = dueToNetworkDrop
        playbackError = message
        streamHealth = .failed(message)
        player.pause()
        syncIdleTimer()
    }

    /// Exposed for unit testing deterministic failure/stall transitions.
    func simulatePlaybackFailureForTesting(_ error: Error, message: String? = nil) {
        handlePlaybackDrop(message: message ?? Self.describe(error), error: error)
    }

    func simulatePlaybackStallForTesting() {
        handlePlaybackStall()
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
        // Parked-only guard: never start video on a car display while moving.
        guard CarVideoOutputController.shared.canStartVideoOutput() else {
            pause()
            return
        }
        // Free users get a daily casting allowance; Pro is unlimited.
        if let gate = entitlementGate, !gate.request(.startCasting) {
            pause()
            return
        }
        wantsToPlay = true
        if !isPlaying && !streamHealth.isReconnecting {
            streamHealth = .buffering
        }
        configureAudioSession()
        player.play()
        lastCastingTick = Date()
        syncIdleTimer()
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
        cancelReconnectTasks()
        wantsToPlay = false
        player.pause()
        if let error = playbackError {
            streamHealth = .failed(error)
        } else {
            streamHealth = .idle
        }
        syncIdleTimer()
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
        cancelReconnectTasks()
        wantsToPlay = false
        reconnectAttempt = 0
        failedDueToNetworkDrop = false
        isControlsLocked = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeItemObservers()
        currentChannel = nil
        playbackError = nil
        isBuffering = false
        streamHealth = .idle
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        syncIdleTimer()
    }

    public func toggleControlsLock() {
        isControlsLocked.toggle()
    }

    public func setControlsLocked(_ locked: Bool) {
        isControlsLocked = locked
    }

    public func toggleVideoAspectMode() {
        videoAspectMode = videoAspectMode.toggled()
    }

    private func syncIdleTimer() {
        let shouldDisableIdleTimer = isVideoLayerAttached
            && currentChannel != nil
            && (isPlaying || streamHealth.isReconnecting)
        if idleTimerController.isIdleTimerDisabled != shouldDisableIdleTimer {
            idleTimerController.isIdleTimerDisabled = shouldDisableIdleTimer
        }
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
                switch status {
                case .playing:
                    self.stallTask?.cancel()
                    self.stallTask = nil
                    self.reconnectTask?.cancel()
                    self.reconnectTask = nil
                    self.reconnectAttempt = 0
                    self.failedDueToNetworkDrop = false
                    self.streamHealth = .playing
                case .waitingToPlayAtSpecifiedRate:
                    if !self.streamHealth.isReconnecting && self.playbackError == nil {
                        self.streamHealth = .buffering
                    }
                case .paused:
                    if !self.streamHealth.isReconnecting && self.playbackError == nil {
                        self.streamHealth = .idle
                    }
                @unknown default:
                    break
                }
                self.syncIdleTimer()
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

    private func observeNetworkPath() {
        networkMonitor.onStatusChange = { [weak self] connected in
            Task { @MainActor [weak self] in
                self?.handleNetworkChange(connected)
            }
        }
        networkMonitor.start()
    }

    private func handleNetworkChange(_ connected: Bool) {
        isNetworkAvailable = connected
        guard connected,
              let channel = currentChannel,
              !channel.streamURL.isFileURL else { return }
        if streamHealth.isReconnecting || (failedDueToNetworkDrop && streamHealth.isFailed) {
            reconnectNow()
        }
    }

    private func observeAppLifecycleAndInterruptions() {
        let center = NotificationCenter.default
        center.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isVideoLayerAttached = false
                    self?.syncIdleTimer()
                }
            }
            .store(in: &cancellables)

        center.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isVideoLayerAttached = true
                    self?.syncIdleTimer()
                }
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
        let play = commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        let pause = commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        let toggle = commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        remoteCommandTargets = [(commands.playCommand, play),
                                (commands.pauseCommand, pause),
                                (commands.togglePlayPauseCommand, toggle)]
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
