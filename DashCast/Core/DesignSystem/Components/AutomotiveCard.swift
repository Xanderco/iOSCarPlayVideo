import SwiftUI

public struct AutomotiveCard<Content: View>: View {
    public let content: Content
    public var cornerRadius: CGFloat
    public var borderColor: Color

    public init(
        cornerRadius: CGFloat = 16,
        borderColor: Color = .dashBorder.opacity(0.6),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}
