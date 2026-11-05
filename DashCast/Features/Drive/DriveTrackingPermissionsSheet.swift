import SwiftUI
import CoreLocation
import UserNotifications

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
                        Text("Enable Tracking")
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
                        title: "Location",
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
                                Text(locationService.authorizationStatus == .notDetermined ? "Allow" : "Settings")
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
                        title: "Notifications",
                        subtitle: "So we can send your trip report when a drive ends."
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
                                Text(notificationStatus == .notDetermined ? "Allow" : "Settings")
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
                    Text("Trips are recorded while you press Start Drive (also with the screen locked). Your trips stay on this device.")
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
                    Button("Done") {
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
        case .authorizedAlways: return "Always allowed."
        case .authorizedWhenInUse: return "Allowed while using DashCast; trips keep recording when the screen locks."
        case .denied, .restricted: return "Off. Turn it on in Settings to record trips."
        default: return "Needed to measure speed, distance and your route."
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
