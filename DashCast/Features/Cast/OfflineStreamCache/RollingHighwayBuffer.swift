import Foundation
import CoreMedia
import AVFoundation

public enum BufferMode: String, CaseIterable, Identifiable, Codable {
    case liveMirror
    case standard
    case highwayDeadzone

    public var id: String { rawValue }

    public var preferredDuration: TimeInterval {
        switch self {
        case .liveMirror:
            return 1.0
        case .standard:
            return 15.0
        case .highwayDeadzone:
            return 60.0
        }
    }

    public var displayName: String {
        switch self {
        case .liveMirror:
            return "Live Mirror (1s)"
        case .standard:
            return "Standard (15s)"
        case .highwayDeadzone:
            return "Highway Deadzone (60s)"
        }
    }

    public var localizedDescription: String {
        switch self {
        case .liveMirror:
            return "Lowest latency for real-time CarPlay screen mirroring."
        case .standard:
            return "Balanced buffer for city driving and stable Wi-Fi/cellular."
        case .highwayDeadzone:
            return "60-second forward buffer window to prevent stream freezes through tunnels, mountains, and remote highway cellular drops."
        }
    }
}

public enum BufferHealth: String, Codable {
    case empty
    case critical
    case adequate
    case highwayProtected

    public var displayName: String {
        switch self {
        case .empty:
            return "Empty"
        case .critical:
            return "Critical (<10s)"
        case .adequate:
            return "Adequate (10-30s)"
        case .highwayProtected:
            return "Highway Ready (60s)"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .empty:
            return "#64748B" // Slate
        case .critical:
            return "#EF4444" // Red
        case .adequate:
            return "#F59E0B" // Amber
        case .highwayProtected:
            return "#FFE600" // Racing Yellow
        }
    }
}

public struct RollingHighwayBufferController {
    public static let highwayTargetDuration: TimeInterval = 60.0
    public static let stallThresholdSeconds: TimeInterval = 3.0

    /// Returns the target forward buffer duration in seconds for the given mode.
    public static func preferredBufferDuration(for mode: BufferMode) -> TimeInterval {
        return mode.preferredDuration
    }

    /// Pure calculation of forward buffer duration from AVPlayerItem loadedTimeRanges and current playback time.
    public static func calculateForwardBufferSeconds(
        loadedTimeRanges: [NSValue],
        currentTimeSeconds: Double
    ) -> Double {
        guard currentTimeSeconds.isFinite && currentTimeSeconds >= 0 else { return 0.0 }

        var maxForwardSeconds: Double = 0.0

        for value in loadedTimeRanges {
            let timeRange = value.timeRangeValue
            let start = timeRange.start.seconds
            let duration = timeRange.duration.seconds
            guard start.isFinite, duration.isFinite else { continue }
            let end = start + duration

            if currentTimeSeconds >= start && currentTimeSeconds <= end {
                let forward = end - currentTimeSeconds
                if forward > maxForwardSeconds {
                    maxForwardSeconds = forward
                }
            }
        }

        return max(0.0, maxForwardSeconds)
    }

    /// Evaluates the buffer health based on available forward buffer seconds.
    public static func evaluateBufferHealth(forwardSeconds: Double) -> BufferHealth {
        if forwardSeconds <= 0.1 {
            return .empty
        } else if forwardSeconds < 10.0 {
            return .critical
        } else if forwardSeconds < 30.0 {
            return .adequate
        } else {
            return .highwayProtected
        }
    }

    /// Determines whether the player should failover to an offline stream cache copy.
    public static func shouldFallbackToOfflineCache(
        bufferHealth: BufferHealth,
        stallDurationSeconds: Double
    ) -> Bool {
        if stallDurationSeconds >= stallThresholdSeconds {
            return true
        }
        if bufferHealth == .empty && stallDurationSeconds >= 1.5 {
            return true
        }
        return false
    }
}
