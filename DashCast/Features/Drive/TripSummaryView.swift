import SwiftUI
import MapKit

public enum TripMapMode: String, CaseIterable, Identifiable {
    case replay = "Route Replay"
    case heatmap = "Speed Heatmap"
    public var id: String { rawValue }
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
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Map Section with Route Replay & Speed Heatmap toggle
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
                                    Text("SCORE")
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
                            statCard(title: "DISTANCE", value: formattedDistance, icon: "road.lanes")
                            statCard(title: "DURATION", value: formatDuration(trip.durationSeconds), icon: "clock.fill")
                            statCard(title: "AVG SPEED", value: formattedAvgSpeed, icon: "gauge.medium")
                            statCard(title: "TOP SPEED", value: formattedTopSpeed, icon: "bolt.fill")
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
                                    telemetryPill(label: "Rapid Accel", count: trip.harshAccelerationCount, color: .dashOrange)
                                    Spacer()
                                    telemetryPill(label: "Sharp Turns", count: trip.harshCorneringCount, color: .dashOrange)
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
            .navigationTitle("Trip Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
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
