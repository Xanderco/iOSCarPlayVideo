import XCTest
import CoreLocation
@testable import DashCast

final class TerritoryEngineTests: XCTestCase {
    func testHexCellDeterministic() {
        let coord = CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855)
        let cell1 = HexGridEngine.hexCell(for: coord)
        let cell2 = HexGridEngine.hexCell(for: coord)

        XCTAssertEqual(cell1, cell2)
        XCTAssertEqual(cell1.id, cell2.id)
    }

    func testPolygonVerticesCount() {
        let cell = HexCell(q: 10, r: 20)
        let vertices = HexGridEngine.polygonVertices(for: cell)

        XCTAssertEqual(vertices.count, 6)
        // Verify vertices surround the center
        let center = HexGridEngine.center(of: cell)
        for vertex in vertices {
            let dist = CLLocation(latitude: center.latitude, longitude: center.longitude)
                .distance(from: CLLocation(latitude: vertex.latitude, longitude: vertex.longitude))
            XCTAssertGreaterThan(dist, 100) // At least 100 meters
            XCTAssertLessThan(dist, 1000)   // Within 1km
        }
    }

    @MainActor
    func testDriverRankProgression() {
        // Verify ranks thresholds
        XCTAssertEqual(DriverRank.rookie.threshold, 0)
        XCTAssertEqual(DriverRank.cruiser.threshold, 50)
        XCTAssertEqual(DriverRank.captain.threshold, 250)
        XCTAssertEqual(DriverRank.king.threshold, 700)
        XCTAssertEqual(DriverRank.legend.threshold, 1500)

        // Verify nextRank chain
        XCTAssertEqual(DriverRank.rookie.nextRank, .cruiser)
        XCTAssertEqual(DriverRank.cruiser.nextRank, .captain)
        XCTAssertEqual(DriverRank.captain.nextRank, .king)
        XCTAssertEqual(DriverRank.king.nextRank, .legend)
        XCTAssertNil(DriverRank.legend.nextRank)
    }

    @MainActor
    func testAreaCalculations() {
        let manager = TerritoryManager.shared
        XCTAssertGreaterThan(manager.totalAreaSqMi(), 0)
        XCTAssertGreaterThan(manager.totalAreaSqKm(), 0)
        // 1 sq mi is ~2.59 sq km
        XCTAssertGreaterThan(manager.totalAreaSqKm(), manager.totalAreaSqMi())
    }
}
