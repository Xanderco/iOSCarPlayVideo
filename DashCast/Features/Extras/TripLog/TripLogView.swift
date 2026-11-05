import SwiftUI
import MapKit

// MARK: - Formatting

public enum TripFormatting {
    public static func distance(meters: Double, useMiles: Bool) -> String {
        if useMiles {
            return String(format: "%.1f mi", meters * 0.000621371)
        }
        return String(format: "%.1f km", meters / 1000.0)
    }

    public static func speed(kmh: Double, useMiles: Bool) -> String {
        if useMiles {
            return String(format: "%.0f mph", kmh * 0.621371)
        }
        return String(format: "%.0f km/h", kmh)
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Trip Log

/// Settings › Car Extras › Trip Log. A plain, passenger-started record of trips: distance,
/// time and route, saved only on this iPhone. No scores, ranks or live speed readout on the phone.
public struct TripLogView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var location = DriveLocationService.shared

    @State private var trips: [TripModel] = []
    @State private var showPassengerCheck = false
    @State private var tripToDelete: TripModel?

    public init() {}

    public var body: some View {
        List {
            if let error = location.lastErrorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.dcWarning)
                    Button("Dismiss") { location.clearError() }
                }
            }

            Section {
                recordingControl
            } footer: {
                Text("Trip Log is for passengers. It records only between Start and Stop, and nothing is uploaded.")
            }

            if trips.isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        title: "No trips yet",
                        message: "Start a trip from the passenger seat. Your route, distance and time will be listed here."
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            tripRow(trip)
                        }
                    }
                    .onDelete(perform: deleteTrips)
                } header: {
                    Text("Saved trips")
                } footer: {
                    Text(totalsLine)
                }
            }
        }
        .tint(Color.dcAccent)
        .scrollContentBackground(.hidden)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle("Trip Log")
        .toolbar {
            if !trips.isEmpty {
                EditButton()
            }
        }
        .onAppear(perform: reload)
        .confirmationDialog(
            "Are you a passenger?",
            isPresented: $showPassengerCheck,
            titleVisibility: .visible
        ) {
            Button("I'm a passenger. Start the trip") { startTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Drivers should not use DashCast while driving. A passenger can start the trip, or you can start it before you set off.")
        }
    }

    // MARK: Recording

    @ViewBuilder
    private var recordingControl: some View {
        if location.isTracking {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(spacing: DSSpacing.sm) {
                    Circle()
                        .fill(Color.dcLive)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(location.isPaused ? "Paused" : "Recording trip")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Spacer()
                    Text(TripFormatting.duration(location.elapsedTime))
                        .font(DSTypography.numeric)
                        .foregroundStyle(Color.dcTextSecondary)
                }
                Text(TripFormatting.distance(meters: location.distanceMeters, useMiles: appState.useMilesPerHour))
                    .font(DSTypography.title)
                    .foregroundStyle(Color.dcTextPrimary)
                    .accessibilityLabel(Text("Distance \(TripFormatting.distance(meters: location.distanceMeters, useMiles: appState.useMilesPerHour))"))
                HStack(spacing: DSSpacing.sm) {
                    PrimaryButton(location.isPaused ? "Resume" : "Pause",
                                  systemImage: location.isPaused ? "play.fill" : "pause.fill",
                                  kind: .secondary, size: .compact) {
                        if location.isPaused { location.resumeTrip() } else { location.pauseTrip() }
                    }
                    PrimaryButton("Stop & Save", systemImage: "stop.fill", kind: .primary, size: .compact) {
                        stopTrip()
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)
        } else {
            Button {
                showPassengerCheck = true
            } label: {
                Label("Start a Trip", systemImage: "record.circle")
                    .font(DSTypography.headline)
                    .frame(minHeight: DSLayout.minTapTarget)
            }
        }
    }

    private func tripRow(_ trip: TripModel) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                .font(DSTypography.headline)
                .foregroundStyle(Color.dcTextPrimary)
            Text("\(TripFormatting.distance(meters: trip.distanceMeters, useMiles: appState.useMilesPerHour)) · \(TripFormatting.duration(trip.durationSeconds))")
                .font(DSTypography.subheadline)
                .foregroundStyle(Color.dcTextSecondary)
        }
        .padding(.vertical, DSSpacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var totalsLine: String {
        let meters = trips.reduce(0) { $0 + $1.distanceMeters }
        let count = trips.count
        return "\(count) trip\(count == 1 ? "" : "s") · \(TripFormatting.distance(meters: meters, useMiles: appState.useMilesPerHour)) in total"
    }

    // MARK: Actions

    private func reload() {
        trips = PersistenceController.shared.loadTrips()
    }

    private func startTrip() {
        location.startTrip()
        if PersistenceController.shared.loadUserPreferences().driveNotificationsEnabled {
            Task { _ = await DriveNotificationService.shared.requestAuthorization() }
        }
    }

    private func stopTrip() {
        let trip = location.endTrip()
        reload()
        let prefs = PersistenceController.shared.loadUserPreferences()
        if prefs.driveNotificationsEnabled {
            DriveNotificationService.shared.sendTripSavedNotification(trip: trip, useMiles: appState.useMilesPerHour)
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        trips.remove(atOffsets: offsets)
        PersistenceController.shared.saveTrips(trips)
    }
}

// MARK: - Trip detail

public struct TripDetailView: View {
    @EnvironmentObject private var appState: AppState
    public let trip: TripModel

    public init(trip: TripModel) {
        self.trip = trip
    }

    private var coordinates: [CLLocationCoordinate2D] {
        trip.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    public var body: some View {
        List {
            Section {
                if coordinates.count > 1 {
                    Map(initialPosition: .automatic) {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.dcAccent, lineWidth: 5)
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel(Text("Route map"))
                } else {
                    EmptyStateView(
                        systemImage: "map",
                        title: "No route recorded",
                        message: "The trip was too short or location was unavailable."
                    )
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                LabeledContent("Started", value: trip.startTime.formatted(date: .abbreviated, time: .shortened))
                if let end = trip.endTime {
                    LabeledContent("Ended", value: end.formatted(date: .omitted, time: .shortened))
                }
                LabeledContent("Duration", value: TripFormatting.duration(trip.durationSeconds))
                LabeledContent("Distance", value: TripFormatting.distance(meters: trip.distanceMeters, useMiles: appState.useMilesPerHour))
                LabeledContent("Average speed", value: TripFormatting.speed(kmh: trip.averageSpeedKmh, useMiles: appState.useMilesPerHour))
            } header: {
                Text("Trip")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Trip Log") {
    NavigationStack { TripLogView() }
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
