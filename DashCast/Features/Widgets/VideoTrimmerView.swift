import SwiftUI

/// Pure bounds-safe math and localization helpers for `VideoTrimmerView`.
public enum VideoTrimmerLogic {
    nonisolated public static let allLocalizationKeys: [String] = [
        "Trim Live Video Loop",
        "%.1fs"
    ]

    @MainActor
    public static var titleKey: LocalizedStringKey {
        LocalizedStringKey("Trim Live Video Loop")
    }

    nonisolated public static func effectiveWindowDuration(
        duration: Double,
        maxTrimDuration: Double
    ) -> Double {
        guard duration.isFinite, duration > 0, maxTrimDuration.isFinite, maxTrimDuration > 0 else {
            return 0
        }
        return min(duration, maxTrimDuration)
    }

    nonisolated public static func draggableDuration(
        duration: Double,
        maxTrimDuration: Double
    ) -> Double {
        guard duration.isFinite, duration > 0, maxTrimDuration.isFinite, maxTrimDuration >= 0 else {
            return 0
        }
        return max(duration - maxTrimDuration, 0)
    }

    nonisolated public static func normalizedOffset(
        trimStartTime: Double,
        duration: Double,
        maxTrimDuration: Double
    ) -> Double {
        let span = draggableDuration(duration: duration, maxTrimDuration: maxTrimDuration)
        guard span > 0, trimStartTime.isFinite else {
            return 0
        }
        return min(max(trimStartTime / span, 0.0), 1.0)
    }

    nonisolated public static func trimStartTime(
        forLocationX locationX: Double,
        containerWidth: Double,
        windowWidth: Double,
        duration: Double,
        maxTrimDuration: Double
    ) -> Double {
        guard locationX.isFinite, containerWidth.isFinite, windowWidth.isFinite else {
            return 0
        }
        let maxOffset = containerWidth - windowWidth
        let span = draggableDuration(duration: duration, maxTrimDuration: maxTrimDuration)
        guard maxOffset > 0, span > 0 else {
            return 0
        }
        let clampedX = min(max(locationX - (windowWidth / 2.0), 0.0), maxOffset)
        let fraction = clampedX / maxOffset
        return fraction * span
    }

    nonisolated public static func durationBadgeText(
        duration: Double,
        maxTrimDuration: Double
    ) -> String {
        let effective = effectiveWindowDuration(duration: duration, maxTrimDuration: maxTrimDuration)
        return String(format: String(localized: "%.1fs"), effective)
    }
}

public struct VideoTrimmerView: View {
    @Binding public var trimStartTime: Double
    public let duration: Double
    public let maxTrimDuration: Double = 3.0

    public init(trimStartTime: Binding<Double>, duration: Double = 10.0) {
        self._trimStartTime = trimStartTime
        self.duration = duration
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(VideoTrimmerLogic.titleKey)
                    .font(ThemeFonts.hudCaption(size: 13))
                    .foregroundStyle(Color.dashTextPrimary)
                    .fontWeight(.semibold)

                Spacer()

                Text(VideoTrimmerLogic.durationBadgeText(duration: duration, maxTrimDuration: maxTrimDuration))
                    .font(ThemeFonts.monospaceDigits(size: 12))
                    .foregroundStyle(Color.dashYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.dashYellow.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Thumbnail strip simulation
            ZStack(alignment: .leading) {
                // Background filmstrip
                HStack(spacing: 3) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.dashSurfaceHighlight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.dashTextMuted)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Active Trim Window Box
                GeometryReader { geo in
                    let windowWidth = max(geo.size.width * 0.35, 0)
                    let maxOffset = max(geo.size.width - windowWidth, 0)
                    let normalizedOffset = VideoTrimmerLogic.normalizedOffset(
                        trimStartTime: trimStartTime,
                        duration: duration,
                        maxTrimDuration: maxTrimDuration
                    )
                    let currentX = normalizedOffset * maxOffset

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.dashYellow, lineWidth: 3)
                        .background(Color.dashYellow.opacity(0.2))
                        .frame(width: windowWidth, height: 54)
                        .offset(x: currentX)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    self.trimStartTime = VideoTrimmerLogic.trimStartTime(
                                        forLocationX: value.location.x,
                                        containerWidth: geo.size.width,
                                        windowWidth: windowWidth,
                                        duration: duration,
                                        maxTrimDuration: maxTrimDuration
                                    )
                                }
                        )
                }
                .frame(height: 54)
            }
        }
        .padding()
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
