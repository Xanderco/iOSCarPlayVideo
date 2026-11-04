import Foundation
import CoreMotion
import Combine

// MARK: - Motion Confidence & Activity Types

public enum MotionConfidence: Int, Codable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public init(confidence: CMMotionActivityConfidence) {
        switch confidence {
        case .low: self = .low
        case .medium: self = .medium
        case .high: self = .high
        @unknown default: self = .low
        }
    }

    public static func < (lhs: MotionConfidence, rhs: MotionConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum MotionActivityType: String, Codable, CaseIterable, Sendable {
    case unknown = "Unknown"
    case automotive = "Automotive"
    case stationary = "Stationary"
    case walking = "Walking"
    case running = "Running"
    case cycling = "Cycling"
}

// MARK: - Motion Activity Snapshot

public struct MotionActivitySnapshot: Equatable, Sendable {
    public let automotive: Bool
    public let stationary: Bool
    public let walking: Bool
    public let running: Bool
    public let cycling: Bool
    public let unknown: Bool
    public let confidence: MotionConfidence
    public let startDate: Date

    public init(
        automotive: Bool = false,
        stationary: Bool = false,
        walking: Bool = false,
        running: Bool = false,
        cycling: Bool = false,
        unknown: Bool = false,
        confidence: MotionConfidence = .high,
        startDate: Date = Date()
    ) {
        self.automotive = automotive
        self.stationary = stationary
        self.walking = walking
        self.running = running
        self.cycling = cycling
        self.unknown = unknown
        self.confidence = confidence
        self.startDate = startDate
    }

    public init(activity: CMMotionActivity) {
        self.automotive = activity.automotive
        self.stationary = activity.stationary
        self.walking = activity.walking
        self.running = activity.running
        self.cycling = activity.cycling
        self.unknown = activity.unknown
        self.confidence = MotionConfidence(confidence: activity.confidence)
        self.startDate = activity.startDate
    }

    public var primaryType: MotionActivityType {
        if automotive { return .automotive }
        if stationary { return .stationary }
        if walking { return .walking }
        if running { return .running }
        if cycling { return .cycling }
        return .unknown
    }
}

// MARK: - Motion Activity Protocol & Concrete Implementations

public protocol MotionActivityManagerProtocol: AnyObject, Sendable {
    var isActivityAvailable: Bool { get }
    func startActivityUpdates(
        to queue: OperationQueue,
        withHandler handler: @escaping @Sendable (MotionActivitySnapshot?) -> Void
    )
    func stopActivityUpdates()
    func queryActivityStarting(
        from start: Date,
        to end: Date,
        to queue: OperationQueue,
        withHandler handler: @escaping @Sendable ([MotionActivitySnapshot]?, Error?) -> Void
    )
}

public final class SystemMotionActivityManager: MotionActivityManagerProtocol, @unchecked Sendable {
    private let manager = CMMotionActivityManager()

    public init() {}

    public var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    public func startActivityUpdates(
        to queue: OperationQueue,
        withHandler handler: @escaping @Sendable (MotionActivitySnapshot?) -> Void
    ) {
        manager.startActivityUpdates(to: queue) { activity in
            if let activity = activity {
                handler(MotionActivitySnapshot(activity: activity))
            } else {
                handler(nil)
            }
        }
    }

    public func stopActivityUpdates() {
        manager.stopActivityUpdates()
    }

    public func queryActivityStarting(
        from start: Date,
        to end: Date,
        to queue: OperationQueue,
        withHandler handler: @escaping @Sendable ([MotionActivitySnapshot]?, Error?) -> Void
    ) {
        manager.queryActivityStarting(from: start, to: end, to: queue) { activities, error in
            if let error = error {
                handler(nil, error)
            } else if let activities = activities {
                handler(activities.map { MotionActivitySnapshot(activity: $0) }, nil)
            } else {
                handler([], nil)
            }
        }
    }
}

public final class MockMotionActivityManager: MotionActivityManagerProtocol, @unchecked Sendable {
    public var isActivityAvailable: Bool = true
    public private(set) var isUpdatesActive: Bool = false
    public var queryResults: [MotionActivitySnapshot] = []
    public var queryError: Error?
    public var updateHandler: (@Sendable (MotionActivitySnapshot?) -> Void)?
    public private(set) var capturedQueue: OperationQueue?

    public init() {}

    public func startActivityUpdates(
        to queue: OperationQueue,
        withHandler handler: @escaping @Sendable (MotionActivitySnapshot?) -> Void
    ) {
        isUpdatesActive = true
        capturedQueue = queue
        updateHandler = handler
    }

    public func stopActivityUpdates() {
        isUpdatesActive = false
        updateHandler = nil
    }

    public func queryActivityStarting(
        from start: Date,
        to end: Date,
        to queue: OperationQueue,
        withHandler handler: @escaping @Sendable ([MotionActivitySnapshot]?, Error?) -> Void
    ) {
        handler(queryResults, queryError)
    }

    public func emitActivity(_ snapshot: MotionActivitySnapshot) {
        updateHandler?(snapshot)
    }
}

// MARK: - Auto Drive State

public enum AutoDriveState: Equatable, Sendable {
    case idle
    case driving
    case stationaryCooldown(remainingSeconds: TimeInterval)
    case finalized
}

// MARK: - AutoDriveDetectionService

@MainActor
public final class AutoDriveDetectionService: ObservableObject {
    public static let shared = AutoDriveDetectionService()

    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var autoDriveState: AutoDriveState = .idle
    @Published public private(set) var currentActivityType: MotionActivityType = .unknown
    @Published public private(set) var currentConfidence: MotionConfidence = .low
    @Published public private(set) var remainingCooldownSeconds: TimeInterval = 0
    @Published public private(set) var lastAutomotiveDate: Date? = nil
    @Published public private(set) var lastStationaryDate: Date? = nil
    @Published public private(set) var lastDetectionMessage: String = "Standby"
    @Published public private(set) var autoStartedTripsCount: Int = 0
    @Published public private(set) var autoFinalizedTripsCount: Int = 0

    // Configuration
    public var cooldownThresholdSeconds: TimeInterval = 180.0 // 3 minutes standard automotive exit timeout
    public var minConfidenceRequired: MotionConfidence = .medium
    public var isTestMode: Bool = false

    private var motionManager: MotionActivityManagerProtocol
    private weak var locationService: DriveLocationService?
    private var notificationService: DriveNotificationService
    private var cooldownTimer: Timer?

    public init(
        motionManager: MotionActivityManagerProtocol = SystemMotionActivityManager(),
        locationService: DriveLocationService = DriveLocationService.shared,
        notificationService: DriveNotificationService = DriveNotificationService.shared,
        cooldownThresholdSeconds: TimeInterval = 180.0
    ) {
        self.motionManager = motionManager
        self.locationService = locationService
        self.notificationService = notificationService
        self.cooldownThresholdSeconds = cooldownThresholdSeconds
    }

    // MARK: - Configuration Updates

    public func configure(
        motionManager: MotionActivityManagerProtocol? = nil,
        locationService: DriveLocationService? = nil,
        notificationService: DriveNotificationService? = nil,
        cooldownThresholdSeconds: TimeInterval? = nil
    ) {
        if let motionManager = motionManager {
            self.motionManager = motionManager
        }
        if let locationService = locationService {
            self.locationService = locationService
        }
        if let notificationService = notificationService {
            self.notificationService = notificationService
        }
        if let cooldownThreshold = cooldownThresholdSeconds {
            self.cooldownThresholdSeconds = cooldownThreshold
        }
    }

    // MARK: - Lifecycle & Monitoring

    public func startMonitoringIfEnabled() {
        let prefs = PersistenceController.shared.loadUserPreferences()
        if prefs.autoDetectDrives {
            _ = startMonitoring()
        }
    }

    @discardableResult
    public func startMonitoring() -> Bool {
        guard motionManager.isActivityAvailable else {
            lastDetectionMessage = "Motion activity unavailable on this device"
            return false
        }

        guard !isMonitoring else { return true }

        isMonitoring = true
        lastDetectionMessage = "Monitoring background motion activities..."

        motionManager.startActivityUpdates(to: .main) { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.handleActivityUpdate(snapshot)
            }
        }

        // Query historical activities for recent drive if starting fresh
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let now = Date()
        motionManager.queryActivityStarting(from: fiveMinutesAgo, to: now, to: .main) { [weak self] activities, _ in
            Task { @MainActor [weak self] in
                guard let self = self, let recentActivities = activities, !recentActivities.isEmpty else { return }
                // If the most recent historical activity was automotive, transition state
                if let latest = recentActivities.last, latest.automotive && latest.confidence >= self.minConfidenceRequired {
                    self.handleActivityUpdate(latest)
                }
            }
        }

        return true
    }

    public func stopMonitoring() {
        motionManager.stopActivityUpdates()
        invalidateCooldownTimer()
        isMonitoring = false
        autoDriveState = .idle
        remainingCooldownSeconds = 0
        lastDetectionMessage = "Auto-drive monitoring stopped"
    }

    // MARK: - Activity Processing

    public func handleActivityUpdate(_ snapshot: MotionActivitySnapshot?) {
        guard let snapshot = snapshot else { return }

        currentConfidence = snapshot.confidence
        currentActivityType = snapshot.primaryType

        let prefs = PersistenceController.shared.loadUserPreferences()
        guard prefs.autoDetectDrives else { return }

        if snapshot.automotive {
            handleAutomotiveDetected(snapshot: snapshot)
        } else if snapshot.stationary || snapshot.walking || snapshot.running || snapshot.cycling {
            handleNonAutomotiveDetected(snapshot: snapshot)
        }
    }

    private func handleAutomotiveDetected(snapshot: MotionActivitySnapshot) {
        guard snapshot.confidence >= minConfidenceRequired else {
            lastDetectionMessage = "Automotive motion observed with low confidence; awaiting stronger signal"
            return
        }

        lastAutomotiveDate = snapshot.startDate

        // Case 1: Currently in cooldown (vehicle stopped temporarily e.g. red light, drive-thru)
        if case .stationaryCooldown = autoDriveState {
            invalidateCooldownTimer()
            remainingCooldownSeconds = 0
            if let locationService = locationService, locationService.isPaused {
                locationService.resumeTrip()
            }
            autoDriveState = .driving
            lastDetectionMessage = "Automotive motion resumed; cancelled stop cooldown"
            return
        }

        // Case 2: Not currently tracking -> Automatically start trip
        guard let locationService = locationService else { return }
        if !locationService.isTracking {
            locationService.startTrip()
            autoDriveState = .driving
            autoStartedTripsCount += 1
            lastDetectionMessage = "Auto-started drive trip via CoreMotion"

            let prefs = PersistenceController.shared.loadUserPreferences()
            if prefs.driveNotificationsEnabled {
                notificationService.sendDriveRecordingNotification(distanceKm: 0.1)
            }
        } else if locationService.isPaused {
            locationService.resumeTrip()
            autoDriveState = .driving
            lastDetectionMessage = "Resumed active drive session"
        } else {
            autoDriveState = .driving
        }
    }

    private func handleNonAutomotiveDetected(snapshot: MotionActivitySnapshot) {
        lastStationaryDate = snapshot.startDate

        guard let locationService = locationService, locationService.isTracking else { return }

        // If we are currently actively driving, vehicle has stopped -> Enter Graceful Cooldown & Pause
        if autoDriveState == .driving {
            locationService.pauseTrip()
            remainingCooldownSeconds = cooldownThresholdSeconds
            autoDriveState = .stationaryCooldown(remainingSeconds: remainingCooldownSeconds)
            lastDetectionMessage = "Vehicle stopped; trip paused. Cooldown pending (\(Int(remainingCooldownSeconds))s)"

            startCooldownTimer()
        }
    }

    // MARK: - Cooldown & Finalization Timer

    private func startCooldownTimer() {
        invalidateCooldownTimer()

        if isTestMode { return }

        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.tickCooldown()
            }
        }
    }

    public func tickCooldown(step: TimeInterval = 1.0) {
        guard case .stationaryCooldown = autoDriveState else { return }

        remainingCooldownSeconds -= step
        if remainingCooldownSeconds <= 0 {
            remainingCooldownSeconds = 0
            finalizeAutoTrip()
        } else {
            autoDriveState = .stationaryCooldown(remainingSeconds: remainingCooldownSeconds)
        }
    }

    public func fastForwardCooldown(seconds: TimeInterval) {
        guard case .stationaryCooldown = autoDriveState else { return }
        remainingCooldownSeconds = max(0, remainingCooldownSeconds - seconds)
        if remainingCooldownSeconds <= 0 {
            finalizeAutoTrip()
        } else {
            autoDriveState = .stationaryCooldown(remainingSeconds: remainingCooldownSeconds)
        }
    }

    public func finalizeAutoTrip() {
        invalidateCooldownTimer()
        autoDriveState = .finalized

        guard let locationService = locationService, locationService.isTracking else {
            autoDriveState = .idle
            remainingCooldownSeconds = 0
            return
        }

        let distanceMeters = locationService.distanceMeters
        let prefs = PersistenceController.shared.loadUserPreferences()
        let minimumMeters = prefs.minimumDriveMeters

        let finalTrip = locationService.endTrip()

        if distanceMeters >= minimumMeters {
            autoFinalizedTripsCount += 1
            lastDetectionMessage = String(format: "Trip successfully finalized: %.2f km recorded", distanceMeters / 1000.0)

            if prefs.driveNotificationsEnabled {
                notificationService.sendTripSavedNotification(trip: finalTrip)
            }
        } else {
            lastDetectionMessage = String(format: "Trip ended under minimum threshold (%.0fm < %.0fm)", distanceMeters, minimumMeters)
        }

        autoDriveState = .idle
        remainingCooldownSeconds = 0
    }

    private func invalidateCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }

    // MARK: - Manual Overrides

    public func handleManualTripStarted() {
        invalidateCooldownTimer()
        remainingCooldownSeconds = 0
        autoDriveState = .driving
        lastDetectionMessage = "Manual drive trip started"
    }

    public func handleManualTripEnded() {
        invalidateCooldownTimer()
        remainingCooldownSeconds = 0
        autoDriveState = .idle
        lastDetectionMessage = "Manual drive trip ended"
    }

    // MARK: - Test Simulation

    public func simulateMotionActivity(_ snapshot: MotionActivitySnapshot) {
        handleActivityUpdate(snapshot)
    }

    public func resetCounters() {
        autoStartedTripsCount = 0
        autoFinalizedTripsCount = 0
        remainingCooldownSeconds = 0
        autoDriveState = .idle
        currentActivityType = .unknown
        currentConfidence = .low
        lastDetectionMessage = "Standby"
        invalidateCooldownTimer()
    }
}
