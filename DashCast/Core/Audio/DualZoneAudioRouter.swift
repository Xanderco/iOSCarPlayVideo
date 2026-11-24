import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Route Models

/// High-level audio output classification for automotive dual-zone routing.
public enum AudioRouteKind: String, Codable, Equatable, CaseIterable, Sendable {
    case headphones
    case carAudio
    case airPlay
    case speaker
    case other

    public var isPassengerPersonalAudio: Bool {
        self == .headphones
    }

    public var isVehicleCabinAudio: Bool {
        self == .carAudio || self == .airPlay
    }
}

/// Snapshot of a single audio output endpoint reported by AVAudioSession.
public struct AudioOutputEndpoint: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let portTypeRaw: String
    public let kind: AudioRouteKind

    public init(id: String, name: String, portTypeRaw: String, kind: AudioRouteKind) {
        self.id = id
        self.name = name
        self.portTypeRaw = portTypeRaw
        self.kind = kind
    }

    public var isPassengerHeadphone: Bool { kind.isPassengerPersonalAudio }
    public var isCabinCarAudio: Bool { kind.isVehicleCabinAudio }
}

/// Immutable snapshot of currently connected audio outputs and route capabilities.
public struct AudioRouteSnapshot: Equatable, Sendable {
    public let outputs: [AudioOutputEndpoint]
    public let hasSecondaryAudioHint: Bool

    public init(outputs: [AudioOutputEndpoint], hasSecondaryAudioHint: Bool = false) {
        self.outputs = outputs
        self.hasSecondaryAudioHint = hasSecondaryAudioHint
    }

    public var headphoneOutputs: [AudioOutputEndpoint] {
        outputs.filter { $0.isPassengerHeadphone }
    }

    public var cabinOutputs: [AudioOutputEndpoint] {
        outputs.filter { $0.isCabinCarAudio }
    }

    public var hasHeadphonesConnected: Bool {
        !headphoneOutputs.isEmpty
    }

    public var hasCarAudioConnected: Bool {
        outputs.contains { $0.kind == .carAudio }
    }

    public var hasAirPlayAudioConnected: Bool {
        outputs.contains { $0.kind == .airPlay }
    }

    public var activePrimaryEndpoint: AudioOutputEndpoint? {
        headphoneOutputs.first ?? cabinOutputs.first ?? outputs.first
    }

    public static let empty = AudioRouteSnapshot(outputs: [], hasSecondaryAudioHint: false)

    public static func from(session: AVAudioSession) -> AudioRouteSnapshot {
        let outputs = session.currentRoute.outputs.map { port in
            AudioOutputEndpoint(
                id: port.uid,
                name: port.portName,
                portTypeRaw: port.portType.rawValue,
                kind: DualZoneAudioRouter.classify(portType: port.portType)
            )
        }
        return AudioRouteSnapshot(
            outputs: outputs,
            hasSecondaryAudioHint: session.secondaryAudioShouldBeSilencedHint
        )
    }
}

// MARK: - Routing Policies & Zones

/// User-selectable audio routing strategy for passenger video playback.
public enum DualZoneRoutingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case autoDualZone = "auto_dual_zone"
    case passengerHeadphones = "passenger_headphones"
    case cabinShared = "cabin_shared"

    public var id: String { rawValue }

    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .autoDualZone: return "Auto Dual-Zone"
        case .passengerHeadphones: return "Passenger Headphones"
        case .cabinShared: return "Shared Cabin Audio"
        }
    }

    public var localizedSubtitle: LocalizedStringKey {
        switch self {
        case .autoDualZone: return "Uses Bluetooth headphones when connected while keeping CarPlay navigation & radio clear."
        case .passengerHeadphones: return "Locks passenger video audio to personal headphones and guards cabin audio on disconnect."
        case .cabinShared: return "Routes video sound through the vehicle display or speakers."
        }
    }

    public var iconName: String {
        switch self {
        case .autoDualZone: return "headphones.circle.fill"
        case .passengerHeadphones: return "airpodsmax"
        case .cabinShared: return "car.fill"
        }
    }
}

/// Action taken if passenger headphones disconnect while CarPlay/cabin audio is active.
public enum HeadphoneDisconnectFallback: String, CaseIterable, Identifiable, Codable, Sendable {
    case mutePassengerVideo = "mute_video"
    case pausePlayback = "pause_playback"
    case fallbackToCabin = "fallback_to_cabin"

    public var id: String { rawValue }

    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .mutePassengerVideo: return "Mute Video (Protect Cabin Nav)"
        case .pausePlayback: return "Pause Video Playback"
        case .fallbackToCabin: return "Switch to Cabin Audio"
        }
    }

    public var localizedSubtitle: LocalizedStringKey {
        switch self {
        case .mutePassengerVideo: return "Silences video immediately so cabin speakers and turn-by-turn prompts are never hijacked."
        case .pausePlayback: return "Pauses video until passenger headphones reconnect."
        case .fallbackToCabin: return "Continues video audio through the car or phone speakers."
        }
    }
}

/// Live effective audio zone state displayed in the UI.
public enum ActiveAudioZone: String, Equatable, Codable, Sendable {
    case passengerHeadphones = "passenger_headphones"
    case cabinCoexistence = "cabin_coexistence"
    case cabinExclusive = "cabin_exclusive"
    case mutedSafetyGuard = "muted_safety_guard"

    public var localizedBadgeTitle: LocalizedStringKey {
        switch self {
        case .passengerHeadphones: return "Headphones"
        case .cabinCoexistence: return "Cabin Coexist"
        case .cabinExclusive: return "Cabin Audio"
        case .mutedSafetyGuard: return "Muted Safe"
        }
    }

    public var localizedHeadline: LocalizedStringKey {
        switch self {
        case .passengerHeadphones: return "Passenger Headphones Active"
        case .cabinCoexistence: return "Cabin Nav & Radio Preserved"
        case .cabinExclusive: return "Shared Cabin Audio"
        case .mutedSafetyGuard: return "Safety Mute Active"
        }
    }

    public var iconName: String {
        switch self {
        case .passengerHeadphones: return "headphones"
        case .cabinCoexistence: return "point.3.connected.trianglepath.dotted"
        case .cabinExclusive: return "speaker.wave.2.fill"
        case .mutedSafetyGuard: return "speaker.slash.fill"
        }
    }
}

/// Deterministic side-effect action returned by route evaluation.
public enum AudioSessionRouteAction: Equatable, Sendable {
    case none
    case muteVideo(reason: String)
    case pauseVideo(reason: String)
    case restoreUnmute
}

/// Declarative AVAudioSession plan built before touching system hardware.
public struct AudioSessionConfigurationPlan: Equatable, @unchecked Sendable {
    public let category: AVAudioSession.Category
    public let mode: AVAudioSession.Mode
    public let options: AVAudioSession.CategoryOptions
    public let routeSharingPolicy: AVAudioSession.RouteSharingPolicy
    public let shouldOverrideToSpeaker: Bool

    public init(
        category: AVAudioSession.Category = .playback,
        mode: AVAudioSession.Mode = .moviePlayback,
        options: AVAudioSession.CategoryOptions = [],
        routeSharingPolicy: AVAudioSession.RouteSharingPolicy = .default,
        shouldOverrideToSpeaker: Bool = false
    ) {
        self.category = category
        self.mode = mode
        self.options = options
        self.routeSharingPolicy = routeSharingPolicy
        self.shouldOverrideToSpeaker = shouldOverrideToSpeaker
    }
}

// MARK: - Hardware Adapter Protocol

/// Abstraction over `AVAudioSession` so routing logic and fallback behavior are fully unit-testable.
public protocol AudioSessionApplying {
    func currentSnapshot() -> AudioRouteSnapshot
    func apply(plan: AudioSessionConfigurationPlan, activate: Bool) throws
}

public final class SystemAudioSessionAdapter: AudioSessionApplying {
    public init() {}

    public func currentSnapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot.from(session: AVAudioSession.sharedInstance())
    }

    public func apply(plan: AudioSessionConfigurationPlan, activate: Bool) throws {
        try Self.applyToSystemSession(plan, activate: activate)
    }

    nonisolated public static func applyToSystemSession(_ plan: AudioSessionConfigurationPlan, activate: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        if plan.routeSharingPolicy != .default && plan.options.isEmpty {
            try session.setCategory(
                plan.category,
                mode: plan.mode,
                policy: plan.routeSharingPolicy,
                options: []
            )
        } else {
            try session.setCategory(plan.category, mode: plan.mode, options: plan.options)
        }

        if plan.shouldOverrideToSpeaker {
            try? session.overrideOutputAudioPort(.speaker)
        } else {
            try? session.overrideOutputAudioPort(.none)
        }

        if activate {
            try session.setActive(true, options: [])
        }
    }
}

// MARK: - Dual-Zone Audio Router

/// Manages independent Bluetooth/wired passenger headphone audio routing while preserving
/// CarPlay cabin navigation prompts and vehicle radio playback without monopolizing audio focus.
@MainActor
public final class DualZoneAudioRouter: ObservableObject {
    public static let shared = DualZoneAudioRouter()

    private enum Keys {
        static let isDualZoneEnabled = "dashcast.audioRoute.dualZoneEnabled"
        static let routingMode = "dashcast.audioRoute.routingMode"
        static let preserveCabinNavigation = "dashcast.audioRoute.preserveCabinNav"
        static let duckNavigationPrompts = "dashcast.audioRoute.duckNavPrompts"
        static let disconnectFallback = "dashcast.audioRoute.disconnectFallback"
        static let passengerVolumeTrim = "dashcast.audioRoute.passengerVolumeTrim"
    }

    // MARK: Published Settings & Live State

    @Published public var isDualZoneEnabled: Bool {
        didSet {
            defaults.set(isDualZoneEnabled, forKey: Keys.isDualZoneEnabled)
            reconcileRoutingState(previousSnapshot: routeSnapshot, currentSnapshot: routeSnapshot)
        }
    }

    @Published public var routingMode: DualZoneRoutingMode {
        didSet {
            defaults.set(routingMode.rawValue, forKey: Keys.routingMode)
            reconcileRoutingState(previousSnapshot: routeSnapshot, currentSnapshot: routeSnapshot)
        }
    }

    @Published public var preserveCabinNavigation: Bool {
        didSet {
            defaults.set(preserveCabinNavigation, forKey: Keys.preserveCabinNavigation)
            reconcileRoutingState(previousSnapshot: routeSnapshot, currentSnapshot: routeSnapshot)
        }
    }

    @Published public var duckNavigationPrompts: Bool {
        didSet {
            defaults.set(duckNavigationPrompts, forKey: Keys.duckNavigationPrompts)
            reconcileRoutingState(previousSnapshot: routeSnapshot, currentSnapshot: routeSnapshot)
        }
    }

    @Published public var disconnectFallback: HeadphoneDisconnectFallback {
        didSet {
            defaults.set(disconnectFallback.rawValue, forKey: Keys.disconnectFallback)
            reconcileRoutingState(previousSnapshot: routeSnapshot, currentSnapshot: routeSnapshot)
        }
    }

    /// Independent passenger stream volume scalar (`0.0...1.0`) applied to `AVPlayer.volume`.
    @Published public var passengerVolumeTrim: Float {
        didSet {
            let clamped = Self.clampVolume(passengerVolumeTrim)
            if clamped != passengerVolumeTrim {
                passengerVolumeTrim = clamped
                return
            }
            defaults.set(passengerVolumeTrim, forKey: Keys.passengerVolumeTrim)
            notifyVolumeChanged()
        }
    }

    @Published public private(set) var routeSnapshot: AudioRouteSnapshot
    @Published public private(set) var activeZone: ActiveAudioZone = .cabinCoexistence
    @Published public private(set) var safetyMuteBannerMessage: String?
    @Published public private(set) var isSafetyMuted: Bool = false
    @Published public private(set) var lastConfigurationError: String?
    @Published public private(set) var lastAppliedPlan: AudioSessionConfigurationPlan?

    public var isHeadphoneZoneActive: Bool {
        activeZone == .passengerHeadphones
    }

    public var effectivePlayerVolume: Float {
        isSafetyMuted ? 0.0 : passengerVolumeTrim
    }

    /// Hook invoked when routing state changes require a player mute, pause, unmute, or volume update.
    public var onPlayerDirective: ((AudioSessionRouteAction, Float) -> Void)?

    private let defaults: UserDefaults
    private let sessionAdapter: AudioSessionApplying
    private var cancellables = Set<AnyCancellable>()

    public init(
        defaults: UserDefaults = .standard,
        sessionAdapter: AudioSessionApplying = SystemAudioSessionAdapter(),
        autoObserveNotifications: Bool = true
    ) {
        self.defaults = defaults
        self.sessionAdapter = sessionAdapter

        let storedEnabled = defaults.object(forKey: Keys.isDualZoneEnabled) as? Bool ?? true
        let storedMode = defaults.string(forKey: Keys.routingMode)
            .flatMap(DualZoneRoutingMode.init(rawValue:)) ?? .autoDualZone
        let storedPreserve = defaults.object(forKey: Keys.preserveCabinNavigation) as? Bool ?? true
        let storedDuck = defaults.object(forKey: Keys.duckNavigationPrompts) as? Bool ?? false
        let storedFallback = defaults.string(forKey: Keys.disconnectFallback)
            .flatMap(HeadphoneDisconnectFallback.init(rawValue:)) ?? .mutePassengerVideo
        let storedVolume = defaults.object(forKey: Keys.passengerVolumeTrim) as? Float ?? 1.0

        self.isDualZoneEnabled = storedEnabled
        self.routingMode = storedMode
        self.preserveCabinNavigation = storedPreserve
        self.duckNavigationPrompts = storedDuck
        self.disconnectFallback = storedFallback
        self.passengerVolumeTrim = Self.clampVolume(storedVolume)
        self.routeSnapshot = sessionAdapter.currentSnapshot()

        self.activeZone = Self.evaluateRouteTransition(
            previous: routeSnapshot,
            current: routeSnapshot,
            isDualZoneEnabled: storedEnabled,
            mode: storedMode,
            preserveCabinNavigation: storedPreserve,
            fallback: storedFallback,
            wasSafetyMuted: false
        ).zone

        if autoObserveNotifications {
            observeAudioRouteNotifications()
        }
    }

    // MARK: - Pure Classification & Policy Logic

    nonisolated public static func clampVolume(_ value: Float) -> Float {
        guard value.isFinite else { return 1.0 }
        return min(max(value, 0.0), 1.0)
    }

    nonisolated public static func classify(portType: AVAudioSession.Port) -> AudioRouteKind {
        switch portType {
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .headphones, .usbAudio:
            return .headphones
        case .carAudio:
            return .carAudio
        case .airPlay:
            return .airPlay
        case .builtInSpeaker, .builtInReceiver:
            return .speaker
        default:
            return .other
        }
    }

    /// Builds an iOS-valid `AVAudioSessionConfigurationPlan` that preserves CarPlay/cabin navigation
    /// and never passes `.playAndRecord`-only options alongside `.playback`.
    nonisolated public static func buildSessionPlan(
        isDualZoneEnabled: Bool,
        mode: DualZoneRoutingMode,
        preserveCabinNavigation: Bool,
        duckCabinAudio: Bool,
        snapshot: AudioRouteSnapshot
    ) -> AudioSessionConfigurationPlan {
        guard isDualZoneEnabled else {
            return AudioSessionConfigurationPlan(
                category: .playback,
                mode: .moviePlayback,
                options: [],
                routeSharingPolicy: .default,
                shouldOverrideToSpeaker: false
            )
        }

        var options: AVAudioSession.CategoryOptions = []
        let wantsCoexistence = preserveCabinNavigation || mode != .cabinShared || snapshot.hasHeadphonesConnected
        if wantsCoexistence {
            options.insert(.mixWithOthers)
        }
        if duckCabinAudio && !wantsCoexistence {
            options.insert(.duckOthers)
        }

        // Apple's AVAudioSession throws `RouteSharingPolicyException` (NSException) if
        // `.mixWithOthers` or `.duckOthers` is combined with any non-`.default` RouteSharingPolicy.
        let policy: AVAudioSession.RouteSharingPolicy
        if !options.isEmpty {
            policy = .default
        } else if snapshot.hasAirPlayAudioConnected && mode == .cabinShared {
            policy = .longFormVideo
        } else {
            policy = .default
        }

        return AudioSessionConfigurationPlan(
            category: .playback,
            mode: .moviePlayback,
            options: options,
            routeSharingPolicy: policy,
            shouldOverrideToSpeaker: false
        )
    }

    /// Computes the next `ActiveAudioZone` and side-effect `AudioSessionRouteAction` for a route transition.
    nonisolated public static func evaluateRouteTransition(
        previous: AudioRouteSnapshot,
        current: AudioRouteSnapshot,
        isDualZoneEnabled: Bool,
        mode: DualZoneRoutingMode,
        preserveCabinNavigation: Bool,
        fallback: HeadphoneDisconnectFallback,
        wasSafetyMuted: Bool
    ) -> (zone: ActiveAudioZone, action: AudioSessionRouteAction) {
        guard isDualZoneEnabled else {
            let action: AudioSessionRouteAction = wasSafetyMuted ? .restoreUnmute : .none
            return (.cabinExclusive, action)
        }

        // 1. Headphones currently connected -> Passenger Headphone Zone active.
        if current.hasHeadphonesConnected && mode != .cabinShared {
            let action: AudioSessionRouteAction = wasSafetyMuted ? .restoreUnmute : .none
            return (.passengerHeadphones, action)
        }

        // 2. Detect sudden headphone disconnection while in a dual-zone / headphone-first mode.
        let headphonesDisconnected = previous.hasHeadphonesConnected && !current.hasHeadphonesConnected
        let shouldGuardCabin = headphonesDisconnected && (mode == .passengerHeadphones || current.hasCarAudioConnected)

        if shouldGuardCabin {
            switch fallback {
            case .mutePassengerVideo:
                let reason = "Passenger headphones disconnected — video muted so cabin navigation & radio stay clear."
                return (.mutedSafetyGuard, .muteVideo(reason: reason))
            case .pausePlayback:
                let reason = "Passenger headphones disconnected — video paused until headphones reconnect."
                return (.mutedSafetyGuard, .pauseVideo(reason: reason))
            case .fallbackToCabin:
                let zone: ActiveAudioZone = preserveCabinNavigation ? .cabinCoexistence : .cabinExclusive
                return (zone, wasSafetyMuted ? .restoreUnmute : .none)
            }
        }

        // 3. Preserve active safety mute if already muted until headphones reconnect or user overrides.
        if wasSafetyMuted && mode == .passengerHeadphones {
            return (.mutedSafetyGuard, .none)
        }

        // 4. Shared / Cabin Coexistence fallback.
        if mode == .cabinShared && !preserveCabinNavigation {
            return (.cabinExclusive, wasSafetyMuted ? .restoreUnmute : .none)
        }

        return (preserveCabinNavigation ? .cabinCoexistence : .cabinExclusive, wasSafetyMuted ? .restoreUnmute : .none)
    }

    // MARK: - Live Session Control

    /// Refreshes current hardware outputs and applies the matching `AVAudioSession` plan.
    @discardableResult
    public func applyCurrentSessionPolicy(activate: Bool = false) -> AudioSessionConfigurationPlan {
        let current = sessionAdapter.currentSnapshot()
        let previous = routeSnapshot
        routeSnapshot = current

        let plan = Self.buildSessionPlan(
            isDualZoneEnabled: isDualZoneEnabled,
            mode: routingMode,
            preserveCabinNavigation: preserveCabinNavigation,
            duckCabinAudio: duckNavigationPrompts,
            snapshot: current
        )

        do {
            try sessionAdapter.apply(plan: plan, activate: activate)
            lastAppliedPlan = plan
            lastConfigurationError = nil
        } catch {
            lastConfigurationError = error.localizedDescription
        }

        reconcileRoutingState(previousSnapshot: previous, currentSnapshot: current, applySession: false)
        return plan
    }

    /// Evaluates a supplied route snapshot (also invoked on `AVAudioSession.routeChangeNotification`).
    public func handleRouteChange(to newSnapshot: AudioRouteSnapshot, reason: AVAudioSession.RouteChangeReason = .unknown) {
        let previous = routeSnapshot
        routeSnapshot = newSnapshot

        // If `oldDeviceUnavailable` occurred even when previous snapshot wasn't cached, treat it as a disconnect check.
        let effectivePrevious: AudioRouteSnapshot
        if reason == .oldDeviceUnavailable && !previous.hasHeadphonesConnected && !newSnapshot.hasHeadphonesConnected {
            effectivePrevious = AudioRouteSnapshot(
                outputs: [AudioOutputEndpoint(id: "prev-hp", name: "Headphones", portTypeRaw: AVAudioSession.Port.bluetoothA2DP.rawValue, kind: .headphones)]
            )
        } else {
            effectivePrevious = previous
        }

        reconcileRoutingState(previousSnapshot: effectivePrevious, currentSnapshot: newSnapshot, applySession: true)
    }

    /// Clears the safety mute guard and allows video audio through cabin speakers / active route.
    public func overrideSafetyMuteToCabin() {
        isSafetyMuted = false
        safetyMuteBannerMessage = nil
        if routingMode == .passengerHeadphones && !routeSnapshot.hasHeadphonesConnected {
            routingMode = .autoDualZone
        }
        activeZone = preserveCabinNavigation ? .cabinCoexistence : .cabinExclusive
        onPlayerDirective?(.restoreUnmute, effectivePlayerVolume)
    }

    /// Dismisses the safety banner without changing mute state.
    public func dismissSafetyBanner() {
        safetyMuteBannerMessage = nil
    }

    // MARK: - Private Helpers

    private func reconcileRoutingState(
        previousSnapshot: AudioRouteSnapshot,
        currentSnapshot: AudioRouteSnapshot,
        applySession: Bool = true
    ) {
        if applySession {
            let plan = Self.buildSessionPlan(
                isDualZoneEnabled: isDualZoneEnabled,
                mode: routingMode,
                preserveCabinNavigation: preserveCabinNavigation,
                duckCabinAudio: duckNavigationPrompts,
                snapshot: currentSnapshot
            )
            do {
                try sessionAdapter.apply(plan: plan, activate: false)
                lastAppliedPlan = plan
                lastConfigurationError = nil
            } catch {
                lastConfigurationError = error.localizedDescription
            }
        }

        let transition = Self.evaluateRouteTransition(
            previous: previousSnapshot,
            current: currentSnapshot,
            isDualZoneEnabled: isDualZoneEnabled,
            mode: routingMode,
            preserveCabinNavigation: preserveCabinNavigation,
            fallback: disconnectFallback,
            wasSafetyMuted: isSafetyMuted
        )

        activeZone = transition.zone

        switch transition.action {
        case .muteVideo(let reason):
            isSafetyMuted = true
            safetyMuteBannerMessage = reason
            onPlayerDirective?(.muteVideo(reason: reason), 0.0)
        case .pauseVideo(let reason):
            isSafetyMuted = true
            safetyMuteBannerMessage = reason
            onPlayerDirective?(.pauseVideo(reason: reason), 0.0)
        case .restoreUnmute:
            isSafetyMuted = false
            safetyMuteBannerMessage = nil
            onPlayerDirective?(.restoreUnmute, passengerVolumeTrim)
        case .none:
            onPlayerDirective?(.none, effectivePlayerVolume)
        }
    }

    private func notifyVolumeChanged() {
        onPlayerDirective?(.none, effectivePlayerVolume)
    }

    private func observeAudioRouteNotifications() {
        let center = NotificationCenter.default
        center.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                let reason = rawReason.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) ?? .unknown
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let snapshot = self.sessionAdapter.currentSnapshot()
                    self.handleRouteChange(to: snapshot, reason: reason)
                }
            }
            .store(in: &cancellables)
    }
}
