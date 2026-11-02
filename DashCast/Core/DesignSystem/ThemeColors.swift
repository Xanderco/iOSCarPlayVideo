import SwiftUI

public extension Color {
    // OLED True Black Automotive Theme
    static let dashBackground = Color(red: 0.04, green: 0.05, blue: 0.06)
    static let dashSurface = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let dashSurfaceHighlight = Color(red: 0.15, green: 0.16, blue: 0.20)
    static let dashBorder = Color(red: 0.22, green: 0.24, blue: 0.28)

    // Signature Electric Yellow Brand Accents
    static let dashYellow = Color(red: 1.00, green: 0.90, blue: 0.00) // #FFE600
    static let dashGold = Color(red: 1.00, green: 0.75, blue: 0.00)   // #FFBF00
    static let dashAmber = Color(red: 1.00, green: 0.60, blue: 0.00)  // #FF9900

    // Legacy aliases mapped to Electric Yellow
    static let dashCyan = Color(red: 1.00, green: 0.88, blue: 0.10)
    static let dashBlue = Color(red: 1.00, green: 0.72, blue: 0.00)

    // Functional Status Colors
    static let dashGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
    static let dashRed = Color(red: 1.00, green: 0.25, blue: 0.25)
    static let dashOrange = Color(red: 1.00, green: 0.55, blue: 0.00)

    // Typography hierarchy
    static let dashTextPrimary = Color.white
    static let dashTextSecondary = Color(red: 0.68, green: 0.71, blue: 0.76)
    static let dashTextMuted = Color(red: 0.44, green: 0.47, blue: 0.53)
}

public extension LinearGradient {
    static let dashAccentGradient = LinearGradient(
        colors: [.dashYellow, .dashGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dashProGoldGradient = LinearGradient(
        colors: [.dashYellow, .dashAmber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dashSpeedGradient = LinearGradient(
        colors: [.dashGreen, .dashYellow, .dashRed],
        startPoint: .leading,
        endPoint: .trailing
    )
}
