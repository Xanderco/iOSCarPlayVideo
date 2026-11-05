import SwiftUI

/// Legacy v1 card. Prefer `.dsCard()` for new UI.

public struct AutomotiveCard<Content: View>: View {
    public let content: Content
    public var cornerRadius: CGFloat
    public var borderColor: Color

    public init(
        cornerRadius: CGFloat = DSRadius.lg,
        borderColor: Color = .dcStroke,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}
