import WidgetKit
import SwiftUI
import ActivityKit

@main
struct DashCastCastWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarCastLiveActivityWidget()
    }
}

private let castYellow = Color(red: 1.0, green: 0.902, blue: 0.0)

struct CarCastLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CarCastActivityAttributes.self) { context in
            CarCastLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(castYellow)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(for: context.state))
                        .font(.title2)
                        .foregroundStyle(context.state.isPausedForMotion ? Color.orange : castYellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: icon(for: context.state))
                    .foregroundStyle(context.state.isPausedForMotion ? Color.orange : castYellow)
            } compactTrailing: {
                Text(context.state.mode)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: icon(for: context.state))
                    .foregroundStyle(castYellow)
            }
        }
    }
}

private func icon(for state: CarCastActivityAttributes.ContentState) -> String {
    if state.isPausedForMotion { return "pause.circle.fill" }
    return state.mode == "Mirroring" ? "rectangle.on.rectangle" : "airplayvideo"
}

struct CarCastLockScreenView: View {
    let state: CarCastActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon(for: state))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(state.isPausedForMotion ? Color.orange : castYellow)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("DashCast · \(state.mode)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(castYellow)
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(state.startedAt, style: .timer)
                .font(.system(.subheadline, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 70)
        }
        .padding(16)
    }
}
