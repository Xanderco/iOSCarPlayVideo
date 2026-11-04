import Foundation
import AVFoundation
import Combine

@MainActor
public final class VideoPlayerService: ObservableObject {
    public static let shared = VideoPlayerService()

    @Published public private(set) var currentChannel: ChannelModel?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var isBuffering: Bool = false
    @Published public var isMuted: Bool = false
    @Published public private(set) var isOfflinePlayback: Bool = false
    @Published public private(set) var isDeadzoneFallbackActive: Bool = false
    @Published public private(set) var activeCacheItem: DeadzoneCacheItem? = nil

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

        let playerItem: AVPlayerItem
        if let localURL = DeadzoneCacheService.shared.localURL(for: channel.streamURL) {
            self.isOfflinePlayback = true
            self.activeCacheItem = DeadzoneCacheService.shared.item(for: channel.streamURL)
            if let cacheId = self.activeCacheItem?.id {
                DeadzoneCacheService.shared.touchItem(id: cacheId)
            }
            playerItem = AVPlayerItem(url: localURL)
        } else {
            self.isOfflinePlayback = false
            self.activeCacheItem = nil
            let asset = AVURLAsset(url: channel.streamURL)
            playerItem = AVPlayerItem(asset: asset)
        }

        statusObserver?.invalidate()
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self.isBuffering = false
                } else if item.status == .failed {
                    self.isBuffering = false
                    if !self.isOfflinePlayback {
                        self.triggerDeadzoneFallback()
                    }
                }
            }
        }

        player.replaceCurrentItem(with: playerItem)
        UsageMetricsManager.shared.recordVideoPlayed()
        play()
    }

    /// Automatically triggers seamless switchover to preloaded offline deadzone cache when cellular drops
    public func triggerDeadzoneFallback() {
        guard !isDeadzoneFallbackActive else { return }
        if let fallbackChannel = DeadzoneCacheService.shared.firstAvailableOfflineChannel() {
            self.isDeadzoneFallbackActive = true
            self.load(channel: fallbackChannel)
        }
    }

    public func play() {
        player.play()
        isPlaying = true
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
                if let item = self.player.currentItem, item.duration.seconds.isFinite {
                    self.duration = item.duration.seconds
                }
            }
        }
    }
}
