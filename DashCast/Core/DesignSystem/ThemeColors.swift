import SwiftUI
import UIKit

// MARK: - DashCast Design System v2 · Color
//
// Semantic, adaptive (light + dark) color tokens. Every token resolves at
// render time through a dynamic `UIColor`, so it follows the system
// appearance, high-contrast mode and CarPlay/external-display traits.
//
// Naming: `dc` prefix + role. Use roles, never raw hex, in feature code.
// See Docs/Design/redesign-spec.md §2 for the palette rationale.

public extension Color {

    // MARK: Hex initializer (unchanged API)

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

    /// Builds an adaptive color from a light and a dark hex value.
    /// Optional high-contrast variants are used when "Increase Contrast" is on.
    init(light: String, dark: String, lightHighContrast: String? = nil, darkHighContrast: String? = nil) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHC = traits.accessibilityContrast == .high
            let hex: String
            switch (isDark, isHC) {
            case (true, true): hex = darkHighContrast ?? dark
            case (true, false): hex = dark
            case (false, true): hex = lightHighContrast ?? light
            case (false, false): hex = light
            }
            return UIColor(Color(hex: hex))
        })
    }

    // MARK: Backgrounds & surfaces

    /// App canvas. Near-black in dark mode (OLED friendly), soft grey in light.
    static let dcBackground = Color(light: "#F2F3F5", dark: "#07090B")
    /// Grouped / secondary canvas (sheets, grouped lists).
    static let dcBackgroundElevated = Color(light: "#FFFFFF", dark: "#0F1215")
    /// Default card / tile / row surface.
    static let dcSurface = Color(light: "#FFFFFF", dark: "#15191D")
    /// Raised surface: pressed rows, nested cards, search field fill.
    static let dcSurfaceRaised = Color(light: "#E9EBEE", dark: "#1E2328")
    /// Hairline separators between rows.
    static let dcSeparator = Color(light: "#D6D9DE", dark: "#262C32", lightHighContrast: "#9AA0A8", darkHighContrast: "#4A525B")
    /// 1pt card outlines.
    static let dcStroke = Color(light: "#DDE0E4", dark: "#232A30", lightHighContrast: "#8E959E", darkHighContrast: "#56606A")

    // MARK: Text

    static let dcTextPrimary = Color(light: "#0B0E11", dark: "#F4F6F8")
    static let dcTextSecondary = Color(light: "#545B64", dark: "#A3ABB4", lightHighContrast: "#353B42", darkHighContrast: "#C9CFD6")
    static let dcTextTertiary = Color(light: "#7D848D", dark: "#6E7781", lightHighContrast: "#545B64", darkHighContrast: "#A3ABB4")

    // MARK: Brand accent — "DashCast Signal Green"

    /// Primary brand accent: selection, primary buttons, now-playing, progress.
    /// Dark variant is a vivid signal green; light variant is deepened to keep
    /// ≥ 4.5:1 contrast as text on white.
    static let dcAccent = Color(light: "#0E9F4E", dark: "#2BE47F", lightHighContrast: "#0A7A3B", darkHighContrast: "#5CF0A0")
    /// Pressed / highlighted state of the accent.
    static let dcAccentPressed = Color(light: "#0A8240", dark: "#1FC46A")
    /// Low-emphasis accent fill (selected chip, active tab pill, tile glow).
    static let dcAccentSoft = Color(light: "#DDF5E7", dark: "#0E2B1C")
    /// Foreground on top of `dcAccent` fills.
    static let dcOnAccent = Color(light: "#FFFFFF", dark: "#04130A")

    // MARK: Status

    /// LIVE badges, recording, destructive.
    static let dcLive = Color(light: "#E5252A", dark: "#FF4D4F")
    static let dcDanger = Color(light: "#D92D20", dark: "#FF5A4F")
    static let dcWarning = Color(light: "#B86E00", dark: "#FFB020")
    static let dcSuccess = Color(light: "#0E9F4E", dark: "#34D27B")
    static let dcInfo = Color(light: "#1F6FEB", dark: "#4C9BFF")
    /// DashCast Pro (lifetime) highlights.
    static let dcPro = Color(light: "#B7791F", dark: "#F5C451")

    // MARK: Overlays

    /// Scrim over video/artwork behind text.
    static let dcScrim = Color.black.opacity(0.55)
    /// Fixed-dark surface for video chrome, car mode and CarPlay (ignores appearance).
    static let dcVideoChrome = Color(hex: "#000000")
}

public extension LinearGradient {
    /// Primary accent gradient (buttons with emphasis, hero tiles).
    static let dcAccentGradient = LinearGradient(
        colors: [Color(light: "#18B860", dark: "#45F08F"), Color.dcAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Pro / lifetime upgrade gradient.
    static let dcProGradient = LinearGradient(
        colors: [Color(light: "#D69E2E", dark: "#FFD873"), Color.dcPro],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Bottom-up scrim for text on artwork/video thumbnails.
    static let dcArtworkScrim = LinearGradient(
        colors: [Color.black.opacity(0), Color.black.opacity(0.75)],
        startPoint: .center,
        endPoint: .bottom
    )

    /// Status ramp (good → bad), e.g. speed or signal quality.
    static let dcStatusRamp = LinearGradient(
        colors: [.dcSuccess, .dcWarning, .dcDanger],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Deprecated v1 aliases
//
// Kept so phase-1 screens compile unchanged. They now resolve to v2 roles,
// so the whole app picks up the new palette immediately. Remove once every
// screen is migrated (redesign phase 2).

public extension Color {
    @available(*, deprecated, renamed: "dcBackground")
    static var dashBackground: Color { .dcBackground }
    @available(*, deprecated, renamed: "dcSurface")
    static var dashSurface: Color { .dcSurface }
    @available(*, deprecated, renamed: "dcSurfaceRaised")
    static var dashSurfaceHighlight: Color { .dcSurfaceRaised }
    @available(*, deprecated, renamed: "dcStroke")
    static var dashBorder: Color { .dcStroke }

    @available(*, deprecated, renamed: "dcAccent")
    static var dashYellow: Color { .dcAccent }
    @available(*, deprecated, renamed: "dcPro")
    static var dashGold: Color { .dcPro }
    @available(*, deprecated, renamed: "dcWarning")
    static var dashAmber: Color { .dcWarning }
    @available(*, deprecated, renamed: "dcAccent")
    static var dashCyan: Color { .dcAccent }
    @available(*, deprecated, renamed: "dcAccent")
    static var dashBlue: Color { .dcAccent }

    @available(*, deprecated, renamed: "dcSuccess")
    static var dashGreen: Color { .dcSuccess }
    @available(*, deprecated, renamed: "dcDanger")
    static var dashRed: Color { .dcDanger }
    @available(*, deprecated, renamed: "dcWarning")
    static var dashOrange: Color { .dcWarning }

    @available(*, deprecated, renamed: "dcTextPrimary")
    static var dashTextPrimary: Color { .dcTextPrimary }
    @available(*, deprecated, renamed: "dcTextSecondary")
    static var dashTextSecondary: Color { .dcTextSecondary }
    @available(*, deprecated, renamed: "dcTextTertiary")
    static var dashTextMuted: Color { .dcTextTertiary }
}

public extension LinearGradient {
    @available(*, deprecated, renamed: "dcAccentGradient")
    static var dashAccentGradient: LinearGradient { .dcAccentGradient }
    @available(*, deprecated, renamed: "dcProGradient")
    static var dashProGoldGradient: LinearGradient { .dcProGradient }
    @available(*, deprecated, renamed: "dcStatusRamp")
    static var dashSpeedGradient: LinearGradient { .dcStatusRamp }
}
