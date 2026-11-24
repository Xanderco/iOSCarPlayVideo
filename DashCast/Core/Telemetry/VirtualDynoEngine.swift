import Foundation
import Combine
import CoreLocation

/// Model representing an individual completed acceleration sprint run.
public struct SprintRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let time0To30: Double?
    public let time0To60: Double?
    public let time0To100Kmh: Double?
    public let timeEighthMile: Double?
    public let speedEighthMileMph: Double?
    public let timeQuarterMile: Double?
    public let speedQuarterMileMph: Double?
    public let peakLongitudinalG: Double
    public let peakLateralG: Double
    public let notes: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        time0To30: Double? = nil,
        time0To60: Double? = nil,
        time0To100Kmh: Double? = nil,
        timeEighthMile: Double? = nil,
        speedEighthMileMph: Double? = nil,
        timeQuarterMile: Double? = nil,
        speedQuarterMileMph: Double? = nil,
        peakLongitudinalG: Double = 0.0,
        peakLateralG: Double = 0.0,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.time0To30 = time0To30
        self.time0To60 = time0To60
        self.time0To100Kmh = time0To100Kmh
        self.timeEighthMile = timeEighthMile
        self.speedEighthMileMph = speedEighthMileMph
        self.timeQuarterMile = timeQuarterMile
        self.speedQuarterMileMph = speedQuarterMileMph
        self.peakLongitudinalG = peakLongitudinalG
        self.peakLateralG = peakLateralG
        self.notes = notes
    }
}

/// Operational state of the Virtual Dyno sprint stopwatch.
public enum DynoState: String, Codable, CaseIterable {
    case idle = "idle"
    case staged = "staged"
    case sprinting = "sprinting"
    case completed = "completed"
    case aborted = "aborted"

    public var localizedDescription: String {
        switch self {
        case .idle: return "Ready / Driving"
        case .staged: return "STAGED — Ready for Launch"
        case .sprinting: return "SPRINTING — Full Throttle"
        case .completed: return "FINISHED — Time Logged"
        case .aborted: return "ABORTED — Speed Dropped"
        }
    }
}

/// Real-time telemetry snapshot of an active sprint.
public struct ActiveSprintTelemetry: Equatable {
    public var startTime: Date
    public var currentElapsedTime: Double
    public var currentSpeedMph: Double
    public var currentSpeedKmh: Double
    public var currentDistanceMeters: Double
    public var time0To30: Double?
    public var time0To60: Double?
    public var time0To100Kmh: Double?
    public var timeEighthMile: Double?
    public var speedEighthMileMph: Double?
    public var timeQuarterMile: Double?
    public var speedQuarterMileMph: Double?
    public var peakLongitudinalG: Double
    public var peakLateralG: Double

    public init(
        startTime: Date = Date(),
        currentElapsedTime: Double = 0.0,
        currentSpeedMph: Double = 0.0,
        currentSpeedKmh: Double = 0.0,
        currentDistanceMeters: Double = 0.0,
        time0To30: Double? = nil,
        time0To60: Double? = nil,
        time0To100Kmh: Double? = nil,
        timeEighthMile: Double? = nil,
        speedEighthMileMph: Double? = nil,
        timeQuarterMile: Double? = nil,
        speedQuarterMileMph: Double? = nil,
        peakLongitudinalG: Double = 0.0,
        peakLateralG: Double = 0.0
    ) {
        self.startTime = startTime
        self.currentElapsedTime = currentElapsedTime
        self.currentSpeedMph = currentSpeedMph
        self.currentSpeedKmh = currentSpeedKmh
        self.currentDistanceMeters = currentDistanceMeters
        self.time0To30 = time0To30
        self.time0To60 = time0To60
        self.time0To100Kmh = time0To100Kmh
        self.timeEighthMile = timeEighthMile
        self.speedEighthMileMph = speedEighthMileMph
        self.timeQuarterMile = timeQuarterMile
        self.speedQuarterMileMph = speedQuarterMileMph
        self.peakLongitudinalG = peakLongitudinalG
        self.peakLateralG = peakLateralG
    }
}

/// High-precision automotive performance sprint timer and launch telemetry engine.
@MainActor
public final class VirtualDynoEngine: ObservableObject {
    public static let shared = VirtualDynoEngine()

    public static let historyStorageKey = "dashcast_dyno_sprint_history_v1"
    public static let autoArmStorageKey = "dashcast_dyno_auto_arm_enabled_v1"

    // Milestone Constants
    public static let target30Mph: Double = 30.0
    public static let target60Mph: Double = 60.0
    public static let target100KmhMph: Double = 62.1371 // 100 km/h in mph
    public static let targetEighthMileMeters: Double = 201.168
    public static let targetQuarterMileMeters: Double = 402.336

    // Launch Detection Thresholds
    public static let stationarySpeedThresholdMps: Double = 0.2 // ~0.45 mph
    public static let launchSpeedThresholdMps: Double = 0.8 // ~1.8 mph
    public static let launchAccelerationThresholdG: Double = 0.15
    public static let stagingDwellDurationSeconds: Double = 1.2

    @Published public private(set) var state: DynoState = .idle
    @Published public private(set) var activeTelemetry: ActiveSprintTelemetry?
    @Published public private(set) var lastRecord: SprintRecord?
    @Published public private(set) var personalBest0To60: SprintRecord?
    @Published public private(set) var personalBestQuarterMile: SprintRecord?
    @Published public private(set) var sprintHistory: [SprintRecord] = []
    @Published public var isAutoArmEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutoArmEnabled, forKey: Self.autoArmStorageKey)
        }
    }

    private var stationarySince: Date?
    private var lastUpdateTime: Date?
    private var lastSpeedMps: Double = 0.0

    public init(loadPersistedData: Bool = true) {
        if loadPersistedData {
            self.isAutoArmEnabled = UserDefaults.standard.object(forKey: Self.autoArmStorageKey) as? Bool ?? true
            self.loadHistory()
        }
    }

    // MARK: - Telemetry Sampling Pipeline

    /// Feeds raw velocity and G-force telemetry into the state machine.
    /// - Parameters:
    ///   - speedMps: Current vehicle velocity in meters per second.
    ///   - longitudinalG: Acceleration in forward/backward axis (positive = acceleration).
    ///   - lateralG: Cornering force in lateral axis.
    ///   - timestamp: Sampling timestamp.
    public func processSample(
        speedMps: Double,
        longitudinalG: Double,
        lateralG: Double,
        timestamp: Date = Date()
    ) {
        let cleanSpeedMps = max(0.0, speedMps)
        let speedMph = cleanSpeedMps * 2.23693629
        let speedKmh = cleanSpeedMps * 3.6

        let dt: Double
        if let lastTime = lastUpdateTime {
            dt = max(0.001, timestamp.timeIntervalSince(lastTime))
        } else {
            dt = 0.1
        }
        lastUpdateTime = timestamp

        switch state {
        case .idle:
            if isAutoArmEnabled && cleanSpeedMps <= Self.stationarySpeedThresholdMps {
                if let since = stationarySince {
                    if timestamp.timeIntervalSince(since) >= Self.stagingDwellDurationSeconds {
                        transition(to: .staged)
                    }
                } else {
                    stationarySince = timestamp
                }
            } else {
                stationarySince = nil
            }

        case .staged:
            // Check if user launched
            let isSpeedExceeded = cleanSpeedMps >= Self.launchSpeedThresholdMps
            let isGForceTriggered = longitudinalG >= Self.launchAccelerationThresholdG && cleanSpeedMps > Self.stationarySpeedThresholdMps

            if isSpeedExceeded || isGForceTriggered {
                startSprint(at: timestamp, initialSpeedMph: speedMph, initialSpeedKmh: speedKmh)
            } else if cleanSpeedMps > Self.launchSpeedThresholdMps * 1.5 {
                // Not a clean launch, re-evaluate
                transition(to: .idle)
                stationarySince = nil
            }

        case .sprinting:
            guard var telemetry = activeTelemetry else {
                transition(to: .idle)
                return
            }

            let elapsed = timestamp.timeIntervalSince(telemetry.startTime)
            telemetry.currentElapsedTime = elapsed
            telemetry.currentSpeedMph = speedMph
            telemetry.currentSpeedKmh = speedKmh

            // Trapezoidal integration for distance
            let averageSpeedMps = (lastSpeedMps + cleanSpeedMps) / 2.0
            telemetry.currentDistanceMeters += averageSpeedMps * dt

            // Track peak Gs
            if longitudinalG > telemetry.peakLongitudinalG {
                telemetry.peakLongitudinalG = longitudinalG
            }
            if abs(lateralG) > telemetry.peakLateralG {
                telemetry.peakLateralG = abs(lateralG)
            }

            // Check milestone: 0 - 30 MPH
            if telemetry.time0To30 == nil && speedMph >= Self.target30Mph {
                telemetry.time0To30 = elapsed
            }

            // Check milestone: 0 - 60 MPH
            if telemetry.time0To60 == nil && speedMph >= Self.target60Mph {
                telemetry.time0To60 = elapsed
            }

            // Check milestone: 0 - 100 KM/H
            if telemetry.time0To100Kmh == nil && speedMph >= Self.target100KmhMph {
                telemetry.time0To100Kmh = elapsed
            }

            // Check milestone: 1/8 Mile
            if telemetry.timeEighthMile == nil && telemetry.currentDistanceMeters >= Self.targetEighthMileMeters {
                telemetry.timeEighthMile = elapsed
                telemetry.speedEighthMileMph = speedMph
            }

            // Check milestone: 1/4 Mile
            if telemetry.timeQuarterMile == nil && telemetry.currentDistanceMeters >= Self.targetQuarterMileMeters {
                telemetry.timeQuarterMile = elapsed
                telemetry.speedQuarterMileMph = speedMph
            }

            // Abort condition: vehicle came to a complete stop or dropped speed heavily before 60 mph
            if elapsed > 2.0 && cleanSpeedMps <= Self.stationarySpeedThresholdMps && telemetry.time0To60 == nil {
                activeTelemetry = telemetry
                transition(to: .aborted)
                return
            }

            self.activeTelemetry = telemetry

            // Completion check: 0-60 captured or 1/4 mile reached
            if (telemetry.time0To60 != nil && telemetry.timeQuarterMile != nil) ||
               (telemetry.time0To60 != nil && elapsed >= 15.0) {
                completeSprint(telemetry: telemetry)
            }

        case .completed, .aborted:
            // Auto re-arm when vehicle stops again
            if isAutoArmEnabled && cleanSpeedMps <= Self.stationarySpeedThresholdMps {
                if let since = stationarySince {
                    if timestamp.timeIntervalSince(since) >= Self.stagingDwellDurationSeconds {
                        transition(to: .staged)
                    }
                } else {
                    stationarySince = timestamp
                }
            } else {
                stationarySince = nil
            }
        }

        lastSpeedMps = cleanSpeedMps
    }

    // MARK: - State Transitions

    public func armManually() {
        stationarySince = Date()
        transition(to: .staged)
    }

    public func disarmManually() {
        stationarySince = nil
        transition(to: .idle)
    }

    public func reset() {
        stationarySince = nil
        activeTelemetry = nil
        transition(to: .idle)
    }

    private func transition(to newState: DynoState) {
        state = newState
    }

    private func startSprint(at timestamp: Date, initialSpeedMph: Double, initialSpeedKmh: Double) {
        activeTelemetry = ActiveSprintTelemetry(
            startTime: timestamp,
            currentElapsedTime: 0.0,
            currentSpeedMph: initialSpeedMph,
            currentSpeedKmh: initialSpeedKmh,
            currentDistanceMeters: 0.0,
            peakLongitudinalG: 0.0,
            peakLateralG: 0.0
        )
        transition(to: .sprinting)
    }

    public func completeSprint(telemetry: ActiveSprintTelemetry) {
        let record = SprintRecord(
            id: UUID(),
            date: telemetry.startTime,
            time0To30: telemetry.time0To30,
            time0To60: telemetry.time0To60,
            time0To100Kmh: telemetry.time0To100Kmh,
            timeEighthMile: telemetry.timeEighthMile,
            speedEighthMileMph: telemetry.speedEighthMileMph,
            timeQuarterMile: telemetry.timeQuarterMile,
            speedQuarterMileMph: telemetry.speedQuarterMileMph,
            peakLongitudinalG: telemetry.peakLongitudinalG,
            peakLateralG: telemetry.peakLateralG,
            notes: "Automatic launch detection"
        )

        lastRecord = record
        sprintHistory.insert(record, at: 0)
        recalculatePersonalBests()
        saveHistory()
        transition(to: .completed)
    }

    // MARK: - Personal Best & Persistence

    private func recalculatePersonalBests() {
        let valid0To60 = sprintHistory.compactMap { r -> (SprintRecord, Double)? in
            guard let t = r.time0To60, t > 1.0, t < 60.0 else { return nil }
            return (r, t)
        }
        personalBest0To60 = valid0To60.min(by: { $0.1 < $1.1 })?.0

        let validQuarter = sprintHistory.compactMap { r -> (SprintRecord, Double)? in
            guard let t = r.timeQuarterMile, t > 5.0, t < 120.0 else { return nil }
            return (r, t)
        }
        personalBestQuarterMile = validQuarter.min(by: { $0.1 < $1.1 })?.0
    }

    public func clearHistory() {
        sprintHistory.removeAll()
        lastRecord = nil
        personalBest0To60 = nil
        personalBestQuarterMile = nil
        UserDefaults.standard.removeObject(forKey: Self.historyStorageKey)
    }

    public func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sprintHistory) {
            UserDefaults.standard.set(data, forKey: Self.historyStorageKey)
        }
    }

    public func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyStorageKey) else {
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SprintRecord].self, from: data) {
            self.sprintHistory = decoded
            self.lastRecord = decoded.first
            recalculatePersonalBests()
        }
    }

    public func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(sprintHistory)
    }
}
