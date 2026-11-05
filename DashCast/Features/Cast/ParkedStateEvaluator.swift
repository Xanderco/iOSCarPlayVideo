import Foundation

enum VehicleMotionState: String, Codable {
    case parked
    case moving
    case unknown
}

/// Pure decision logic for the "parked only" guard, with hysteresis so a
/// stop at a red light does not immediately re-enable video.
struct ParkedStateEvaluator {
    /// At or above this GPS speed the vehicle is considered moving.
    var movingSpeedKmh: Double = 8
    /// Below this GPS speed the vehicle is a candidate for "parked".
    var parkedSpeedKmh: Double = 3
    /// How long the vehicle must stay slow after moving before video resumes.
    var parkedHoldSeconds: TimeInterval = 10

    private(set) var state: VehicleMotionState = .unknown
    private var slowSince: Date?

    init(movingSpeedKmh: Double = 8, parkedSpeedKmh: Double = 3, parkedHoldSeconds: TimeInterval = 10) {
        self.movingSpeedKmh = movingSpeedKmh
        self.parkedSpeedKmh = parkedSpeedKmh
        self.parkedHoldSeconds = parkedHoldSeconds
    }

    /// - Parameters:
    ///   - speedKmh: latest valid GPS speed, or nil when unknown.
    ///   - automotiveMoving: Core Motion "automotive and not stationary", or nil when unknown.
    @discardableResult
    mutating func update(speedKmh: Double?, automotiveMoving: Bool?, at now: Date) -> VehicleMotionState {
        let fastBySpeed = (speedKmh ?? 0) >= movingSpeedKmh
        let movingByMotion = automotiveMoving == true && (speedKmh == nil || speedKmh! >= parkedSpeedKmh)

        if fastBySpeed || movingByMotion {
            state = .moving
            slowSince = nil
            return state
        }

        let slow: Bool
        if let speedKmh {
            slow = speedKmh < parkedSpeedKmh
        } else {
            slow = automotiveMoving == false
        }

        guard slow else {
            // In the band between parked and moving thresholds: keep the current state.
            slowSince = nil
            return state
        }

        if slowSince == nil { slowSince = now }
        if state != .moving || now.timeIntervalSince(slowSince!) >= parkedHoldSeconds {
            state = .parked
        }
        return state
    }

    /// Video output is blocked only when we positively know the vehicle is moving.
    var blocksVideo: Bool { state == .moving }
}
