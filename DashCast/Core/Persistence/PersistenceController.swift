import Foundation

public final class PersistenceController {
    public static let shared = PersistenceController()

    private let tripsKey = "dashcast_saved_trips"
    private let playlistsKey = "dashcast_saved_playlists"
    private let widgetsKey = "dashcast_saved_widgets"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // Trips Persistence
    public func saveTrips(_ trips: [TripModel]) {
        if let data = try? JSONEncoder().encode(trips) {
            userDefaults.set(data, forKey: tripsKey)
        }
        WidgetSharedPublisher.publishTrips(trips)
    }

    public func loadTrips() -> [TripModel] {
        guard let data = userDefaults.data(forKey: tripsKey),
              let trips = try? JSONDecoder().decode([TripModel].self, from: data) else {
            return []
        }
        return trips
    }

    // Playlists Persistence
    public func savePlaylists(_ playlists: [IPTVPlaylist]) {
        if let data = try? JSONEncoder().encode(playlists) {
            userDefaults.set(data, forKey: playlistsKey)
        }
    }

    public func loadPlaylists() -> [IPTVPlaylist] {
        guard let data = userDefaults.data(forKey: playlistsKey),
              let playlists = try? JSONDecoder().decode([IPTVPlaylist].self, from: data) else {
            return []
        }
        return playlists
    }

    // Widgets Persistence
    public func saveWidgets(_ widgets: [WidgetConfigModel]) {
        if let data = try? JSONEncoder().encode(widgets) {
            userDefaults.set(data, forKey: widgetsKey)
        }
        WidgetSharedPublisher.publishWidgets(widgets)
    }

    public func loadWidgets() -> [WidgetConfigModel] {
        guard let data = userDefaults.data(forKey: widgetsKey),
              let widgets = try? JSONDecoder().decode([WidgetConfigModel].self, from: data) else {
            return []
        }
        return widgets
    }

    private let userPreferencesKey = "dashcast_user_preferences"

    // User Preferences Persistence
    public func saveUserPreferences(_ preferences: UserPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: userPreferencesKey)
        }
    }

    public func loadUserPreferences() -> UserPreferences {
        guard let data = userDefaults.data(forKey: userPreferencesKey),
              let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return decoded
    }
}
