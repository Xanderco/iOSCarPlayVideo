import Foundation
import UserNotifications

/// Local notifications for Trip Log. Never scheduled for marketing.
public final class DriveNotificationService {
    public static let shared = DriveNotificationService()

    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// Text for the "trip saved" notification. Kept separate so it can be unit-tested.
    public static func tripSavedBody(for trip: TripModel, useMiles: Bool) -> String {
        let minutes = Int(trip.durationSeconds / 60)
        let distance = TripFormatting.distance(meters: trip.distanceMeters, useMiles: useMiles)
        return "\(distance) · \(minutes) min. Saved to Trip Log on this iPhone."
    }

    public func sendTripSavedNotification(trip: TripModel, useMiles: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = "Trip saved"
        content.body = DriveNotificationService.tripSavedBody(for: trip, useMiles: useMiles)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dashcast.trip.saved", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
