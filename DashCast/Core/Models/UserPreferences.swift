import Foundation

public struct UserPreferences: Codable {
    public var useMilesPerHour: Bool
    public var isProLifetimeUnlocked: Bool
    public var connectionSoundId: String?
    public var disconnectionSoundId: String?
    public var homeArrivalSoundId: String?
    public var autoDetectDrives: Bool
    public var minimumDriveMeters: Double
    public var driveNotificationsEnabled: Bool
    public var driveCountry: String
    public var driveVehicleName: String
    public var driveVehicleImage: String

    public init(
        useMilesPerHour: Bool = false,
        isProLifetimeUnlocked: Bool = false,
        connectionSoundId: String? = "jet_startup",
        disconnectionSoundId: String? = "airline_dingy",
        homeArrivalSoundId: String? = "welcome_sir",
        autoDetectDrives: Bool = true,
        minimumDriveMeters: Double = 50.0,
        driveNotificationsEnabled: Bool = true,
        driveCountry: String = "Colombia",
        driveVehicleName: String = "Chevrolet Trax",
        driveVehicleImage: String = "car_chevrolet_corvette"
    ) {
        self.useMilesPerHour = useMilesPerHour
        self.isProLifetimeUnlocked = isProLifetimeUnlocked
        self.connectionSoundId = connectionSoundId
        self.disconnectionSoundId = disconnectionSoundId
        self.homeArrivalSoundId = homeArrivalSoundId
        self.autoDetectDrives = autoDetectDrives
        self.minimumDriveMeters = minimumDriveMeters
        self.driveNotificationsEnabled = driveNotificationsEnabled
        self.driveCountry = driveCountry
        self.driveVehicleName = driveVehicleName
        self.driveVehicleImage = driveVehicleImage
    }

    enum CodingKeys: String, CodingKey {
        case useMilesPerHour
        case isProLifetimeUnlocked
        case connectionSoundId
        case disconnectionSoundId
        case homeArrivalSoundId
        case autoDetectDrives
        case minimumDriveMeters
        case driveNotificationsEnabled
        case driveCountry
        case driveVehicleName
        case driveVehicleImage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        useMilesPerHour = try container.decodeIfPresent(Bool.self, forKey: .useMilesPerHour) ?? false
        isProLifetimeUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isProLifetimeUnlocked) ?? false
        connectionSoundId = try container.decodeIfPresent(String.self, forKey: .connectionSoundId) ?? "jet_startup"
        disconnectionSoundId = try container.decodeIfPresent(String.self, forKey: .disconnectionSoundId) ?? "airline_dingy"
        homeArrivalSoundId = try container.decodeIfPresent(String.self, forKey: .homeArrivalSoundId) ?? "welcome_sir"
        autoDetectDrives = try container.decodeIfPresent(Bool.self, forKey: .autoDetectDrives) ?? true
        minimumDriveMeters = try container.decodeIfPresent(Double.self, forKey: .minimumDriveMeters) ?? 50.0
        driveNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .driveNotificationsEnabled) ?? true
        driveCountry = try container.decodeIfPresent(String.self, forKey: .driveCountry) ?? "Colombia"
        driveVehicleName = try container.decodeIfPresent(String.self, forKey: .driveVehicleName) ?? "Chevrolet Trax"
        driveVehicleImage = try container.decodeIfPresent(String.self, forKey: .driveVehicleImage) ?? "car_chevrolet_corvette"
    }
}
