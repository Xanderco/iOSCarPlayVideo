import SwiftUI

public struct NeonGaugeView: View {
    public var value: Double // e.g. speed
    public var maxValue: Double // e.g. 240
    public var title: String
    public var unit: String
    public var accentColor: Color

    public init(
        value: Double,
        maxValue: Double = 220,
        title: String = "SPEED",
        unit: String = "KM/H",
        accentColor: Color = .dashCyan
    ) {
        self.value = value
        self.maxValue = maxValue
        self.title = title
        self.unit = unit
        self.accentColor = accentColor
    }

    private var progress: Double {
        min(max(value / maxValue, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            // Background arc track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.dashSurfaceHighlight,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))

            // Neon glowing active arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (progress * 0.70))
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .shadow(color: accentColor.opacity(0.8), radius: 8, x: 0, y: 0)
                .animation(.easeOut(duration: 0.2), value: value)

            // Digital readout
            VStack(spacing: 2) {
                Text(title)
                    .font(ThemeFonts.hudCaption(size: 11))
                    .foregroundStyle(Color.dashTextMuted)
                    .tracking(1.5)

                Text(String(format: "%.0f", value))
                    .font(ThemeFonts.speedDisplay(size: 56))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(unit)
                    .font(ThemeFonts.hudCaption(size: 12))
                    .foregroundStyle(accentColor)
                    .fontWeight(.bold)
            }
        }
        .frame(width: 170, height: 170)
    }
}
