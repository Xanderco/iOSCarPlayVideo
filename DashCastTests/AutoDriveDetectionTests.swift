import XCTest
@testable import DashCast

final class AutoDriveDetectionTests: XCTestCase {
    private var mockMotionManager: MockMotionActivityManager!
    private var service: AutoDriveDetectionService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockMotionManager = MockMotionActivityManager()
        service = AutoDriveDetectionService(
            motionManager: mockMotionManager,
            locationService: DriveLocationService.shared,
            notificationService: DriveNotificationService.shared,
            cooldownThresholdSeconds: 180.0
        )
        service.isTestMode = true
        service.resetCounters()

        // Ensure DriveLocationService is clean
        if DriveLocationService.shared.isTracking {
            _ = DriveLocationService.shared.endTrip()
        }

        // Ensure autoDetectDrives is enabled for tests
        var prefs = PersistenceController.shared.loadUserPreferences()
        prefs.autoDetectDrives = true
        prefs.autoDriveCooldownSeconds = 180.0
        prefs.minimumDriveMeters = 10.0
        PersistenceController.shared.saveUserPreferences(prefs)
    }

    @MainActor
    override func tearDown() {
        service.stopMonitoring()
        if DriveLocationService.shared.isTracking {
            _ = DriveLocationService.shared.endTrip()
        }
        super.tearDown()
    }

    // MARK: - Snapshot & Types Tests

    func testMotionActivitySnapshotCreationAndTypes() {
        let autoSnapshot = MotionActivitySnapshot(
            automotive: true,
            confidence: .high
        )
        XCTAssertTrue(autoSnapshot.automotive)
        XCTAssertFalse(autoSnapshot.stationary)
        XCTAssertEqual(autoSnapshot.primaryType, .automotive)
        XCTAssertEqual(autoSnapshot.confidence, .high)

        let stationarySnapshot = MotionActivitySnapshot(
            stationary: true,
            confidence: .medium
        )
        XCTAssertEqual(stationarySnapshot.primaryType, .stationary)
        XCTAssertEqual(stationarySnapshot.confidence, .medium)

        let walkingSnapshot = MotionActivitySnapshot(
            walking: true,
            confidence: .low
        )
        XCTAssertEqual(walkingSnapshot.primaryType, .walking)

        let runningSnapshot = MotionActivitySnapshot(running: true)
        XCTAssertEqual(runningSnapshot.primaryType, .running)

        let cyclingSnapshot = MotionActivitySnapshot(cycling: true)
        XCTAssertEqual(cyclingSnapshot.primaryType, .cycling)

        let unknownSnapshot = MotionActivitySnapshot()
        XCTAssertEqual(unknownSnapshot.primaryType, .unknown)
    }

    func testMotionConfidenceComparison() {
        XCTAssertTrue(MotionConfidence.low < MotionConfidence.medium)
        XCTAssertTrue(MotionConfidence.medium < MotionConfidence.high)
        XCTAssertFalse(MotionConfidence.high < MotionConfidence.low)
    }

    // MARK: - Lifecycle & Monitoring Tests

    @MainActor
    func testStartAndStopMonitoring() {
        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(mockMotionManager.isUpdatesActive)

        let started = service.startMonitoring()
        XCTAssertTrue(started)
        XCTAssertTrue(service.isMonitoring)
        XCTAssertTrue(mockMotionManager.isUpdatesActive)

        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(mockMotionManager.isUpdatesActive)
        XCTAssertEqual(service.autoDriveState, .idle)
    }

    @MainActor
    func testUnavailableHardwareHandledGracefully() {
        mockMotionManager.isActivityAvailable = false

        let started = service.startMonitoring()
        XCTAssertFalse(started)
        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(mockMotionManager.isUpdatesActive)
    }

    // MARK: - Automotive Detection & Auto-Start Tests

    @MainActor
    func testAutoDriveStartsSessionOnAutomotiveMotion() {
        service.startMonitoring()

        let carSnapshot = MotionActivitySnapshot(
            automotive: true,
            confidence: .high,
            startDate: Date()
        )
        mockMotionManager.emitActivity(carSnapshot)

        XCTAssertTrue(DriveLocationService.shared.isTracking)
        XCTAssertFalse(DriveLocationService.shared.isPaused)
        XCTAssertEqual(service.autoDriveState, .driving)
        XCTAssertEqual(service.autoStartedTripsCount, 1)
        XCTAssertNotNil(service.lastAutomotiveDate)
        XCTAssertEqual(service.currentActivityType, .automotive)
    }

    @MainActor
    func testLowConfidenceAutomotiveIgnoredWhenMediumRequired() {
        service.minConfidenceRequired = .medium
        service.startMonitoring()

        let lowConfidenceCar = MotionActivitySnapshot(
            automotive: true,
            confidence: .low
        )
        mockMotionManager.emitActivity(lowConfidenceCar)

        XCTAssertFalse(DriveLocationService.shared.isTracking)
        XCTAssertEqual(service.autoDriveState, .idle)
        XCTAssertEqual(service.autoStartedTripsCount, 0)
    }

    @MainActor
    func testAutoDriveDisabledInPreferencesIgnored() {
        var prefs = PersistenceController.shared.loadUserPreferences()
        prefs.autoDetectDrives = false
        PersistenceController.shared.saveUserPreferences(prefs)

        service.startMonitoring()

        let carSnapshot = MotionActivitySnapshot(
            automotive: true,
            confidence: .high
        )
        mockMotionManager.emitActivity(carSnapshot)

        XCTAssertFalse(DriveLocationService.shared.isTracking)
        XCTAssertEqual(service.autoDriveState, .idle)
    }

    // MARK: - Graceful Pause & Cooldown Tests

    @MainActor
    func testVehicleStopsTriggersGracefulPauseAndCooldown() {
        service.startMonitoring()

        // 1. Start drive via automotive motion
        let carSnapshot = MotionActivitySnapshot(automotive: true, confidence: .high)
        mockMotionManager.emitActivity(carSnapshot)
        XCTAssertTrue(DriveLocationService.shared.isTracking)
        XCTAssertFalse(DriveLocationService.shared.isPaused)
        XCTAssertEqual(service.autoDriveState, .driving)

        // 2. Vehicle stops: emit stationary motion
        let stopSnapshot = MotionActivitySnapshot(stationary: true, confidence: .high)
        mockMotionManager.emitActivity(stopSnapshot)

        // 3. Verify trip gracefully paused and entered cooldown
        XCTAssertTrue(DriveLocationService.shared.isPaused)
        XCTAssertEqual(service.remainingCooldownSeconds, 180.0)
        XCTAssertEqual(service.autoDriveState, .stationaryCooldown(remainingSeconds: 180.0))
        XCTAssertNotNil(service.lastStationaryDate)
    }

    @MainActor
    func testAutomotiveResumedDuringCooldownCancelsStop() {
        service.startMonitoring()

        // 1. Start drive
        mockMotionManager.emitActivity(MotionActivitySnapshot(automotive: true, confidence: .high))

        // 2. Vehicle stops at traffic light (stationary)
        mockMotionManager.emitActivity(MotionActivitySnapshot(stationary: true, confidence: .high))
        XCTAssertTrue(DriveLocationService.shared.isPaused)
        XCTAssertEqual(service.autoDriveState, .stationaryCooldown(remainingSeconds: 180.0))

        // 3. Tick 30 seconds
        service.tickCooldown(step: 30)
        XCTAssertEqual(service.remainingCooldownSeconds, 150.0)

        // 4. Light turns green: car accelerates again
        mockMotionManager.emitActivity(MotionActivitySnapshot(automotive: true, confidence: .high))

        // 5. Verify cooldown cancelled, trip resumed
        XCTAssertFalse(DriveLocationService.shared.isPaused)
        XCTAssertEqual(service.autoDriveState, .driving)
        XCTAssertEqual(service.remainingCooldownSeconds, 0)
    }

    // MARK: - Finalization After > 3 Minutes Cooldown

    @MainActor
    func testFinalizeTripWhenVehicleStopsOverThreeMinutes() {
        service.startMonitoring()

        // 1. Drive session begins
        mockMotionManager.emitActivity(MotionActivitySnapshot(automotive: true, confidence: .high))
        XCTAssertTrue(DriveLocationService.shared.isTracking)

        // 2. Vehicle parked at destination
        mockMotionManager.emitActivity(MotionActivitySnapshot(stationary: true, confidence: .high))
        XCTAssertTrue(DriveLocationService.shared.isPaused)

        // 3. Fast-forward past 180 seconds (3 minutes)
        service.fastForwardCooldown(seconds: 181)

        // 4. Verify trip ended and finalized
        XCTAssertFalse(DriveLocationService.shared.isTracking)
        XCTAssertEqual(service.autoDriveState, .idle)
        XCTAssertEqual(service.remainingCooldownSeconds, 0)
        XCTAssertEqual(service.autoFinalizedTripsCount, 1)
    }

    // MARK: - Manual Overrides & Preferences Tests

    @MainActor
    func testManualTripControlsSynchronizeAutoDriveState() {
        service.handleManualTripStarted()
        XCTAssertEqual(service.autoDriveState, .driving)

        service.handleManualTripEnded()
        XCTAssertEqual(service.autoDriveState, .idle)
        XCTAssertEqual(service.remainingCooldownSeconds, 0)
    }

    func testUserPreferencesAutoDriveCooldownSerialization() throws {
        var prefs = UserPreferences()
        prefs.autoDetectDrives = true
        prefs.autoDriveCooldownSeconds = 120.0

        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserPreferences.self, from: data)

        XCTAssertTrue(decoded.autoDetectDrives)
        XCTAssertEqual(decoded.autoDriveCooldownSeconds, 120.0)
    }

    @MainActor
    func testHistoricalActivityQueryDetection() {
        let historicalAutomotive = MotionActivitySnapshot(
            automotive: true,
            confidence: .high,
            startDate: Date().addingTimeInterval(-60)
        )
        mockMotionManager.queryResults = [historicalAutomotive]

        service.startMonitoring()

        XCTAssertTrue(DriveLocationService.shared.isTracking)
        XCTAssertEqual(service.autoDriveState, .driving)
    }
}
