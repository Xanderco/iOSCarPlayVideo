import SwiftUI

public struct TripHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var trips: [TripModel] = []
    @State private var showingClearAlert = false

    public init() {}

    private var totalDistanceFormatted: String {
        let totalMeters = trips.reduce(0.0) { $0 + $1.distanceMeters }
        if appState.useMilesPerHour {
            let miles = totalMeters * 0.000621371
            return String(format: "%.1f mi", miles)
        } else {
            let km = totalMeters / 1000.0
            return String(format: "%.1f km", km)
        }
    }

    private var averageScore: Int {
        guard !trips.isEmpty else { return 0 }
        let total = trips.reduce(0) { $0 + $1.drivingScore }
        return total / trips.count
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                if trips.isEmpty {
                    EmptyStateView(
                        systemImage: "map",
                        title: "No Trips Recorded Yet",
                        message: "Trips you record or auto-detect with DashCast will appear here with route replay and telemetry stats."
                    )
                } else {
                    List {
                        // Summary Stats Header Card
                        Section {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TOTAL DRIVES")
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dashTextMuted)
                                        Text("\(trips.count)")
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(Color.dashTextPrimary)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TOTAL DISTANCE")
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dashTextMuted)
                                        Text(totalDistanceFormatted)
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(Color.dashYellow)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AVG SCORE")
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dashTextMuted)
                                        Text("\(averageScore)")
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(averageScore >= 80 ? Color.dashGreen : Color.dashOrange)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.dashSurface)
                        } header: {
                            Text("Summary")
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashTextMuted)
                        }

                        // Past Trips List
                        Section {
                            ForEach(trips) { trip in
                                NavigationLink {
                                    TripDetailView(trip: trip)
                                } label: {
                                    tripRow(trip: trip)
                                }
                                .listRowBackground(Color.dashSurface)
                            }
                            .onDelete(perform: deleteTrips)
                        } header: {
                            Text("All Recorded Trips (\(trips.count))")
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashTextMuted)
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
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dashTextPrimary)
                }

                if !trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.dashRed)
                        }
                        .accessibilityLabel("Clear all trips")
                    }
                }
            }
            .alert("Clear Trip History?", isPresented: $showingClearAlert) {
                Button("Clear All", role: .destructive) {
                    clearAllTrips()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete all recorded trips? This action cannot be undone.")
            }
            .onAppear {
                loadTrips()
            }
        }
    }

    private func tripRow(trip: TripModel) -> some View {
        HStack(spacing: 12) {
            // Icon / Indicator
            ZStack {
                Circle()
                    .fill(Color.dashSurfaceHighlight)
                    .frame(width: 40, height: 40)
                Image(systemName: "road.lanes")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dashYellow)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)

                HStack(spacing: 6) {
                    Text(formatDistance(trip.distanceMeters))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                    Text(formatDuration(trip.durationSeconds))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                    if trip.points.count >= 2 {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextMuted)
                        HStack(spacing: 2) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 10))
                            Text("Replay")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.dcAccent)
                    }
                }
            }

            Spacer()

            // Score badge
            VStack(spacing: 1) {
                Text("\(trip.drivingScore)")
                    .font(ThemeFonts.hudStat(size: 17))
                    .foregroundStyle(scoreColor(for: trip.drivingScore))
                Text("SCORE")
                    .font(ThemeFonts.hudCaption(size: 8))
                    .foregroundStyle(scoreColor(for: trip.drivingScore))
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(scoreColor(for: trip.drivingScore).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 85 { return .dashGreen }
        if score >= 70 { return .dashYellow }
        return .dashRed
    }

    private func formatDistance(_ meters: Double) -> String {
        if appState.useMilesPerHour {
            let miles = meters * 0.000621371
            return String(format: "%.1f mi", miles)
        } else {
            let km = meters / 1000.0
            return String(format: "%.1f km", km)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 60 {
            let hours = mins / 60
            let remMins = mins % 60
            return "\(hours)h \(remMins)m"
        }
        return "\(mins)m \(secs)s"
    }

    private func loadTrips() {
        trips = PersistenceController.shared.loadTrips()
    }

    private func deleteTrips(at offsets: IndexSet) {
        trips.remove(atOffsets: offsets)
        PersistenceController.shared.saveTrips(trips)
    }

    private func clearAllTrips() {
        trips.removeAll()
        PersistenceController.shared.saveTrips(trips)
    }
}
