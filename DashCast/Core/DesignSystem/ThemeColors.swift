import SwiftUI

public extension Color {
    // Automotive Deep Dark Theme
    static let dashBackground = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let dashSurface = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let dashSurfaceHighlight = Color(red: 0.15, green: 0.17, blue: 0.22)
    static let dashBorder = Color(red: 0.20, green: 0.23, blue: 0.29)

    // Neon & Accent Colors inspired by sports car dashes
    static let dashCyan = Color(red: 0.00, green: 0.82, blue: 1.00)
    static let dashBlue = Color(red: 0.08, green: 0.52, blue: 1.00)
    static let dashGreen = Color(red: 0.16, green: 0.85, blue: 0.53)
    static let dashOrange = Color(red: 1.00, green: 0.55, blue: 0.00)
    static let dashRed = Color(red: 1.00, green: 0.27, blue: 0.27)
    static let dashGold = Color(red: 1.00, green: 0.78, blue: 0.17)

    // Typography hierarchy
    static let dashTextPrimary = Color.white
    static let dashTextSecondary = Color(red: 0.65, green: 0.68, blue: 0.74)
    static let dashTextMuted = Color(red: 0.42, green: 0.45, blue: 0.52)
}

public extension LinearGradient {
    static let dashAccentGradient = LinearGradient(
        colors: [.dashCyan, .dashBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dashProGoldGradient = LinearGradient(
        colors: [.dashGold, .dashOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dashSpeedGradient = LinearGradient(
        colors: [.dashGreen, .dashOrange, .dashRed],
        startPoint: .leading,
        endPoint: .trailing
    )
}
