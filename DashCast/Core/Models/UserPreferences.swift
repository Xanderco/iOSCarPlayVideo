import Foundation

public struct UserPreferences: Codable {
    public var useMilesPerHour: Bool
    public var isProLifetimeUnlocked: Bool
    public var connectionSoundId: String?
    public var disconnectionSoundId: String?
    public var homeArrivalSoundId: String?

    public init(
        useMilesPerHour: Bool = false,
        isProLifetimeUnlocked: Bool = false,
        connectionSoundId: String? = "jet_startup",
        disconnectionSoundId: String? = "airline_dingy",
        homeArrivalSoundId: String? = "welcome_sir"
    ) {
        self.useMilesPerHour = useMilesPerHour
        self.isProLifetimeUnlocked = isProLifetimeUnlocked
        self.connectionSoundId = connectionSoundId
        self.disconnectionSoundId = disconnectionSoundId
        self.homeArrivalSoundId = homeArrivalSoundId
    }
}
