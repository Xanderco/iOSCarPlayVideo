import SwiftUI
import CoreLocation

public struct DriveSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var preferences: UserPreferences = PersistenceController.shared.loadUserPreferences()
    @State private var showingPermissionsSheet: Bool = false
    @State private var showingVehiclePicker: Bool = false

    private let minimumDriveOptions: [Double] = [50, 100, 250, 500, 1000]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Vehicle Card
                        vehicleCard

                        // TRACKING Section
                        trackingSection

                        // REGION Section
                        regionSection

                        // NOTIFICATIONS Section
                        notificationsSection

                        // PERMISSIONS Section
                        permissionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 36, height: 36)
                            .background(Color.dashSurface)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingPermissionsSheet) {
                DriveTrackingPermissionsSheet()
            }
            .sheet(isPresented: $showingVehiclePicker) {
                vehiclePickerSheet
            }
        }
    }

    // MARK: - Vehicle Card

    private var vehicleCard: some View {
        Button {
            showingVehiclePicker = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dashSurfaceHighlight)
                        .frame(width: 56, height: 56)

                    Image(preferences.driveVehicleImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 36)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.driveVehicleName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("Used for share cards and your map")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dashTextMuted)
            }
            .padding(14)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Tracking Section

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRACKING")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Auto-detect drives
                Toggle(isOn: $preferences.autoDetectDrives) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-detect drives")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("Starts and stops on its own")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextMuted)
                    }
                }
                .tint(Color.dashYellow)
                .padding(14)
                .onChange(of: preferences.autoDetectDrives) { _ in
                    preferences.autoTripDetectionEnabled = preferences.autoDetectDrives
                    savePreferences()
                    // Drives the real detector (CoreMotion + significant location changes).
                    AutoTripService.shared.setEnabled(preferences.autoDetectDrives)
                }

                Divider().background(Color.dashBorder)

                // Minimum drive
                HStack {
                    Text("Minimum drive")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Spacer()

                    Menu {
                        ForEach(minimumDriveOptions, id: \.self) { meters in
                            Button("\(formatMeters(meters))") {
                                preferences.minimumDriveMeters = meters
                                savePreferences()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(formatMeters(preferences.minimumDriveMeters))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.dashTextMuted)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dashTextMuted)
                        }
                    }
                }
                .padding(14)

                Divider().background(Color.dashBorder)

                // Units: mph / km/h
                HStack {
                    Text("Units")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Spacer()

                    HStack(spacing: 2) {
                        Button {
                            preferences.useMilesPerHour = true
                            appState.setSpeedUnit(milesPerHour: true)
                            savePreferences()
                        } label: {
                            Text("mph")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(preferences.useMilesPerHour ? Color.dashYellow : Color.clear)
                                .foregroundStyle(preferences.useMilesPerHour ? Color.black : Color.dashTextMuted)
                                .clipShape(Capsule())
                        }

                        Button {
                            preferences.useMilesPerHour = false
                            appState.setSpeedUnit(milesPerHour: false)
                            savePreferences()
                        } label: {
                            Text("km/h")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(!preferences.useMilesPerHour ? Color.dashYellow : Color.clear)
                                .foregroundStyle(!preferences.useMilesPerHour ? Color.black : Color.dashTextMuted)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(3)
                    .background(Color.dashSurfaceHighlight)
                    .clipShape(Capsule())
                }
                .padding(14)
            }
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Region Section

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REGION")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            HStack {
                Text("Country")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Text(preferences.driveCountry)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dashTextMuted)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
            }
            .padding(14)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTIFICATIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            Toggle(isOn: $preferences.driveNotificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drive notifications")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text("Trip recaps and your weekly summary")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
            }
            .tint(Color.dashYellow)
            .padding(14)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onChange(of: preferences.driveNotificationsEnabled) { enabled in
                savePreferences()
                if enabled {
                    Task {
                        _ = await DriveNotificationService.shared.requestAuthorization()
                        DriveNotificationService.shared.scheduleFeatureTips()
                    }
                }
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERMISSIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                permissionRow(title: "Location", statusText: "While using", color: .dashOrange) {
                    showingPermissionsSheet = true
                }

                Divider().background(Color.dashBorder)

                permissionRow(title: "Motion & Fitness", statusText: "On", color: .dashGreen) {
                    showingPermissionsSheet = true
                }

                Divider().background(Color.dashBorder)

                permissionRow(title: "Notifications", statusText: preferences.driveNotificationsEnabled ? "On" : "Off", color: preferences.driveNotificationsEnabled ? .dashGreen : .dashTextMuted) {
                    showingPermissionsSheet = true
                }
            }
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func permissionRow(title: String, statusText: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
            }
            .padding(14)
        }
    }

    private func formatMeters(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.0f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func savePreferences() {
        PersistenceController.shared.saveUserPreferences(preferences)
    }

    // MARK: - Vehicle Picker Sheet

    private var vehiclePickerSheet: some View {
        NavigationStack {
            List(VehicleCatalogService.shared.vehicles) { vehicle in
                Button {
                    preferences.driveVehicleName = vehicle.name
                    preferences.driveVehicleImage = vehicle.imageName
                    savePreferences()
                    showingVehiclePicker = false
                } label: {
                    HStack(spacing: 12) {
                        Image(vehicle.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 35)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)
                            Text(vehicle.brandId.capitalized)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dashTextMuted)
                        }

                        Spacer()

                        if preferences.driveVehicleName == vehicle.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.dashYellow)
                        }
                    }
                }
                .listRowBackground(Color.dashSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.dashBackground)
            .navigationTitle("Select Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingVehiclePicker = false }
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }
}
