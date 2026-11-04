import SwiftUI
import ActivityKit

public struct DynamicIslandCompactLeadingView: View {
    public let state: DashCastTelemetryAttributes.ContentState

    public init(state: DashCastTelemetryAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.car.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.dashYellow)

            Text(state.speedFormatted)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)
        }
        .padding(.leading, 4)
    }
}

public struct DynamicIslandCompactTrailingView: View {
    public let state: DashCastTelemetryAttributes.ContentState

    public init(state: DashCastTelemetryAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text("\(state.smoothnessScore)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(state.scoreColor)

            Text("🏁")
                .font(.system(size: 10))
        }
        .padding(.trailing, 4)
    }
}

public struct DynamicIslandMinimalView: View {
    public let state: DashCastTelemetryAttributes.ContentState

    public init(state: DashCastTelemetryAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.dashYellow.opacity(0.3), lineWidth: 2)
                .frame(width: 22, height: 22)

            Text(state.speedFormatted)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)
        }
    }
}

public struct DynamicIslandExpandedLeadingView: View {
    public let state: DashCastTelemetryAttributes.ContentState
    public let attributes: DashCastTelemetryAttributes

    public init(state: DashCastTelemetryAttributes.ContentState, attributes: DashCastTelemetryAttributes) {
        self.state = state
        self.attributes = attributes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.speedFormatted)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)

            Text(attributes.speedUnit)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)
        }
        .padding(.leading, 8)
    }
}

public struct DynamicIslandExpandedTrailingView: View {
    public let state: DashCastTelemetryAttributes.ContentState

    public init(state: DashCastTelemetryAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 3) {
                Text(state.gForceFormatted)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.dashTextPrimary)

                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dashYellow)
            }

            HStack(spacing: 3) {
                Text("Score \(state.smoothnessScore)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(state.scoreColor)

                Text("🏁")
                    .font(.system(size: 10))
            }
        }
        .padding(.trailing, 8)
    }
}

public struct DynamicIslandExpandedCenterView: View {
    public let attributes: DashCastTelemetryAttributes
    public let state: DashCastTelemetryAttributes.ContentState

    public init(attributes: DashCastTelemetryAttributes, state: DashCastTelemetryAttributes.ContentState) {
        self.attributes = attributes
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.isPaused ? Color.dashOrange : Color.dashYellow)
                .frame(width: 6, height: 6)

            Text(attributes.vehicleName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.dashTextMuted)
        }
    }
}

public struct DynamicIslandExpandedBottomView: View {
    public let state: DashCastTelemetryAttributes.ContentState
    public let attributes: DashCastTelemetryAttributes

    public init(state: DashCastTelemetryAttributes.ContentState, attributes: DashCastTelemetryAttributes) {
        self.state = state
        self.attributes = attributes
    }

    public var body: some View {
        HStack {
            statItem(title: "DIST", value: state.distanceFormatted)
            Spacer()
            statItem(title: "TIME", value: state.elapsedDurationFormatted)
            Spacer()
            statItem(title: "TOP", value: "\(state.topSpeedFormatted) \(attributes.speedUnit)")
            Spacer()
            statItem(title: "PEAK G", value: state.peakGForceFormatted)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dashTextPrimary)
        }
    }
}
