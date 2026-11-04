import Foundation
import CoreLocation
import Combine
import UIKit

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

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var timer: Timer?
    private var tripStartTime: Date?

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2 // 2 meters
        locationManager.allowsBackgroundLocationUpdates = false

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppDidEnterBackground()
            }
        }
    }

    private func handleAppDidEnterBackground() {
        guard isTracking else { return }
        let prefs = PersistenceController.shared.loadUserPreferences()
        if prefs.liveActivitiesEnabled && !DriveLiveActivityManager.shared.isLiveActivityActive {
            DriveLiveActivityManager.shared.startLiveActivity(
                vehicleName: prefs.driveVehicleName,
                vehicleImageName: prefs.driveVehicleImage,
                speedUnit: prefs.useMilesPerHour ? "MPH" : "KM/H",
                useMilesPerHour: prefs.useMilesPerHour,
                initialSpeed: prefs.useMilesPerHour ? currentSpeedKmh * 0.621371 : currentSpeedKmh
            )
        }
    }

    public func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    public func startTrip() {
        requestPermissions()
        distanceMeters = 0
        topSpeedKmh = 0
        averageSpeedKmh = 0
        elapsedTime = 0
        stopDuration = 0
        tripPoints = []
        isTracking = true
        isPaused = false
        tripStartTime = Date()

        let prefs = PersistenceController.shared.loadUserPreferences()
        if prefs.liveActivitiesEnabled {
            DriveLiveActivityManager.shared.startLiveActivity(
                vehicleName: prefs.driveVehicleName,
                vehicleImageName: prefs.driveVehicleImage,
                speedUnit: prefs.useMilesPerHour ? "MPH" : "KM/H",
                useMilesPerHour: prefs.useMilesPerHour,
                initialSpeed: 0.0
            )
        }

        locationManager.startUpdatingLocation()
        startTimer()
    }

    public func pauseTrip() {
        isPaused = true
        locationManager.stopUpdatingLocation()

        let prefs = PersistenceController.shared.loadUserPreferences()
        DriveLiveActivityManager.shared.updateLiveActivity(
            speedKmh: currentSpeedKmh,
            distanceMeters: distanceMeters,
            elapsedTime: elapsedTime,
            currentGForce: DrivingScorer.shared.currentGForce,
            peakGForce: DrivingScorer.shared.peakGForce,
            smoothnessScore: DrivingScorer.shared.currentScore,
            isPaused: true,
            useMilesPerHour: prefs.useMilesPerHour,
            forceUpdate: true
        )
    }

    public func resumeTrip() {
        isPaused = false
        locationManager.startUpdatingLocation()

        let prefs = PersistenceController.shared.loadUserPreferences()
        DriveLiveActivityManager.shared.updateLiveActivity(
            speedKmh: currentSpeedKmh,
            distanceMeters: distanceMeters,
            elapsedTime: elapsedTime,
            currentGForce: DrivingScorer.shared.currentGForce,
            peakGForce: DrivingScorer.shared.peakGForce,
            smoothnessScore: DrivingScorer.shared.currentScore,
            isPaused: false,
            useMilesPerHour: prefs.useMilesPerHour,
            forceUpdate: true
        )
    }

    public func endTrip() -> TripModel {
        isTracking = false
        isPaused = false
        locationManager.stopUpdatingLocation()
        stopTimer()

        DriveLiveActivityManager.shared.endLiveActivity(dismissImmediately: false)

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
        print("Location manager error: \(error.localizedDescription)")
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isTracking, !isPaused else { return }

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
        DrivingScorer.shared.recordPoint(speedKmh: speedKmh)

        // Stream telemetry to ActivityKit Live Activity & Dynamic Island
        let prefs = PersistenceController.shared.loadUserPreferences()
        DriveLiveActivityManager.shared.updateLiveActivity(
            speedKmh: speedKmh,
            distanceMeters: distanceMeters,
            elapsedTime: elapsedTime,
            currentGForce: DrivingScorer.shared.currentGForce,
            peakGForce: DrivingScorer.shared.peakGForce,
            smoothnessScore: DrivingScorer.shared.currentScore,
            isPaused: isPaused,
            useMilesPerHour: prefs.useMilesPerHour
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

        let prefs = PersistenceController.shared.loadUserPreferences()
        DriveLiveActivityManager.shared.updateLiveActivity(
            speedKmh: speedKmh,
            distanceMeters: distanceMeters,
            elapsedTime: elapsedTime,
            currentGForce: DrivingScorer.shared.currentGForce,
            peakGForce: DrivingScorer.shared.peakGForce,
            smoothnessScore: DrivingScorer.shared.currentScore,
            isPaused: isPaused,
            useMilesPerHour: prefs.useMilesPerHour
        )
    }
}
