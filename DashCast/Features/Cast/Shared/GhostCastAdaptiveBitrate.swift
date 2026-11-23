import Foundation
import CoreMedia

/// GhostCast Smart Adaptive Bitrate (ABR) profiles for wireless CarPlay video streaming.
///
/// Wireless CarPlay runs over a local Wi-Fi peer-to-peer connection between iPhone and the
/// head unit. Head-unit Wi-Fi chips often experience interference and packet jitter. Hardcoded
/// bitrates cause severe frame stuttering and buffer under-runs. GhostCast dynamically switches
/// encoding profiles between 1080p@60fps (6 Mbps) and 720p@30fps (2.5 Mbps) based on socket
/// write queue depth and network RTT.
enum GhostCastProfile: String, CaseIterable, Equatable, Sendable {
    case high1080p60 = "1080p@60fps (6 Mbps)"
    case medium720p30 = "720p@30fps (2.5 Mbps)"
    case low540p24 = "540p@24fps (1.2 Mbps)"

    var resolution: (width: Int, height: Int) {
        switch self {
        case .high1080p60: return (1920, 1080)
        case .medium720p30: return (1280, 720)
        case .low540p24: return (960, 540)
        }
    }

    var framesPerSecond: Int {
        switch self {
        case .high1080p60: return 60
        case .medium720p30: return 30
        case .low540p24: return 24
        }
    }

    var bitRate: Int {
        switch self {
        case .high1080p60: return 6_000_000
        case .medium720p30: return 2_500_000
        case .low540p24: return 1_200_000
        }
    }

    var encoderConfig: MirrorEncoderConfig {
        switch self {
        case .high1080p60:
            return .ghostCast1080p60
        case .medium720p30:
            return .ghostCast720p30
        case .low540p24:
            return MirrorEncoderConfig(
                maxLongSide: 960,
                maxShortSide: 540,
                framesPerSecond: 24,
                averageBitRate: 1_200_000,
                keyFrameIntervalSeconds: 1,
                segmentDurationSeconds: 1,
                playlistWindow: 4
            )
        }
    }
}

/// Operational thresholds governing GhostCast ABR scaling decisions.
struct GhostCastThresholds: Equatable, Sendable {
    /// When write queue depth exceeds this number of frames, downgrade immediately to prevent buffer bloat.
    var queueDepthDowngradeLimit: Int
    /// When write queue depth is at or below this limit, stream is eligible for upgrade.
    var queueDepthUpgradeLimit: Int
    /// Round-trip time (in seconds) exceeding this threshold indicates Wi-Fi congestion / packet jitter.
    var rttDowngradeThreshold: TimeInterval
    /// Round-trip time (in seconds) at or below this threshold is considered healthy low latency.
    var rttUpgradeThreshold: TimeInterval
    /// Consecutive healthy samples required before upgrading to the next higher profile.
    var consecutiveStableSamplesRequired: Int
    /// Severe queue depth indicating critical packet loss requiring emergency drop to lowest tier.
    var severeQueueDepthLimit: Int

    static let `default` = GhostCastThresholds(
        queueDepthDowngradeLimit: 3,
        queueDepthUpgradeLimit: 1,
        rttDowngradeThreshold: 0.150, // 150 ms
        rttUpgradeThreshold: 0.050,   // 50 ms
        consecutiveStableSamplesRequired: 3,
        severeQueueDepthLimit: 6
    )

    init(
        queueDepthDowngradeLimit: Int = 3,
        queueDepthUpgradeLimit: Int = 1,
        rttDowngradeThreshold: TimeInterval = 0.150,
        rttUpgradeThreshold: TimeInterval = 0.050,
        consecutiveStableSamplesRequired: Int = 3,
        severeQueueDepthLimit: Int = 6
    ) {
        self.queueDepthDowngradeLimit = queueDepthDowngradeLimit
        self.queueDepthUpgradeLimit = queueDepthUpgradeLimit
        self.rttDowngradeThreshold = rttDowngradeThreshold
        self.rttUpgradeThreshold = rttUpgradeThreshold
        self.consecutiveStableSamplesRequired = consecutiveStableSamplesRequired
        self.severeQueueDepthLimit = severeQueueDepthLimit
    }
}

/// Controller managing dynamic bitrate and resolution adaptation for GhostCast.
/// Thread-safe for invocation from network callback queues and sample handlers.
final class GhostCastAdaptiveBitrateController: @unchecked Sendable {
    let thresholds: GhostCastThresholds
    private let lock = NSLock()

    private var _activeProfile: GhostCastProfile = .high1080p60
    private var _currentRTT: TimeInterval = 0
    private var _currentQueueDepth: Int = 0
    private var _isCongestionDetected: Bool = false
    private var _stableSampleCount: Int = 0
    private var _totalAdaptationEvents: Int = 0

    var onProfileChanged: ((GhostCastProfile) -> Void)?

    var activeProfile: GhostCastProfile {
        lock.lock(); defer { lock.unlock() }
        return _activeProfile
    }

    var currentRTT: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return _currentRTT
    }

    var currentQueueDepth: Int {
        lock.lock(); defer { lock.unlock() }
        return _currentQueueDepth
    }

    var isCongestionDetected: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCongestionDetected
    }

    var totalAdaptationEvents: Int {
        lock.lock(); defer { lock.unlock() }
        return _totalAdaptationEvents
    }

    init(
        initialProfile: GhostCastProfile = .high1080p60,
        thresholds: GhostCastThresholds = .default
    ) {
        self._activeProfile = initialProfile
        self.thresholds = thresholds
    }

    /// Evaluates current socket write queue depth and frame delivery RTT,
    /// triggering downscaling or upgrading as appropriate.
    @discardableResult
    func recordSample(queueDepth: Int, rtt: TimeInterval) -> GhostCastProfile {
        lock.lock()
        _currentQueueDepth = max(0, queueDepth)
        _currentRTT = max(0, rtt)

        let isQueueCongested = _currentQueueDepth > thresholds.queueDepthDowngradeLimit
        let isRTTJitter = _currentRTT > thresholds.rttDowngradeThreshold
        let isCongested = isQueueCongested || isRTTJitter

        _isCongestionDetected = isCongested

        var profileChanged = false
        var targetProfile = _activeProfile

        if isCongested {
            _stableSampleCount = 0
            // Check for severe congestion
            if _currentQueueDepth >= thresholds.severeQueueDepthLimit || _currentRTT >= (thresholds.rttDowngradeThreshold * 2.5) {
                if _activeProfile != .low540p24 {
                    targetProfile = .low540p24
                    profileChanged = true
                }
            } else if _activeProfile == .high1080p60 {
                // Requirement 2: Dynamically downscale from 1080p@60fps (6 Mbps) to 720p@30fps (2.5 Mbps) when write queue depth > 3
                targetProfile = .medium720p30
                profileChanged = true
            }
        } else if _currentQueueDepth <= thresholds.queueDepthUpgradeLimit && _currentRTT <= thresholds.rttUpgradeThreshold {
            _stableSampleCount += 1
            if _stableSampleCount >= thresholds.consecutiveStableSamplesRequired {
                _stableSampleCount = 0
                if _activeProfile == .low540p24 {
                    targetProfile = .medium720p30
                    profileChanged = true
                } else if _activeProfile == .medium720p30 {
                    targetProfile = .high1080p60
                    profileChanged = true
                }
            }
        } else {
            // In intermediate state: hold current profile without resetting stability counter entirely
            _stableSampleCount = max(0, _stableSampleCount - 1)
        }

        if profileChanged {
            _activeProfile = targetProfile
            _totalAdaptationEvents += 1
        }
        let updatedProfile = _activeProfile
        let notify = profileChanged ? onProfileChanged : nil
        lock.unlock()

        if let notify {
            notify(updatedProfile)
        }
        return updatedProfile
    }

    /// Resets the controller state to initial configuration.
    func reset(to profile: GhostCastProfile = .high1080p60) {
        lock.lock()
        _activeProfile = profile
        _currentRTT = 0
        _currentQueueDepth = 0
        _isCongestionDetected = false
        _stableSampleCount = 0
        _totalAdaptationEvents = 0
        lock.unlock()
    }
}
