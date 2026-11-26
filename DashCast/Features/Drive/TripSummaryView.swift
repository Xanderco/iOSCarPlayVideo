import SwiftUI
import MapKit

/// Localized copy keys for `TripSummaryView`.
public enum TripSummaryCopy {
    nonisolated public static let mapModeString = "Map Mode"
    nonisolated public static let routeReplayString = "Route Replay"
    nonisolated public static let speedHeatmapString = "Speed Heatmap"
    nonisolated public static let scoreLabelString = "SCORE"
    nonisolated public static let distanceLabelString = "DISTANCE"
    nonisolated public static let durationLabelString = "DURATION"
    nonisolated public static let avgSpeedLabelString = "AVG SPEED"
    nonisolated public static let topSpeedLabelString = "TOP SPEED"
    nonisolated public static let drivingSmoothnessTitleString = "DRIVING SMOOTHNESS"
    nonisolated public static let hardBrakesLabelString = "Hard Brakes"
    nonisolated public static let rapidAccelLabelString = "Rapid Accel"
    nonisolated public static let sharpTurnsLabelString = "Sharp Turns"
    nonisolated public static let smoothnessLabelString = "Smoothness"
    nonisolated public static let doneButtonString = "Done"
    nonisolated public static let navigationTitleString = "Trip Summary"
    nonisolated public static let smoothEfficientScoreString = "Smooth & Efficient"
    nonisolated public static let goodDrivingScoreString = "Good Driving"
    nonisolated public static let moderateRideScoreString = "Moderate Ride"
    nonisolated public static let aggressiveDrivingScoreString = "Aggressive Driving Detected"

    nonisolated public static let allLocalizationKeys: [String] = [
        mapModeString,
        routeReplayString,
        speedHeatmapString,
        scoreLabelString,
        distanceLabelString,
        durationLabelString,
        avgSpeedLabelString,
        topSpeedLabelString,
        drivingSmoothnessTitleString,
        hardBrakesLabelString,
        rapidAccelLabelString,
        sharpTurnsLabelString,
        smoothnessLabelString,
        doneButtonString,
        navigationTitleString,
        smoothEfficientScoreString,
        goodDrivingScoreString,
        moderateRideScoreString,
        aggressiveDrivingScoreString
    ]

    @MainActor public static var mapModeKey: LocalizedStringKey { LocalizedStringKey(mapModeString) }
    @MainActor public static var routeReplayKey: LocalizedStringKey { LocalizedStringKey(routeReplayString) }
    @MainActor public static var speedHeatmapKey: LocalizedStringKey { LocalizedStringKey(speedHeatmapString) }
    @MainActor public static var scoreLabelKey: LocalizedStringKey { LocalizedStringKey(scoreLabelString) }
    @MainActor public static var distanceLabelKey: LocalizedStringKey { LocalizedStringKey(distanceLabelString) }
    @MainActor public static var durationLabelKey: LocalizedStringKey { LocalizedStringKey(durationLabelString) }
    @MainActor public static var avgSpeedLabelKey: LocalizedStringKey { LocalizedStringKey(avgSpeedLabelString) }
    @MainActor public static var topSpeedLabelKey: LocalizedStringKey { LocalizedStringKey(topSpeedLabelString) }
    @MainActor public static var drivingSmoothnessTitleKey: LocalizedStringKey { LocalizedStringKey(drivingSmoothnessTitleString) }
    @MainActor public static var hardBrakesLabelKey: LocalizedStringKey { LocalizedStringKey(hardBrakesLabelString) }
    @MainActor public static var rapidAccelLabelKey: LocalizedStringKey { LocalizedStringKey(rapidAccelLabelString) }
    @MainActor public static var sharpTurnsLabelKey: LocalizedStringKey { LocalizedStringKey(sharpTurnsLabelString) }
    @MainActor public static var smoothnessLabelKey: LocalizedStringKey { LocalizedStringKey(smoothnessLabelString) }
    @MainActor public static var doneButtonKey: LocalizedStringKey { LocalizedStringKey(doneButtonString) }
    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
}

/// Pure formatting and score-tier helpers for `TripSummaryView`.
public enum TripSummaryMetricsFormatter {
    nonisolated public static func formattedDistance(meters: Double, useMilesPerHour: Bool) -> String {
        let safeMeters = (meters.isFinite && meters > 0) ? meters : 0
        if useMilesPerHour {
            return String(format: "%.2f mi", safeMeters * 0.000621371)
        } else {
            return String(format: "%.2f km", safeMeters / 1000.0)
        }
    }

    nonisolated public static func formattedSpeed(kmh: Double, useMilesPerHour: Bool) -> String {
        let safeKmh = (kmh.isFinite && kmh > 0) ? kmh : 0
        if useMilesPerHour {
            return String(format: "%.0f mph", safeKmh * 0.621371)
        } else {
            return String(format: "%.0f km/h", safeKmh)
        }
    }

    nonisolated public static func formattedDuration(seconds: TimeInterval) -> String {
        let safeSeconds = (seconds.isFinite && seconds > 0) ? Int(seconds) : 0
        let mins = safeSeconds / 60
        let secs = safeSeconds % 60
        return String(format: "%dm %02ds", mins, secs)
    }

    nonisolated public static func scoreTierString(for score: Int) -> String {
        if score >= 90 { return TripSummaryCopy.smoothEfficientScoreString }
        if score >= 80 { return TripSummaryCopy.goodDrivingScoreString }
        if score >= 70 { return TripSummaryCopy.moderateRideScoreString }
        return TripSummaryCopy.aggressiveDrivingScoreString
    }

    @MainActor public static func scoreTierKey(for score: Int) -> LocalizedStringKey {
        LocalizedStringKey(scoreTierString(for: score))
    }
}

public enum TripMapMode: String, CaseIterable, Identifiable {
    case replay = "Route Replay"
    case heatmap = "Speed Heatmap"
    public var id: String { rawValue }

    @MainActor public var localizedTitle: LocalizedStringKey {
        switch self {
        case .replay: return TripSummaryCopy.routeReplayKey
        case .heatmap: return TripSummaryCopy.speedHeatmapKey
        }
    }
}

public struct TripSummaryView: View {
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
        TripSummaryMetricsFormatter.formattedDistance(meters: trip.distanceMeters, useMilesPerHour: appState.useMilesPerHour)
    }

    private var formattedAvgSpeed: String {
        TripSummaryMetricsFormatter.formattedSpeed(kmh: trip.averageSpeedKmh, useMilesPerHour: appState.useMilesPerHour)
    }

    private var formattedTopSpeed: String {
        TripSummaryMetricsFormatter.formattedSpeed(kmh: trip.maxSpeedKmh, useMilesPerHour: appState.useMilesPerHour)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Map Section with Route Replay & Speed Heatmap toggle
                        if coordinates.count >= 2 {
                            VStack(spacing: 10) {
                                Picker(TripSummaryCopy.mapModeKey, selection: $mapMode) {
                                    ForEach(TripMapMode.allCases) { mode in
                                        Text(mode.localizedTitle).tag(mode)
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
                            SpeedGradientRouteView(points: trip.points)
                                .frame(height: 220)
                                .padding(.horizontal)
                        }

                        // Driving Score Circle
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.dashSurface)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Circle()
                                            .stroke(scoreColor, lineWidth: 6)
                                    )

                                VStack(spacing: 0) {
                                    Text("\(trip.drivingScore)")
                                        .font(ThemeFonts.speedDisplay(size: 38))
                                        .foregroundStyle(Color.dashTextPrimary)
                                    Text(TripSummaryCopy.scoreLabelKey)
                                        .font(ThemeFonts.hudCaption(size: 10))
                                        .foregroundStyle(scoreColor)
                                        .fontWeight(.bold)
                                }
                            }

                            Text(scoreMessage)
                                .font(ThemeFonts.hudTitle(size: 16))
                                .foregroundStyle(scoreColor)
                        }

                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            statCard(title: TripSummaryCopy.distanceLabelKey, value: formattedDistance, icon: "road.lanes")
                            statCard(title: TripSummaryCopy.durationLabelKey, value: TripSummaryMetricsFormatter.formattedDuration(seconds: trip.durationSeconds), icon: "clock.fill")
                            statCard(title: TripSummaryCopy.avgSpeedLabelKey, value: formattedAvgSpeed, icon: "gauge.medium")
                            statCard(title: TripSummaryCopy.topSpeedLabelKey, value: formattedTopSpeed, icon: "bolt.fill")
                        }
                        .padding(.horizontal)

                        // Smoothness Telemetry breakdown
                        AutomotiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(TripSummaryCopy.drivingSmoothnessTitleKey)
                                    .font(ThemeFonts.hudCaption(size: 12))
                                    .foregroundStyle(Color.dashTextMuted)
                                    .tracking(1.2)

                                HStack {
                                    telemetryPill(label: TripSummaryCopy.hardBrakesLabelKey, count: trip.harshBrakingCount, color: .dashOrange)
                                    Spacer()
                                    telemetryPill(label: TripSummaryCopy.rapidAccelLabelKey, count: trip.harshAccelerationCount, color: .dashOrange)
                                    Spacer()
                                    telemetryPill(label: TripSummaryCopy.sharpTurnsLabelKey, count: trip.harshCorneringCount, color: .dashOrange)
                                    Spacer()
                                    telemetryPill(label: TripSummaryCopy.smoothnessLabelKey, count: trip.drivingScore, color: .dashGreen)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(TripSummaryCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(TripSummaryCopy.doneButtonKey) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private var scoreColor: Color {
        if trip.drivingScore >= 85 { return .dashGreen }
        if trip.drivingScore >= 70 { return .dashYellow }
        return .dashRed
    }

    private var scoreMessage: LocalizedStringKey {
        TripSummaryMetricsFormatter.scoreTierKey(for: trip.drivingScore)
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
}
