import Foundation
import CoreLocation
import CoreMotion

/// Watches GPS speed and Core Motion activity while video is going to a car
/// display, and publishes whether the vehicle is parked. The state is also
/// mirrored into the app group so the broadcast extension can stop mirroring.
@MainActor
final class ParkedGuard: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var state: VehicleMotionState = .unknown
    @Published private(set) var isMonitoring = false

    private var evaluator = ParkedStateEvaluator()
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionActivityManager()
    private var lastSpeedKmh: Double?
    private var lastSpeedAt: Date?
    private var lastAutomotiveMoving: Bool?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        default:
            break
        }

        if CMMotionActivityManager.isActivityAvailable() {
            motionManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity else { return }
                let moving = activity.automotive && !activity.stationary && activity.confidence != .low
                Task { @MainActor [weak self] in
                    self?.ingest(automotiveMoving: moving)
                }
            }
        }
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        locationManager.stopUpdatingLocation()
        motionManager.stopActivityUpdates()
        lastSpeedKmh = nil
        lastSpeedAt = nil
        lastAutomotiveMoving = nil
        evaluator = ParkedStateEvaluator()
        state = .unknown
        CarCastShared.setVehicleMoving(false)
    }

    private func startLocationUpdates() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if modes.contains("location") {
            // Keeps the guard alive while the user is in another app during mirroring.
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
        }
        locationManager.startUpdatingLocation()
    }

    private func ingest(speedKmh: Double?) {
        lastSpeedKmh = speedKmh
        lastSpeedAt = speedKmh == nil ? nil : Date()
        evaluate()
    }

    private func ingest(automotiveMoving: Bool) {
        lastAutomotiveMoving = automotiveMoving
        evaluate()
    }

    private func evaluate() {
        guard isMonitoring else { return }
        let now = Date()
        // Ignore stale GPS speed (e.g. in a tunnel or garage).
        let speed = (lastSpeedAt.map { now.timeIntervalSince($0) < 15 } ?? false) ? lastSpeedKmh : nil
        let newState = evaluator.update(speedKmh: speed, automotiveMoving: lastAutomotiveMoving, at: now)
        if newState != state {
            state = newState
        }
        CarCastShared.setVehicleMoving(newState == .moving)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, self.isMonitoring else { return }
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startLocationUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let fresh = abs(location.timestamp.timeIntervalSinceNow) < 10
        let speedKmh: Double? = (fresh && location.speed >= 0 && location.speedAccuracy >= 0) ? location.speed * 3.6 : nil
        Task { @MainActor [weak self] in
            self?.ingest(speedKmh: speedKmh)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
