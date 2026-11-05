import Foundation

/// Core Motion confidence, decoupled from `CMMotionActivityConfidence` so the logic is testable.
enum MotionConfidence: Int, Comparable {
    case low = 0, medium, high
    static func < (lhs: MotionConfidence, rhs: MotionConfidence) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One observation fed to the state machine. Any field may be nil when that sensor has nothing new.
struct TripDetectionSample {
    var speedKmh: Double?
    /// true = Core Motion says automotive, false = stationary/walking/etc., nil = unknown.
    var automotive: Bool?
    var confidence: MotionConfidence
    var at: Date

    init(speedKmh: Double? = nil, automotive: Bool? = nil, confidence: MotionConfidence = .low, at: Date) {
        self.speedKmh = speedKmh
        self.automotive = automotive
        self.confidence = confidence
        self.at = at
    }
}

enum TripDetectionEvent: Equatable {
    case none
    case startTrip
    case endTrip
}

/// Pure decision logic for automatic trip detection. No Core Location / Core Motion here:
/// the caller feeds samples with explicit timestamps, so tests drive it with a fake clock.
///
/// Start: automotive (confidence >= medium) AND speed above `startSpeedKmh`, sustained for
/// `startHoldSeconds`. Without a recent automotive reading, a sustained speed above
/// `speedOnlyStartKmh` also counts (Core Motion can lag or be unavailable in the simulator).
///
/// End: reuses `ParkedStateEvaluator` (the same hysteresis as the parked-only video guard)
/// with a `stopHoldSeconds` hold, so a red light doesn't end the trip.
struct TripDetectionStateMachine {
    enum Phase: Equatable {
        case idle
        case candidate(since: Date)
        case driving
    }

    var startSpeedKmh: Double = 15
    var speedOnlyStartKmh: Double = 25
    var startHoldSeconds: TimeInterval = 60
    var stopHoldSeconds: TimeInterval = 180
    /// A motion reading older than this no longer counts as "automotive now".
    var motionFreshnessSeconds: TimeInterval = 120

    private(set) var phase: Phase = .idle
    private var lastAutomotive: (value: Bool, confidence: MotionConfidence, at: Date)?
    private var lastSpeed: (kmh: Double, at: Date)?
    private var parked: ParkedStateEvaluator

    init(startSpeedKmh: Double = 15,
         speedOnlyStartKmh: Double = 25,
         startHoldSeconds: TimeInterval = 60,
         stopHoldSeconds: TimeInterval = 180) {
        self.startSpeedKmh = startSpeedKmh
        self.speedOnlyStartKmh = speedOnlyStartKmh
        self.startHoldSeconds = startHoldSeconds
        self.stopHoldSeconds = stopHoldSeconds
        self.parked = ParkedStateEvaluator(movingSpeedKmh: 8, parkedSpeedKmh: 3, parkedHoldSeconds: stopHoldSeconds)
    }

    var isDriving: Bool { phase == .driving }

    /// Call when a trip was started or stopped by hand so detection follows along.
    mutating func reset(driving: Bool, at now: Date) {
        phase = driving ? .driving : .idle
        parked = ParkedStateEvaluator(movingSpeedKmh: 8, parkedSpeedKmh: 3, parkedHoldSeconds: stopHoldSeconds)
        if driving { parked.update(speedKmh: startSpeedKmh, automotiveMoving: true, at: now) }
    }

    @discardableResult
    mutating func update(_ sample: TripDetectionSample) -> TripDetectionEvent {
        let now = sample.at
        if let automotive = sample.automotive {
            lastAutomotive = (automotive, sample.confidence, now)
        }
        if let speed = sample.speedKmh, speed >= 0 {
            lastSpeed = (speed, now)
        }

        switch phase {
        case .idle, .candidate:
            if looksLikeDriving(at: now) {
                let since: Date
                if case .candidate(let s) = phase { since = s } else { since = now; phase = .candidate(since: now) }
                if now.timeIntervalSince(since) >= startHoldSeconds {
                    reset(driving: true, at: now)
                    return .startTrip
                }
            } else {
                phase = .idle
            }
            return .none

        case .driving:
            let speed = freshSpeed(at: now)
            var automotiveMoving: Bool?
            if let motion = freshAutomotive(at: now), motion.confidence >= .medium {
                automotiveMoving = motion.value
            }
            // No fresh speed and no fresh motion (updates stopped, e.g. parked in a garage): treat
            // as stationary so the trip still ends after the hold.
            let effectiveSpeed = (speed == nil && automotiveMoving == nil) ? 0 : speed
            let state = parked.update(speedKmh: effectiveSpeed, automotiveMoving: automotiveMoving, at: now)
            if state == .parked {
                phase = .idle
                return .endTrip
            }
            return .none
        }
    }

    private func freshSpeed(at now: Date) -> Double? {
        guard let lastSpeed, now.timeIntervalSince(lastSpeed.at) <= 30 else { return nil }
        return lastSpeed.kmh
    }

    private func freshAutomotive(at now: Date) -> (value: Bool, confidence: MotionConfidence)? {
        guard let a = lastAutomotive, now.timeIntervalSince(a.at) <= motionFreshnessSeconds else { return nil }
        return (a.value, a.confidence)
    }

    private func looksLikeDriving(at now: Date) -> Bool {
        guard let speed = freshSpeed(at: now) else { return false }
        if let motion = freshAutomotive(at: now) {
            if motion.value && motion.confidence >= .medium { return speed > startSpeedKmh }
            if !motion.value && motion.confidence >= .medium { return speed > speedOnlyStartKmh * 2 } // e.g. train mislabelled
        }
        return speed > speedOnlyStartKmh
    }
}
