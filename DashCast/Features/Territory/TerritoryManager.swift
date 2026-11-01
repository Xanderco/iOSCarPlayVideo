import Foundation
import CoreLocation
import Combine

public enum DriverRank: String, CaseIterable {
    case rookie = "Rookie Driver"
    case cruiser = "Street Cruiser"
    case captain = "Road Captain"
    case king = "Road King"
    case legend = "Highway Legend"

    public var threshold: Int {
        switch self {
        case .rookie: return 0
        case .cruiser: return 50
        case .captain: return 250
        case .king: return 700
        case .legend: return 1500
        }
    }

    public var nextRank: DriverRank? {
        switch self {
        case .rookie: return .cruiser
        case .cruiser: return .captain
        case .captain: return .king
        case .king: return .legend
        case .legend: return nil
        }
    }
}

@MainActor
public final class TerritoryManager: ObservableObject {
    public static let shared = TerritoryManager()

    @Published public private(set) var claimedHexIDs: Set<String> = []
    @Published public private(set) var weeklyHexCount: Int = 126
    @Published public private(set) var totalDrivesCount: Int = 8

    public init() {
        self.claimedHexIDs = PersistenceController.shared.loadClaimedHexes()
        if claimedHexIDs.isEmpty {
            seedInitialDemoTerritory()
        }
    }

    public var totalHexesCount: Int {
        claimedHexIDs.count
    }

    public var currentRank: DriverRank {
        let count = totalHexesCount
        if count >= DriverRank.legend.threshold { return .legend }
        if count >= DriverRank.king.threshold { return .king }
        if count >= DriverRank.captain.threshold { return .captain }
        if count >= DriverRank.cruiser.threshold { return .cruiser }
        return .rookie
    }

    public var progressToNextRank: Double {
        guard let next = currentRank.nextRank else { return 1.0 }
        let currentThreshold = currentRank.threshold
        let nextThreshold = next.threshold
        let earned = totalHexesCount - currentThreshold
        let needed = nextThreshold - currentThreshold
        return max(0.0, min(Double(earned) / Double(needed), 1.0))
    }

    public func totalAreaSqMi() -> Double {
        Double(totalHexesCount) * HexGridEngine.areaPerHexSqMi
    }

    public func totalAreaSqKm() -> Double {
        Double(totalHexesCount) * HexGridEngine.areaPerHexSqKm
    }

    public func claimCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let cell = HexGridEngine.hexCell(for: coordinate)
        if !claimedHexIDs.contains(cell.id) {
            claimedHexIDs.insert(cell.id)
            weeklyHexCount += 1
            PersistenceController.shared.saveClaimedHexes(claimedHexIDs)
            UsageMetricsManager.shared.recordHexClaimed()
            return true
        }
        return false
    }

    public func claimPoints(from tripPoints: [TripPoint]) {
        var added = 0
        for pt in tripPoints {
            let cell = HexGridEngine.hexCell(for: CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            if !claimedHexIDs.contains(cell.id) {
                claimedHexIDs.insert(cell.id)
                added += 1
            }
        }
        if added > 0 {
            weeklyHexCount += added
            totalDrivesCount += 1
            PersistenceController.shared.saveClaimedHexes(claimedHexIDs)
        }
    }

    private func seedInitialDemoTerritory() {
        // Seed Manhattan route corridor (matching CarDash screenshot #6)
        // From Financial District up through Midtown to Central Park (~40.71 to 40.78, -74.00 to -73.96)
        var seeded = Set<String>()
        let startLat = 40.7128
        let startLon = -74.0060

        for i in 0..<35 {
            let lat = startLat + (Double(i) * 0.0025)
            let lon = startLon + (Double(i) * 0.0015) + (sin(Double(i) * 0.4) * 0.004)
            let cell = HexGridEngine.hexCell(for: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            seeded.insert(cell.id)

            // Adjacent companion hexes to create a rich highway corridor
            seeded.insert(HexCell(q: cell.q + 1, r: cell.r).id)
            seeded.insert(HexCell(q: cell.q - 1, r: cell.r).id)
            seeded.insert(HexCell(q: cell.q, r: cell.r + 1).id)
            seeded.insert(HexCell(q: cell.q, r: cell.r - 1).id)
        }

        self.claimedHexIDs = seeded
        PersistenceController.shared.saveClaimedHexes(seeded)
    }
}
