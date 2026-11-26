import SwiftUI

public struct TripHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var trips: [TripModel] = []
    @State private var selectedCategory: TripCategory? = nil
    @State private var showingClearAlert = false

    public init() {}

    private var filteredTrips: [TripModel] {
        TripCategorySummary.filter(trips, by: selectedCategory)
    }

    private var filteredSummary: TripCategorySummary {
        TripCategorySummary.summarize(trips, category: selectedCategory)
    }

    private var totalDistanceFormatted: String {
        if appState.useMilesPerHour {
            return String(format: "%.1f mi", filteredSummary.totalDistanceMiles)
        } else {
            return String(format: "%.1f km", filteredSummary.totalDistanceKilometers)
        }
    }

    private var averageScore: Int {
        filteredSummary.averageScore
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                if trips.isEmpty {
                    EmptyStateView(
                        systemImage: "map",
                        title: "No Trips Recorded Yet",
                        message: "Trips you record or auto-detect with DashCast will appear here with route replay and telemetry stats."
                    )
                } else {
                    List {
                        // Purpose Filter Chips
                        Section {
                            categoryFilterStrip
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                        }

                        // Summary Stats Header Card
                        Section {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TOTAL DRIVES")
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dcTextTertiary)
                                        Text("\(filteredSummary.tripCount)")
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(Color.dcTextPrimary)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TOTAL DISTANCE")
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dcTextTertiary)
                                        Text(totalDistanceFormatted)
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(Color.dcAccent)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AVG SCORE")
                                            .font(ThemeFonts.hudCaption(size: 11))
                                            .foregroundStyle(Color.dcTextTertiary)
                                        Text("\(averageScore)")
                                            .font(ThemeFonts.hudStat(size: 22))
                                            .foregroundStyle(averageScore >= 80 ? Color.dcSuccess : Color.dcWarning)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.dcSurface)
                        } header: {
                            Group {
                                if let selectedCategory {
                                    HStack(spacing: 4) {
                                        Text("Summary")
                                        Text("·")
                                        Text(LocalizedStringKey(selectedCategory.displayName))
                                    }
                                } else {
                                    Text("Summary")
                                }
                            }
                            .font(ThemeFonts.hudCaption(size: 12))
                            .foregroundStyle(Color.dcTextTertiary)
                        }

                        // Past Trips List
                        Section {
                            if filteredTrips.isEmpty {
                                VStack(spacing: 6) {
                                    Text("No Trips in This Category")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.dcTextPrimary)
                                    Text("Open any trip to tag it as Business, Commute, or Personal.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.dcTextSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .listRowBackground(Color.dcSurface)
                            } else {
                                ForEach(filteredTrips) { trip in
                                    NavigationLink {
                                        TripDetailView(trip: trip) { updated in
                                            applyUpdatedTrip(updated)
                                        }
                                    } label: {
                                        tripRow(trip: trip)
                                    }
                                    .listRowBackground(Color.dcSurface)
                                }
                                .onDelete(perform: deleteTrips)
                            }
                        } header: {
                            Group {
                                if let selectedCategory {
                                    HStack(spacing: 4) {
                                        Text(LocalizedStringKey(selectedCategory.displayName))
                                        Text("(\(filteredTrips.count))")
                                    }
                                } else {
                                    Text("All Recorded Trips (\(filteredTrips.count))")
                                }
                            }
                            .font(ThemeFonts.hudCaption(size: 12))
                            .foregroundStyle(Color.dcTextTertiary)
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
                    .foregroundStyle(Color.dcTextPrimary)
                }

                if !trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.dcDanger)
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

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.sm) {
                filterChip(
                    title: "All",
                    systemImage: "line.3.horizontal.decrease.circle",
                    count: trips.count,
                    isSelected: selectedCategory == nil,
                    identifier: "TripHistory_Filter_all"
                ) {
                    selectedCategory = nil
                }

                ForEach(TripCategory.allCases) { category in
                    let count = trips.filter { $0.category == category }.count
                    filterChip(
                        title: LocalizedStringKey(category.displayName),
                        systemImage: category.systemImage,
                        count: count,
                        isSelected: selectedCategory == category,
                        identifier: "TripHistory_Filter_\(category.rawValue)"
                    ) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, DSSpacing.xs)
        }
    }

    private func filterChip(
        title: LocalizedStringKey,
        systemImage: String,
        count: Int,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(count)")
                    .font(ThemeFonts.monospaceDigits(size: 11))
                    .opacity(0.8)
            }
            .foregroundStyle(isSelected ? Color.dcOnAccent : Color.dcTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.dcAccent : Color.dcSurface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.dcStroke, lineWidth: DSStroke.regular)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func tripRow(trip: TripModel) -> some View {
        HStack(spacing: 12) {
            // Icon / Indicator
            ZStack {
                Circle()
                    .fill(Color.dcSurfaceRaised)
                    .frame(width: 40, height: 40)
                Image(systemName: trip.category?.systemImage ?? "road.lanes")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dcAccent)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)

                    if let category = trip.category {
                        HStack(spacing: 3) {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 9, weight: .semibold))
                            Text(LocalizedStringKey(category.displayName))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.dcAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.dcAccentSoft)
                        .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(formatDistance(trip.distanceMeters))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextTertiary)
                    Text(formatDuration(trip.durationSeconds))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                    if trip.points.count >= 2 {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dcTextTertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 10))
                            Text("Replay")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.dcAccent)
                    }
                }

                if let note = TripModel.normalizedNote(trip.note) {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextTertiary)
                        .lineLimit(1)
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
        if score >= 85 { return .dcSuccess }
        if score >= 70 { return .dcAccent }
        return .dcDanger
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

    private func applyUpdatedTrip(_ updatedTrip: TripModel) {
        if let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) {
            trips[index] = updatedTrip
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        let idsToDelete = Set(offsets.compactMap { index in
            filteredTrips.indices.contains(index) ? filteredTrips[index].id : nil
        })
        trips.removeAll { idsToDelete.contains($0.id) }
        PersistenceController.shared.saveTrips(trips)
    }

    private func clearAllTrips() {
        trips.removeAll()
        PersistenceController.shared.saveTrips(trips)
    }
}
