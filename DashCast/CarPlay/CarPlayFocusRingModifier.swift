import SwiftUI

/// High-contrast electric yellow focus ring modifier designed for physical rotary dial
/// navigation on CarPlay screens and automotive in-car displays.
public struct CarPlayFocusRingModifier: ViewModifier {
    public let isFocused: Bool
    public let cornerRadius: CGFloat
    public let lineWidth: CGFloat

    public init(
        isFocused: Bool,
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 3.5
    ) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isFocused ? Color.dcAccent : Color.clear,
                        lineWidth: isFocused ? lineWidth : 0
                    )
                    .shadow(
                        color: isFocused ? Color.dcAccent.opacity(0.55) : Color.clear,
                        radius: isFocused ? 8 : 0
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: isFocused)
    }
}

public extension View {
    /// Applies an automotive electric-yellow focus ring when this element is active in rotary navigation.
    func carPlayFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 3.5
    ) -> some View {
        modifier(CarPlayFocusRingModifier(
            isFocused: isFocused,
            cornerRadius: cornerRadius,
            lineWidth: lineWidth
        ))
    }
}
