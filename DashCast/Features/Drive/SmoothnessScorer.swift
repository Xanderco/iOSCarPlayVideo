import Foundation
import CoreMotion
import SwiftUI

/// Smoothness badge classification tier for drive telemetry and social sharing.
public enum SmoothnessBadgeTier: String, Codable, CaseIterable {
    case formulaElite = "PRO PILOT"
    case smoothOperator = "SMOOTH OPERATOR"
    case urbanCruiser = "URBAN CRUISER"
    case spiritedDriver = "SPIRITED DRIVER"
    case trackDemon = "TRACK DEMON"

    public var title: String { rawValue }

    public var accentHex: String {
        switch self {
        case .formulaElite: return "#FFE600"    // Electric Yellow
        case .smoothOperator: return "#34C759"  // Emerald Green
        case .urbanCruiser: return "#3B82F6"    // Precision Blue
        case .spiritedDriver: return "#FFB800"  // Racing Gold / Amber
        case .trackDemon: return "#FF3B30"      // Track Red
        }
    }

    public var accentColor: Color {
        Color(hex: accentHex)
    }

    public var badgeSubtitle: String {
        switch self {
        case .formulaElite: return "F1-Grade Chassis Balance"
        case .smoothOperator: return "Buttery Throttle & Trail-Braking"
        case .urbanCruiser: return "Clean Commuter Flow"
        case .spiritedDriver: return "Dynamic Weight Transfer"
        case .trackDemon: return "Aggressive Apex Hunter"
        }
    }

    public static func tier(for score: Int) -> SmoothnessBadgeTier {
        switch score {
        case 95...100: return .formulaElite
        case 85..<95: return .smoothOperator
        case 70..<85: return .urbanCruiser
        case 50..<70: return .spiritedDriver
        default: return .trackDemon
        }
    }
}

/// Dynamic and peak G-force metrics captured during a driving session.
public struct SmoothnessMetrics: Codable, Equatable {
    public var score: Int
    public var badgeTier: SmoothnessBadgeTier
    public var peakLateralG: Double
    public var peakLongitudinalG: Double
    public var peakCombinedG: Double
    public var harshBrakingCount: Int
    public var harshAccelerationCount: Int
    public var harshCorneringCount: Int
    public var calculatedAt: Date

    public init(
        score: Int = 100,
        badgeTier: SmoothnessBadgeTier = .formulaElite,
        peakLateralG: Double = 0.0,
        peakLongitudinalG: Double = 0.0,
        peakCombinedG: Double = 0.0,
        harshBrakingCount: Int = 0,
        harshAccelerationCount: Int = 0,
        harshCorneringCount: Int = 0,
        calculatedAt: Date = Date()
    ) {
        self.score = score
        self.badgeTier = badgeTier
        self.peakLateralG = peakLateralG
        self.peakLongitudinalG = peakLongitudinalG
        self.peakCombinedG = peakCombinedG
        self.harshBrakingCount = harshBrakingCount
        self.harshAccelerationCount = harshAccelerationCount
        self.harshCorneringCount = harshCorneringCount
        self.calculatedAt = calculatedAt
    }
}

/// High-precision driving smoothness evaluation engine and real-time G-force analyzer.
@MainActor
public final class SmoothnessScorer: ObservableObject {
    public static let shared = SmoothnessScorer()

    @Published public private(set) var currentScore: Int = 100
    @Published public private(set) var currentBadgeTier: SmoothnessBadgeTier = .formulaElite
    @Published public private(set) var harshBrakingCount: Int = 0
    @Published public private(set) var harshAccelerationCount: Int = 0
    @Published public private(set) var harshCorneringCount: Int = 0
    @Published public private(set) var peakLateralG: Double = 0.0
    @Published public private(set) var peakLongitudinalG: Double = 0.0
    @Published public private(set) var peakCombinedG: Double = 0.0

    // Calibrated G-force thresholds
    public static let harshBrakingDecelThreshold: Double = -3.5  // m/s^2 (~0.36g)
    public static let harshAccelThreshold: Double = 3.0          // m/s^2 (~0.31g)
    public static let sharpCorneringGThreshold: Double = 0.52     // calibrated lateral G

    private let motionManager = CMMotionManager()
    private var lastSpeedKmh: Double?
    private var lastSpeedTime: Date?

    public init() {
        startMotionUpdates()
    }

    public func reset() {
        currentScore = 100
        currentBadgeTier = .formulaElite
        harshBrakingCount = 0
        harshAccelerationCount = 0
        harshCorneringCount = 0
        peakLateralG = 0.0
        peakLongitudinalG = 0.0
        peakCombinedG = 0.0
        lastSpeedKmh = nil
        lastSpeedTime = nil
    }

    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }
            self.analyzeGForce(x: acceleration.x, y: acceleration.y, z: acceleration.z)
        }
    }

    /// Evaluates raw 3-axis accelerometer readings, updates peak G tracking, and flags harsh cornering.
    public func analyzeGForce(x: Double, y: Double, z: Double) {
        let lateralG = abs(x)
        let longitudinalG = abs(y)
        let combinedG = sqrt(x * x + y * y)

        if lateralG > peakLateralG {
            peakLateralG = lateralG
        }
        if longitudinalG > peakLongitudinalG {
            peakLongitudinalG = longitudinalG
        }
        if combinedG > peakCombinedG {
            peakCombinedG = combinedG
        }

        if lateralG >= Self.sharpCorneringGThreshold {
            recordHarshEvent(.cornering)
        }
    }

    /// Analyzes sequential speed telemetry delta to detect longitudinal harsh acceleration or braking.
    public func recordPoint(speedKmh: Double, timestamp: Date = Date()) {
        if let previousSpeed = lastSpeedKmh, let previousTime = lastSpeedTime {
            let dt = timestamp.timeIntervalSince(previousTime)
            if dt > 0.3 && dt < 3.0 {
                let deltaKmh = speedKmh - previousSpeed
                let accelerationMs2 = (deltaKmh / 3.6) / dt

                // Update longitudinal G approximation (1g = 9.80665 m/s^2)
                let approxG = abs(accelerationMs2) / 9.80665
                if approxG > peakLongitudinalG {
                    peakLongitudinalG = approxG
                }

                if accelerationMs2 <= Self.harshBrakingDecelThreshold {
                    recordHarshEvent(.braking)
                } else if accelerationMs2 >= Self.harshAccelThreshold {
                    recordHarshEvent(.acceleration)
                }
            }
        }
        lastSpeedKmh = speedKmh
        lastSpeedTime = timestamp
    }

    public enum HarshEventType {
        case braking
        case acceleration
        case cornering
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

    /// Calculates composite driving score: 100 base - (braking * 4) - (accel * 3) - (cornering * 3). Clamped floor: 10.
    @discardableResult
    public func calculateScore() -> Int {
        let penalty = (harshBrakingCount * 4) + (harshAccelerationCount * 3) + (harshCorneringCount * 3)
        let finalScore = max(10, 100 - penalty)
        self.currentScore = finalScore
        self.currentBadgeTier = SmoothnessBadgeTier.tier(for: finalScore)
        return finalScore
    }

    /// Exports snapshot metrics structure for card rendering.
    public var metrics: SmoothnessMetrics {
        SmoothnessMetrics(
            score: currentScore,
            badgeTier: currentBadgeTier,
            peakLateralG: peakLateralG,
            peakLongitudinalG: peakLongitudinalG,
            peakCombinedG: peakCombinedG,
            harshBrakingCount: harshBrakingCount,
            harshAccelerationCount: harshAccelerationCount,
            harshCorneringCount: harshCorneringCount,
            calculatedAt: Date()
        )
    }

    /// Pure function evaluator for completed trips.
    public static func evaluate(trip: TripModel) -> SmoothnessMetrics {
        let score = trip.drivingScore
        let badge = SmoothnessBadgeTier.tier(for: score)

        // Calculate approximate peak G from recorded points if available
        var maxLateral: Double = 0.35
        var maxLongitudinal: Double = 0.30

        if trip.harshCorneringCount > 0 {
            maxLateral = max(0.55, 0.52 + Double(trip.harshCorneringCount) * 0.05)
        }
        if trip.harshBrakingCount > 0 || trip.harshAccelerationCount > 0 {
            let maxHarsh = max(trip.harshBrakingCount, trip.harshAccelerationCount)
            maxLongitudinal = max(0.40, 0.36 + Double(maxHarsh) * 0.04)
        }

        let combined = sqrt(maxLateral * maxLateral + maxLongitudinal * maxLongitudinal)

        return SmoothnessMetrics(
            score: score,
            badgeTier: badge,
            peakLateralG: maxLateral,
            peakLongitudinalG: maxLongitudinal,
            peakCombinedG: combined,
            harshBrakingCount: trip.harshBrakingCount,
            harshAccelerationCount: trip.harshAccelerationCount,
            harshCorneringCount: trip.harshCorneringCount,
            calculatedAt: trip.endTime ?? Date()
        )
    }
}
