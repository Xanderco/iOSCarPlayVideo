import SwiftUI
import MapKit

public struct DriveHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var locationService = DriveLocationService.shared
    @StateObject private var drivingScorer = DrivingScorer.shared

    @State private var showingTripSummary: Bool = false
    @State private var completedTrip: TripModel?
    @State private var showingHistory: Bool = false
    @State private var pastTrips: [TripModel] = []

    public init() {}

    private var displaySpeed: Double {
        if appState.useMilesPerHour {
            return locationService.currentSpeedKmh * 0.621371
        } else {
            return locationService.currentSpeedKmh
        }
    }

    private var speedUnit: String {
        appState.useMilesPerHour ? "MPH" : "KM/H"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Map & Route View
                    ZStack(alignment: .topTrailing) {
                        SpeedGradientRouteView(points: locationService.tripPoints)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Top right quick toggles
                        VStack(spacing: 8) {
                            Button {
                                appState.setSpeedUnit(milesPerHour: !appState.useMilesPerHour)
                            } label: {
                                Text(speedUnit)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.dashCyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.dashSurface.opacity(0.85))
                                    .clipShape(Capsule())
                            }

                            Button {
                                pastTrips = PersistenceController.shared.loadTrips()
                                showingHistory = true
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .padding(8)
                                    .background(Color.dashSurface.opacity(0.85))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                    }

                    // Bottom Automotive HUD Console
                    bottomHUDConsole
                }
            }
            .navigationTitle("Drive")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTripSummary) {
                if let completedTrip {
                    TripSummaryView(trip: completedTrip)
                }
            }
            .sheet(isPresented: $showingHistory) {
                pastTripsListView
            }
        }
    }

    private var bottomHUDConsole: some View {
        VStack(spacing: 16) {
            // Speedometer & Primary metrics
            HStack(spacing: 16) {
                NeonGaugeView(
                    value: displaySpeed,
                    maxValue: appState.useMilesPerHour ? 140 : 220,
                    title: "SPEED",
                    unit: speedUnit,
                    accentColor: .dashCyan
                )

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance")
                            .font(ThemeFonts.hudCaption(size: 11))
                            .foregroundStyle(Color.dashTextMuted)
                        Text(formatDistance(locationService.distanceMeters))
                            .font(ThemeFonts.hudStat(size: 24))
                            .foregroundStyle(Color.dashTextPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(ThemeFonts.hudCaption(size: 11))
                            .foregroundStyle(Color.dashTextMuted)
                        Text(formatDuration(locationService.elapsedTime))
                            .font(ThemeFonts.hudStat(size: 24))
                            .foregroundStyle(Color.dashTextPrimary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal)

            // Secondary Stats Bar: AVG, TOP, ALT, STOP
            HStack {
                statColumn(
                    title: "AVG",
                    value: String(format: "%.0f %@", appState.useMilesPerHour ? locationService.averageSpeedKmh * 0.621371 : locationService.averageSpeedKmh, speedUnit)
                )
                Spacer()
                statColumn(
                    title: "TOP",
                    value: String(format: "%.0f %@", appState.useMilesPerHour ? locationService.topSpeedKmh * 0.621371 : locationService.topSpeedKmh, speedUnit)
                )
                Spacer()
                statColumn(
                    title: "ALT",
                    value: String(format: "%.0f m", locationService.currentAltitudeMeters)
                )
                Spacer()
                statColumn(
                    title: "STOP",
                    value: formatDuration(locationService.stopDuration)
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Controls: Start / Pause / Resume / End
            HStack(spacing: 12) {
                if !locationService.isTracking {
                    GlowButton(title: "Start Drive", iconName: "play.fill", gradient: .dashAccentGradient) {
                        locationService.startTrip()
                    }
                } else {
                    Button {
                        if locationService.isPaused {
                            locationService.resumeTrip()
                        } else {
                            locationService.pauseTrip()
                        }
                    } label: {
                        HStack {
                            Image(systemName: locationService.isPaused ? "play.fill" : "pause.fill")
                            Text(locationService.isPaused ? "Resume" : "Pause")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.dashOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        let trip = locationService.endTrip()
                        self.completedTrip = trip
                        self.showingTripSummary = true
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("End Trip")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.dashRed)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 36)
        }
        .padding(.top, 10)
        .background(Color.dashBackground)
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(ThemeFonts.hudCaption(size: 10))
                .foregroundStyle(Color.dashTextMuted)
            Text(value)
                .font(ThemeFonts.monospaceDigits(size: 13))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if appState.useMilesPerHour {
            let miles = meters * 0.000621371
            return String(format: "%.2f mi", miles)
        } else {
            let km = meters / 1000.0
            return String(format: "%.2f km", km)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02dm %02ds", mins, secs)
    }

    private var pastTripsListView: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                if pastTrips.isEmpty {
                    Text("No past trips recorded yet")
                        .font(ThemeFonts.hudCaption(size: 16))
                        .foregroundStyle(Color.dashTextMuted)
                } else {
                    List {
                        ForEach(pastTrips) { trip in
                            Button {
                                self.completedTrip = trip
                                self.showingTripSummary = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.dashTextPrimary)
                                        Text(String(format: "%.2f km · %dm duration", trip.distanceKilometers, Int(trip.durationSeconds / 60)))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()

                                    Text("\(trip.drivingScore)")
                                        .font(ThemeFonts.hudStat(size: 18))
                                        .foregroundStyle(trip.drivingScore >= 80 ? Color.dashGreen : Color.dashOrange)
                                }
                            }
                            .listRowBackground(Color.dashSurface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Trip History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showingHistory = false
                    }
                }
            }
        }
    }
}
