import SwiftUI

/// Localized copy and VoiceOver formatting helpers for `SourceTile`.
public enum SourceTileCopy {
    nonisolated public static let addSourceString = "Add Source"
    nonisolated public static let addHintString = "Adds a playlist, server or files"
    nonisolated public static let openHintString = "Opens source"
    nonisolated public static let loadingString = "Loading"
    nonisolated public static let errorFormatString = "Error: %@"

    nonisolated public static let allLocalizationKeys: [String] = [
        addSourceString,
        addHintString,
        openHintString,
        loadingString,
        errorFormatString
    ]

    @MainActor public static var addTitleKey: LocalizedStringKey {
        LocalizedStringKey(addSourceString)
    }

    @MainActor public static func accessibilityHintKey(style: SourceTile.Style) -> LocalizedStringKey {
        LocalizedStringKey(style == .add ? addHintString : openHintString)
    }

    nonisolated public static func accessibilityValue(
        status: SourceTile.Status,
        subtitle: String?,
        badge: String?,
        bundle: Bundle = .main
    ) -> String {
        switch status {
        case .loading:
            let loadingText = bundle.localizedString(forKey: loadingString, value: loadingString, table: nil)
            return [subtitle, loadingText].compactMap { $0 }.joined(separator: ", ")
        case .error(let message):
            let format = bundle.localizedString(forKey: errorFormatString, value: errorFormatString, table: nil)
            return String(format: format, message)
        case .ready:
            return [subtitle, badge].compactMap { $0 }.joined(separator: ", ")
        }
    }
}

/// Big rounded tile representing a media source (M3U playlist, media server,
/// local files, web) on Home and in Library. Also used for "Add source".
public struct SourceTile: View {
    public enum Status: Equatable {
        case ready
        case loading
        case error(String)
    }

    public enum Style { case standard, add }

    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let tint: Color
    private let status: Status
    private let badge: String?
    private let style: Style
    private let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color = .dcAccent,
        status: Status = .ready,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint,
                  status: status, badge: badge, style: .standard, action: action)
    }

    private init(
        title: String,
        subtitle: String?,
        systemImage: String,
        tint: Color,
        status: Status,
        badge: String?,
        style: Style,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.status = status
        self.badge = badge
        self.style = style
        self.action = action
    }

    /// Dashed "add a source" tile.
    public static func add(title: String = SourceTileCopy.addSourceString, action: @escaping () -> Void) -> SourceTile {
        SourceTile(title: title, subtitle: nil, systemImage: "plus", tint: .dcAccent,
                   status: .ready, badge: nil, style: .add, action: action)
    }

    @ScaledMetric(relativeTo: .title3) private var iconBox: CGFloat = 44

    public var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(SourceTilePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitleText)
        .accessibilityValue(Text(verbatim: accessibilityValue))
        .accessibilityHint(Text(SourceTileCopy.accessibilityHintKey(style: style)))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityTitleText: Text {
        if style == .add && title == SourceTileCopy.addSourceString {
            return Text(SourceTileCopy.addTitleKey)
        }
        return Text(title)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .add:
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                    .frame(width: iconBox, height: iconBox)
                    .background(Color.dcAccentSoft, in: Circle())
                Group {
                    if title == SourceTileCopy.addSourceString {
                        Text(SourceTileCopy.addTitleKey)
                    } else {
                        Text(LocalizedStringKey(title))
                    }
                }
                .font(DSTypography.headline)
                .foregroundStyle(Color.dcTextPrimary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: DSLayout.sourceTileMinWidth)
            .padding(DSSpacing.lg)
            .background(Color.dcSurface.opacity(0.5), in: shape)
            .overlay(shape.strokeBorder(Color.dcStroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))

        case .standard:
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: iconBox, height: iconBox)
                        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    Spacer(minLength: DSSpacing.xs)
                    statusAccessory
                }
                Spacer(minLength: DSSpacing.md)
                Text(LocalizedStringKey(title))
                    .font(DSTypography.title3)
                    .foregroundStyle(Color.dcTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if case .error(let message) = status {
                    Text(LocalizedStringKey(message))
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcWarning)
                        .lineLimit(2)
                } else if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(DSTypography.subheadline)
                        .foregroundStyle(Color.dcTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: DSLayout.sourceTileMinWidth, alignment: .leading)
            .padding(DSSpacing.lg)
            .background {
                ZStack {
                    shape.fill(Color.dcSurface)
                    shape.fill(
                        LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
            }
            .overlay(shape.strokeBorder(Color.dcStroke, lineWidth: DSStroke.regular))
        }
    }

    @ViewBuilder
    private var statusAccessory: some View {
        switch status {
        case .loading:
            ProgressView().tint(Color.dcTextSecondary)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.dcWarning)
        case .ready:
            if let badge {
                Text(badge)
                    .font(DSTypography.badge)
                    .foregroundStyle(Color.dcTextSecondary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(Color.dcSurfaceRaised, in: Capsule())
            }
        }
    }

    private var accessibilityValue: String {
        SourceTileCopy.accessibilityValue(status: status, subtitle: subtitle, badge: badge)
    }
}

private struct SourceTilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(DSMotion.animation(DSMotion.quick, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

#Preview("SourceTile grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: DSLayout.sourceTileMinWidth), spacing: DSSpacing.gridGap)], spacing: DSSpacing.gridGap) {
            SourceTile(title: "Family TV", subtitle: "1,284 channels", systemImage: "list.bullet.rectangle.fill", badge: "M3U") {}
            SourceTile(title: "Home Server", subtitle: "Movies · Shows", systemImage: "server.rack", tint: .dcInfo, status: .loading) {}
            SourceTile(title: "Sports Pack", systemImage: "sportscourt.fill", tint: .dcWarning, status: .error("Couldn't reach server")) {}
            SourceTile(title: "On This iPhone", subtitle: "12 videos", systemImage: "iphone", tint: .dcPro) {}
            SourceTile.add {}
        }
        .padding(DSSpacing.screenGutter)
    }
    .background(Color.dcBackground)
    .preferredColorScheme(.dark)
}

#Preview("SourceTile · Light") {
    HStack(spacing: DSSpacing.gridGap) {
        SourceTile(title: "Family TV", subtitle: "1,284 channels", systemImage: "list.bullet.rectangle.fill") {}
        SourceTile.add {}
    }
    .padding(DSSpacing.screenGutter)
    .background(Color.dcBackground)
    .preferredColorScheme(.light)
}
