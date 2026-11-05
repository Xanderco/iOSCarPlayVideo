import Foundation
import AVFoundation
import Combine

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
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var isBuffering: Bool = false
    @Published public var isMuted: Bool = false

    public let player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        configureAudioSession()
        setupTimeObserver()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        statusObserver?.invalidate()
    }

    public func configureAudioSession() {
        // Offload audio session configuration to prevent UI hang risk on main thread
        Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay])
                try session.setActive(true)
            } catch {
                print("Failed to configure audio session: \(error)")
            }
        }
    }

    public func load(channel: ChannelModel) {
        self.currentChannel = channel
        let asset = AVURLAsset(url: channel.streamURL)
        let playerItem = AVPlayerItem(asset: asset)

        statusObserver?.invalidate()
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self.isBuffering = false
                } else if item.status == .failed {
                    self.isBuffering = false
                }
            }
        }

        player.replaceCurrentItem(with: playerItem)
        UsageMetricsManager.shared.recordVideoPlayed()
        play()
    }

    public func play() {
        // Free users get a daily casting allowance; Pro is unlimited.
        if let gate = entitlementGate, !gate.request(.startCasting) {
            pause()
            return
        }
        player.play()
        isPlaying = true
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
        player.pause()
        isPlaying = false
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func skip(seconds: Double) {
        let current = player.currentTime().seconds
        let target = max(0, min(current + seconds, duration > 0 ? duration : current + seconds))
        seek(to: target)
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = time.seconds
                self.trackCastingTime()
                if let item = self.player.currentItem, item.duration.seconds.isFinite {
                    self.duration = item.duration.seconds
                }
            }
        }
    }
}
