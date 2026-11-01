import Foundation
import CoreLocation

public struct HexCell: Hashable, Identifiable {
    public let q: Int
    public let r: Int

    public var id: String {
        "hex_\(q)_\(r)"
    }

    public init(q: Int, r: Int) {
        self.q = q
        self.r = r
    }
}

public struct HexGridEngine {
    // Hex cell radius in degrees ~ 0.0035 deg (~390 meters / ~0.24 mi)
    public static let hexSizeDegrees: Double = 0.0035

    public static func hexCell(for coordinate: CLLocationCoordinate2D) -> HexCell {
        let size = hexSizeDegrees
        // Flat-topped hexagon projection
        let x = coordinate.longitude / (size * 1.5)
        let y = coordinate.latitude / (size * sqrt(3.0))

        let q = Int(round(x))
        let r = Int(round(y - (Double(q) * 0.5)))
        return HexCell(q: q, r: r)
    }

    public static func center(of cell: HexCell) -> CLLocationCoordinate2D {
        let size = hexSizeDegrees
        let lon = Double(cell.q) * size * 1.5
        let lat = (Double(cell.r) + Double(cell.q) * 0.5) * (size * sqrt(3.0))
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public static func polygonVertices(for cell: HexCell) -> [CLLocationCoordinate2D] {
        let centerCoord = center(of: cell)
        let size = hexSizeDegrees * 0.95 // Small gap between hex borders for clean aesthetics
        var vertices: [CLLocationCoordinate2D] = []

        for i in 0..<6 {
            let angleDeg = 60.0 * Double(i) - 30.0
            let angleRad = angleDeg * .pi / 180.0
            let lat = centerCoord.latitude + (size * sin(angleRad))
            let lon = centerCoord.longitude + (size * cos(angleRad))
            vertices.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        return vertices
    }

    public static let areaPerHexSqKm: Double = 0.162 // ~0.162 sq km per cell
    public static let areaPerHexSqMi: Double = 0.0627 // ~0.0627 sq mi per cell
}
