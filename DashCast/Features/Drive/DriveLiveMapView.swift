import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// Testable localization copy & state mapping for `DriveLiveMapView` and `LocationPermissionCard`.
enum LocationPermissionCardCopy {
    struct Descriptor: Equatable {
        let icon: String
        let titleKeyName: String
        let messageKeyName: String
        let buttonKeyName: String?

        @MainActor var title: LocalizedStringKey { LocalizedStringKey(titleKeyName) }
        @MainActor var message: LocalizedStringKey { LocalizedStringKey(messageKeyName) }
        @MainActor var button: LocalizedStringKey? { buttonKeyName.map { LocalizedStringKey($0) } }
    }

    static let allLocalizationKeys: [String] = [
        "Recenter",
        "Centres the map on your location",
        "Map of your current location",
        "Show where you are",
        "DashCast uses your location to centre the map on you and to record the route of a trip. Trips stay on this iPhone and are never uploaded.",
        "Allow Location",
        "Record trips automatically",
        "Choose “Change to Always Allow” so DashCast can notice when you start driving and save the trip on its own, even with the app closed. You can turn this off any time.",
        "Allow All the Time",
        "Location is off for DashCast",
        "Turn on location in Settings › DashCast › Location to see yourself on the map and record trips.",
        "Open Settings",
        "Location is restricted",
        "Location Services are limited on this device (for example by Screen Time or a device profile), so DashCast can't show your position."
    ]

    nonisolated static func descriptor(forKind kind: LocationPermissionCard.Kind) -> Descriptor? {
        switch kind {
        case .askWhenInUse:
            return Descriptor(
                icon: "location.circle.fill",
                titleKeyName: "Show where you are",
                messageKeyName: "DashCast uses your location to centre the map on you and to record the route of a trip. Trips stay on this iPhone and are never uploaded.",
                buttonKeyName: "Allow Location"
            )
        case .askAlways:
            return Descriptor(
                icon: "car.circle.fill",
                titleKeyName: "Record trips automatically",
                messageKeyName: "Choose “Change to Always Allow” so DashCast can notice when you start driving and save the trip on its own, even with the app closed. You can turn this off any time.",
                buttonKeyName: "Allow All the Time"
            )
        case .denied:
            return Descriptor(
                icon: "location.slash.fill",
                titleKeyName: "Location is off for DashCast",
                messageKeyName: "Turn on location in Settings › DashCast › Location to see yourself on the map and record trips.",
                buttonKeyName: "Open Settings"
            )
        case .restricted:
            return Descriptor(
                icon: "lock.fill",
                titleKeyName: "Location is restricted",
                messageKeyName: "Location Services are limited on this device (for example by Screen Time or a device profile), so DashCast can't show your position.",
                buttonKeyName: nil
            )
        case .none:
            return nil
        }
    }

    nonisolated static func descriptor(for status: CLAuthorizationStatus) -> Descriptor? {
        descriptor(forKind: LocationPermissionCard.kind(for: status))
    }
}

/// Live map for Drive: centred on the user (not the whole region), follows heading while a
/// trip records, and draws the route recorded so far.
struct DriveLiveMapView: View {
    @ObservedObject private var location = DriveLocationService.shared
    @State private var position: MapCameraPosition = DriveLiveMapView.camera(tracking: false)

    static func camera(tracking: Bool) -> MapCameraPosition {
        .userLocation(followsHeading: tracking, fallback: .automatic)
    }

    private var route: [CLLocationCoordinate2D] {
        location.tripPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            if location.isTracking, route.count > 1 {
                MapPolyline(coordinates: route)
                    .stroke(Color.dcAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .bottomLeading) {
            if !position.followsUserLocation && location.isAuthorized {
                Button {
                    withAnimation { position = Self.camera(tracking: location.isTracking) }
                } label: {
                    Label(LocalizedStringKey("Recenter"), systemImage: "location.fill")
                        .font(DSTypography.subheadline)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.xs)
                        .background(.thinMaterial, in: Capsule())
                }
                .padding(DSSpacing.sm)
                .accessibilityHint(Text("Centres the map on your location"))
            }
        }
        .onChange(of: location.isTracking) { _, tracking in
            withAnimation { position = Self.camera(tracking: tracking) }
        }
        .onChange(of: location.authorizationStatus) { _, _ in
            // Permission just granted: jump from the region fallback to the user.
            position = Self.camera(tracking: location.isTracking)
        }
        .accessibilityLabel(Text("Map of your current location"))
    }
}

/// Explains why DashCast wants location before asking, and handles denied/restricted.
struct LocationPermissionCard: View {
    @ObservedObject private var location = DriveLocationService.shared

    enum Kind: Equatable { case askWhenInUse, askAlways, denied, restricted, none }

    nonisolated static func kind(for status: CLAuthorizationStatus) -> Kind {
        switch status {
        case .notDetermined: return .askWhenInUse
        case .authorizedWhenInUse: return .askAlways
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .none
        }
    }

    var body: some View {
        let kind = Self.kind(for: location.authorizationStatus)
        if let copy = LocationPermissionCardCopy.descriptor(forKind: kind) {
            card(
                icon: copy.icon,
                title: copy.title,
                message: copy.message,
                button: copy.button
            ) {
                switch kind {
                case .askWhenInUse:
                    location.requestPermissions()
                case .askAlways:
                    location.requestAlwaysAuthorization()
                case .denied:
                    openSettings()
                case .restricted, .none:
                    break
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func card(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        button: LocalizedStringKey?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label(title, systemImage: icon)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dcTextPrimary)
            Text(message)
                .font(DSTypography.subheadline)
                .foregroundStyle(Color.dcTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let button {
                PrimaryButton(button, systemImage: nil, kind: .primary, size: .compact, action: action)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
