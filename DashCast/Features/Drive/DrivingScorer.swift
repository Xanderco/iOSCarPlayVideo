import Foundation

/// Scores a trip from GPS-derived events.
///
/// The previous version started the accelerometer at app launch (forever, even with no trip) and
/// flagged "harsh cornering" whenever raw `acceleration.x` exceeded 0.45 g. Raw accelerometer data
/// includes gravity, so a phone in a landscape mount reads ~1 g on x permanently and every 0.2 s
/// sample cost 3 points: scores collapsed to the 10-point floor. Cornering is now derived from GPS
/// (lateral acceleration = speed × heading change rate), which does not depend on how the phone
/// is mounted, and only runs while a trip is recording.
@MainActor
public final class DrivingScorer: ObservableObject {
    public static let shared = DrivingScorer()

    @Published public private(set) var currentScore: Int = 100
    @Published public private(set) var harshBrakingCount: Int = 0
    @Published public private(set) var harshAccelerationCount: Int = 0
    @Published public private(set) var harshCorneringCount: Int = 0

    // Thresholds (m/s²)
    nonisolated public static let brakingThreshold = -3.5      // ~0.36 g
    nonisolated public static let accelerationThreshold = 3.0  // ~0.31 g
    nonisolated public static let corneringThreshold = 4.0     // ~0.41 g lateral
    /// Minimum speed for cornering detection; GPS course is noise below this.
    nonisolated public static let minCorneringSpeedKmh = 20.0
    /// One physical event spans several GPS samples; count it once.
    nonisolated public static let eventCooldown: TimeInterval = 3.0

    private var lastSpeedKmh: Double?
    private var lastCourse: Double?
    private var lastSampleTime: Date?
    private var lastEventTime: [HarshEventType: Date] = [:]

    public init() {}

    public func reset() {
        currentScore = 100
        harshBrakingCount = 0
        harshAccelerationCount = 0
        harshCorneringCount = 0
        lastSpeedKmh = nil
        lastCourse = nil
        lastSampleTime = nil
        lastEventTime = [:]
    }

    /// Feed one GPS sample. `course` is degrees (0–360) or negative when invalid.
    /// `timestamp` should be the location's own timestamp so batched/background updates
    /// are evaluated with the real time delta.
    public func recordPoint(speedKmh: Double, course: Double = -1, timestamp: Date = Date()) {
        if let previousSpeed = lastSpeedKmh, let previousTime = lastSampleTime {
            let dt = timestamp.timeIntervalSince(previousTime)
            if dt > 0.3 && dt < 3.0 {
                let accelerationMs2 = ((speedKmh - previousSpeed) / 3.6) / dt
                if accelerationMs2 < Self.brakingThreshold {
                    recordDetectedEvent(.braking, at: timestamp)
                } else if accelerationMs2 > Self.accelerationThreshold {
                    recordDetectedEvent(.acceleration, at: timestamp)
                }

                if course >= 0, let previousCourse = lastCourse, previousCourse >= 0,
                   speedKmh >= Self.minCorneringSpeedKmh {
                    let lateral = Self.lateralAcceleration(
                        speedKmh: speedKmh, previousCourse: previousCourse, course: course, dt: dt
                    )
                    if lateral > Self.corneringThreshold {
                        recordDetectedEvent(.cornering, at: timestamp)
                    }
                }
            }
        }
        lastSpeedKmh = speedKmh
        lastCourse = course
        lastSampleTime = timestamp
    }

    /// Lateral acceleration (m/s²) = v · ω, with ω the heading change rate in rad/s.
    nonisolated public static func lateralAcceleration(
        speedKmh: Double, previousCourse: Double, course: Double, dt: TimeInterval
    ) -> Double {
        guard dt > 0 else { return 0 }
        var delta = abs(course - previousCourse).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta = 360 - delta }
        let omega = (delta * .pi / 180) / dt
        return (speedKmh / 3.6) * omega
    }

    /// Kept for API compatibility. Raw accelerometer samples include gravity and depend on how
    /// the phone is mounted, so they are no longer used for scoring.
    public func analyzeGForce(x: Double, y: Double, z: Double) {}

    public enum HarshEventType: Hashable {
        case braking
        case acceleration
        case cornering
    }

    private func recordDetectedEvent(_ type: HarshEventType, at time: Date) {
        if let last = lastEventTime[type], time.timeIntervalSince(last) < Self.eventCooldown {
            return
        }
        lastEventTime[type] = time
        recordHarshEvent(type)
    }

    public func recordHarshEvent(_ type: HarshEventType) {
        switch type {
        case .braking:
            harshBrakingCount += 1
        case .acceleration:
            harshAccelerationCount += 1
        case .cornering:
            harshCorneringCount += 1
        }
        _ = calculateScore()
    }

    public func calculateScore() -> Int {
        // Base score = 100
        // Harsh braking: -4 pts each
        // Harsh acceleration: -3 pts each
        // Harsh cornering: -3 pts each
        let penalty = (harshBrakingCount * 4) + (harshAccelerationCount * 3) + (harshCorneringCount * 3)
        let finalScore = max(10, 100 - penalty)
        self.currentScore = finalScore
        return finalScore
    }
}
