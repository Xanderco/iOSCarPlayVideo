import SwiftUI
import MapKit

public struct SpeedGradientRouteView: View {
    public let points: [TripPoint]

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    public init(points: [TripPoint]) {
        self.points = points
    }

    public var body: some View {
        Map(position: $position) {
            // Real-time Current User Location Pin
            UserAnnotation()

            if points.count >= 2 {
                // Render segments colored by speed
                ForEach(0..<(points.count - 1), id: \.self) { i in
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let coords = [
                        CLLocationCoordinate2D(latitude: p1.latitude, longitude: p1.longitude),
                        CLLocationCoordinate2D(latitude: p2.latitude, longitude: p2.longitude)
                    ]
                    MapPolyline(coordinates: coords)
                        .stroke(colorForSpeed(p1.speedKmh), lineWidth: 5)
                }

                // Start Marker
                if let first = points.first {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                        Circle()
                            .fill(Color.dashRed)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForSpeed(_ speedKmh: Double) -> Color {
        switch speedKmh {
        case ..<15:
            return .dashRed
        case 15..<40:
            return .dashOrange
        case 40..<80:
            return .dashGreen
        default:
            return .dashCyan
        }
    }
}
