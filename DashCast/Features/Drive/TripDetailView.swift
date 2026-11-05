import SwiftUI
import MapKit

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
        if appState.useMilesPerHour {
            let miles = trip.distanceMeters * 0.000621371
            return String(format: "%.2f mi", miles)
        } else {
            return String(format: "%.2f km", trip.distanceKilometers)
        }
    }

    private var formattedAvgSpeed: String {
        if appState.useMilesPerHour {
            return String(format: "%.0f mph", trip.averageSpeedKmh * 0.621371)
        } else {
            return String(format: "%.0f km/h", trip.averageSpeedKmh)
        }
    }

    private var formattedTopSpeed: String {
        if appState.useMilesPerHour {
            return String(format: "%.0f mph", trip.maxSpeedKmh * 0.621371)
        } else {
            return String(format: "%.0f km/h", trip.maxSpeedKmh)
        }
    }

    public var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Map Section with Replay / Heatmap
                    if coordinates.count >= 2 {
                        VStack(spacing: 10) {
                            Picker("Map Mode", selection: $mapMode) {
                                ForEach(TripMapMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
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
                        statCard(title: "DISTANCE", value: formattedDistance, icon: "road.lanes")
                        statCard(title: "DURATION", value: formatDuration(trip.durationSeconds), icon: "clock.fill")
                        statCard(title: "AVG SPEED", value: formattedAvgSpeed, icon: "gauge.medium")
                        statCard(title: "TOP SPEED", value: formattedTopSpeed, icon: "bolt.fill")
                    }
                    .padding(.horizontal)

                    // Timing Breakdown
                    AutomotiveCard {
                        VStack(spacing: 12) {
                            timingRow(title: "Started", value: trip.startTime.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
                            Divider().background(Color.dashBorder)
                            if let end = trip.endTime {
                                timingRow(title: "Ended", value: end.formatted(date: .omitted, time: .shortened), icon: "flag.checkered")
                                Divider().background(Color.dashBorder)
                            }
                            timingRow(title: "Total Time", value: formatDuration(trip.durationSeconds), icon: "hourglass")
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
                                telemetryPill(label: "Hard Brakes", count: trip.harshBrakingCount, color: .dashOrange)
                                Spacer()
                                telemetryPill(label: "Rapid Accel", count: trip.rapidAccelerationCount, color: .dashOrange)
                                Spacer()
                                telemetryPill(label: "Sharp Turns", count: trip.sharpTurnCount, color: .dashOrange)
                                Spacer()
                                telemetryPill(label: "Smoothness", count: trip.drivingScore, color: .dashGreen)
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
        if trip.drivingScore >= 85 { return .dashGreen }
        if trip.drivingScore >= 70 { return .dashYellow }
        return .dashRed
    }

    private var scoreMessage: String {
        if trip.drivingScore >= 90 { return "Smooth & Efficient" }
        if trip.drivingScore >= 80 { return "Good Driving" }
        if trip.drivingScore >= 70 { return "Moderate Ride" }
        return "Aggressive Driving Detected"
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
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
                Text(value)
                    .font(ThemeFonts.hudStat(size: 20))
                    .foregroundStyle(Color.dashTextPrimary)
            }
        }
    }

    private func timingRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.dashTextMuted)
                .frame(width: 20)
            Text(title)
                .font(ThemeFonts.hudCaption(size: 13))
                .foregroundStyle(Color.dashTextSecondary)
            Spacer()
            Text(value)
                .font(ThemeFonts.monospaceDigits(size: 13))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }

    private func telemetryPill(label: String, count: Int, color: Color) -> some View {
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
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%dm %02ds", mins, secs)
    }
}
