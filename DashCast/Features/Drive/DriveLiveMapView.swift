import SwiftUI
import MapKit
import CoreLocation
import UIKit

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
                    Label("Recenter", systemImage: "location.fill")
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
        switch Self.kind(for: location.authorizationStatus) {
        case .askWhenInUse:
            card(icon: "location.circle.fill",
                 title: "Show where you are",
                 message: "DashCast uses your location to centre the map on you and to record the route of a trip. Trips stay on this iPhone and are never uploaded.",
                 button: "Allow Location") { location.requestPermissions() }
        case .askAlways:
            card(icon: "car.circle.fill",
                 title: "Record trips automatically",
                 message: "Choose “Change to Always Allow” so DashCast can notice when you start driving and save the trip on its own, even with the app closed. You can turn this off any time.",
                 button: "Allow All the Time") { location.requestAlwaysAuthorization() }
        case .denied:
            card(icon: "location.slash.fill",
                 title: "Location is off for DashCast",
                 message: "Turn on location in Settings › DashCast › Location to see yourself on the map and record trips.",
                 button: "Open Settings") { openSettings() }
        case .restricted:
            card(icon: "lock.fill",
                 title: "Location is restricted",
                 message: "Location Services are limited on this device (for example by Screen Time or a device profile), so DashCast can't show your position.",
                 button: nil) {}
        case .none:
            EmptyView()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func card(icon: String, title: String, message: String, button: String?, action: @escaping () -> Void) -> some View {
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
