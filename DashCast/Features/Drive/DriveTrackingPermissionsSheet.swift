import SwiftUI
import CoreLocation
import UserNotifications

/// Localized copy keys for `DriveTrackingPermissionsSheet`.
public enum DriveTrackingPermissionsCopy {
    nonisolated public static let titleString = "Enable Tracking"
    nonisolated public static let locationTitleString = "Location"
    nonisolated public static let allowButtonString = "Allow"
    nonisolated public static let settingsButtonString = "Settings"
    nonisolated public static let notificationsTitleString = "Notifications"
    nonisolated public static let notificationsSubtitleString = "So we can send your trip report when a drive ends."
    nonisolated public static let privacyNoteString = "Trips are recorded while you press Start Drive (also with the screen locked). Your trips stay on this device."
    nonisolated public static let doneButtonString = "Done"
    nonisolated public static let locationAlwaysAllowedString = "Always allowed."
    nonisolated public static let locationWhenInUseAllowedString = "Allowed while using DashCast; trips keep recording when the screen locks."
    nonisolated public static let locationDeniedString = "Off. Turn it on in Settings to record trips."
    nonisolated public static let locationNeededString = "Needed to measure speed, distance and your route."

    nonisolated public static let allLocalizationKeys: [String] = [
        titleString,
        locationTitleString,
        allowButtonString,
        settingsButtonString,
        notificationsTitleString,
        notificationsSubtitleString,
        privacyNoteString,
        doneButtonString,
        locationAlwaysAllowedString,
        locationWhenInUseAllowedString,
        locationDeniedString,
        locationNeededString
    ]

    @MainActor public static var titleKey: LocalizedStringKey { LocalizedStringKey(titleString) }
    @MainActor public static var locationTitleKey: LocalizedStringKey { LocalizedStringKey(locationTitleString) }
    @MainActor public static var allowButtonKey: LocalizedStringKey { LocalizedStringKey(allowButtonString) }
    @MainActor public static var settingsButtonKey: LocalizedStringKey { LocalizedStringKey(settingsButtonString) }
    @MainActor public static var notificationsTitleKey: LocalizedStringKey { LocalizedStringKey(notificationsTitleString) }
    @MainActor public static var notificationsSubtitleKey: LocalizedStringKey { LocalizedStringKey(notificationsSubtitleString) }
    @MainActor public static var privacyNoteKey: LocalizedStringKey { LocalizedStringKey(privacyNoteString) }
    @MainActor public static var doneButtonKey: LocalizedStringKey { LocalizedStringKey(doneButtonString) }
    @MainActor public static var locationAlwaysAllowedKey: LocalizedStringKey { LocalizedStringKey(locationAlwaysAllowedString) }
    @MainActor public static var locationWhenInUseAllowedKey: LocalizedStringKey { LocalizedStringKey(locationWhenInUseAllowedString) }
    @MainActor public static var locationDeniedKey: LocalizedStringKey { LocalizedStringKey(locationDeniedString) }
    @MainActor public static var locationNeededKey: LocalizedStringKey { LocalizedStringKey(locationNeededString) }
}

public struct DriveTrackingPermissionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = DriveLocationService.shared

    // These used to be hardcoded to "granted" (green checkmarks) and nothing was ever requested.
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header with Car Avatar
                    HStack(alignment: .center) {
                        Text(DriveTrackingPermissionsCopy.titleKey)
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Color.dashTextPrimary)

                        Spacer()

                        // Circular Car Avatar
                        ZStack {
                            Circle()
                                .fill(Color.dashSurfaceHighlight)
                                .frame(width: 48, height: 48)
                                .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))

                            Image("car_porsche_911")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 24)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Permission Card 1: Location Always
                    permissionCard(
                        icon: "location.fill",
                        title: DriveTrackingPermissionsCopy.locationTitleKey,
                        subtitle: locationSubtitle
                    ) {
                        if locationService.authorizationStatus == .authorizedAlways ||
                            locationService.authorizationStatus == .authorizedWhenInUse {
                            grantedCheckmark
                        } else {
                            Button {
                                switch locationService.authorizationStatus {
                                case .notDetermined:
                                    locationService.requestPermissions()
                                default:
                                    openSettings()
                                }
                            } label: {
                                Text(locationService.authorizationStatus == .notDetermined ? DriveTrackingPermissionsCopy.allowButtonKey : DriveTrackingPermissionsCopy.settingsButtonKey)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color.dashGreen)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    // Permission Card 2: Notifications
                    permissionCard(
                        icon: "bell.fill",
                        title: DriveTrackingPermissionsCopy.notificationsTitleKey,
                        subtitle: DriveTrackingPermissionsCopy.notificationsSubtitleKey
                    ) {
                        if notificationStatus == .authorized || notificationStatus == .provisional {
                            grantedCheckmark
                        } else {
                            Button {
                                if notificationStatus == .notDetermined {
                                    Task {
                                        _ = await DriveNotificationService.shared.requestAuthorization()
                                        await refreshNotificationStatus()
                                    }
                                } else {
                                    openSettings()
                                }
                            } label: {
                                Text(notificationStatus == .notDetermined ? DriveTrackingPermissionsCopy.allowButtonKey : DriveTrackingPermissionsCopy.settingsButtonKey)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(Color.dashGreen)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // On-device privacy note
                    Text(DriveTrackingPermissionsCopy.privacyNoteKey)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dashTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshNotificationStatus() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(DriveTrackingPermissionsCopy.doneButtonKey) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private var grantedCheckmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 26))
            .foregroundStyle(Color.dashGreen)
    }

    private var locationSubtitle: LocalizedStringKey {
        switch locationService.authorizationStatus {
        case .authorizedAlways: return DriveTrackingPermissionsCopy.locationAlwaysAllowedKey
        case .authorizedWhenInUse: return DriveTrackingPermissionsCopy.locationWhenInUseAllowedKey
        case .denied, .restricted: return DriveTrackingPermissionsCopy.locationDeniedKey
        default: return DriveTrackingPermissionsCopy.locationNeededKey
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationStatus = await DriveNotificationService.shared.checkAuthorizationStatus()
    }

    private func permissionCard<Trailing: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.14, green: 0.16, blue: 0.22))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.dashYellow)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            trailing()
        }
        .padding(14)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
