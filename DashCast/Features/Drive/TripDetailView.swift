import SwiftUI
import MapKit

public struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    public let trip: TripModel
    private let onTripUpdated: ((TripModel) -> Void)?

    @State private var mapMode: TripMapMode = .replay
    @State private var selectedCategory: TripCategory?
    @State private var savedCategory: TripCategory?
    @State private var noteText: String
    @State private var savedNote: String?
    @FocusState private var isNoteFocused: Bool

    public init(trip: TripModel, onTripUpdated: ((TripModel) -> Void)? = nil) {
        self.trip = trip
        self.onTripUpdated = onTripUpdated
        _selectedCategory = State(initialValue: trip.category)
        _savedCategory = State(initialValue: trip.category)
        _noteText = State(initialValue: trip.note ?? "")
        _savedNote = State(initialValue: TripModel.normalizedNote(trip.note))
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

                    // Purpose & Notes Card
                    purposeAndNotesCard
                        .padding(.horizontal)

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
        .navigationTitle(trip.startTime.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isNoteFocused) { _, focused in
            if !focused {
                persistEdits()
            }
        }
        .onDisappear {
            persistEdits()
        }
    }

    private var purposeAndNotesCard: some View {
        let pendingNote = TripModel.normalizedNote(noteText)
        let hasUnsavedNote = pendingNote != savedNote

        return AutomotiveCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TRIP PURPOSE")
                        .font(ThemeFonts.hudCaption(size: 12))
                        .foregroundStyle(Color.dcTextTertiary)
                        .tracking(1.2)

                    Spacer()

                    if selectedCategory != nil {
                        Button("Clear") {
                            selectedCategory = nil
                            persistEdits()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dcTextSecondary)
                        .accessibilityIdentifier("TripDetail_ClearCategoryButton")
                    }
                }

                HStack(spacing: 8) {
                    ForEach(TripCategory.allCases) { category in
                        let isSelected = selectedCategory == category
                        Button {
                            selectedCategory = isSelected ? nil : category
                            persistEdits()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(LocalizedStringKey(category.displayName))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(isSelected ? Color.dcOnAccent : Color.dcTextSecondary)
                            .background(
                                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                    .fill(isSelected ? Color.dcAccent : Color.dcSurfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                    .strokeBorder(isSelected ? Color.clear : Color.dcStroke, lineWidth: DSStroke.regular)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("TripDetail_Category_\(category.rawValue)")
                    }
                }

                Divider().background(Color.dcSeparator)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("NOTES")
                            .font(ThemeFonts.hudCaption(size: 11))
                            .foregroundStyle(Color.dcTextTertiary)
                            .tracking(1.1)

                        Spacer()

                        if hasUnsavedNote {
                            Button("Save Note") {
                                isNoteFocused = false
                                persistEdits()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dcAccent)
                            .accessibilityIdentifier("TripDetail_SaveNoteButton")
                        }
                    }

                    TextField("Add a trip note (optional)", text: $noteText, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dcTextPrimary)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                                .fill(Color.dcSurfaceRaised)
                        )
                        .focused($isNoteFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isNoteFocused = false
                            persistEdits()
                        }
                        .accessibilityIdentifier("TripDetail_NoteField")
                }
            }
        }
    }

    private func persistEdits() {
        let normalized = TripModel.normalizedNote(noteText)
        guard selectedCategory != savedCategory || normalized != savedNote else {
            return
        }
        var updated = trip
        updated.category = selectedCategory
        updated.note = normalized
        savedCategory = selectedCategory
        savedNote = normalized
        PersistenceController.shared.updateTrip(updated)
        onTripUpdated?(updated)
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
