import Foundation

/// App-wide preferences persisted by `PersistenceController`.
/// Unknown keys from older versions (extra sound slots, vehicle/country fields) are ignored on decode.
public struct UserPreferences: Codable {
    public var useMilesPerHour: Bool
    public var isProLifetimeUnlocked: Bool
    /// Chime played by the "Play Car Chime" Shortcuts action (Settings › Car Extras › Car Chime).
    public var connectionSoundId: String?
    /// Post a local "Trip saved" notification when a Trip Log recording is stopped.
    public var driveNotificationsEnabled: Bool

    public init(
        useMilesPerHour: Bool = false,
        isProLifetimeUnlocked: Bool = false,
        connectionSoundId: String? = SoundCatalogService.defaultSoundId,
        driveNotificationsEnabled: Bool = true
    ) {
        self.useMilesPerHour = useMilesPerHour
        self.isProLifetimeUnlocked = isProLifetimeUnlocked
        self.connectionSoundId = connectionSoundId
        self.driveNotificationsEnabled = driveNotificationsEnabled
    }

    enum CodingKeys: String, CodingKey {
        case useMilesPerHour
        case isProLifetimeUnlocked
        case connectionSoundId
        case driveNotificationsEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        useMilesPerHour = try container.decodeIfPresent(Bool.self, forKey: .useMilesPerHour) ?? false
        isProLifetimeUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isProLifetimeUnlocked) ?? false
        connectionSoundId = try container.decodeIfPresent(String.self, forKey: .connectionSoundId) ?? SoundCatalogService.defaultSoundId
        driveNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .driveNotificationsEnabled) ?? true
    }
}
