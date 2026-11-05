import Foundation
import CoreLocation
import CoreMotion
import Combine

/// Starts and stops Trip Log recordings automatically.
///
/// Signals: Core Motion activity (automotive + confidence) and GPS speed. Significant-location
/// monitoring wakes (or relaunches) the app in the background; standard updates only run while
/// a drive looks possible, to save battery. All decisions are made by `TripDetectionStateMachine`;
/// recording and saving reuse `DriveLocationService` and `PersistenceController`.
@MainActor
final class AutoTripService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AutoTripService()

    @Published private(set) var isMonitoring = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Short, human-readable status for the Trip Log screen.
    @Published private(set) var statusText = "Off"

    private let manager = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var machine = TripDetectionStateMachine()
    private var tick: Timer?
    private var standardUpdatesRunning = false
    private var lastAutomotiveAt: Date?
    /// True while the current Trip Log recording was started by this service.
    private(set) var currentTripIsAutomatic = false

    private let recorder: DriveLocationService

    override init() {
        recorder = DriveLocationService.shared
        super.init()
        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: Preference

    /// Default: ON once Always permission is granted, unless the user has chosen explicitly.
    nonisolated static func isEnabled(preference: Bool?, status: CLAuthorizationStatus) -> Bool {
        guard status == .authorizedAlways else { return false }
        return preference ?? true
    }

    var isEnabled: Bool {
        Self.isEnabled(preference: PersistenceController.shared.loadUserPreferences().autoTripDetectionEnabled,
                       status: authorizationStatus)
    }

    func setEnabled(_ enabled: Bool) {
        var prefs = PersistenceController.shared.loadUserPreferences()
        prefs.autoTripDetectionEnabled = enabled
        PersistenceController.shared.saveUserPreferences(prefs)
        if enabled {
            if authorizationStatus != .authorizedAlways { recorder.requestAlwaysAuthorization() }
            if prefs.driveNotificationsEnabled {
                Task { _ = await DriveNotificationService.shared.requestAuthorization() }
            }
        }
        refresh()
    }

    /// Call at launch and whenever permission or the toggle changes.
    func refresh() {
        objectWillChange.send()
        authorizationStatus = manager.authorizationStatus
        if isEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
            let pref = PersistenceController.shared.loadUserPreferences().autoTripDetectionEnabled
            if pref != false && authorizationStatus != .authorizedAlways {
                statusText = "Needs location access set to Always"
            }
        }
    }

    // MARK: Monitoring

    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        statusText = "Watching for drives"
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = false
        }
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
        if CMMotionActivityManager.isActivityAvailable() {
            motion.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity else { return }
                let confidence: MotionConfidence
                switch activity.confidence {
                case .high: confidence = .high
                case .medium: confidence = .medium
                default: confidence = .low
                }
                let automotive = activity.automotive
                MainActor.assumeIsolated {
                    self?.handle(TripDetectionSample(automotive: automotive, confidence: confidence, at: Date()))
                }
            }
        } else {
            // No Core Motion (e.g. Simulator): GPS speed alone decides, so keep standard updates on.
            setStandardUpdates(true)
        }
        tick = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handle(TripDetectionSample(at: Date())) }
        }
    }

    private func stopMonitoring() {
        guard isMonitoring else { statusText = "Off"; return }
        isMonitoring = false
        statusText = "Off"
        tick?.invalidate()
        tick = nil
        motion.stopActivityUpdates()
        manager.stopMonitoringSignificantLocationChanges()
        setStandardUpdates(false)
        manager.allowsBackgroundLocationUpdates = false
        machine.reset(driving: false, at: Date())
        // A trip this service started keeps recording; the user can stop it in Trip Log.
    }

    private func setStandardUpdates(_ on: Bool) {
        guard on != standardUpdatesRunning else { return }
        standardUpdatesRunning = on
        if on { manager.startUpdatingLocation() } else { manager.stopUpdatingLocation() }
    }

    // MARK: Decisions

    private func handle(_ sample: TripDetectionSample) {
        guard isMonitoring else { return }

        // A trip started by hand is the user's to stop.
        if recorder.isTracking && !currentTripIsAutomatic {
            machine.reset(driving: true, at: sample.at)
            statusText = "Recording (started by you)"
            return
        }
        // The user stopped an automatic trip by hand.
        if !recorder.isTracking && currentTripIsAutomatic {
            currentTripIsAutomatic = false
            machine.reset(driving: false, at: sample.at)
        }

        if sample.automotive == true, sample.confidence >= .medium { lastAutomotiveAt = sample.at }

        switch machine.update(sample) {
        case .startTrip:
            currentTripIsAutomatic = true
            recorder.startTrip()
        case .endTrip:
            finishAutomaticTrip()
        case .none:
            break
        }

        // GPS only while a drive is possible (motion recently automotive, or already candidate/driving).
        if CMMotionActivityManager.isActivityAvailable() {
            let recentlyAutomotive = lastAutomotiveAt.map { sample.at.timeIntervalSince($0) < 300 } ?? false
            setStandardUpdates(recentlyAutomotive || machine.phase != .idle)
        }

        switch machine.phase {
        case .idle: statusText = "Watching for drives"
        case .candidate: statusText = "Possible drive detected…"
        case .driving: statusText = "Recording a drive"
        }
    }

    private func finishAutomaticTrip() {
        guard currentTripIsAutomatic, recorder.isTracking else { return }
        currentTripIsAutomatic = false
        let trip = recorder.endTrip()
        let prefs = PersistenceController.shared.loadUserPreferences()
        if prefs.driveNotificationsEnabled {
            DriveNotificationService.shared.sendTripSavedNotification(trip: trip, useMiles: prefs.useMilesPerHour)
        }
        NotificationCenter.default.post(name: .dashCastTripSaved, object: nil)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              DriveLocationService.isUsableFix(horizontalAccuracy: location.horizontalAccuracy,
                                               age: -location.timestamp.timeIntervalSinceNow) else { return }
        let speed: Double? = location.speed >= 0 ? location.speed * 3.6 : nil
        let at = location.timestamp
        Task { @MainActor [weak self] in
            self?.handle(TripDetectionSample(speedKmh: speed, at: at))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
}

extension Notification.Name {
    /// Posted after an automatic trip is saved so open screens can reload.
    static let dashCastTripSaved = Notification.Name("dashcast.trip.saved")
}
