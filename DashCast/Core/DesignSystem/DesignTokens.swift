import SwiftUI

// MARK: - DashCast Design System v2 · Layout tokens

/// 4-pt spacing scale.
public enum DSSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    /// Horizontal screen gutter on iPhone.
    public static let screenGutter: CGFloat = 16
    /// Horizontal screen gutter in landscape car mode.
    public static let carGutter: CGFloat = 32
    /// Gap between items in a grid / horizontal shelf.
    public static let gridGap: CGFloat = 12
    /// Vertical gap between home sections.
    public static let sectionGap: CGFloat = 28
}

/// Corner radii. Always use `.continuous` rounded rectangles.
public enum DSRadius {
    public static let xs: CGFloat = 6     // badges, progress tracks
    public static let sm: CGFloat = 10    // channel logos, small thumbnails
    public static let md: CGFloat = 14    // buttons, search field, rows in cards
    public static let lg: CGFloat = 20    // cards, mini player
    public static let xl: CGFloat = 26    // source tiles, hero cards
    public static let sheet: CGFloat = 32 // custom sheets / car mode panels
}

/// Fixed layout metrics. Values that should scale with Dynamic Type are read
/// through `@ScaledMetric` inside components.
public enum DSLayout {
    /// HIG minimum hit target.
    public static let minTapTarget: CGFloat = 44
    /// Car mode / CarPlay-adjacent minimum hit target (glanceable, gloves).
    public static let carTapTarget: CGFloat = 72
    public static let channelLogo: CGFloat = 48
    public static let miniPlayerHeight: CGFloat = 64
    public static let sourceTileMinWidth: CGFloat = 156
    public static let sourceTileAspect: CGFloat = 1.0
    public static let primaryButtonHeight: CGFloat = 52
    public static let carButtonHeight: CGFloat = 72
}

/// Stroke widths.
public enum DSStroke {
    public static let hairline: CGFloat = 0.5
    public static let regular: CGFloat = 1
    public static let focus: CGFloat = 2
}

/// Shadows. Dark UI relies on surface contrast, so shadows are subtle.
public struct DSShadow {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat

    public static let card = DSShadow(color: .black.opacity(0.18), radius: 10, y: 4)
    public static let floating = DSShadow(color: .black.opacity(0.35), radius: 18, y: 8)
}

public extension View {
    func dsShadow(_ shadow: DSShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

/// Motion. Respect Reduce Motion by passing through `DSMotion.animation(_:reduceMotion:)`.
public enum DSMotion {
    public static let quick = Animation.easeOut(duration: 0.15)
    public static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    public static let emphasized = Animation.spring(response: 0.45, dampingFraction: 0.75)

    public static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - Materials

/// Translucent materials for chrome that floats over content.
public enum DSMaterial {
    /// Mini player, floating tab bar, overlays on video.
    case chrome
    /// Sticky headers, search bar backdrop.
    case bar
    /// Heavy panels in car mode over video.
    case panel

    public var material: Material {
        switch self {
        case .chrome: return .ultraThinMaterial
        case .bar: return .regularMaterial
        case .panel: return .thickMaterial
        }
    }
}

public extension View {
    /// Standard card treatment: surface fill, continuous corners, 1pt stroke.
    func dsCard(radius: CGFloat = DSRadius.lg, padding: CGFloat? = DSSpacing.lg) -> some View {
        self
            .padding(padding ?? 0)
            .background(Color.dcSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.dcStroke, lineWidth: DSStroke.regular)
            )
    }

    /// Floating translucent chrome (falls back to solid when Reduce Transparency is on).
    func dsMaterialBackground(_ material: DSMaterial, radius: CGFloat = DSRadius.lg) -> some View {
        modifier(DSMaterialBackground(material: material, radius: radius))
    }
}

private struct DSMaterialBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let material: DSMaterial
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color.dcSurfaceRaised)
                } else {
                    shape.fill(material.material)
                }
            }
            .overlay(shape.strokeBorder(Color.dcStroke.opacity(0.8), lineWidth: DSStroke.hairline))
    }
}
