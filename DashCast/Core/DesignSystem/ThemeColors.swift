import SwiftUI

public extension Color {
    // Hex Initializer
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // OLED True Deep Black Automotive Surfaces
    static let dashBackground = Color(hex: "#0C0D10")
    static let dashSurface = Color(hex: "#171920")
    static let dashSurfaceHighlight = Color(hex: "#222530")
    static let dashBorder = Color(hex: "#2D3240")

    // Signature Electric Racing Yellow & Gold Accents
    static let dashYellow = Color(hex: "#FFE600") // Electric Yellow
    static let dashGold = Color(hex: "#FFB800")   // Racing Gold
    static let dashAmber = Color(hex: "#FF9900")  // Deep Amber

    // Compatibility aliases mapped to Yellow Theme
    static let dashCyan = Color(hex: "#FFE600")
    static let dashBlue = Color(hex: "#FFB800")

    // Functional Status Colors
    static let dashGreen = Color(hex: "#34C759")
    static let dashRed = Color(hex: "#FF3B30")
    static let dashOrange = Color(hex: "#FF9500")

    // Typography hierarchy
    static let dashTextPrimary = Color.white
    static let dashTextSecondary = Color(hex: "#A0A5B2")
    static let dashTextMuted = Color(hex: "#636876")
}

public extension LinearGradient {
    static let dashAccentGradient = LinearGradient(
        colors: [Color(hex: "#FFDE00"), Color(hex: "#FF9900")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let dashProGoldGradient = LinearGradient(
        colors: [Color(hex: "#FFE600"), Color(hex: "#FFB800")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dashSpeedGradient = LinearGradient(
        colors: [.dashGreen, .dashYellow, .dashOrange, .dashRed],
        startPoint: .leading,
        endPoint: .trailing
    )
}
