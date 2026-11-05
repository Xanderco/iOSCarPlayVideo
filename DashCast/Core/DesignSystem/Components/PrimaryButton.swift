import SwiftUI

/// The single button component for DashCast v2.
///
/// - `kind`: `.primary` (accent fill), `.secondary` (tinted surface),
///   `.tertiary` (text only), `.destructive`.
/// - `size`: `.compact` (36pt), `.regular` (52pt), `.car` (72pt, car mode).
/// - Shows a spinner and disables itself while `isLoading`.
public struct PrimaryButton: View {
    public enum Kind { case primary, secondary, tertiary, destructive }
    public enum Size { case compact, regular, car }

    private let title: String
    private let systemImage: String?
    private let kind: Kind
    private let size: Size
    private let isLoading: Bool
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        kind: Kind = .primary,
        size: Size = .regular,
        isLoading: Bool = false,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.size = size
        self.isLoading = isLoading
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(DSButtonStyle.foreground(for: kind))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(size == .car ? .large : .medium)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(DSButtonStyle(kind: kind, size: size, fullWidth: fullWidth))
        .disabled(isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isLoading ? Text("Loading") : Text(""))
    }
}

/// Button style backing `PrimaryButton`; can be applied to any `Button`.
public struct DSButtonStyle: ButtonStyle {
    public let kind: PrimaryButton.Kind
    public let size: PrimaryButton.Size
    public let fullWidth: Bool

    public init(kind: PrimaryButton.Kind = .primary, size: PrimaryButton.Size = .regular, fullWidth: Bool = true) {
        self.kind = kind
        self.size = size
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, kind: kind, size: size, fullWidth: fullWidth)
    }

    static func foreground(for kind: PrimaryButton.Kind) -> Color {
        switch kind {
        case .primary: return .dcOnAccent
        case .secondary, .tertiary: return .dcAccent
        case .destructive: return .white
        }
    }
}

private struct DSButtonBody: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration
    let kind: PrimaryButton.Kind
    let size: PrimaryButton.Size
    let fullWidth: Bool

    @ScaledMetric(relativeTo: .headline) private var regularHeight = DSLayout.primaryButtonHeight
    @ScaledMetric(relativeTo: .subheadline) private var compactHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .title2) private var carHeight = DSLayout.carButtonHeight

    private var height: CGFloat {
        switch size {
        case .compact: return compactHeight
        case .regular: return regularHeight
        case .car: return carHeight
        }
    }

    private var font: Font {
        switch size {
        case .compact: return .system(.subheadline, weight: .semibold)
        case .regular: return DSTypography.headline
        case .car: return DSTypography.carHeadline
        }
    }

    private var background: Color {
        let pressed = configuration.isPressed
        switch kind {
        case .primary: return pressed ? .dcAccentPressed : .dcAccent
        case .secondary: return pressed ? .dcAccentSoft.opacity(0.7) : .dcAccentSoft
        case .tertiary: return pressed ? .dcSurfaceRaised : .clear
        case .destructive: return pressed ? .dcDanger.opacity(0.8) : .dcDanger
        }
    }

    var body: some View {
        configuration.label
            .font(font)
            .foregroundStyle(DSButtonStyle.foreground(for: kind))
            .padding(.horizontal, size == .compact ? DSSpacing.md : DSSpacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: max(height, DSLayout.minTapTarget))
            .background(background, in: RoundedRectangle(cornerRadius: size == .car ? DSRadius.lg : DSRadius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(DSMotion.animation(DSMotion.quick, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

#Preview("PrimaryButton") {
    ScrollView {
        VStack(spacing: DSSpacing.md) {
            PrimaryButton("Add Playlist", systemImage: "plus") {}
            PrimaryButton("Import from Files", systemImage: "folder", kind: .secondary) {}
            PrimaryButton("Not now", kind: .tertiary) {}
            PrimaryButton("Remove Source", systemImage: "trash", kind: .destructive) {}
            PrimaryButton("Refreshing", isLoading: true) {}
            PrimaryButton("Disabled") {}.disabled(true)
            HStack {
                PrimaryButton("Compact", kind: .secondary, size: .compact, fullWidth: false) {}
                PrimaryButton("Retry", systemImage: "arrow.clockwise", size: .compact, fullWidth: false) {}
            }
            PrimaryButton("Play", systemImage: "play.fill", size: .car) {}
        }
        .padding(DSSpacing.screenGutter)
    }
    .background(Color.dcBackground)
    .preferredColorScheme(.dark)
}
