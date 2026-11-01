import SwiftUI
import MapKit

public struct TerritoryMapView: View {
    public let claimedHexIDs: Set<String>

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    public init(claimedHexIDs: Set<String>) {
        self.claimedHexIDs = claimedHexIDs
    }

    private var hexCells: [HexCell] {
        claimedHexIDs.compactMap { id -> HexCell? in
            let parts = id.components(separatedBy: "_")
            if parts.count == 3, let q = Int(parts[1]), let r = Int(parts[2]) {
                return HexCell(q: q, r: r)
            }
            return nil
        }
    }

    public var body: some View {
        Map(position: $position) {
            // Live User GPS Location
            UserAnnotation()

            ForEach(hexCells) { cell in
                let vertices = HexGridEngine.polygonVertices(for: cell)
                MapPolygon(coordinates: vertices)
                    .foregroundStyle(Color.dashCyan.opacity(0.35))
                    .stroke(Color.dashCyan, lineWidth: 2)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea()
    }
}
