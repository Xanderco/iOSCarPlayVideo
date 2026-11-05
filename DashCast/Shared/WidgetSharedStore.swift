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
        let host = url.host ?? ""
        let target = host.isEmpty ? (url.pathComponents.first { $0 != "/" } ?? "") : host
        return Destination(rawValue: target.lowercased())
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

/// Colour helpers shared by the app and widgets. Widgets may be shown on a car display
/// (CarPlay, iOS 26), so user accent colours must stay readable on the dark widget backdrop.
public enum WidgetColorMath {
    /// sRGB components 0...1 from "#RRGGBB" / "RRGGBB".
    public static func components(hex: String?) -> (r: Double, g: Double, b: Double)? {
        guard var h = hex?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    public static func relativeLuminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func lin(_ x: Double) -> Double { x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// WCAG 2.x contrast ratio (1...21).
    public static func contrastRatio(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Darkest point of the widget backdrop gradient (#0D121C).
    public static let backdropHex = "#0D121C"
    /// Brand accent used when the user's colour is missing, white, or unreadable.
    public static let fallbackAccentHex = "#40D9BF"

    /// Returns the user's accent if it reaches `minimumContrast` against the backdrop, else the brand accent.
    public static func readableAccentHex(_ hex: String?, minimumContrast: Double = 4.5) -> String {
        guard let c = components(hex: hex), let bg = components(hex: backdropHex) else { return fallbackAccentHex }
        // Pure white is the app's default *text* colour, not a deliberate accent choice.
        if c.r == 1, c.g == 1, c.b == 1 { return fallbackAccentHex }
        return contrastRatio(c, bg) >= minimumContrast ? (hex ?? fallbackAccentHex) : fallbackAccentHex
    }
}
