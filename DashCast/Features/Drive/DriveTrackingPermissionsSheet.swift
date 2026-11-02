import SwiftUI
import CoreLocation

public struct DriveTrackingPermissionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = DriveLocationService.shared

    @State private var locationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    @State private var motionAuthorized: Bool = true
    @State private var notificationsAuthorized: Bool = true

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
                        title: "Location — Always Allow",
                        subtitle: "Lets us detect drives even when the app is closed."
                    ) {
                        Button {
                            locationService.requestAlwaysAuthorization()
                        } label: {
                            Text("Continue")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color.dashGreen)
                                .clipShape(Capsule())
                        }
                    }

                    // Permission Card 2: Motion & Fitness
                    permissionCard(
                        icon: "car.side.fill",
                        title: "Motion & Fitness",
                        subtitle: "How we sense that you've started driving."
                    ) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.dashGreen)
                    }

                    // Permission Card 3: Notifications
                    permissionCard(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: "So we can send your trip report when a drive ends."
                    ) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.dashGreen)
                    }

                    // On-device privacy note
                    Text("All of these are needed for automatic drive tracking. Your trips stay on this device.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dashTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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

    private func permissionCard<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String,
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
