import SwiftUI
import WidgetKit
import ActivityKit

public struct DashCastLiveActivityWidget: Widget {
    public let kind: String = "DashCastLiveActivityWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: DashCastTelemetryAttributes.self) { context in
            // Lock Screen / Notification Banner Presentation
            DashCastLockScreenLiveActivityView(
                state: context.state,
                attributes: context.attributes
            )
            .activityBackgroundTint(Color.dashBackground)
            .activitySystemActionForegroundColor(Color.dashYellow)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Presentation
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandExpandedLeadingView(
                        state: context.state,
                        attributes: context.attributes
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandExpandedTrailingView(
                        state: context.state
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandExpandedCenterView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandExpandedBottomView(
                        state: context.state,
                        attributes: context.attributes
                    )
                }
            } compactLeading: {
                DynamicIslandCompactLeadingView(state: context.state)
            } compactTrailing: {
                DynamicIslandCompactTrailingView(state: context.state)
            } minimal: {
                DynamicIslandMinimalView(state: context.state)
            }
            .keylineTint(Color.dashYellow)
        }
    }
}
