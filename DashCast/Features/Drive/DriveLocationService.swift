import Foundation
import CoreLocation
import Combine

@MainActor
public final class DriveLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = DriveLocationService()

    @Published public private(set) var currentSpeedKmh: Double = 0
    @Published public private(set) var currentAltitudeMeters: Double = 0
    @Published public private(set) var distanceMeters: Double = 0
    @Published public private(set) var topSpeedKmh: Double = 0
    @Published public private(set) var averageSpeedKmh: Double = 0
    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public private(set) var stopDuration: TimeInterval = 0
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentLocation: CLLocation?
    @Published public private(set) var tripPoints: [TripPoint] = []
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var lastErrorMessage: String?

    public var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var timer: Timer?
    private var tripStartTime: Date?

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2 // 2 meters
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Background updates must be enabled while a trip records, otherwise tracking stops as soon
    /// as the phone locks (previously hardcoded to `false` despite the `location` background mode).
    /// Only enabled when Info.plist declares the mode, since setting it without the mode crashes.
    private func setBackgroundUpdates(_ enabled: Bool) {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        guard modes.contains("location") else { return }
        locationManager.allowsBackgroundLocationUpdates = enabled
        locationManager.showsBackgroundLocationIndicator = enabled
    }

    public func clearError() {
        lastErrorMessage = nil
    }

    public func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    public func startTrip() {
        lastErrorMessage = nil
        if authorizationStatus == .notDetermined {
            requestPermissions()
        } else if !isAuthorized {
            lastErrorMessage = "Location access is off. Enable it in Settings › DashCast › Location to record trips."
        }
        // Each trip starts clean: previously the scorer kept events from before the trip and
        // the first fix was measured from the previous trip's last location.
        DrivingScorer.shared.reset()
        lastLocation = nil
        currentLocation = nil
        currentSpeedKmh = 0
        distanceMeters = 0
        topSpeedKmh = 0
        averageSpeedKmh = 0
        elapsedTime = 0
        stopDuration = 0
        tripPoints = []
        isTracking = true
        isPaused = false
        tripStartTime = Date()

        setBackgroundUpdates(true)
        locationManager.startUpdatingLocation()
        startTimer()
    }

    public func pauseTrip() {
        isPaused = true
        locationManager.stopUpdatingLocation()
        // Don't measure a straight line from where we paused to where we resume.
        lastLocation = nil
    }

    public func resumeTrip() {
        isPaused = false
        locationManager.startUpdatingLocation()
    }

    public func endTrip() -> TripModel {
        isTracking = false
        isPaused = false
        locationManager.stopUpdatingLocation()
        setBackgroundUpdates(false)
        stopTimer()
        currentSpeedKmh = 0

        let score = DrivingScorer.shared.calculateScore()
        let trip = TripModel(
            id: UUID(),
            startTime: tripStartTime ?? Date(),
            endTime: Date(),
            distanceMeters: distanceMeters,
            averageSpeedKmh: averageSpeedKmh,
            maxSpeedKmh: topSpeedKmh,
            drivingScore: score,
            points: tripPoints,
            harshBrakingCount: DrivingScorer.shared.harshBrakingCount,
            harshAccelerationCount: DrivingScorer.shared.harshAccelerationCount,
            harshCorneringCount: DrivingScorer.shared.harshCorneringCount
        )

        // Save trip
        var trips = PersistenceController.shared.loadTrips()
        trips.insert(trip, at: 0)
        PersistenceController.shared.saveTrips(trips)

        // Record on-device local usage metrics
        UsageMetricsManager.shared.recordTrip(trip: trip)

        DrivingScorer.shared.reset()
        return trip
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isTracking, !self.isPaused else { return }
                self.elapsedTime += 1

                if self.currentSpeedKmh < 1.0 {
                    self.stopDuration += 1
                }

                if self.elapsedTime > 0 {
                    self.averageSpeedKmh = (self.distanceMeters / 1000.0) / (self.elapsedTime / 3600.0)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Swift 6 CLLocationManagerDelegate Conformance
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.handleLocationUpdate(location)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor [weak self] in
            // kCLErrorLocationUnknown is transient; only surface real failures.
            if denied { self?.lastErrorMessage = "Location access was denied. Enable it in Settings to record trips." }
            print("Location manager error: \(message)")
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            if self.isAuthorized {
                self.lastErrorMessage = nil
            } else if status == .denied || status == .restricted {
                self.lastErrorMessage = "Location access is off. Enable it in Settings › DashCast › Location to record trips."
            }
        }
    }

    /// Whether a fix is good enough to add to distance / route. Exposed for tests.
    nonisolated static func isUsableFix(horizontalAccuracy: Double, age: TimeInterval) -> Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy <= 50 && age < 10
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isTracking, !isPaused else { return }
        // Skip invalid, very inaccurate, or cached (stale) fixes; they caused distance jumps
        // and phantom speed at trip start.
        guard Self.isUsableFix(
            horizontalAccuracy: location.horizontalAccuracy,
            age: -location.timestamp.timeIntervalSinceNow
        ) else { return }

        self.currentLocation = location

        // Calculate speed (CLLocation.speed is in m/s)
        let rawSpeed = location.speed
        let speedKmh = max(rawSpeed >= 0 ? rawSpeed * 3.6 : 0, 0)
        self.currentSpeedKmh = speedKmh
        if speedKmh > topSpeedKmh {
            topSpeedKmh = speedKmh
        }

        self.currentAltitudeMeters = max(location.altitude, 0)

        // Accumulate distance
        if let previous = lastLocation {
            let delta = location.distance(from: previous)
            if delta > 0 && delta < 500 { // Filter out GPS teleport glitches
                distanceMeters += delta
            }
        }
        lastLocation = location

        // Record breadcrumb point
        let point = TripPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedKmh: speedKmh,
            altitudeMeters: location.altitude,
            timestamp: location.timestamp
        )
        tripPoints.append(point)

        // Pass motion acceleration to scorer
        DrivingScorer.shared.recordPoint(
            speedKmh: speedKmh,
            course: location.courseAccuracy >= 0 ? location.course : -1,
            timestamp: location.timestamp
        )
    }

    // Manual simulation injection for tests & preview
    public func simulatePoint(latitude: Double, longitude: Double, speedKmh: Double, altitude: Double) {
        let point = TripPoint(
            latitude: latitude,
            longitude: longitude,
            speedKmh: speedKmh,
            altitudeMeters: altitude
        )
        tripPoints.append(point)
        currentSpeedKmh = speedKmh
        if speedKmh > topSpeedKmh { topSpeedKmh = speedKmh }
        DrivingScorer.shared.recordPoint(speedKmh: speedKmh)
    }
}
