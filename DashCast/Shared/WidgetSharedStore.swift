import Foundation

/// Data shared between the DashCast app and the DashCastWidgets extension through the
/// app group `group.com.xanderco.dashcast`. Compiled into both targets; keep it Foundation-only.
public struct SharedCarSnapshot: Codable, Equatable {
    public var name: String
    public var brand: String
    public var model: String
    public var plate: String?
    /// Small JPEG thumbnail of the user's own car photo (already downscaled by the app).
    public var photoData: Data?
    public var accentHex: String?

    public init(name: String, brand: String, model: String, plate: String? = nil,
                photoData: Data? = nil, accentHex: String? = nil) {
        self.name = name
        self.brand = brand
        self.model = model
        self.plate = plate
        self.photoData = photoData
        self.accentHex = accentHex
    }

    public static let placeholder = SharedCarSnapshot(
        name: "My Car", brand: "DashCast", model: "Set up in app", plate: "DASH-01")
}

public struct SharedTripSnapshot: Codable, Equatable {
    public var distanceMeters: Double
    public var score: Int
    public var date: Date
    public var durationSeconds: Double

    public init(distanceMeters: Double, score: Int, date: Date, durationSeconds: Double) {
        self.distanceMeters = distanceMeters
        self.score = score
        self.date = date
        self.durationSeconds = durationSeconds
    }

    public var distanceKm: Double { distanceMeters / 1000 }
    public var distanceMiles: Double { distanceMeters / 1609.344 }

    public static let placeholder = SharedTripSnapshot(
        distanceMeters: 12_400, score: 92, date: Date(timeIntervalSince1970: 1_793_000_000), durationSeconds: 1_380)
}

public struct WidgetSharedPayload: Codable, Equatable {
    public static let currentVersion = 1
    public var version: Int
    public var car: SharedCarSnapshot?
    public var lastTrip: SharedTripSnapshot?
    public var usesMiles: Bool
    public var updatedAt: Date

    public init(car: SharedCarSnapshot? = nil, lastTrip: SharedTripSnapshot? = nil,
                usesMiles: Bool = false, updatedAt: Date = Date()) {
        self.version = Self.currentVersion
        self.car = car
        self.lastTrip = lastTrip
        self.usesMiles = usesMiles
        self.updatedAt = updatedAt
    }
}

public enum DashCastLinks {
    public static let scheme = "dashcast"
    public static let cast = URL(string: "dashcast://cast")!
    public static let drive = URL(string: "dashcast://drive")!

    /// Destinations a widget may deep-link to. Deliberately not tied to tab layout,
    /// so navigation redesigns only need to update `AppState.handleDeepLink`.
    public enum Destination: String, CaseIterable {
        case cast, drive
    }

    public static func destination(for url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let target = (url.host ?? url.pathComponents.dropFirst().first ?? "").lowercased()
        return Destination(rawValue: target)
    }
}

public final class WidgetSharedStore {
    public static let appGroupID = "group.com.xanderco.dashcast"
    public static let payloadKey = "dashcast_widget_payload_v1"
    public static let shared = WidgetSharedStore()

    private let defaults: UserDefaults

    /// Falls back to `.standard` when the app group is unavailable (unsigned CI/simulator builds).
    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    public static func encode(_ payload: WidgetSharedPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(payload)
    }

    public static func decode(_ data: Data) throws -> WidgetSharedPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetSharedPayload.self, from: data)
    }

    public func load() -> WidgetSharedPayload {
        guard let data = defaults.data(forKey: Self.payloadKey),
              let payload = try? Self.decode(data) else {
            return WidgetSharedPayload()
        }
        return payload
    }

    @discardableResult
    public func save(_ payload: WidgetSharedPayload) -> Bool {
        guard let data = try? Self.encode(payload) else { return false }
        defaults.set(data, forKey: Self.payloadKey)
        return true
    }

    public func update(_ change: (inout WidgetSharedPayload) -> Void) {
        var payload = load()
        change(&payload)
        payload.updatedAt = Date()
        save(payload)
    }
}
