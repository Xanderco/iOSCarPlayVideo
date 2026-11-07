import SwiftUI

/// Legacy v1 button. Prefer `PrimaryButton` for new UI.

public struct GlowButton: View {
    public let title: LocalizedStringKey
    public let iconName: String?
    public var gradient: LinearGradient
    public var textColor: Color
    public var height: CGFloat
    public let action: () -> Void

    public init(
        title: LocalizedStringKey,
        iconName: String? = nil,
        gradient: LinearGradient = .dcAccentGradient,
        textColor: Color = .dcOnAccent,
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

    public init(
        titleString: String,
        iconName: String? = nil,
        gradient: LinearGradient = .dcAccentGradient,
        textColor: Color = .dcOnAccent,
        height: CGFloat = 52,
        action: @escaping () -> Void
    ) {
        self.init(
            title: LocalizedStringKey(titleString),
            iconName: iconName,
            gradient: gradient,
            textColor: textColor,
            height: height,
            action: action
        )
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
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .shadow(color: Color.dcAccent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
