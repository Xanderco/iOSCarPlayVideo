import Foundation
import CoreMotion

@MainActor
public final class DrivingScorer: ObservableObject {
    public static let shared = DrivingScorer()

    @Published public private(set) var currentScore: Int = 100
    @Published public private(set) var harshBrakingCount: Int = 0
    @Published public private(set) var harshAccelerationCount: Int = 0
    @Published public private(set) var harshCorneringCount: Int = 0
    @Published public private(set) var currentGForce: Double = 0.0
    @Published public private(set) var peakGForce: Double = 0.0

    private let motionManager = CMMotionManager()
    private var lastSpeedKmh: Double?
    private var lastSpeedTime: Date?

    public init() {
        startMotionUpdates()
    }

    public func reset() {
        currentScore = 100
        harshBrakingCount = 0
        harshAccelerationCount = 0
        harshCorneringCount = 0
        currentGForce = 0.0
        peakGForce = 0.0
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

    public func analyzeGForce(x: Double, y: Double, z: Double) {
        let lateralG = abs(x)
        self.currentGForce = lateralG
        if lateralG > peakGForce {
            peakGForce = lateralG
        }

        // Lateral G-Force (cornering)
        if lateralG > 0.45 {
            recordHarshEvent(.cornering)
        }
    }

    public func simulateGForce(current: Double, peak: Double? = nil) {
        self.currentGForce = current
        if let peak = peak {
            self.peakGForce = peak
        } else if current > self.peakGForce {
            self.peakGForce = current
        }
    }

    public func recordPoint(speedKmh: Double) {
        let now = Date()
        if let previousSpeed = lastSpeedKmh, let previousTime = lastSpeedTime {
            let dt = now.timeIntervalSince(previousTime)
            if dt > 0.3 && dt < 3.0 {
                let deltaKmh = speedKmh - previousSpeed
                let accelerationMs2 = (deltaKmh / 3.6) / dt
                let longitudinalG = abs(accelerationMs2 / 9.80665)
                let combinedG = max(self.currentGForce, longitudinalG)
                self.currentGForce = combinedG
                if combinedG > self.peakGForce {
                    self.peakGForce = combinedG
                }

                // Harsh Braking: deceleration > 3.5 m/s^2 (~0.36g)
                if accelerationMs2 < -3.5 {
                    recordHarshEvent(.braking)
                }
                // Harsh Acceleration: acceleration > 3.0 m/s^2 (~0.31g)
                else if accelerationMs2 > 3.0 {
                    recordHarshEvent(.acceleration)
                }
            }
        }
        lastSpeedKmh = speedKmh
        lastSpeedTime = now
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
