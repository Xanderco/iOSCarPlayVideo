import Foundation
import UIKit
import AVFoundation
import AVKit
import Combine

/// Darwin notification callback (C function pointer, so it lives outside the actor-isolated class).
/// The controller is a process-lifetime singleton, so the unretained pointer stays valid.
private let broadcastStatusDarwinCallback: CFNotificationCallback = { _, observer, _, _, _ in
    guard let observer else { return }
    let controller = Unmanaged<CarVideoOutputController>.fromOpaque(observer).takeUnretainedValue()
    Task { @MainActor in controller.reloadBroadcastStatus() }
}

/// Localized copy keys for `CarVideoOutputController` Live Activity state.
enum CarVideoOutputCopy {
    nonisolated static let mirroringModeString = "Mirroring"
    nonisolated static let mirroringViewerURLFormatString = "Open %@ in the car browser"
    nonisolated static let mirroringLiveString = "Screen mirroring is live"
    nonisolated static let airPlayModeString = "AirPlay"
    nonisolated static let playingOnFormatString = "Playing on %@"
    nonisolated static let carDisplayFallbackString = "car display"
    nonisolated static let externalDisplayModeString = "External display"
    nonisolated static let externalDisplayPlayingString = "Playing on connected display"
    nonisolated static let pausedForMotionString = "Paused while the vehicle is moving"

    nonisolated static let allLocalizationKeys: [String] = [
        mirroringModeString,
        mirroringViewerURLFormatString,
        mirroringLiveString,
        airPlayModeString,
        playingOnFormatString,
        carDisplayFallbackString,
        externalDisplayModeString,
        externalDisplayPlayingString,
        pausedForMotionString
    ]
}

/// Pure Live Activity content state builder for `CarVideoOutputController`.
enum CarVideoOutputActivityBuilder {
    nonisolated static func buildState(
        isBroadcasting: Bool,
        viewerURL: String?,
        isExternalPlaybackActive: Bool,
        airPlayRouteName: String?,
        channelName: String?,
        pausedForMotion: Bool,
        startedAt: Date,
        bundle: Bundle = .main
    ) -> CarCastActivityAttributes.ContentState {
        let mode: String
        let baseDetail: String

        if isBroadcasting {
            mode = localized(CarVideoOutputCopy.mirroringModeString, bundle: bundle)
            if let viewerURL {
                let format = localized(CarVideoOutputCopy.mirroringViewerURLFormatString, bundle: bundle)
                baseDetail = String(format: format, viewerURL)
            } else {
                baseDetail = localized(CarVideoOutputCopy.mirroringLiveString, bundle: bundle)
            }
        } else if isExternalPlaybackActive {
            mode = localized(CarVideoOutputCopy.airPlayModeString, bundle: bundle)
            let route = airPlayRouteName ?? localized(CarVideoOutputCopy.carDisplayFallbackString, bundle: bundle)
            let format = localized(CarVideoOutputCopy.playingOnFormatString, bundle: bundle)
            baseDetail = String(format: format, route)
        } else {
            mode = localized(CarVideoOutputCopy.externalDisplayModeString, bundle: bundle)
            baseDetail = localized(CarVideoOutputCopy.externalDisplayPlayingString, bundle: bundle)
        }

        let detail = pausedForMotion
            ? localized(CarVideoOutputCopy.pausedForMotionString, bundle: bundle)
            : baseDetail
        let title = channelName ?? "DashCast"

        return CarCastActivityAttributes.ContentState(
            mode: mode,
            title: title,
            detail: detail,
            isPausedForMotion: pausedForMotion,
            startedAt: startedAt
        )
    }

    nonisolated private static func localized(_ key: String, bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// Coordinates every way DashCast puts video on a car display:
///  1. AVPlayer external playback over AirPlay (iOS 26 "AirPlay video in the car",
///     AirPlay TVs/receivers, wireless adapters that act as AirPlay receivers),
///  2. a UIScreen / external-display scene (wired adapters, ExternalDisplayManager),
///  3. ReplayKit screen mirroring to a car browser (DashCastBroadcast extension).
/// It also enforces the "parked only" rule and drives the casting Live Activity.
@MainActor
final class CarVideoOutputController: ObservableObject {
    static let shared = CarVideoOutputController()

    @Published private(set) var isExternalPlaybackActive = false
    @Published private(set) var airPlayRouteName: String?
    @Published private(set) var isCarAudioRoute = false
    @Published private(set) var multipleRoutesDetected = false
    @Published private(set) var broadcastStatus: BroadcastStatus = .idle
    @Published private(set) var pausedForMotion = false

    let parkedGuard = ParkedGuard()

    private weak var player: AVPlayer?
    private var pauseHandler: (() -> Void)?
    private var externalPlaybackObservation: NSKeyValueObservation?
    private let routeDetector = AVRouteDetector()
    private var cancellables = Set<AnyCancellable>()
    private var panelVisible = false
    private var outputStartedAt: Date?

    var isBroadcasting: Bool { broadcastStatus.isLive }

    var isExternalDisplayConnected: Bool { ExternalDisplayManager.shared.isExternalDisplayConnected }

    /// True when video from DashCast is (or may be) visible on another screen.
    var isOutputActive: Bool {
        isExternalPlaybackActive || isBroadcasting || isExternalDisplayConnected
    }

    var motionState: VehicleMotionState { parkedGuard.state }

    init() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAudioRoute() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVRouteDetectorMultipleRoutesDetectedDidChange, object: routeDetector)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.multipleRoutesDetected = self.routeDetector.multipleRoutesDetected
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadBroadcastStatus()
                self?.refreshAudioRoute()
            }
            .store(in: &cancellables)

        parkedGuard.$state
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.handleMotion(state) }
            .store(in: &cancellables)

        ExternalDisplayManager.shared.$isExternalDisplayConnected
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.outputDidChange() }
            .store(in: &cancellables)

        registerDarwinObserver()
        refreshAudioRoute()
        reloadBroadcastStatus()
    }

    // MARK: Player configuration

    /// Configures the shared player so video (not just audio) follows an AirPlay
    /// route to the car, and so DashCast can pause it when the car moves.
    func attach(player: AVPlayer, pause: @escaping () -> Void) {
        self.player = player
        self.pauseHandler = pause
        player.allowsExternalPlayback = true
        // With mirroring active, send the video stream full screen instead of mirroring the UI.
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.preventsDisplaySleepDuringVideoPlayback = true

        externalPlaybackObservation = player.observe(\.isExternalPlaybackActive, options: [.initial, .new]) { [weak self] player, _ in
            let active = player.isExternalPlaybackActive
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isExternalPlaybackActive = active
                self.refreshAudioRoute()
                self.outputDidChange()
            }
        }
    }

    /// The cast panel calls this so route detection / motion state are live while it is on screen.
    func setPanelVisible(_ visible: Bool) {
        panelVisible = visible
        routeDetector.isRouteDetectionEnabled = visible
        if visible {
            multipleRoutesDetected = routeDetector.multipleRoutesDetected
            reloadBroadcastStatus()
        }
        updateMonitoring()
    }

    /// Returns false (and explains via `pausedForMotion`) when playback must not start.
    func canStartVideoOutput() -> Bool {
        !(isOutputActive && parkedGuard.state == .moving)
    }

    // MARK: Routes

    private func refreshAudioRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        airPlayRouteName = outputs.first(where: { $0.portType == .airPlay })?.portName
        isCarAudioRoute = outputs.contains(where: { $0.portType == .carAudio })
    }

    // MARK: Broadcast extension status

    private func registerDarwinObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            broadcastStatusDarwinCallback,
            CarCastShared.DarwinNotification.broadcastStatusChanged as CFString,
            nil,
            .deliverImmediately
        )
    }

    func reloadBroadcastStatus() {
        let status = BroadcastStatus.load()
        if status != broadcastStatus {
            let wasLive = broadcastStatus.isLive
            broadcastStatus = status
            outputDidChange()
            // Mirror iPhone → car display: play the extension's HLS stream through the
            // system player route (external playback) as soon as the broadcast goes live.
            if status.isLive, !wasLive, CarMirrorFeature.isEnabled() {
                CarPlayMirrorPlayback.start()
            } else if !status.isLive {
                CarPlayMirrorPlayback.stopIfMirroring()
            }
        }
    }

    // MARK: Parked-only guard

    private func handleMotion(_ state: VehicleMotionState) {
        if state == .moving, isOutputActive {
            pausedForMotion = true
            pauseHandler?()
        } else if state != .moving {
            pausedForMotion = false
        }
        updateLiveActivity()
    }

    private func outputDidChange() {
        updateMonitoring()
        if isOutputActive, parkedGuard.state == .moving {
            pausedForMotion = true
            pauseHandler?()
        }
        updateLiveActivity()
    }

    private func updateMonitoring() {
        if isOutputActive || panelVisible {
            parkedGuard.start()
        } else {
            parkedGuard.stop()
        }
    }

    // MARK: Live Activity

    private func updateLiveActivity() {
        guard isOutputActive else {
            outputStartedAt = nil
            CarCastLiveActivityManager.shared.end()
            return
        }
        if outputStartedAt == nil { outputStartedAt = Date() }

        let startedAt = (isBroadcasting ? broadcastStatus.startedAt : nil) ?? outputStartedAt ?? Date()
        let state = CarVideoOutputActivityBuilder.buildState(
            isBroadcasting: isBroadcasting,
            viewerURL: broadcastStatus.viewerURL,
            isExternalPlaybackActive: isExternalPlaybackActive,
            airPlayRouteName: airPlayRouteName,
            channelName: VideoPlayerService.shared.currentChannel?.name,
            pausedForMotion: pausedForMotion,
            startedAt: startedAt
        )
        CarCastLiveActivityManager.shared.startOrUpdate(state)
    }
}
