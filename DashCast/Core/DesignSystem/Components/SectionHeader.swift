import SwiftUI

/// Localized copy and VoiceOver accessibility formatting helpers for `SectionHeader`.
public enum SectionHeaderCopy {
    nonisolated public static let defaultActionTitleString = "See All"
    nonisolated public static let itemCountFormatString = "%lld items"
    nonisolated public static let actionAccessibilityFormatString = "%@, %@"

    nonisolated public static let allLocalizationKeys: [String] = [
        defaultActionTitleString,
        itemCountFormatString,
        actionAccessibilityFormatString
    ]

    @MainActor public static var defaultActionTitleKey: LocalizedStringKey {
        LocalizedStringKey(defaultActionTitleString)
    }

    nonisolated public static func itemCountAccessibilityLabel(count: Int, bundle: Bundle = .main) -> String {
        let format = bundle.localizedString(forKey: itemCountFormatString, value: itemCountFormatString, table: nil)
        return String(format: format, Int64(count))
    }

    nonisolated public static func actionAccessibilityLabel(
        actionTitle: String,
        title: String,
        bundle: Bundle = .main
    ) -> String {
        let localizedAction = bundle.localizedString(forKey: actionTitle, value: actionTitle, table: nil)
        let localizedTitle = bundle.localizedString(forKey: title, value: title, table: nil)
        let format = bundle.localizedString(
            forKey: actionAccessibilityFormatString,
            value: actionAccessibilityFormatString,
            table: nil
        )
        return String(format: format, localizedAction, localizedTitle)
    }
}

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
        actionTitle: String = SectionHeaderCopy.defaultActionTitleString,
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
                    Text(LocalizedStringKey(title))
                        .font(DSTypography.title2)
                        .foregroundStyle(Color.dcTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let count {
                        Text("\(count)")
                            .font(DSTypography.numeric)
                            .foregroundStyle(Color.dcTextTertiary)
                            .accessibilityLabel(Text(verbatim: SectionHeaderCopy.itemCountAccessibilityLabel(count: count)))
                    }
                }
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(DSTypography.subheadline)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            Spacer(minLength: DSSpacing.sm)
            if let action {
                Button(action: action) {
                    HStack(spacing: DSSpacing.xxs) {
                        Text(LocalizedStringKey(actionTitle))
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
                .accessibilityLabel(
                    Text(verbatim: SectionHeaderCopy.actionAccessibilityLabel(actionTitle: actionTitle, title: title))
                )
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
