import Foundation
import SwiftUI
import Combine
import MediaPlayer
#if canImport(CarPlay)
import CarPlay
#endif

/// Acceleration mathematical models for vehicle rotary knobs (BMW iDrive, Mazda Commander, Mercedes COMAND).
/// Higher rotation speeds dynamically scale item jump strides to allow rapid playlist navigation
/// without causing driver distraction.
public enum RotaryScrollAccelerationCurve: String, CaseIterable, Codable {
    case linear = "linear"
    case parabolic = "parabolic"
    case stepped = "stepped"

    public var title: String {
        switch self {
        case .linear: return "Linear"
        case .parabolic: return "Parabolic"
        case .stepped: return "Stepped"
        }
    }

    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .linear: return "Linear"
        case .parabolic: return "Parabolic"
        case .stepped: return "Stepped"
        }
    }

    public var formulaDescription: String {
        switch self {
        case .linear: return "Constant proportional acceleration (1x to 8x)"
        case .parabolic: return "Quadratic curve: smooth low-speed precision, explosive high-speed scrolling"
        case .stepped: return "4 distinct automotive click velocity tiers (1x, 2x, 5x, 10x)"
        }
    }
}

/// Operational modes for steering wheel next/previous track hardware buttons.
public enum SteeringWheelControlMode: String, CaseIterable, Codable {
    case channelSwitching = "channel_switching"
    case trackSeeking = "track_seeking"
    case disabled = "disabled"

    public var title: String {
        switch self {
        case .channelSwitching: return "Channel Switching"
        case .trackSeeking: return "Track Seeking (15s)"
        case .disabled: return "Disabled"
        }
    }

    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .channelSwitching: return "Channel Switching"
        case .trackSeeking: return "Track Seeking (15s)"
        case .disabled: return "Disabled"
        }
    }
}

/// Focus navigation and rotary dial acceleration engine tailored for CarPlay physical rotary dials
/// and steering wheel track buttons.
@MainActor
public final class CarPlayRotaryNavigationService: ObservableObject {
    public static let shared = CarPlayRotaryNavigationService()

    public enum Keys {
        public static let accelerationCurve = "dashcast_rotary_acceleration_curve"
        public static let steeringWheelMode = "dashcast_steering_wheel_mode"
        public static let wrapAround = "dashcast_rotary_wrap_around"
        public static let hapticFeedback = "dashcast_rotary_haptics"
        public static let maxStride = "dashcast_rotary_max_stride"
    }

    /// Notification posted when the active channel is switched via steering wheel hardware buttons.
    public static let channelDidSwitchNotification = Notification.Name("CarPlayRotaryChannelDidSwitch")

    // MARK: - Published Properties

    /// Active index of the focused element in the current CarPlay or automotive view list.
    @Published public private(set) var focusedIndex: Int = 0

    /// Total number of items in the navigable list container.
    @Published public var itemCount: Int = 0 {
        didSet {
            validateFocusBounds()
        }
    }

    /// Whether rotary hardware navigation is actively driving focus.
    @Published public private(set) var isRotaryNavigationActive: Bool = false

    /// The selected scroll acceleration mathematical curve.
    @Published public var accelerationCurve: RotaryScrollAccelerationCurve {
        didSet {
            UserDefaults.standard.set(accelerationCurve.rawValue, forKey: Keys.accelerationCurve)
        }
    }

    /// Hardware steering wheel button control mode.
    @Published public var steeringWheelMode: SteeringWheelControlMode {
        didSet {
            UserDefaults.standard.set(steeringWheelMode.rawValue, forKey: Keys.steeringWheelMode)
            updateRemoteCommandsRegistration()
        }
    }

    /// Whether reaching the boundary wraps around to the beginning or end of the list.
    @Published public var isWrapAroundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isWrapAroundEnabled, forKey: Keys.wrapAround)
        }
    }

    /// Maximum accelerated step stride when spinning the rotary knob at maximum speed.
    @Published public var maxStride: Int {
        didSet {
            let clamped = max(2, min(25, maxStride))
            if clamped != maxStride {
                maxStride = clamped
            } else {
                UserDefaults.standard.set(maxStride, forKey: Keys.maxStride)
            }
        }
    }

    /// Real-time calculated velocity multiplier of the last rotary click (1x, 2x, etc.).
    @Published public private(set) var currentVelocityMultiplier: Int = 1

    /// Real-time label describing the current rotary scroll status.
    @Published public private(set) var statusLabel: String = "Rotary Ready"

    // MARK: - Private State

    private var lastClickTime: Date?
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    private var isAttached: Bool = false

    // Tuning constants for automotive rotary dials
    public let slowIntervalThreshold: TimeInterval = 0.28
    public let fastIntervalThreshold: TimeInterval = 0.06

    // MARK: - Initialization

    public init() {
        let storedCurve = UserDefaults.standard.string(forKey: Keys.accelerationCurve)
            .flatMap { RotaryScrollAccelerationCurve(rawValue: $0) } ?? .parabolic
        self.accelerationCurve = storedCurve

        let storedMode = UserDefaults.standard.string(forKey: Keys.steeringWheelMode)
            .flatMap { SteeringWheelControlMode(rawValue: $0) } ?? .channelSwitching
        self.steeringWheelMode = storedMode

        if UserDefaults.standard.object(forKey: Keys.wrapAround) != nil {
            self.isWrapAroundEnabled = UserDefaults.standard.bool(forKey: Keys.wrapAround)
        } else {
            self.isWrapAroundEnabled = true
        }

        if UserDefaults.standard.object(forKey: Keys.maxStride) != nil {
            let stored = UserDefaults.standard.integer(forKey: Keys.maxStride)
            self.maxStride = max(2, min(25, stored))
        } else {
            self.maxStride = 10
        }
    }

    // MARK: - Scene Attachment

    /// Connects to CarPlay and registers steering wheel hardware media controls.
    public func attach() {
        guard !isAttached else { return }
        isAttached = true
        isRotaryNavigationActive = true
        updateRemoteCommandsRegistration()
    }

    /// Detaches when CarPlay session ends.
    public func detach() {
        guard isAttached else { return }
        isAttached = false
        isRotaryNavigationActive = false
        removeRemoteCommands()
    }

    // MARK: - Rotary Focus Traversal

    /// Advances focus forwards (clockwise knob turn) with velocity acceleration.
    @discardableResult
    public func moveFocusNext(clicks: Int = 1, timestamp: Date = Date()) -> Int {
        let stride = calculateAcceleratedStride(timestamp: timestamp)
        let totalSteps = max(1, clicks) * stride
        currentVelocityMultiplier = stride
        isRotaryNavigationActive = true

        guard itemCount > 0 else {
            focusedIndex = 0
            return 0
        }

        if isWrapAroundEnabled {
            focusedIndex = (focusedIndex + totalSteps) % itemCount
        } else {
            focusedIndex = min(itemCount - 1, focusedIndex + totalSteps)
        }

        statusLabel = "Rotary Next (+\(totalSteps))"
        return focusedIndex
    }

    /// Reverses focus backwards (counter-clockwise knob turn) with velocity acceleration.
    @discardableResult
    public func moveFocusPrevious(clicks: Int = 1, timestamp: Date = Date()) -> Int {
        let stride = calculateAcceleratedStride(timestamp: timestamp)
        let totalSteps = max(1, clicks) * stride
        currentVelocityMultiplier = stride
        isRotaryNavigationActive = true

        guard itemCount > 0 else {
            focusedIndex = 0
            return 0
        }

        if isWrapAroundEnabled {
            focusedIndex = ((focusedIndex - totalSteps) % itemCount + itemCount) % itemCount
        } else {
            focusedIndex = max(0, focusedIndex - totalSteps)
        }

        statusLabel = "Rotary Prev (-\(totalSteps))"
        return focusedIndex
    }

    /// Direct focus assignment.
    public func setFocusedIndex(_ index: Int) {
        guard itemCount > 0 else {
            focusedIndex = 0
            return
        }
        focusedIndex = max(0, min(itemCount - 1, index))
    }

    /// Resets focus to the beginning.
    public func resetFocus() {
        focusedIndex = 0
        currentVelocityMultiplier = 1
        lastClickTime = nil
        statusLabel = "Rotary Ready"
    }

    // MARK: - Mathematical Acceleration Curves

    /// Calculates the accelerated step stride based on time delta between consecutive rotary clicks.
    public func calculateAcceleratedStride(timestamp: Date = Date()) -> Int {
        let delta: TimeInterval
        if let last = lastClickTime {
            delta = max(0.001, timestamp.timeIntervalSince(last))
        } else {
            delta = 1.0 // Initial click is unaccelerated
        }
        lastClickTime = timestamp

        return computeStride(for: delta, curve: accelerationCurve, maxStride: maxStride)
    }

    /// Pure function for unit testing acceleration formulas.
    public func computeStride(for delta: TimeInterval, curve: RotaryScrollAccelerationCurve, maxStride: Int) -> Int {
        guard delta < slowIntervalThreshold else {
            return 1
        }

        let clampedDelta = max(fastIntervalThreshold, min(slowIntervalThreshold, delta))
        let normalizedSpeed = (slowIntervalThreshold - clampedDelta) / (slowIntervalThreshold - fastIntervalThreshold) // 0.0 to 1.0

        switch curve {
        case .linear:
            let additional = Double(maxStride - 1) * normalizedSpeed
            return max(1, min(maxStride, 1 + Int(additional.rounded())))

        case .parabolic:
            // Quadratic ease-in: Stays close to 1x for deliberate turns, accelerates rapidly past 50% speed
            let quadFactor = normalizedSpeed * normalizedSpeed
            let additional = Double(maxStride - 1) * quadFactor
            return max(1, min(maxStride, 1 + Int(additional.rounded())))

        case .stepped:
            // Distinct automotive tiers matching physical detent feelings
            if delta <= 0.08 {
                return min(maxStride, 10)
            } else if delta <= 0.14 {
                return min(maxStride, 5)
            } else if delta <= 0.22 {
                return min(maxStride, 2)
            } else {
                return 1
            }
        }
    }

    // MARK: - Steering Wheel Hardware Commands

    private func updateRemoteCommandsRegistration() {
        removeRemoteCommands()

        guard steeringWheelMode != .disabled else { return }

        let center = MPRemoteCommandCenter.shared()

        let nextTarget = center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            return self.handleNextTrackCommand()
        }
        center.nextTrackCommand.isEnabled = true
        remoteCommandTargets.append((center.nextTrackCommand, nextTarget))

        let prevTarget = center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            return self.handlePreviousTrackCommand()
        }
        center.previousTrackCommand.isEnabled = true
        remoteCommandTargets.append((center.previousTrackCommand, prevTarget))
    }

    private func removeRemoteCommands() {
        for (cmd, token) in remoteCommandTargets {
            cmd.removeTarget(token)
            cmd.isEnabled = false
        }
        remoteCommandTargets.removeAll()
    }

    /// Handles steering wheel Next Track press.
    @discardableResult
    public func handleNextTrackCommand() -> MPRemoteCommandHandlerStatus {
        switch steeringWheelMode {
        case .channelSwitching:
            let switched = VideoPlayerService.shared.playNextChannel()
            if switched {
                postChannelSwitchNotification(direction: "next")
                return .success
            }
            return .noActionableNowPlayingItem

        case .trackSeeking:
            VideoPlayerService.shared.skip(seconds: 15)
            return .success

        case .disabled:
            return .commandFailed
        }
    }

    /// Handles steering wheel Previous Track press.
    @discardableResult
    public func handlePreviousTrackCommand() -> MPRemoteCommandHandlerStatus {
        switch steeringWheelMode {
        case .channelSwitching:
            let switched = VideoPlayerService.shared.playPreviousChannel()
            if switched {
                postChannelSwitchNotification(direction: "previous")
                return .success
            }
            return .noActionableNowPlayingItem

        case .trackSeeking:
            VideoPlayerService.shared.skip(seconds: -15)
            return .success

        case .disabled:
            return .commandFailed
        }
    }

    private func postChannelSwitchNotification(direction: String) {
        NotificationCenter.default.post(
            name: Self.channelDidSwitchNotification,
            object: self,
            userInfo: [
                "direction": direction,
                "channelName": VideoPlayerService.shared.currentChannel?.name ?? ""
            ]
        )
    }

    private func validateFocusBounds() {
        guard itemCount > 0 else {
            focusedIndex = 0
            return
        }
        if focusedIndex >= itemCount {
            focusedIndex = itemCount - 1
        }
    }

    // MARK: - Visual Focus Ring Tokens

    public var focusRingColor: Color {
        Color.dcAccent
    }

    public var focusRingBorderWidth: CGFloat {
        3.5
    }

    public var focusRingGlowRadius: CGFloat {
        8.0
    }

    // MARK: - Reset Defaults

    public func resetDefaults() {
        accelerationCurve = .parabolic
        steeringWheelMode = .channelSwitching
        isWrapAroundEnabled = true
        maxStride = 10
        focusedIndex = 0
        itemCount = 0
        currentVelocityMultiplier = 1
        lastClickTime = nil
        statusLabel = "Rotary Ready"
        UserDefaults.standard.removeObject(forKey: Keys.accelerationCurve)
        UserDefaults.standard.removeObject(forKey: Keys.steeringWheelMode)
        UserDefaults.standard.removeObject(forKey: Keys.wrapAround)
        UserDefaults.standard.removeObject(forKey: Keys.maxStride)
    }
}
