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
        accentColor: Color = .dcAccent
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
                    Color.dcSurfaceHighlight,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))

            // Neon glowing active arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (progress * 0.70))
                .stroke(
                    LinearGradient(
                        colors: [.dcAccent, .dcSuccess, .dcWarning],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .shadow(color: Color.dcAccent.opacity(0.85), radius: 10, x: 0, y: 0)
                .animation(.easeOut(duration: 0.2), value: value)

            // Digital readout
            VStack(spacing: 2) {
                Text(title)
                    .font(DSTypography.badge)
                    .foregroundStyle(Color.dcTextTertiary)
                    .tracking(1.5)

                Text(String(format: "%.0f", value))
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.dcTextPrimary)

                Text(unit)
                    .font(DSTypography.caption)
                    .foregroundStyle(accentColor)
                    .fontWeight(.bold)
            }
        }
        .frame(width: 170, height: 170)
    }
}
