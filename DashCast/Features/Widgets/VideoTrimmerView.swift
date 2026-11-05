import SwiftUI

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
                Text("Trim Live Video Loop")
                    .font(ThemeFonts.hudCaption(size: 13))
                    .foregroundStyle(Color.dashTextPrimary)
                    .fontWeight(.semibold)

                Spacer()

                Text("3.0s")
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

                // Active 3.0s Trim Window Box
                GeometryReader { geo in
                    let windowWidth = geo.size.width * 0.35
                    let maxOffset = geo.size.width - windowWidth
                    let normalizedOffset = min(max(trimStartTime / max(duration - maxTrimDuration, 1.0), 0.0), 1.0)
                    let currentX = normalizedOffset * maxOffset

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.dashYellow, lineWidth: 3)
                        .background(Color.dashYellow.opacity(0.2))
                        .frame(width: windowWidth, height: 54)
                        .offset(x: currentX)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newX = min(max(value.location.x - (windowWidth / 2), 0), maxOffset)
                                    let fraction = newX / maxOffset
                                    self.trimStartTime = fraction * (duration - maxTrimDuration)
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
