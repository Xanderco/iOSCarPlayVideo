import Foundation
import UserNotifications

public final class DriveNotificationService {
    public static let shared = DriveNotificationService()

    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    public func sendDriveRecordingNotification(distanceKm: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Recording your drive"
        content.body = String(format: "%.1f km so far · DashCast is tracking this trip.", distanceKm)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dashcast.drive.recording", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    public func sendTripSavedNotification(trip: TripModel) {
        let content = UNMutableNotificationContent()
        content.title = "Trip saved"
        let distKm = trip.distanceMeters / 1000.0
        let mins = Int(trip.durationSeconds / 60)
        let topSpeed = trip.maxSpeedKmh
        content.body = String(format: "%.1f km · %d min · top %.0f km/h\n🏁 Score %d/100", distKm, mins, topSpeed, trip.drivingScore)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dashcast.trip.saved", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    public func scheduleFeatureTips() {
        let tips: [(title: String, body: String, delay: TimeInterval)] = [
            ("Every detail, yours", "🔧 Fine-tune your widget — size, colors, layout", 3600),
            ("30 seconds to wow", "⭐ Make your CarPlay screen yours in 30 seconds", 7200),
            ("Show off your car", "📸 That photo of your car deserves a spot on your dashboard", 14400),
            ("Two taps, done", "⚡ Two taps to set your CarPlay startup sound", 21600)
        ]

        for (index, tip) in tips.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = tip.title
            content.body = tip.body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: tip.delay, repeats: false)
            let request = UNNotificationRequest(identifier: "dashcast.tip.\(index)", content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }
}
