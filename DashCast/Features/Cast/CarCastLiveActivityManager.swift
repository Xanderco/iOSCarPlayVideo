import Foundation
import ActivityKit

/// Shows a Lock Screen / Dynamic Island Live Activity while DashCast is
/// sending video to a car display (AirPlay, external display or mirroring).
@MainActor
final class CarCastLiveActivityManager {
    static let shared = CarCastLiveActivityManager()

    private var activity: Activity<CarCastActivityAttributes>?
    private var lastState: CarCastActivityAttributes.ContentState?

    func startOrUpdate(_ state: CarCastActivityAttributes.ContentState) {
        guard state != lastState else { return }
        lastState = state

        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity.request(
                attributes: CarCastActivityAttributes(sessionName: "DashCast"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func end() {
        lastState = nil
        guard let current = activity else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
