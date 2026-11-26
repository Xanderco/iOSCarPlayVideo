import SwiftUI
import MapKit

/// Speed-color tiers for rendering speed-gradient trip polylines.
public enum SpeedGradientTier: String, CaseIterable, Equatable, Sendable {
    case slow
    case moderate
    case cruising
    case highway

    nonisolated public static let startAnnotationString = "Start"
    nonisolated public static let endAnnotationString = "End"

    @MainActor
    public static var startAnnotationKey: LocalizedStringKey {
        LocalizedStringKey(startAnnotationString)
    }

    @MainActor
    public static var endAnnotationKey: LocalizedStringKey {
        LocalizedStringKey(endAnnotationString)
    }

    nonisolated public static func tier(forSpeedKmh speedKmh: Double) -> SpeedGradientTier {
        guard speedKmh.isFinite else { return .slow }
        switch speedKmh {
        case ..<15:
            return .slow
        case 15..<40:
            return .moderate
        case 40..<80:
            return .cruising
        default:
            return .highway
        }
    }

    public var color: Color {
        switch self {
        case .slow:
            return .dashRed
        case .moderate:
            return .dashOrange
        case .cruising:
            return .dashGreen
        case .highway:
            return .dashCyan
        }
    }
}

public struct SpeedGradientRouteView: View {
    public let points: [TripPoint]

    @State private var position: MapCameraPosition = .automatic

    public init(points: [TripPoint]) {
        self.points = points
    }

    public var body: some View {
        Map(position: $position) {
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
                        .stroke(SpeedGradientTier.tier(forSpeedKmh: p1.speedKmh).color, lineWidth: 5)
                }

                // Start Marker
                if let first = points.first {
                    Annotation(SpeedGradientTier.startAnnotationKey, coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                        Circle()
                            .fill(Color.dashRed)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }

                // Current/End Marker
                if let last = points.last {
                    Annotation(SpeedGradientTier.endAnnotationKey, coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.dashCyan)
                            .background(Circle().fill(Color.white))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
