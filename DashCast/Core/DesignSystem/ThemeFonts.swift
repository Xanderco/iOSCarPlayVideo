import SwiftUI

// MARK: - DashCast Design System v2 · Typography
//
// All text styles are built on Apple text styles so they scale with
// Dynamic Type. Display/heading styles use the rounded design for a warm,
// automotive feel; body copy stays on the default (SF Pro) design for
// legibility. Numbers that update live use monospaced digits.

public enum DSTypography {
    /// 34pt bold rounded — screen titles in custom headers, car mode clock.
    public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// 28pt bold rounded — hero tiles, paywall title.
    public static let title = Font.system(.title, design: .rounded, weight: .bold)
    /// 22pt semibold rounded — section headers.
    public static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    /// 20pt semibold rounded — tile titles, sheet titles.
    public static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
    /// 17pt semibold — row titles, button labels.
    public static let headline = Font.system(.headline, design: .default, weight: .semibold)
    /// 17pt regular — body copy.
    public static let body = Font.system(.body)
    /// 16pt regular — secondary row lines, descriptions.
    public static let callout = Font.system(.callout)
    /// 15pt regular — metadata.
    public static let subheadline = Font.system(.subheadline)
    /// 13pt — footnotes, helper text.
    public static let footnote = Font.system(.footnote)
    /// 12pt medium — badges, timestamps.
    public static let caption = Font.system(.caption, weight: .medium)
    /// 11pt bold, use with `.textCase(.uppercase)` + tracking — LIVE / PRO badges.
    public static let badge = Font.system(.caption2, design: .rounded, weight: .bold)
    /// Live-updating numbers (time codes, counts, speed).
    public static let numeric = Font.system(.body, design: .rounded, weight: .semibold).monospacedDigit()

    // MARK: Car mode (landscape, glanceable)
    //
    // Car mode uses the same roles one or two steps larger, and additionally
    // clamps Dynamic Type to at least `.xLarge` via `.dsCarModeTypography()`.

    public static let carTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    public static let carHeadline = Font.system(.title2, design: .rounded, weight: .bold)
    public static let carBody = Font.system(.title3, design: .rounded, weight: .medium)
}

public extension View {
    /// Enlarges and clamps Dynamic Type for landscape car mode so type is never
    /// smaller than `.xLarge`, while still honoring accessibility sizes.
    func dsCarModeTypography() -> some View {
        dynamicTypeSize(.xLarge ... .accessibility3)
    }
}

// MARK: - Deprecated v1 API

@available(*, deprecated, message: "Use DSTypography text styles (Dynamic Type aware).")
public struct ThemeFonts {
    public static func speedDisplay(size: CGFloat = 64) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    public static func hudTitle(size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    public static func hudStat(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    public static func hudCaption(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    public static func monospaceDigits(size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}
