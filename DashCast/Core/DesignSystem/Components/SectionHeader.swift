import SwiftUI

/// Header for a Home shelf or list section: title, optional count/subtitle,
/// optional trailing "See All" action.
public struct SectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let count: Int?
    private let actionTitle: String
    private let action: (() -> Void)?

    public init(
        _ title: String,
        subtitle: String? = nil,
        count: Int? = nil,
        actionTitle: String = "See All",
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                    Text(title)
                        .font(DSTypography.title2)
                        .foregroundStyle(Color.dcTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let count {
                        Text("\(count)")
                            .font(DSTypography.numeric)
                            .foregroundStyle(Color.dcTextTertiary)
                            .accessibilityLabel(Text("\(count) items"))
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(DSTypography.subheadline)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            Spacer(minLength: DSSpacing.sm)
            if let action {
                Button(action: action) {
                    HStack(spacing: DSSpacing.xxs) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                    .frame(minHeight: DSLayout.minTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(actionTitle), \(title)"))
            }
        }
        .padding(.horizontal, DSSpacing.screenGutter)
    }
}

#Preview("SectionHeader") {
    VStack(alignment: .leading, spacing: DSSpacing.lg) {
        SectionHeader("Continue Watching", action: {})
        SectionHeader("News", count: 42, action: {})
        SectionHeader("Sources", subtitle: "Playlists, servers and files")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.dcBackground)
    .preferredColorScheme(.dark)
}
