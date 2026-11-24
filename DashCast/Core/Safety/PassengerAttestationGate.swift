import Foundation
import Combine
import SwiftUI

/// Automotive safety gate regulating driver-facing and CarPlay video playback
/// based on vehicle velocity geofencing and passenger attestation.
///
/// Federal & state automotive safety regulations (FMVSS / NHTSA) prohibit
/// driver-visible video displays while a vehicle is in motion (velocity > 5 mph / ~8.05 km/h).
/// When the vehicle velocity exceeds this threshold, video playback is gated
/// until a passenger provides verifiable physical multi-finger attestation.
@MainActor
public final class PassengerAttestationGate: ObservableObject {
    public static let shared = PassengerAttestationGate()

    // MARK: - Constants
    /// Regulatory speed threshold: 5.0 mph in km/h (~8.04672 km/h).
    public static let speedThresholdMph: Double = 5.0
    public static let speedThresholdKmh: Double = 8.04672
    public static let defaultSessionDuration: TimeInterval = 900 // 15 minutes

    // MARK: - Published State
    @Published public private(set) var currentSpeedKmh: Double = 0
    @Published public private(set) var currentSpeedMph: Double = 0
    @Published public private(set) var isVehicleMovingAboveThreshold: Bool = false
    @Published public private(set) var isAttestationRequired: Bool = false
    @Published public private(set) var isPassengerModeActive: Bool = false
    @Published public private(set) var isPlaybackAllowed: Bool = true
    @Published public private(set) var attestationExpiresAt: Date?
    @Published public private(set) var sessionTimeRemaining: TimeInterval = 0
    @Published public var sessionDuration: TimeInterval = defaultSessionDuration
    @Published public private(set) var auditHistory: [AuditEvent] = []
    @Published public var showAttestationSheet: Bool = false

    // MARK: - Audit Model
    public struct AuditEvent: Codable, Identifiable, Equatable {
        public let id: UUID
        public let timestamp: Date
        public let eventType: EventType
        public let speedMph: Double
        public let speedKmh: Double
        public let method: String
        public let details: String

        public enum EventType: String, Codable {
            case speedThresholdExceeded
            case speedDroppedBelowThreshold
            case attestationGranted
            case attestationRevoked
            case attestationExpired
            case playbackBlocked
            case playbackAllowed
        }

        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            eventType: EventType,
            speedMph: Double,
            speedKmh: Double,
            method: String,
            details: String
        ) {
            self.id = id
            self.timestamp = timestamp
            self.eventType = eventType
            self.speedMph = speedMph
            self.speedKmh = speedKmh
            self.method = method
            self.details = details
        }
    }

    // MARK: - Attestation Methods
    public enum AttestationMethod: String, Codable {
        case multiFingerTouch = "multi_finger_touch"
        case manualConfirmation = "manual_confirm"
        case simulated = "simulated"
    }

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private let auditLogFileName = "passenger_attestation_audit.json"
    private let userDefaultsSessionKey = "dashcast_passenger_attestation_session_v1"

    // MARK: - Initialization
    public init() {
        loadAuditHistory()
        bindToLocationService()
        restorePersistedSession()
    }

    deinit {
        sessionTimer?.invalidate()
    }

    // MARK: - Location Service Integration
    private func bindToLocationService() {
        DriveLocationService.shared.$currentSpeedKmh
            .receive(on: RunLoop.main)
            .sink { [weak self] speed in
                self?.ingestSpeed(kmh: speed)
            }
            .store(in: &cancellables)
    }

    /// Ingests speed updates from GPS telemetry and evaluates safety geofence gates.
    public func ingestSpeed(kmh: Double, at date: Date = Date()) {
        currentSpeedKmh = max(0, kmh)
        currentSpeedMph = currentSpeedKmh * 0.621371

        let wasAboveThreshold = isVehicleMovingAboveThreshold
        let isNowAboveThreshold = currentSpeedKmh > Self.speedThresholdKmh
        isVehicleMovingAboveThreshold = isNowAboveThreshold

        if isNowAboveThreshold {
            if !wasAboveThreshold {
                recordAudit(
                    eventType: .speedThresholdExceeded,
                    method: "telemetry",
                    details: String(format: "Speed exceeded 5 mph: %.1f mph (%.1f km/h)", currentSpeedMph, currentSpeedKmh)
                )
            }

            // Check if active attestation session is valid
            if let expiresAt = attestationExpiresAt, date < expiresAt {
                // Attestation still valid
                isPassengerModeActive = true
                isAttestationRequired = false
                isPlaybackAllowed = true
                updateTimeRemaining(now: date)
                startSessionTimerIfNeeded()
            } else {
                // Not attested or session expired: block playback and prompt passenger
                let wasExpired = attestationExpiresAt != nil
                if wasExpired && isPassengerModeActive {
                    recordAudit(
                        eventType: .attestationExpired,
                        method: "timer",
                        details: "Passenger attestation session timed out while in motion"
                    )
                }

                isPassengerModeActive = false
                isAttestationRequired = true
                isPlaybackAllowed = false
                attestationExpiresAt = nil
                sessionTimeRemaining = 0
                stopSessionTimer()

                recordAudit(
                    eventType: .playbackBlocked,
                    method: "gate",
                    details: "Video playback blocked: vehicle velocity exceeds 5 mph without passenger attestation"
                )
            }
        } else {
            // Speed dropped below threshold: parked or stopped at red light
            if wasAboveThreshold {
                recordAudit(
                    eventType: .speedDroppedBelowThreshold,
                    method: "telemetry",
                    details: String(format: "Speed dropped below 5 mph: %.1f mph (%.1f km/h)", currentSpeedMph, currentSpeedKmh)
                )
            }

            // Parked or stopped vehicle video playback is legally unrestricted
            isAttestationRequired = false
            isPlaybackAllowed = true

            // If attestation is valid, maintain session remaining time
            if let expiresAt = attestationExpiresAt, date < expiresAt {
                updateTimeRemaining(now: date)
            }
        }
    }

    // MARK: - Attestation Actions
    /// Passenger confirms viewing via physical multi-finger touch or acknowledgment.
    public func confirmPassengerAttestation(
        method: AttestationMethod = .multiFingerTouch,
        now: Date = Date()
    ) {
        let expiration = now.addingTimeInterval(sessionDuration)
        attestationExpiresAt = expiration
        isPassengerModeActive = true
        isAttestationRequired = false
        isPlaybackAllowed = true
        showAttestationSheet = false

        updateTimeRemaining(now: now)
        startSessionTimerIfNeeded()
        persistSession(expiresAt: expiration)

        recordAudit(
            eventType: .attestationGranted,
            method: method.rawValue,
            details: String(format: "Passenger attestation confirmed via %@ for %.0f seconds", method.rawValue, sessionDuration)
        )
        recordAudit(
            eventType: .playbackAllowed,
            method: "gate",
            details: "Video playback unlocked for passenger viewing while in motion"
        )
    }

    /// Revokes active passenger attestation, immediately locking motion video.
    public func revokeAttestation(reason: String = "manual_user_action") {
        attestationExpiresAt = nil
        isPassengerModeActive = false
        sessionTimeRemaining = 0
        stopSessionTimer()
        clearPersistedSession()

        if isVehicleMovingAboveThreshold {
            isAttestationRequired = true
            isPlaybackAllowed = false
            recordAudit(
                eventType: .playbackBlocked,
                method: "gate",
                details: "Video playback blocked following passenger attestation revocation"
            )
        } else {
            isAttestationRequired = false
            isPlaybackAllowed = true
        }

        recordAudit(
            eventType: .attestationRevoked,
            method: "manual",
            details: "Passenger attestation revoked: \(reason)"
        )
    }

    // MARK: - Timer Handling
    private func startSessionTimerIfNeeded() {
        guard sessionTimer == nil else { return }
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimerTick()
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func handleTimerTick() {
        let now = Date()
        guard let expiresAt = attestationExpiresAt else {
            stopSessionTimer()
            sessionTimeRemaining = 0
            return
        }

        if now >= expiresAt {
            // Expired
            stopSessionTimer()
            attestationExpiresAt = nil
            sessionTimeRemaining = 0
            clearPersistedSession()

            if isVehicleMovingAboveThreshold {
                isPassengerModeActive = false
                isAttestationRequired = true
                isPlaybackAllowed = false

                recordAudit(
                    eventType: .attestationExpired,
                    method: "timer",
                    details: "Passenger session expired while vehicle is moving"
                )
                recordAudit(
                    eventType: .playbackBlocked,
                    method: "gate",
                    details: "Playback blocked due to expired attestation"
                )
            }
        } else {
            updateTimeRemaining(now: now)
        }
    }

    private func updateTimeRemaining(now: Date = Date()) {
        if let expiresAt = attestationExpiresAt {
            sessionTimeRemaining = max(0, expiresAt.timeIntervalSince(now))
        } else {
            sessionTimeRemaining = 0
        }
    }

    // MARK: - Persistence & Secure Audit Trail
    private var auditFileURL: URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("DashCastSecurity", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(auditLogFileName)
    }

    private func recordAudit(eventType: AuditEvent.EventType, method: String, details: String) {
        let event = AuditEvent(
            eventType: eventType,
            speedMph: currentSpeedMph,
            speedKmh: currentSpeedKmh,
            method: method,
            details: details
        )
        auditHistory.append(event)
        saveAuditHistory()
    }

    private func saveAuditHistory() {
        do {
            let data = try JSONEncoder().encode(auditHistory)
            try data.write(to: auditFileURL, options: .atomic)
        } catch {
            // Silently fallback if disk writes are restricted in sandbox unit tests
        }
    }

    private func loadAuditHistory() {
        guard let data = try? Data(contentsOf: auditFileURL),
              let history = try? JSONDecoder().decode([AuditEvent].self, from: data) else {
            auditHistory = []
            return
        }
        auditHistory = history
    }

    public func clearAuditHistory() {
        auditHistory.removeAll()
        try? FileManager.default.removeItem(at: auditFileURL)
    }

    private func persistSession(expiresAt: Date) {
        UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: userDefaultsSessionKey)
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: userDefaultsSessionKey)
    }

    private func restorePersistedSession() {
        let timestamp = UserDefaults.standard.double(forKey: userDefaultsSessionKey)
        guard timestamp > 0 else { return }
        let expiration = Date(timeIntervalSince1970: timestamp)
        let now = Date()
        if expiration > now {
            attestationExpiresAt = expiration
            updateTimeRemaining(now: now)
            startSessionTimerIfNeeded()
        } else {
            clearPersistedSession()
        }
    }

    // MARK: - Test & Debug Utilities
    public func resetDefaults() {
        stopSessionTimer()
        currentSpeedKmh = 0
        currentSpeedMph = 0
        isVehicleMovingAboveThreshold = false
        isAttestationRequired = false
        isPassengerModeActive = false
        isPlaybackAllowed = true
        attestationExpiresAt = nil
        sessionTimeRemaining = 0
        sessionDuration = Self.defaultSessionDuration
        showAttestationSheet = false
        clearPersistedSession()
        clearAuditHistory()
    }

    public func simulateSpeed(kmh: Double, at date: Date = Date()) {
        ingestSpeed(kmh: kmh, at: date)
    }

    public func simulateExpiration() {
        attestationExpiresAt = Date().addingTimeInterval(-1)
        handleTimerTick()
    }
}
