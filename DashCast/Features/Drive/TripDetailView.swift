import SwiftUI
import MapKit

/// Testable formatting and localization helpers for `TripDetailView` and `TripHistoryView`.
public enum TripDetailFormatter {
    public enum ScoreColorTone: Equatable {
        case green
        case yellow
        case red
    }

    public enum StatField: CaseIterable {
        case distance
        case duration
        case avgSpeed
        case topSpeed

        public var keyName: String {
            switch self {
            case .distance: return "DISTANCE"
            case .duration: return "DURATION"
            case .avgSpeed: return "AVG SPEED"
            case .topSpeed: return "TOP SPEED"
            }
        }

        public var icon: String {
            switch self {
            case .distance: return "road.lanes"
            case .duration: return "clock.fill"
            case .avgSpeed: return "gauge.medium"
            case .topSpeed: return "bolt.fill"
            }
        }

        @MainActor
        public var title: LocalizedStringKey {
            LocalizedStringKey(keyName)
        }
    }

    public enum TimingField: CaseIterable {
        case started
        case ended
        case totalTime

        public var keyName: String {
            switch self {
            case .started: return "Started"
            case .ended: return "Ended"
            case .totalTime: return "Total Time"
            }
        }

        public var icon: String {
            switch self {
            case .started: return "calendar"
            case .ended: return "flag.checkered"
            case .totalTime: return "hourglass"
            }
        }

        @MainActor
        public var title: LocalizedStringKey {
            LocalizedStringKey(keyName)
        }
    }

    public enum TelemetryField: CaseIterable {
        case hardBrakes
        case rapidAccel
        case sharpTurns
        case smoothness

        public var keyName: String {
            switch self {
            case .hardBrakes: return "Hard Brakes"
            case .rapidAccel: return "Rapid Accel"
            case .sharpTurns: return "Sharp Turns"
            case .smoothness: return "Smoothness"
            }
        }

        @MainActor
        public var title: LocalizedStringKey {
            LocalizedStringKey(keyName)
        }
    }

    public static let allLocalizationKeys: [String] = [
        "Map Mode",
        "Route Replay",
        "Speed Heatmap",
        "No Route Recorded",
        "The trip was too short or location was unavailable.",
        "SCORE",
        "Smooth & Efficient",
        "Good Driving",
        "Moderate Ride",
        "Aggressive Driving Detected",
        "DISTANCE",
        "DURATION",
        "AVG SPEED",
        "TOP SPEED",
        "Started",
        "Ended",
        "Total Time",
        "DRIVING SMOOTHNESS",
        "Hard Brakes",
        "Rapid Accel",
        "Sharp Turns",
        "Smoothness",
        "No Trips Recorded Yet",
        "Trips you record or auto-detect with DashCast will appear here with route replay and telemetry stats.",
        "TOTAL DRIVES",
        "TOTAL DISTANCE",
        "AVG SCORE",
        "Summary",
        "All Recorded Trips (%lld)",
        "Trip History",
        "Close",
        "Clear all trips",
        "Clear Trip History?",
        "Clear All",
        "Cancel",
        "Are you sure you want to delete all recorded trips? This action cannot be undone.",
        "Replay"
    ]

    public static func formatDistance(_ meters: Double, useMilesPerHour: Bool, decimals: Int = 2) -> String {
        let clampedDecimals = max(decimals, 0)
        if useMilesPerHour {
            let miles = meters * 0.000621371
            return String(format: "%.\(clampedDecimals)f mi", miles)
        } else {
            let km = meters / 1000.0
            return String(format: "%.\(clampedDecimals)f km", km)
        }
    }

    public static func formatSpeed(_ speedKmh: Double, useMilesPerHour: Bool) -> String {
        if useMilesPerHour {
            return String(format: "%.0f mph", speedKmh * 0.621371)
        } else {
            return String(format: "%.0f km/h", speedKmh)
        }
    }

    public static func formatDuration(_ seconds: TimeInterval, compactMinutesOnlyForHours: Bool = false) -> String {
        let clamped = max(Int(seconds), 0)
        let mins = clamped / 60
        let secs = clamped % 60
        if compactMinutesOnlyForHours {
            if mins > 60 {
                let hours = mins / 60
                let remMins = mins % 60
                return "\(hours)h \(remMins)m"
            }
            return "\(mins)m \(secs)s"
        }
        return String(format: "%dm %02ds", mins, secs)
    }

    public static func scoreColorTone(for score: Int) -> ScoreColorTone {
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        return .red
    }

    public static func scoreColor(for score: Int) -> Color {
        switch scoreColorTone(for: score) {
        case .green: return .dashGreen
        case .yellow: return .dashYellow
        case .red: return .dashRed
        }
    }

    public static func scoreMessageKeyName(for score: Int) -> String {
        if score >= 90 { return "Smooth & Efficient" }
        if score >= 80 { return "Good Driving" }
        if score >= 70 { return "Moderate Ride" }
        return "Aggressive Driving Detected"
    }

    @MainActor
    public static func scoreMessage(for score: Int) -> LocalizedStringKey {
        LocalizedStringKey(scoreMessageKeyName(for: score))
    }

    public static func mapModeKeyName(for mode: TripMapMode) -> String {
        mode.rawValue
    }

    @MainActor
    public static func mapModeTitle(for mode: TripMapMode) -> LocalizedStringKey {
        LocalizedStringKey(mapModeKeyName(for: mode))
    }
}

public struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    public let trip: TripModel

    @State private var mapMode: TripMapMode = .replay

    public init(trip: TripModel) {
        self.trip = trip
    }

    private var coordinates: [CLLocationCoordinate2D] {
        trip.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var formattedDistance: String {
        TripDetailFormatter.formatDistance(trip.distanceMeters, useMilesPerHour: appState.useMilesPerHour, decimals: 2)
    }

    private var formattedAvgSpeed: String {
        TripDetailFormatter.formatSpeed(trip.averageSpeedKmh, useMilesPerHour: appState.useMilesPerHour)
    }

    private var formattedTopSpeed: String {
        TripDetailFormatter.formatSpeed(trip.maxSpeedKmh, useMilesPerHour: appState.useMilesPerHour)
    }

    public var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Map Section with Replay / Heatmap
                    if coordinates.count >= 2 {
                        VStack(spacing: 10) {
                            Picker(LocalizedStringKey("Map Mode"), selection: $mapMode) {
                                ForEach(TripMapMode.allCases) { mode in
                                    Text(TripDetailFormatter.mapModeTitle(for: mode)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

                            if mapMode == .replay {
                                TripReplayMapView(coordinates: coordinates)
                                    .padding(.horizontal)
                            } else {
                                SpeedGradientRouteView(points: trip.points)
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                                    .padding(.horizontal)
                            }
                        }
                    } else if coordinates.count == 1 {
                        TripReplayMapView(coordinates: coordinates)
                            .padding(.horizontal)
                    } else {
                        EmptyStateView(
                            systemImage: "map",
                            title: "No Route Recorded",
                            message: "The trip was too short or location was unavailable."
                        )
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    // Score Circle
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.dashSurface)
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(scoreColor, lineWidth: 5)
                                )

                            VStack(spacing: 0) {
                                Text("\(trip.drivingScore)")
                                    .font(ThemeFonts.speedDisplay(size: 34))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Text("SCORE")
                                    .font(ThemeFonts.hudCaption(size: 9))
                                    .foregroundStyle(scoreColor)
                                    .fontWeight(.bold)
                            }
                        }

                        Text(scoreMessage)
                            .font(ThemeFonts.hudTitle(size: 15))
                            .foregroundStyle(scoreColor)
                    }

                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        statCard(
                            title: TripDetailFormatter.StatField.distance.title,
                            value: formattedDistance,
                            icon: TripDetailFormatter.StatField.distance.icon
                        )
                        statCard(
                            title: TripDetailFormatter.StatField.duration.title,
                            value: formatDuration(trip.durationSeconds),
                            icon: TripDetailFormatter.StatField.duration.icon
                        )
                        statCard(
                            title: TripDetailFormatter.StatField.avgSpeed.title,
                            value: formattedAvgSpeed,
                            icon: TripDetailFormatter.StatField.avgSpeed.icon
                        )
                        statCard(
                            title: TripDetailFormatter.StatField.topSpeed.title,
                            value: formattedTopSpeed,
                            icon: TripDetailFormatter.StatField.topSpeed.icon
                        )
                    }
                    .padding(.horizontal)

                    // Timing Breakdown
                    AutomotiveCard {
                        VStack(spacing: 12) {
                            timingRow(
                                title: TripDetailFormatter.TimingField.started.title,
                                value: trip.startTime.formatted(date: .abbreviated, time: .shortened),
                                icon: TripDetailFormatter.TimingField.started.icon
                            )
                            Divider().background(Color.dashBorder)
                            if let end = trip.endTime {
                                timingRow(
                                    title: TripDetailFormatter.TimingField.ended.title,
                                    value: end.formatted(date: .omitted, time: .shortened),
                                    icon: TripDetailFormatter.TimingField.ended.icon
                                )
                                Divider().background(Color.dashBorder)
                            }
                            timingRow(
                                title: TripDetailFormatter.TimingField.totalTime.title,
                                value: formatDuration(trip.durationSeconds),
                                icon: TripDetailFormatter.TimingField.totalTime.icon
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Smoothness Telemetry breakdown
                    AutomotiveCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DRIVING SMOOTHNESS")
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashTextMuted)
                                .tracking(1.2)

                            HStack {
                                telemetryPill(
                                    label: TripDetailFormatter.TelemetryField.hardBrakes.title,
                                    count: trip.harshBrakingCount,
                                    color: .dashOrange
                                )
                                Spacer()
                                telemetryPill(
                                    label: TripDetailFormatter.TelemetryField.rapidAccel.title,
                                    count: trip.harshAccelerationCount,
                                    color: .dashOrange
                                )
                                Spacer()
                                telemetryPill(
                                    label: TripDetailFormatter.TelemetryField.sharpTurns.title,
                                    count: trip.harshCorneringCount,
                                    color: .dashOrange
                                )
                                Spacer()
                                telemetryPill(
                                    label: TripDetailFormatter.TelemetryField.smoothness.title,
                                    count: trip.drivingScore,
                                    color: .dashGreen
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(trip.startTime.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreColor: Color {
        TripDetailFormatter.scoreColor(for: trip.drivingScore)
    }

    private var scoreMessage: LocalizedStringKey {
        TripDetailFormatter.scoreMessage(for: trip.drivingScore)
    }

    private func statCard(title: LocalizedStringKey, value: String, icon: String) -> some View {
        AutomotiveCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(Color.dashYellow)
                    Spacer()
                }
                Text(title)
                    .font(ThemeFonts.hudCaption(size: 11))
                    .foregroundStyle(Color.dashTextMuted)
                Text(verbatim: value)
                    .font(ThemeFonts.hudStat(size: 20))
                    .foregroundStyle(Color.dashTextPrimary)
            }
        }
    }

    private func timingRow(title: LocalizedStringKey, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.dashTextMuted)
                .frame(width: 20)
            Text(title)
                .font(ThemeFonts.hudCaption(size: 13))
                .foregroundStyle(Color.dashTextSecondary)
            Spacer()
            Text(verbatim: value)
                .font(ThemeFonts.monospaceDigits(size: 13))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }

    private func telemetryPill(label: LocalizedStringKey, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(ThemeFonts.hudStat(size: 18))
                .foregroundStyle(count == 0 ? Color.dashGreen : color)
            Text(label)
                .font(ThemeFonts.hudCaption(size: 10))
                .foregroundStyle(Color.dashTextSecondary)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        TripDetailFormatter.formatDuration(seconds)
    }
}
