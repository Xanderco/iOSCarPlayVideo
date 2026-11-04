import Foundation
import SwiftUI
import ActivityKit
import Combine

@MainActor
public final class DriveLiveActivityManager: ObservableObject {
    public static let shared = DriveLiveActivityManager()

    @Published public private(set) var isLiveActivityActive: Bool = false
    @Published public private(set) var currentActivityId: String? = nil
    @Published public private(set) var latestState: DashCastTelemetryAttributes.ContentState? = nil
    @Published public private(set) var latestAttributes: DashCastTelemetryAttributes? = nil

    private var currentActivity: Activity<DashCastTelemetryAttributes>? = nil
    private var lastUpdateTime: Date = .distantPast
    private var lastUpdatedSpeed: Double = -1
    private var lastUpdatedGForce: Double = -1
    private var topSpeedRecorded: Double = 0

    // Test support toggle
    public var isTestMode: Bool = false

    public init() {}

    // MARK: - Capabilities Check

    public var areActivitiesEnabled: Bool {
        if isTestMode { return true }
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    // MARK: - Start Activity

    public func startLiveActivity(
        vehicleName: String = "Cyberpunk GT",
        vehicleImageName: String = "car_cyberpunk_supercar",
        speedUnit: String = "KM/H",
        useMilesPerHour: Bool = false,
        initialSpeed: Double = 0.0,
        teaserMode: Bool = false
    ) {
        guard areActivitiesEnabled else {
            print("ActivityKit Live Activities are disabled by user or unsupported on this device.")
            return
        }

        // Avoid duplicate concurrent activities
        if isLiveActivityActive && currentActivity != nil {
            return
        }

        topSpeedRecorded = initialSpeed

        let attributes = DashCastTelemetryAttributes(
            tripId: UUID().uuidString,
            vehicleName: vehicleName,
            vehicleImageName: vehicleImageName,
            speedUnit: speedUnit,
            useMilesPerHour: useMilesPerHour
        )

        let initialState = DashCastTelemetryAttributes.ContentState(
            currentSpeed: initialSpeed,
            currentSpeedKmh: useMilesPerHour ? initialSpeed / 0.621371 : initialSpeed,
            topSpeed: initialSpeed,
            distanceFormatted: useMilesPerHour ? "0.00 mi" : "0.00 km",
            distanceMeters: 0,
            elapsedTime: 0,
            elapsedDurationFormatted: "00:00",
            currentGForce: 0.0,
            peakGForce: 0.0,
            smoothnessScore: 100,
            isPaused: false,
            isParked: false,
            teaserMode: teaserMode,
            lastUpdated: Date()
        )

        self.latestAttributes = attributes
        self.latestState = initialState
        self.isLiveActivityActive = true
        self.lastUpdateTime = Date()
        self.lastUpdatedSpeed = initialSpeed
        self.lastUpdatedGForce = 0.0

        if isTestMode {
            self.currentActivityId = attributes.tripId
            return
        }

        if #available(iOS 16.1, *) {
            do {
                let activity = try Activity<DashCastTelemetryAttributes>.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: nil),
                    pushType: nil
                )
                self.currentActivity = activity
                self.currentActivityId = activity.id
                print("Started DashCast Live Activity: \(activity.id)")
            } catch {
                print("Failed to start DashCast Live Activity: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Update Activity

    public func updateLiveActivity(
        speedKmh: Double,
        distanceMeters: Double,
        elapsedTime: TimeInterval,
        currentGForce: Double,
        peakGForce: Double,
        smoothnessScore: Int,
        isPaused: Bool = false,
        useMilesPerHour: Bool = false,
        forceUpdate: Bool = false
    ) {
        guard isLiveActivityActive else { return }

        let now = Date()
        let displaySpeed = useMilesPerHour ? speedKmh * 0.621371 : speedKmh

        if displaySpeed > topSpeedRecorded {
            topSpeedRecorded = displaySpeed
        }

        // Throttling: ActivityKit limits background frequency
        let timeSinceLast = now.timeIntervalSince(lastUpdateTime)
        let speedDelta = abs(displaySpeed - lastUpdatedSpeed)
        let gForceDelta = abs(currentGForce - lastUpdatedGForce)

        let shouldUpdate = forceUpdate ||
            timeSinceLast >= 1.0 ||
            speedDelta >= 4.0 ||
            gForceDelta >= 0.08 ||
            isPaused != (latestState?.isPaused ?? false)

        guard shouldUpdate else { return }

        let distFormatted: String
        if useMilesPerHour {
            let miles = distanceMeters * 0.000621371
            distFormatted = String(format: "%.2f mi", miles)
        } else {
            let km = distanceMeters / 1000.0
            distFormatted = String(format: "%.2f km", km)
        }

        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        let timeFormatted = String(format: "%02d:%02d", mins, secs)

        let updatedState = DashCastTelemetryAttributes.ContentState(
            currentSpeed: displaySpeed,
            currentSpeedKmh: speedKmh,
            topSpeed: topSpeedRecorded,
            distanceFormatted: distFormatted,
            distanceMeters: distanceMeters,
            elapsedTime: elapsedTime,
            elapsedDurationFormatted: timeFormatted,
            currentGForce: currentGForce,
            peakGForce: peakGForce,
            smoothnessScore: smoothnessScore,
            isPaused: isPaused,
            isParked: speedKmh < 1.0,
            teaserMode: false,
            lastUpdated: now
        )

        self.latestState = updatedState
        self.lastUpdateTime = now
        self.lastUpdatedSpeed = displaySpeed
        self.lastUpdatedGForce = currentGForce

        if isTestMode { return }

        if #available(iOS 16.1, *), let activity = currentActivity {
            Task {
                await activity.update(.init(state: updatedState, staleDate: nil))
            }
        }
    }

    // MARK: - Teaser Banner Activation

    public func startTeaserLiveActivity() {
        startLiveActivity(
            vehicleName: "DashCast Pro",
            initialSpeed: 0,
            teaserMode: true
        )
    }

    // MARK: - End Activity

    public func endLiveActivity(dismissImmediately: Bool = false) {
        guard isLiveActivityActive else { return }

        isLiveActivityActive = false

        if isTestMode {
            currentActivityId = nil
            return
        }

        if #available(iOS 16.1, *), let activity = currentActivity {
            let finalState = latestState
            Task {
                if let state = finalState {
                    await activity.end(
                        .init(state: state, staleDate: nil),
                        dismissalPolicy: dismissImmediately ? .immediate : .default
                    )
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }

        currentActivity = nil
        currentActivityId = nil
    }
}
