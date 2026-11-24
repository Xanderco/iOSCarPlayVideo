import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Station Presets

public enum EVStationPreset: String, CaseIterable, Identifiable, Codable {
    case teslaSupercharger = "teslaSupercharger"
    case electrifyAmerica = "electrifyAmerica"
    case evgo = "evgo"
    case restArea = "restArea"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .teslaSupercharger: return "Tesla Supercharger"
        case .electrifyAmerica: return "Electrify America"
        case .evgo: return "EVgo Fast Charging"
        case .restArea: return "Rest Area & Coffee Break"
        }
    }

    public var shortName: String {
        switch self {
        case .teslaSupercharger: return "Supercharger"
        case .electrifyAmerica: return "Electrify Am."
        case .evgo: return "EVgo"
        case .restArea: return "Rest Stop"
        }
    }

    public var systemImage: String {
        switch self {
        case .teslaSupercharger: return "bolt.car.fill"
        case .electrifyAmerica: return "bolt.batteryblock.fill"
        case .evgo: return "powerplug.fill"
        case .restArea: return "cup.and.saucer.fill"
        }
    }

    public var brandColorHex: String {
        switch self {
        case .teslaSupercharger: return "#E82127"
        case .electrifyAmerica: return "#00B140"
        case .evgo: return "#0057B8"
        case .restArea: return "#FFB800"
        }
    }

    public var brandColor: Color {
        switch self {
        case .teslaSupercharger: return Color(red: 0.91, green: 0.13, blue: 0.15)
        case .electrifyAmerica: return Color(red: 0.0, green: 0.69, blue: 0.25)
        case .evgo: return Color(red: 0.0, green: 0.34, blue: 0.72)
        case .restArea: return Color.dashYellow
        }
    }

    public var defaultPowerKw: Double {
        switch self {
        case .teslaSupercharger: return 250.0
        case .electrifyAmerica: return 350.0
        case .evgo: return 150.0
        case .restArea: return 0.0
        }
    }

    public var isRestArea: Bool {
        self == .restArea
    }

    /// Estimates charging time in minutes based on starting % and target %, factoring in
    /// typical lithium-ion charging taper curves (slower above 80%).
    public func estimatedMinutes(startPct: Double, targetPct: Double, batteryCapacityKWh: Double = 75.0) -> Double {
        if isRestArea { return 20.0 }
        let clampedStart = max(0.0, min(startPct, 100.0))
        let clampedTarget = max(clampedStart, min(targetPct, 100.0))
        if clampedTarget <= clampedStart { return 0.0 }

        // Fast rate below 80%, tapering above 80%
        let below80Start = min(clampedStart, 80.0)
        let below80End = min(clampedTarget, 80.0)
        let deltaBelow80 = max(0.0, below80End - below80Start)

        let above80Start = max(clampedStart, 80.0)
        let above80End = max(clampedTarget, 80.0)
        let deltaAbove80 = max(0.0, above80End - above80Start)

        let power = max(50.0, defaultPowerKw)
        // Average effective power below 80% is ~70% of peak; above 80% drops to ~30%
        let effectivePowerBelow80 = power * 0.70
        let effectivePowerAbove80 = power * 0.30

        let energyBelow80 = (deltaBelow80 / 100.0) * batteryCapacityKWh
        let energyAbove80 = (deltaAbove80 / 100.0) * batteryCapacityKWh

        let hoursBelow80 = energyBelow80 / effectivePowerBelow80
        let hoursAbove80 = energyAbove80 / effectivePowerAbove80

        let totalMinutes = (hoursBelow80 + hoursAbove80) * 60.0
        return max(1.0, round(totalMinutes))
    }
}

// MARK: - EV Charging Session Manager

@MainActor
public final class EVChargingSessionManager: ObservableObject {
    public static let shared = EVChargingSessionManager()

    @Published public var activePreset: EVStationPreset = .teslaSupercharger
    @Published public var startBatteryPercentage: Double = 20.0
    @Published public var targetBatteryPercentage: Double = 80.0
    @Published public var currentBatteryPercentage: Double = 20.0
    @Published public var restStopDurationMinutes: Int = 20
    @Published public var chargePowerKw: Double = 250.0
    @Published public var isSessionActive: Bool = false
    @Published public var sessionStartTime: Date? = nil
    @Published public var estimatedCompletionTime: Date? = nil
    @Published public var energyDeliveredKWh: Double = 0.0
    @Published public var isLiveActivityEnabled: Bool = true

    #if canImport(ActivityKit)
    private var liveActivity: Activity<EVChargingActivityAttributes>?
    #endif

    public init() {
        self.chargePowerKw = activePreset.defaultPowerKw
    }

    public func selectPreset(_ preset: EVStationPreset) {
        self.activePreset = preset
        self.chargePowerKw = preset.defaultPowerKw
        if preset.isRestArea {
            recalculateCompletion()
        } else {
            recalculateCompletion()
        }
        if isSessionActive {
            syncToWidgetStore()
            updateLiveActivity()
        }
    }

    public func setStartBattery(_ percentage: Double) {
        startBatteryPercentage = max(0.0, min(percentage, 100.0))
        if !isSessionActive {
            currentBatteryPercentage = startBatteryPercentage
        }
        if targetBatteryPercentage < startBatteryPercentage {
            targetBatteryPercentage = min(100.0, startBatteryPercentage + 10.0)
        }
        recalculateCompletion()
    }

    public func setTargetBattery(_ percentage: Double) {
        targetBatteryPercentage = max(startBatteryPercentage, min(percentage, 100.0))
        recalculateCompletion()
    }

    public func setRestStopMinutes(_ minutes: Int) {
        restStopDurationMinutes = max(5, min(minutes, 180))
        recalculateCompletion()
    }

    public func recalculateCompletion() {
        guard isSessionActive else {
            estimatedCompletionTime = nil
            return
        }
        let now = sessionStartTime ?? Date()
        if activePreset.isRestArea {
            estimatedCompletionTime = now.addingTimeInterval(Double(restStopDurationMinutes * 60))
        } else {
            let minutes = activePreset.estimatedMinutes(
                startPct: currentBatteryPercentage,
                targetPct: targetBatteryPercentage
            )
            estimatedCompletionTime = now.addingTimeInterval(minutes * 60.0)
        }
    }

    public func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
        currentBatteryPercentage = startBatteryPercentage
        energyDeliveredKWh = 0.0
        recalculateCompletion()
        syncToWidgetStore()
        startLiveActivity()
    }

    public func stopSession() {
        isSessionActive = false
        sessionStartTime = nil
        estimatedCompletionTime = nil
        syncToWidgetStore()
        endLiveActivity()
    }

    public func tickSimulation(elapsedSeconds: TimeInterval = 60.0) {
        guard isSessionActive else { return }

        if activePreset.isRestArea {
            // Rest area session checks if countdown reached zero
            if let completion = estimatedCompletionTime, Date() >= completion {
                // Done
            }
        } else {
            // Fast-charging session increases battery percentage
            let energyKWh = (chargePowerKw * (elapsedSeconds / 3600.0)) * 0.90
            energyDeliveredKWh += energyKWh
            let deltaPct = (energyKWh / 75.0) * 100.0
            currentBatteryPercentage = min(targetBatteryPercentage, currentBatteryPercentage + deltaPct)
        }

        syncToWidgetStore()
        updateLiveActivity()
    }

    public var progressPercentage: Double {
        if activePreset.isRestArea {
            guard let start = sessionStartTime, let completion = estimatedCompletionTime else { return 0.0 }
            let total = completion.timeIntervalSince(start)
            guard total > 0 else { return 1.0 }
            let elapsed = Date().timeIntervalSince(start)
            return max(0.0, min(1.0, elapsed / total))
        } else {
            let total = max(1.0, targetBatteryPercentage - startBatteryPercentage)
            let current = max(0.0, currentBatteryPercentage - startBatteryPercentage)
            return max(0.0, min(1.0, current / total))
        }
    }

    public func remainingTimeInterval(from now: Date = Date()) -> TimeInterval {
        guard let completion = estimatedCompletionTime else { return 0.0 }
        return max(0.0, completion.timeIntervalSince(now))
    }

    public func elapsedTimeInterval(from now: Date = Date()) -> TimeInterval {
        guard let start = sessionStartTime else { return 0.0 }
        return max(0.0, now.timeIntervalSince(start))
    }

    public func syncToWidgetStore() {
        let snapshot = SharedEVChargingSnapshot(
            stationName: activePreset.name,
            stationPresetRaw: activePreset.rawValue,
            currentBattery: Int(round(currentBatteryPercentage)),
            targetBattery: Int(round(targetBatteryPercentage)),
            powerKw: chargePowerKw,
            isCharging: isSessionActive && !activePreset.isRestArea,
            isRestArea: activePreset.isRestArea,
            startTime: sessionStartTime,
            targetCompletionTime: estimatedCompletionTime,
            restStopDurationMinutes: restStopDurationMinutes,
            notes: activePreset.isRestArea ? "Rest Stop Break" : "\(Int(chargePowerKw)) kW Fast Charge"
        )
        WidgetSharedStore.shared.update { payload in
            payload.evSession = snapshot
        }
    }

    // MARK: - ActivityKit Integration

    private func startLiveActivity() {
        guard isLiveActivityEnabled else { return }
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = EVChargingActivityAttributes(
            sessionTitle: activePreset.isRestArea ? "Road Trip Rest Stop" : activePreset.name
        )
        let state = EVChargingActivityAttributes.ContentState(
            stationName: activePreset.name,
            stationPresetRaw: activePreset.rawValue,
            currentBattery: Int(round(currentBatteryPercentage)),
            targetBattery: Int(round(targetBatteryPercentage)),
            powerKw: chargePowerKw,
            isCharging: isSessionActive && !activePreset.isRestArea,
            isRestArea: activePreset.isRestArea,
            startTime: sessionStartTime ?? Date(),
            estimatedCompletionTime: estimatedCompletionTime ?? Date().addingTimeInterval(1200),
            statusText: activePreset.isRestArea ? "Rest Stop" : "Supercharging"
        )

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("Failed to start EVCharging Live Activity: \(error)")
        }
        #endif
    }

    private func updateLiveActivity() {
        #if canImport(ActivityKit)
        guard let activity = liveActivity else { return }
        let state = EVChargingActivityAttributes.ContentState(
            stationName: activePreset.name,
            stationPresetRaw: activePreset.rawValue,
            currentBattery: Int(round(currentBatteryPercentage)),
            targetBattery: Int(round(targetBatteryPercentage)),
            powerKw: chargePowerKw,
            isCharging: isSessionActive && !activePreset.isRestArea,
            isRestArea: activePreset.isRestArea,
            startTime: sessionStartTime ?? Date(),
            estimatedCompletionTime: estimatedCompletionTime ?? Date().addingTimeInterval(1200),
            statusText: activePreset.isRestArea ? "Rest Stop" : "Supercharging"
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        #endif
    }

    private func endLiveActivity() {
        #if canImport(ActivityKit)
        guard let activity = liveActivity else { return }
        let state = EVChargingActivityAttributes.ContentState(
            stationName: activePreset.name,
            stationPresetRaw: activePreset.rawValue,
            currentBattery: Int(round(currentBatteryPercentage)),
            targetBattery: Int(round(targetBatteryPercentage)),
            powerKw: chargePowerKw,
            isCharging: false,
            isRestArea: activePreset.isRestArea,
            startTime: sessionStartTime ?? Date(),
            estimatedCompletionTime: Date(),
            statusText: "Complete"
        )
        Task {
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            self.liveActivity = nil
        }
        #endif
    }
}
