import Foundation
import CoreHaptics
import UIKit
import Combine

/// Functional category for automotive cabin tactile cues.
public enum CabinHapticCategory: String, Codable, CaseIterable, Sendable {
    case safety
    case connection
    case playback
    case performance
    case navigation

    public var displayName: String {
        switch self {
        case .safety: return "Safety"
        case .connection: return "Connection"
        case .playback: return "Playback"
        case .performance: return "Performance"
        case .navigation: return "Navigation"
        }
    }
}

/// Calibrated automotive haptic cue identifiers.
public enum CabinHapticCue: String, Codable, CaseIterable, Identifiable, Sendable {
    case streamBuffering
    case streamReady
    case carConnected
    case carDisconnected
    case speedWarning
    case harshDrivingEvent
    case launchStaged
    case launchReady
    case blindSelect

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .streamBuffering: return "Stream Buffering"
        case .streamReady: return "Stream Ready"
        case .carConnected: return "Car Display Connected"
        case .carDisconnected: return "Car Display Disconnected"
        case .speedWarning: return "Speed Warning"
        case .harshDrivingEvent: return "Harsh Driving Alert"
        case .launchStaged: return "Launch Staged"
        case .launchReady: return "Launch Ready"
        case .blindSelect: return "Tactile Select"
        }
    }

    public var subtitle: String {
        switch self {
        case .streamBuffering: return "Subtle dual-tick cadence when stream buffering begins"
        case .streamReady: return "Rising chime pulse when video playback locks in"
        case .carConnected: return "Ascending chime pulse for car display or AirPlay link"
        case .carDisconnected: return "Descending release pulse on display disconnect"
        case .speedWarning: return "Heavy double warning thud when exceeding threshold"
        case .harshDrivingEvent: return "Low-frequency impact thud for abrupt braking or cornering"
        case .launchStaged: return "Sustained low-frequency launch stage rumble"
        case .launchReady: return "Crisp high-sharpness launch release confirmation"
        case .blindSelect: return "Clean tactile detent for eyes-free control taps"
        }
    }

    public var category: CabinHapticCategory {
        switch self {
        case .streamBuffering, .streamReady: return .playback
        case .carConnected, .carDisconnected: return .connection
        case .speedWarning, .harshDrivingEvent: return .safety
        case .launchStaged, .launchReady: return .performance
        case .blindSelect: return .navigation
        }
    }

    /// Critical driver safety and disconnect cues remain active while driving;
    /// non-critical playback, navigation, and setup cues are suppressed in motion.
    public var allowsWhileMoving: Bool {
        switch self {
        case .speedWarning, .harshDrivingEvent, .carDisconnected:
            return true
        case .streamBuffering, .streamReady, .carConnected, .launchStaged, .launchReady, .blindSelect:
            return false
        }
    }

    /// Safety alerts bypass Quiet Mode so speed/harsh-driving feedback is never silenced unintentionally.
    public var bypassesQuietMode: Bool {
        category == .safety
    }

    /// Minimum interval between repeated triggers of the same cue to avoid continuous buzzing.
    public var defaultCooldownSeconds: TimeInterval {
        switch self {
        case .speedWarning: return 5.0
        case .harshDrivingEvent: return 3.0
        case .carConnected, .carDisconnected, .streamBuffering, .streamReady: return 2.0
        case .launchStaged, .launchReady: return 1.0
        case .blindSelect: return 0.15
        }
    }

    /// Calibrated CoreHaptics waveform specification.
    public var waveform: CabinHapticWaveformSpec {
        switch self {
        case .streamBuffering:
            return CabinHapticWaveformSpec(
                patternFamily: "Buffer Cadence",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.42, sharpness: 0.62),
                    HapticEventSpec(kind: .transient, relativeTime: 0.14, duration: 0.0, intensity: 0.36, sharpness: 0.55)
                ]
            )
        case .streamReady:
            return CabinHapticWaveformSpec(
                patternFamily: "Chime Pulse",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.55, sharpness: 0.68),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.03, duration: 0.18, intensity: 0.40, sharpness: 0.50),
                    HapticEventSpec(kind: .transient, relativeTime: 0.22, duration: 0.0, intensity: 0.72, sharpness: 0.80)
                ]
            )
        case .carConnected:
            return CabinHapticWaveformSpec(
                patternFamily: "Chime Pulse",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.62, sharpness: 0.72),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.05, duration: 0.22, intensity: 0.48, sharpness: 0.58),
                    HapticEventSpec(kind: .transient, relativeTime: 0.28, duration: 0.0, intensity: 0.85, sharpness: 0.88)
                ]
            )
        case .carDisconnected:
            return CabinHapticWaveformSpec(
                patternFamily: "Chime Pulse",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.75, sharpness: 0.65),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.04, duration: 0.24, intensity: 0.45, sharpness: 0.28)
                ]
            )
        case .speedWarning:
            return CabinHapticWaveformSpec(
                patternFamily: "Warning Thud",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.95, sharpness: 0.22),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.02, duration: 0.18, intensity: 0.88, sharpness: 0.16),
                    HapticEventSpec(kind: .transient, relativeTime: 0.26, duration: 0.0, intensity: 1.00, sharpness: 0.24),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.28, duration: 0.22, intensity: 0.92, sharpness: 0.15)
                ]
            )
        case .harshDrivingEvent:
            return CabinHapticWaveformSpec(
                patternFamily: "Warning Thud",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.90, sharpness: 0.25),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.02, duration: 0.20, intensity: 0.78, sharpness: 0.18)
                ]
            )
        case .launchStaged:
            return CabinHapticWaveformSpec(
                patternFamily: "Launch Stage Rumble",
                events: [
                    HapticEventSpec(kind: .continuous, relativeTime: 0.00, duration: 0.20, intensity: 0.55, sharpness: 0.18),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.22, duration: 0.24, intensity: 0.72, sharpness: 0.24)
                ]
            )
        case .launchReady:
            return CabinHapticWaveformSpec(
                patternFamily: "Launch Stage Rumble",
                events: [
                    HapticEventSpec(kind: .continuous, relativeTime: 0.00, duration: 0.12, intensity: 0.65, sharpness: 0.30),
                    HapticEventSpec(kind: .transient, relativeTime: 0.14, duration: 0.0, intensity: 0.95, sharpness: 0.88)
                ]
            )
        case .blindSelect:
            return CabinHapticWaveformSpec(
                patternFamily: "Tactile Detent",
                events: [
                    HapticEventSpec(kind: .transient, relativeTime: 0.00, duration: 0.0, intensity: 0.55, sharpness: 0.68),
                    HapticEventSpec(kind: .continuous, relativeTime: 0.01, duration: 0.03, intensity: 0.22, sharpness: 0.42)
                ]
            )
        }
    }
}

/// Platform-independent CoreHaptics event descriptor for calibrated waveform composition and testing.
public struct HapticEventSpec: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case transient
        case continuous
    }

    public let kind: Kind
    public let relativeTime: TimeInterval
    public let duration: TimeInterval
    public let intensity: Float
    public let sharpness: Float

    public init(kind: Kind, relativeTime: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) {
        self.kind = kind
        self.relativeTime = relativeTime
        self.duration = duration
        self.intensity = intensity
        self.sharpness = sharpness
    }
}

/// Calibrated waveform container that builds `CHHapticPattern` instances safely.
public struct CabinHapticWaveformSpec: Equatable, Sendable {
    public let patternFamily: String
    public let events: [HapticEventSpec]

    public init(patternFamily: String, events: [HapticEventSpec]) {
        self.patternFamily = patternFamily
        self.events = events
    }

    public var totalDuration: TimeInterval {
        events.map { $0.relativeTime + $0.duration }.max() ?? 0
    }

    public func scaledIntensity(_ raw: Float, scale: Float) -> Float {
        min(max(raw * min(max(scale, 0.0), 1.0), 0.0), 1.0)
    }

    public func buildCHHapticPattern(intensityScale: Float = 1.0) throws -> CHHapticPattern {
        let chEvents: [CHHapticEvent] = events.map { spec in
            let scaled = scaledIntensity(spec.intensity, scale: intensityScale)
            let params = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: scaled),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(spec.sharpness, 0.0), 1.0))
            ]
            switch spec.kind {
            case .transient:
                return CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: spec.relativeTime)
            case .continuous:
                return CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: params,
                    relativeTime: spec.relativeTime,
                    duration: max(spec.duration, 0.02)
                )
            }
        }
        return try CHHapticPattern(events: chEvents, parameters: [])
    }
}

/// Reason a haptic cue was suppressed by the cabin safety policy.
public enum CabinHapticSuppressionReason: String, Codable, Equatable, Sendable {
    case hapticsDisabled
    case suppressedWhileMoving
    case quietModeActive
    case cooldownActive
    case speedWarningDisabled

    public var localizedLabel: String {
        switch self {
        case .hapticsDisabled: return "Haptics Off"
        case .suppressedWhileMoving: return "Suppressed (Moving)"
        case .quietModeActive: return "Quiet Mode"
        case .cooldownActive: return "Cooldown"
        case .speedWarningDisabled: return "Speed Alerts Off"
        }
    }
}

/// Result of attempting to trigger a cabin haptic cue.
public enum CabinHapticTriggerOutcome: Equatable, Sendable {
    case triggered(cue: CabinHapticCue, usedCoreHaptics: Bool)
    case suppressed(cue: CabinHapticCue, reason: CabinHapticSuppressionReason)

    public var didTrigger: Bool {
        if case .triggered = self { return true }
        return false
    }

    public var suppressionReason: CabinHapticSuppressionReason? {
        if case .suppressed(_, let reason) = self { return reason }
        return nil
    }
}

/// Diagnostic history record for UI inspection and verification.
public struct CabinHapticTriggerRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let cue: CabinHapticCue
    public let triggered: Bool
    public let suppressionReason: CabinHapticSuppressionReason?
    public let speedKmh: Double
    public let wasMoving: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        cue: CabinHapticCue,
        triggered: Bool,
        suppressionReason: CabinHapticSuppressionReason? = nil,
        speedKmh: Double,
        wasMoving: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cue = cue
        self.triggered = triggered
        self.suppressionReason = suppressionReason
        self.speedKmh = speedKmh
        self.wasMoving = wasMoving
    }
}

/// Pure, deterministic policy evaluator for motion-aware haptic triggering and suppression.
public struct CabinHapticsPolicy: Sendable {
    public static func evaluateSuppression(
        cue: CabinHapticCue,
        isHapticsEnabled: Bool,
        suppressNonCriticalWhileMoving: Bool,
        isVehicleMoving: Bool,
        isQuietModeEnabled: Bool,
        isSpeedWarningEnabled: Bool,
        bypassMotionSuppression: Bool = false,
        lastTriggeredAt: Date?,
        now: Date
    ) -> CabinHapticSuppressionReason? {
        guard isHapticsEnabled else {
            return .hapticsDisabled
        }

        if cue == .speedWarning && !isSpeedWarningEnabled && !bypassMotionSuppression {
            return .speedWarningDisabled
        }

        if isQuietModeEnabled && !cue.bypassesQuietMode && !bypassMotionSuppression {
            return .quietModeActive
        }

        if !bypassMotionSuppression && suppressNonCriticalWhileMoving && isVehicleMoving && !cue.allowsWhileMoving {
            return .suppressedWhileMoving
        }

        if !bypassMotionSuppression, let lastTriggeredAt {
            let elapsed = now.timeIntervalSince(lastTriggeredAt)
            if elapsed >= 0 && elapsed < cue.defaultCooldownSeconds {
                return .cooldownActive
            }
        }

        return nil
    }
}

/// Automotive cabin tactile feedback engine and steering vibration signaler powered by CoreHaptics.
@MainActor
public final class CabinHapticsEngine: ObservableObject {
    public static let shared = CabinHapticsEngine()

    public static let movingSpeedThresholdKmh: Double = 8.0
    public static let defaultSpeedWarningLimitKmh: Double = 120.0
    public static let maxHistoryCount: Int = 25

    private enum StorageKeys {
        static let enabled = "dashcast_haptics_enabled_v1"
        static let suppressMoving = "dashcast_haptics_suppress_moving_v1"
        static let speedWarningEnabled = "dashcast_haptics_speed_warning_enabled_v1"
        static let speedWarningLimitKmh = "dashcast_haptics_speed_limit_kmh_v1"
        static let quietMode = "dashcast_haptics_quiet_mode_v1"
        static let intensityScale = "dashcast_haptics_intensity_scale_v1"
    }

    @Published public var isHapticsEnabled: Bool {
        didSet { userDefaults.set(isHapticsEnabled, forKey: StorageKeys.enabled) }
    }

    @Published public var suppressNonCriticalWhileMoving: Bool {
        didSet { userDefaults.set(suppressNonCriticalWhileMoving, forKey: StorageKeys.suppressMoving) }
    }

    @Published public var isSpeedWarningEnabled: Bool {
        didSet { userDefaults.set(isSpeedWarningEnabled, forKey: StorageKeys.speedWarningEnabled) }
    }

    @Published public var speedWarningLimitKmh: Double {
        didSet {
            let clamped = min(max(speedWarningLimitKmh, 40.0), 220.0)
            if clamped != speedWarningLimitKmh {
                speedWarningLimitKmh = clamped
                return
            }
            userDefaults.set(clamped, forKey: StorageKeys.speedWarningLimitKmh)
        }
    }

    @Published public var isQuietModeEnabled: Bool {
        didSet { userDefaults.set(isQuietModeEnabled, forKey: StorageKeys.quietMode) }
    }

    @Published public var intensityScale: Double {
        didSet {
            let clamped = min(max(intensityScale, 0.3), 1.0)
            if clamped != intensityScale {
                intensityScale = clamped
                return
            }
            userDefaults.set(clamped, forKey: StorageKeys.intensityScale)
        }
    }

    @Published public private(set) var isVehicleMoving: Bool = false
    @Published public private(set) var currentSpeedKmh: Double = 0.0
    @Published public private(set) var supportsCoreHaptics: Bool = false
    @Published public private(set) var lastOutcome: CabinHapticTriggerOutcome?
    @Published public private(set) var triggerHistory: [CabinHapticTriggerRecord] = []

    private let userDefaults: UserDefaults
    private let enableHardwareEngine: Bool
    private var hapticEngine: CHHapticEngine?
    private var lastTriggeredByCue: [CabinHapticCue: Date] = [:]

    public init(userDefaults: UserDefaults = .standard, enableHardwareEngine: Bool = true) {
        self.userDefaults = userDefaults
        self.enableHardwareEngine = enableHardwareEngine

        self.isHapticsEnabled = userDefaults.object(forKey: StorageKeys.enabled) as? Bool ?? true
        self.suppressNonCriticalWhileMoving = userDefaults.object(forKey: StorageKeys.suppressMoving) as? Bool ?? true
        self.isSpeedWarningEnabled = userDefaults.object(forKey: StorageKeys.speedWarningEnabled) as? Bool ?? true
        let savedLimit = userDefaults.object(forKey: StorageKeys.speedWarningLimitKmh) as? Double ?? Self.defaultSpeedWarningLimitKmh
        self.speedWarningLimitKmh = min(max(savedLimit, 40.0), 220.0)
        self.isQuietModeEnabled = userDefaults.object(forKey: StorageKeys.quietMode) as? Bool ?? false
        let savedScale = userDefaults.object(forKey: StorageKeys.intensityScale) as? Double ?? 1.0
        self.intensityScale = min(max(savedScale, 0.3), 1.0)

        if enableHardwareEngine {
            self.supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
            if self.supportsCoreHaptics {
                prepareCoreHapticsEngine()
            }
        }
    }

    // MARK: - Public Controls & Telemetry

    /// Updates motion state from `ParkedGuard` or external telemetry.
    public func updateMotionState(isMoving: Bool, speedKmh: Double? = nil) {
        isVehicleMoving = isMoving
        if let speedKmh {
            currentSpeedKmh = max(0, speedKmh)
        }
    }

    /// Evaluates GPS / CoreMotion telemetry and fires `.speedWarning` when exceeding the configured threshold.
    @discardableResult
    public func evaluateTelemetry(
        speedKmh: Double,
        isAutomotiveMoving: Bool? = nil,
        now: Date = Date()
    ) -> CabinHapticTriggerOutcome? {
        let normalizedSpeed = max(0, speedKmh)
        currentSpeedKmh = normalizedSpeed
        isVehicleMoving = normalizedSpeed >= Self.movingSpeedThresholdKmh || isAutomotiveMoving == true

        if normalizedSpeed >= speedWarningLimitKmh {
            return trigger(.speedWarning, now: now)
        }
        return nil
    }

    /// Triggers a calibrated haptic cue subject to motion suppression, quiet mode, and cooldown rules.
    @discardableResult
    public func trigger(
        _ cue: CabinHapticCue,
        bypassMotionSuppression: Bool = false,
        now: Date = Date()
    ) -> CabinHapticTriggerOutcome {
        if let suppressionReason = CabinHapticsPolicy.evaluateSuppression(
            cue: cue,
            isHapticsEnabled: isHapticsEnabled,
            suppressNonCriticalWhileMoving: suppressNonCriticalWhileMoving,
            isVehicleMoving: isVehicleMoving,
            isQuietModeEnabled: isQuietModeEnabled,
            isSpeedWarningEnabled: isSpeedWarningEnabled,
            bypassMotionSuppression: bypassMotionSuppression,
            lastTriggeredAt: lastTriggeredByCue[cue],
            now: now
        ) {
            let outcome = CabinHapticTriggerOutcome.suppressed(cue: cue, reason: suppressionReason)
            record(outcome: outcome, cue: cue, at: now)
            return outcome
        }

        lastTriggeredByCue[cue] = now
        let usedCoreHaptics = playWaveform(for: cue)
        let outcome = CabinHapticTriggerOutcome.triggered(cue: cue, usedCoreHaptics: usedCoreHaptics)
        record(outcome: outcome, cue: cue, at: now)
        return outcome
    }

    /// Manual preview helper for testing calibrated waveforms from the Cabin Haptics sheet.
    @discardableResult
    public func preview(_ cue: CabinHapticCue, now: Date = Date()) -> CabinHapticTriggerOutcome {
        trigger(cue, bypassMotionSuppression: true, now: now)
    }

    public func resetSessionState() {
        lastTriggeredByCue.removeAll()
        triggerHistory.removeAll()
        lastOutcome = nil
        isVehicleMoving = false
        currentSpeedKmh = 0.0
    }

    // MARK: - CoreHaptics Execution

    private func prepareCoreHapticsEngine() {
        guard enableHardwareEngine, supportsCoreHaptics, hapticEngine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.hapticEngine = nil
                }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    try? self?.hapticEngine?.start()
                }
            }
            try engine.start()
            self.hapticEngine = engine
        } catch {
            self.hapticEngine = nil
        }
    }

    private func playWaveform(for cue: CabinHapticCue) -> Bool {
        guard enableHardwareEngine else { return false }

        if supportsCoreHaptics {
            if hapticEngine == nil {
                prepareCoreHapticsEngine()
            }
            if let engine = hapticEngine {
                do {
                    try engine.start()
                    let pattern = try cue.waveform.buildCHHapticPattern(intensityScale: Float(intensityScale))
                    let player = try engine.makePlayer(with: pattern)
                    try player.start(atTime: CHHapticTimeImmediate)
                    return true
                } catch {
                    // Fall through to UIKit feedback generator if CoreHaptics runtime is interrupted.
                }
            }
        }

        playFallbackUIKitFeedback(for: cue)
        return false
    }

    private func playFallbackUIKitFeedback(for cue: CabinHapticCue) {
        let scale = CGFloat(intensityScale)
        switch cue {
        case .speedWarning, .harshDrivingEvent:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        case .carConnected, .streamReady, .launchReady:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .carDisconnected, .launchStaged:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred(intensity: scale)
        case .streamBuffering, .blindSelect:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred(intensity: scale)
        }
    }

    private func record(outcome: CabinHapticTriggerOutcome, cue: CabinHapticCue, at date: Date) {
        lastOutcome = outcome
        let entry = CabinHapticTriggerRecord(
            timestamp: date,
            cue: cue,
            triggered: outcome.didTrigger,
            suppressionReason: outcome.suppressionReason,
            speedKmh: currentSpeedKmh,
            wasMoving: isVehicleMoving
        )
        triggerHistory.insert(entry, at: 0)
        if triggerHistory.count > Self.maxHistoryCount {
            triggerHistory.removeLast(triggerHistory.count - Self.maxHistoryCount)
        }
    }
}
