import Foundation
import UserNotifications

/// Localized copy keys for `DriveNotificationService`.
public enum DriveNotificationCopy {
    nonisolated public static let recordingTitleString = "Recording your drive"
    nonisolated public static let recordingBodyFormatString = "%.1f km so far · DashCast is tracking this trip."
    nonisolated public static let tripSavedTitleString = "Trip saved"
    nonisolated public static let tripSavedMilesBodyFormatString = "%.1f mi · %d min · top %.0f mph\n🏁 Score %d/100"
    nonisolated public static let tripSavedKmBodyFormatString = "%.1f km · %d min · top %.0f km/h\n🏁 Score %d/100"

    nonisolated public static let tip0TitleString = "Every detail, yours"
    nonisolated public static let tip0BodyString = "🔧 Fine-tune your widget — size, colors, layout"
    nonisolated public static let tip1TitleString = "30 seconds to wow"
    nonisolated public static let tip1BodyString = "⭐ Make your CarPlay screen yours in 30 seconds"
    nonisolated public static let tip2TitleString = "Show off your car"
    nonisolated public static let tip2BodyString = "📸 That photo of your car deserves a spot on your dashboard"
    nonisolated public static let tip3TitleString = "Two taps, done"
    nonisolated public static let tip3BodyString = "⚡ Two taps to set your CarPlay startup sound"

    nonisolated public static let allLocalizationKeys: [String] = [
        recordingTitleString,
        recordingBodyFormatString,
        tripSavedTitleString,
        tripSavedMilesBodyFormatString,
        tripSavedKmBodyFormatString,
        tip0TitleString,
        tip0BodyString,
        tip1TitleString,
        tip1BodyString,
        tip2TitleString,
        tip2BodyString,
        tip3TitleString,
        tip3BodyString
    ]
}

/// Value representation for a scheduled drive local notification.
public struct DriveNotificationContentPayload: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let body: String
    public let delay: TimeInterval

    nonisolated public init(identifier: String, title: String, body: String, delay: TimeInterval = 1) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.delay = delay
    }
}

/// Pure localized content builder for `DriveNotificationService`.
public enum DriveNotificationContentBuilder {
    nonisolated public static func recordingContent(distanceKm: Double, bundle: Bundle = .main) -> DriveNotificationContentPayload {
        let safeKm = (distanceKm.isFinite && distanceKm > 0) ? distanceKm : 0
        let title = localizedString(DriveNotificationCopy.recordingTitleString, bundle: bundle)
        let format = localizedString(DriveNotificationCopy.recordingBodyFormatString, bundle: bundle)
        return DriveNotificationContentPayload(
            identifier: "dashcast.drive.recording",
            title: title,
            body: String(format: format, safeKm),
            delay: 1
        )
    }

    nonisolated public static func tripSavedContent(trip: TripModel, useMiles: Bool, bundle: Bundle = .main) -> DriveNotificationContentPayload {
        let title = localizedString(DriveNotificationCopy.tripSavedTitleString, bundle: bundle)
        let mins = (trip.durationSeconds.isFinite && trip.durationSeconds > 0) ? Int(trip.durationSeconds / 60) : 0
        let safeMeters = (trip.distanceMeters.isFinite && trip.distanceMeters > 0) ? trip.distanceMeters : 0
        let safeMaxKmh = (trip.maxSpeedKmh.isFinite && trip.maxSpeedKmh > 0) ? trip.maxSpeedKmh : 0

        let body: String
        if useMiles {
            let miles = safeMeters / 1609.344
            let topMph = safeMaxKmh * 0.621371
            let format = localizedString(DriveNotificationCopy.tripSavedMilesBodyFormatString, bundle: bundle)
            body = String(format: format, miles, mins, topMph, trip.drivingScore)
        } else {
            let distKm = safeMeters / 1000.0
            let format = localizedString(DriveNotificationCopy.tripSavedKmBodyFormatString, bundle: bundle)
            body = String(format: format, distKm, mins, safeMaxKmh, trip.drivingScore)
        }

        return DriveNotificationContentPayload(
            identifier: "dashcast.trip.saved",
            title: title,
            body: body,
            delay: 1
        )
    }

    nonisolated public static func featureTipContents(bundle: Bundle = .main) -> [DriveNotificationContentPayload] {
        let specs: [(titleKey: String, bodyKey: String, delay: TimeInterval)] = [
            (DriveNotificationCopy.tip0TitleString, DriveNotificationCopy.tip0BodyString, 3600),
            (DriveNotificationCopy.tip1TitleString, DriveNotificationCopy.tip1BodyString, 7200),
            (DriveNotificationCopy.tip2TitleString, DriveNotificationCopy.tip2BodyString, 14400),
            (DriveNotificationCopy.tip3TitleString, DriveNotificationCopy.tip3BodyString, 21600)
        ]

        return specs.enumerated().map { index, spec in
            DriveNotificationContentPayload(
                identifier: "dashcast.tip.\(index)",
                title: localizedString(spec.titleKey, bundle: bundle),
                body: localizedString(spec.bodyKey, bundle: bundle),
                delay: spec.delay
            )
        }
    }

    nonisolated private static func localizedString(_ key: String, bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

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
        schedule(DriveNotificationContentBuilder.recordingContent(distanceKm: distanceKm))
    }

    /// Used by AutoTripService; units follow the user's km/mi setting.
    public func sendTripSavedNotification(trip: TripModel, useMiles: Bool) {
        schedule(DriveNotificationContentBuilder.tripSavedContent(trip: trip, useMiles: useMiles))
    }

    public func sendTripSavedNotification(trip: TripModel) {
        sendTripSavedNotification(trip: trip, useMiles: false)
    }

    public func scheduleFeatureTips() {
        for payload in DriveNotificationContentBuilder.featureTipContents() {
            schedule(payload)
        }
    }

    private func schedule(_ payload: DriveNotificationContentPayload) {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: payload.delay, repeats: false)
        let request = UNNotificationRequest(identifier: payload.identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
