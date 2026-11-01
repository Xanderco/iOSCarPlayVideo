import SwiftUI

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
