import SwiftUI

public struct GlowButton: View {
    public let title: String
    public let iconName: String?
    public var gradient: LinearGradient
    public var textColor: Color
    public var height: CGFloat
    public let action: () -> Void

    public init(
        title: String,
        iconName: String? = nil,
        gradient: LinearGradient = .dashAccentGradient,
        textColor: Color = .black,
        height: CGFloat = 52,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.gradient = gradient
        self.textColor = textColor
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.dashYellow.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
