import SwiftUI

/// Renders a sleek, neon automotive waveform preview matching DashCast's high-contrast theme.
public struct AudioWaveformView: View {
    public let samples: [Float]
    public let isPlaying: Bool
    public let tintColor: Color
    public let barSpacing: CGFloat
    public let barCornerRadius: CGFloat

    public init(
        samples: [Float],
        isPlaying: Bool = false,
        tintColor: Color = .dashYellow,
        barSpacing: CGFloat = 2.0,
        barCornerRadius: CGFloat = 2.0
    ) {
        self.samples = samples.isEmpty ? AudioWaveformService.syntheticWaveform(frequencyHz: 440, category: .engine, sampleCount: 24) : samples
        self.isPlaying = isPlaying
        self.tintColor = tintColor
        self.barSpacing = barSpacing
        self.barCornerRadius = barCornerRadius
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalBars = max(1, samples.count)
            let totalSpacing = barSpacing * CGFloat(totalBars - 1)
            let availableWidth = max(0, geometry.size.width - totalSpacing)
            let barWidth = max(1.5, availableWidth / CGFloat(totalBars))
            let maxHeight = geometry.size.height

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<totalBars, id: \.self) { index in
                    let sample = samples[index]
                    let targetHeight = max(4.0, maxHeight * CGFloat(sample))

                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .fill(
                            isPlaying
                            ? LinearGradient(
                                colors: [tintColor, tintColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                            : LinearGradient(
                                colors: [tintColor.opacity(0.85), tintColor.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                        )
                        .frame(width: barWidth, height: targetHeight)
                        .shadow(
                            color: isPlaying ? tintColor.opacity(0.6) : Color.clear,
                            radius: isPlaying ? 3 : 0
                        )
                        .animation(
                            isPlaying
                            ? Animation.easeInOut(duration: 0.35)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.02)
                            : .default,
                            value: isPlaying
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }
}
