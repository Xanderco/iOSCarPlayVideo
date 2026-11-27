import SwiftUI

/// Localized copy and title formatting helpers for `TripHistoryView`.
public enum TripHistoryCopy {
    nonisolated public static let emptyTitleString = "No Trips Recorded Yet"
    nonisolated public static let emptyMessageString = "Trips you record or auto-detect with DashCast will appear here with route replay and telemetry stats."
    nonisolated public static let totalDrivesString = "TOTAL DRIVES"
    nonisolated public static let totalDistanceString = "TOTAL DISTANCE"
    nonisolated public static let avgScoreString = "AVG SCORE"
    nonisolated public static let summaryHeaderString = "Summary"
    nonisolated public static let allRecordedTripsFormatString = "All Recorded Trips (%lld)"
    nonisolated public static let navigationTitleString = "Trip History"
    nonisolated public static let closeString = "Close"
    nonisolated public static let clearAllAccessibilityString = "Clear all trips"
    nonisolated public static let clearAlertTitleString = "Clear Trip History?"
    nonisolated public static let clearAllButtonString = "Clear All"
    nonisolated public static let cancelString = "Cancel"
    nonisolated public static let clearAlertMessageString = "Are you sure you want to delete all recorded trips? This action cannot be undone."
    nonisolated public static let replayString = "Replay"
    nonisolated public static let scoreBadgeString = "SCORE"

    nonisolated public static let allLocalizationKeys: [String] = [
        emptyTitleString,
        emptyMessageString,
        totalDrivesString,
        totalDistanceString,
        avgScoreString,
        summaryHeaderString,
        allRecordedTripsFormatString,
        navigationTitleString,
        closeString,
        clearAllAccessibilityString,
        clearAlertTitleString,
        clearAllButtonString,
        cancelString,
        clearAlertMessageString,
        replayString,
        scoreBadgeString
    ]

    @MainActor public static var totalDrivesKey: LocalizedStringKey { LocalizedStringKey(totalDrivesString) }
    @MainActor public static var totalDistanceKey: LocalizedStringKey { LocalizedStringKey(totalDistanceString) }
    @MainActor public static var avgScoreKey: LocalizedStringKey { LocalizedStringKey(avgScoreString) }
    @MainActor public static var summaryHeaderKey: LocalizedStringKey { LocalizedStringKey(summaryHeaderString) }
    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
    @MainActor public static var closeKey: LocalizedStringKey { LocalizedStringKey(closeString) }
    @MainActor public static var clearAllAccessibilityKey: LocalizedStringKey { LocalizedStringKey(clearAllAccessibilityString) }
    @MainActor public static var clearAlertTitleKey: LocalizedStringKey { LocalizedStringKey(clearAlertTitleString) }
    @MainActor public static var clearAllButtonKey: LocalizedStringKey { LocalizedStringKey(clearAllButtonString) }
    @MainActor public static var cancelKey: LocalizedStringKey { LocalizedStringKey(cancelString) }
    @MainActor public static var clearAlertMessageKey: LocalizedStringKey { LocalizedStringKey(clearAlertMessageString) }
    @MainActor public static var replayKey: LocalizedStringKey { LocalizedStringKey(replayString) }
    @MainActor public static var scoreBadgeKey: LocalizedStringKey { LocalizedStringKey(scoreBadgeString) }

    nonisolated public static func allRecordedTripsHeader(count: Int, bundle: Bundle = .main) -> String {
        let format = bundle.localizedString(forKey: allRecordedTripsFormatString, value: allRecordedTripsFormatString, table: nil)
        return String(format: format, Int64(count))
    }
}

/// Pure aggregate stats and row formatting helpers for `TripHistoryView`.
public enum TripHistoryMetricsFormatter {
    nonisolated public static func totalDistanceFormatted(trips: [TripModel], useMilesPerHour: Bool) -> String {
        let totalMeters = trips.reduce(0.0) { $0 + $1.distanceMeters }
        return distanceText(meters: totalMeters, useMilesPerHour: useMilesPerHour)
    }

    nonisolated public static func averageScore(trips: [TripModel]) -> Int {
        guard !trips.isEmpty else { return 0 }
        let total = trips.reduce(0) { $0 + $1.drivingScore }
        return total / trips.count
    }

    nonisolated public static func distanceText(meters: Double, useMilesPerHour: Bool) -> String {
        if useMilesPerHour {
            let miles = meters * 0.000621371
            return String(format: "%.1f mi", miles)
        } else {
            let km = meters / 1000.0
            return String(format: "%.1f km", km)
        }
    }

    nonisolated public static func durationText(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 60 {
            let hours = mins / 60
            let remMins = mins % 60
            return "\(hours)h \(remMins)m"
        }
        return "\(mins)m \(secs)s"
    }
}

public struct TripHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var trips: [TripModel] = []
    @State private var showingClearAlert = false

    public init() {}

    private var totalDistanceFormatted: String {
        TripHistoryMetricsFormatter.totalDistanceFormatted(trips: trips, useMilesPerHour: appState.useMilesPerHour)
    }

    private var averageScore: Int {
        TripHistoryMetricsFormatter.averageScore(trips: trips)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                if trips.isEmpty {
                    EmptyStateView(
                        systemImage: "map",
                        title: TripHistoryCopy.emptyTitleString,
                        message: TripHistoryCopy.emptyMessageString
                    )
                } else {
                    List {
                        // Summary Stats Header Card
                        Section {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(TripHistoryCopy.totalDrivesKey)
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dashTextMuted)
                                        Text("\(trips.count)")
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(Color.dashTextPrimary)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(TripHistoryCopy.totalDistanceKey)
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dashTextMuted)
                                        Text(totalDistanceFormatted)
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(Color.dashYellow)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(TripHistoryCopy.avgScoreKey)
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
                            Text(TripHistoryCopy.summaryHeaderKey)
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
                            Text(verbatim: TripHistoryCopy.allRecordedTripsHeader(count: trips.count))
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashTextMuted)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(TripHistoryCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(TripHistoryCopy.closeKey) {
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
                        .accessibilityLabel(TripHistoryCopy.clearAllAccessibilityKey)
                    }
                }
            }
            .alert(TripHistoryCopy.clearAlertTitleKey, isPresented: $showingClearAlert) {
                Button(TripHistoryCopy.clearAllButtonKey, role: .destructive) {
                    clearAllTrips()
                }
                Button(TripHistoryCopy.cancelKey, role: .cancel) {}
            } message: {
                Text(TripHistoryCopy.clearAlertMessageKey)
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
                    Text(TripHistoryMetricsFormatter.distanceText(meters: trip.distanceMeters, useMilesPerHour: appState.useMilesPerHour))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                    Text(TripHistoryMetricsFormatter.durationText(seconds: trip.durationSeconds))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                    if trip.points.count >= 2 {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextMuted)
                        HStack(spacing: 2) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 10))
                            Text(TripHistoryCopy.replayKey)
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
                Text(TripHistoryCopy.scoreBadgeKey)
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
