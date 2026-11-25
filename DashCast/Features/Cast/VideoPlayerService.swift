import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
public final class VideoPlayerService: ObservableObject {
    /// The only instance that owns the lock-screen / CarPlay / headset remote commands.
    public static let shared: VideoPlayerService = {
        let service = VideoPlayerService(handlesRemoteCommands: true)
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
    @Published public private(set) var availableAudioTracks: [MediaTrackOption] = []
    @Published public private(set) var availableSubtitleTracks: [MediaTrackOption] = []
    @Published public private(set) var selectedAudioTrack: MediaTrackOption?
    @Published public private(set) var selectedSubtitleTrack: MediaTrackOption?
    @Published public private(set) var hasSavedTrackPreferences: Bool = false

    public let player: AVPlayer = AVPlayer()
    public let trackSelectionPolicy: MediaTrackSelectionPolicy
    private var timeObserverToken: Any?
    private var itemObservers: [NSKeyValueObservation] = []
    private var timeControlObserver: NSKeyValueObservation?
    private var itemNotificationTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var wantsToPlay = false
    private var audibleGroup: AVMediaSelectionGroup?
    private var legibleGroup: AVMediaSelectionGroup?
    private var trackDiscoveryTask: Task<Void, Never>?
    private var hasAppliedInitialTrackPreferencesForCurrentItem = false

    /// True while playback has been requested and allowed (entitlement gate, parked-only guard).
    /// `isPlaying` instead mirrors AVPlayer's asynchronous `timeControlStatus`.
    public var isPlaybackRequested: Bool { wantsToPlay }

    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    /// Number of MPRemoteCommandCenter targets this instance registered. Exposed for tests.
    var remoteCommandTargetCount: Int { remoteCommandTargets.count }

    /// - Parameter handlesRemoteCommands: only `shared` passes `true`. Every extra instance (tests,
    ///   previews) used to add its own play/pause/toggle targets to the process-wide
    ///   `MPRemoteCommandCenter`, and a toggle delivered to two targets flips twice (= no-op).
    public init(handlesRemoteCommands: Bool = false, defaults: UserDefaults = .standard) {
        let policy = MediaTrackSelectionPolicy(defaults: defaults)
        self.trackSelectionPolicy = policy
        self.hasSavedTrackPreferences = policy.hasSavedPreferences
        player.allowsExternalPlayback = true
        setupTimeObserver()
        observeTimeControlStatus()
        observeAppLifecycleAndInterruptions()
        if handlesRemoteCommands { setupRemoteCommands() }
        // Route video to AirPlay / car displays and enforce the parked-only guard.
        CarVideoOutputController.shared.attach(player: player) { [weak self] in
            self?.pause()
        }
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
        resetMediaTracksState()

        let playerItem = AVPlayerItem(asset: AVURLAsset(url: channel.streamURL))
        if channel.id == CarPlayMirrorPlayback.channelID {
            // Live iPhone mirror: keep the buffer (and so the delay) short.
            playerItem.preferredForwardBufferDuration = 1
        }
        observe(item: playerItem)

        player.replaceCurrentItem(with: playerItem)
        updateNowPlayingInfo()
        UsageMetricsManager.shared.recordVideoPlayed()
        play()
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
                let message = item.error.map(VideoPlayerService.describe)
                Task { @MainActor [weak self] in
                    guard let self, self.player.currentItem === item else { return }
                    switch status {
                    case .readyToPlay:
                        self.duration = seconds.isFinite ? seconds : 0
                        self.updateNowPlayingInfo()
                        self.loadMediaTracks(for: item, applyPreferences: !self.hasAppliedInitialTrackPreferencesForCurrentItem)
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
            },
            center.addObserver(forName: AVPlayerItem.mediaSelectionDidChangeNotification, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.player.currentItem === item else { return }
                    self.loadMediaTracks(for: item, applyPreferences: false)
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
        removeItemObservers()
        resetMediaTracksState()
        currentChannel = nil
        playbackError = nil
        isBuffering = false
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Audio & Subtitle Track Selection

    public func refreshMediaTracks() {
        guard let item = player.currentItem else {
            resetMediaTracksState()
            return
        }
        loadMediaTracks(for: item, applyPreferences: false)
    }

    public func selectAudioTrack(_ track: MediaTrackOption) {
        trackSelectionPolicy.recordAudioSelection(track)
        hasSavedTrackPreferences = trackSelectionPolicy.hasSavedPreferences
        selectedAudioTrack = track

        guard let item = player.currentItem,
              let group = audibleGroup,
              let index = track.optionIndex,
              group.options.indices.contains(index) else {
            return
        }
        let targetOption = group.options[index]
        if item.currentMediaSelection.selectedMediaOption(in: group) !== targetOption {
            item.select(targetOption, in: group)
        }
    }

    public func selectSubtitleTrack(_ track: MediaTrackOption?) {
        let effectiveTrack = (track?.isOff == true) ? nil : track
        trackSelectionPolicy.recordSubtitleSelection(effectiveTrack)
        hasSavedTrackPreferences = trackSelectionPolicy.hasSavedPreferences
        selectedSubtitleTrack = effectiveTrack

        guard let item = player.currentItem, let group = legibleGroup else {
            return
        }

        if let effectiveTrack,
           let index = effectiveTrack.optionIndex,
           group.options.indices.contains(index) {
            let targetOption = group.options[index]
            if item.currentMediaSelection.selectedMediaOption(in: group) !== targetOption {
                item.select(targetOption, in: group)
            }
        } else if group.allowsEmptySelection {
            if item.currentMediaSelection.selectedMediaOption(in: group) != nil {
                item.select(nil, in: group)
            }
        }
    }

    public func clearTrackPreferences() {
        trackSelectionPolicy.clearPreferences()
        hasSavedTrackPreferences = trackSelectionPolicy.hasSavedPreferences
    }

    private func resetMediaTracksState() {
        trackDiscoveryTask?.cancel()
        trackDiscoveryTask = nil
        audibleGroup = nil
        legibleGroup = nil
        availableAudioTracks = []
        availableSubtitleTracks = []
        selectedAudioTrack = nil
        selectedSubtitleTrack = nil
        hasAppliedInitialTrackPreferencesForCurrentItem = false
    }

    private func loadMediaTracks(for item: AVPlayerItem, applyPreferences: Bool) {
        trackDiscoveryTask?.cancel()
        trackDiscoveryTask = Task { @MainActor [weak self] in
            guard let self, self.player.currentItem === item else { return }
            let asset = item.asset
            let characteristics = (try? await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)) ?? []
            guard !Task.isCancelled, self.player.currentItem === item else { return }

            var loadedAudible: AVMediaSelectionGroup?
            var loadedLegible: AVMediaSelectionGroup?
            if characteristics.contains(.audible) {
                loadedAudible = try? await asset.loadMediaSelectionGroup(for: .audible)
            }
            if characteristics.contains(.legible) {
                loadedLegible = try? await asset.loadMediaSelectionGroup(for: .legible)
            }
            guard !Task.isCancelled, self.player.currentItem === item else { return }

            self.applyLoadedMediaGroups(
                item: item,
                audibleGroup: loadedAudible,
                legibleGroup: loadedLegible,
                applyPreferences: applyPreferences
            )
        }
    }

    private func applyLoadedMediaGroups(
        item: AVPlayerItem,
        audibleGroup: AVMediaSelectionGroup?,
        legibleGroup: AVMediaSelectionGroup?,
        applyPreferences: Bool
    ) {
        self.audibleGroup = audibleGroup
        self.legibleGroup = legibleGroup

        let audioOptions = MediaTrackSelectionPolicy.buildOptions(from: audibleGroup, kind: .audio)
        let subtitleOptions = MediaTrackSelectionPolicy.buildOptions(from: legibleGroup, kind: .subtitle)

        self.availableAudioTracks = audioOptions
        self.availableSubtitleTracks = subtitleOptions

        if applyPreferences {
            hasAppliedInitialTrackPreferencesForCurrentItem = true
            if let preferredAudio = trackSelectionPolicy.resolveAutoAudioOption(from: audioOptions),
               let index = preferredAudio.optionIndex,
               let audibleGroup,
               audibleGroup.options.indices.contains(index) {
                let option = audibleGroup.options[index]
                if item.currentMediaSelection.selectedMediaOption(in: audibleGroup) !== option {
                    item.select(option, in: audibleGroup)
                }
            }

            if let legibleGroup {
                if trackSelectionPolicy.areSubtitlesExplicitlyOff {
                    if legibleGroup.allowsEmptySelection,
                       item.currentMediaSelection.selectedMediaOption(in: legibleGroup) != nil {
                        item.select(nil, in: legibleGroup)
                    }
                } else if let preferredSub = trackSelectionPolicy.resolveAutoSubtitleOption(from: subtitleOptions),
                          let index = preferredSub.optionIndex,
                          legibleGroup.options.indices.contains(index) {
                    let option = legibleGroup.options[index]
                    if item.currentMediaSelection.selectedMediaOption(in: legibleGroup) !== option {
                        item.select(option, in: legibleGroup)
                    }
                }
            }
        }

        let currentSelection = item.currentMediaSelection
        if let audibleGroup, let activeAudio = currentSelection.selectedMediaOption(in: audibleGroup),
           let activeAudioIndex = audibleGroup.options.firstIndex(where: { $0 === activeAudio }) {
            self.selectedAudioTrack = audioOptions.first(where: { $0.optionIndex == activeAudioIndex })
        } else {
            self.selectedAudioTrack = audioOptions.first
        }

        if let legibleGroup, let activeSub = currentSelection.selectedMediaOption(in: legibleGroup),
           let activeSubIndex = legibleGroup.options.firstIndex(where: { $0 === activeSub }) {
            self.selectedSubtitleTrack = subtitleOptions.first(where: { $0.optionIndex == activeSubIndex })
        } else {
            self.selectedSubtitleTrack = nil
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
