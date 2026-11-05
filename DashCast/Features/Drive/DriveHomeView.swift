import SwiftUI
import MapKit

public struct DriveHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var locationService = DriveLocationService.shared
    @StateObject private var drivingScorer = DrivingScorer.shared

    @State private var showingTripSummary: Bool = false
    @State private var completedTrip: TripModel?
    @State private var showingHistory: Bool = false
    @State private var showingPermissions: Bool = false
    @State private var showingDriveSettings: Bool = false
    @State private var showingLiveActivityPreview: Bool = false

    public init() {}

    private var displaySpeed: Double {
        if appState.useMilesPerHour {
            return locationService.currentSpeedKmh * 0.621371
        } else {
            return locationService.currentSpeedKmh
        }
    }

    private var trackingChipTitle: String {
        if !locationService.isAuthorized {
            return locationService.authorizationStatus == .notDetermined ? "Enable Location" : "Location Off"
        }
        return locationService.isTracking ? (locationService.isPaused ? "Paused" : "Tracking") : "Ready"
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
                        // Live map centred on the user (follows heading while recording, draws the route).
                        DriveLiveMapView()

                        // Status chip over the map
                        Button {
                            showingPermissions = true
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(locationService.isTracking ? Color.dashGreen : (locationService.isAuthorized ? Color.dashYellow : Color.dashRed))
                                    .frame(width: 8, height: 8)
                                Text(trackingChipTitle)
                                    .font(ThemeFonts.hudCaption(size: 11))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.dashTextMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.dashSurface.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding()

                        // Top right quick toggles
                        VStack(spacing: 8) {
                            Button {
                                appState.setSpeedUnit(milesPerHour: !appState.useMilesPerHour)
                            } label: {
                                Text(speedUnit)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.dashYellow)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.dashSurface.opacity(0.85))
                                    .clipShape(Capsule())
                            }

                            Button {
                                showingHistory = true
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .padding(8)
                                    .background(Color.dashSurface.opacity(0.85))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Trip History")

                            Button {
                                showingDriveSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.dashYellow)
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
            .sheet(isPresented: $showingTripSummary) {
                if let completedTrip {
                    TripSummaryView(trip: completedTrip)
                }
            }
            .sheet(isPresented: $showingHistory) {
                TripHistoryView()
            }
            .sheet(isPresented: $showingPermissions) {
                DriveTrackingPermissionsSheet()
            }
            .onAppear {
                // Show the user's own location as soon as Drive opens (the map otherwise falls back
                // to the whole region). Asks once; afterwards the chip/Settings handle changes.
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestPermissions()
                }
            }
            .sheet(isPresented: $showingDriveSettings) {
                DriveSettingsView()
            }
            .alert("Location needed", isPresented: Binding(
                get: { locationService.lastErrorMessage != nil },
                set: { if !$0 { locationService.clearError() } }
            )) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(locationService.lastErrorMessage ?? "")
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
                    accentColor: .dashYellow
                )
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MAX SPEED")
                            .font(ThemeFonts.hudCaption(size: 11))
                            .foregroundStyle(Color.dashTextMuted)
                        Text(String(format: "%.0f %@", appState.useMilesPerHour ? locationService.topSpeedKmh * 0.621371 : locationService.topSpeedKmh, speedUnit))
                            .font(ThemeFonts.hudStat(size: 24))
                            .foregroundStyle(Color.dashYellow)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DISTANCE")
                            .font(ThemeFonts.hudCaption(size: 11))
                            .foregroundStyle(Color.dashTextMuted)
                        Text(formatDistance(locationService.currentDistanceMeters))
                            .font(ThemeFonts.hudStat(size: 24))
                            .foregroundStyle(Color.dashGreen)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ELAPSED")
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
                        DriveNotificationService.shared.sendDriveRecordingNotification(distanceKm: 0)
                    }

                    Button {
                        showingHistory = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Trips")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(Color.dashSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        DriveNotificationService.shared.sendTripSavedNotification(trip: trip)
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
            .padding(.bottom, 80)
        }
        .padding(.top, 14)
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
}
