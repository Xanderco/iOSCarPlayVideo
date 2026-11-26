import SwiftUI

/// Localized copy keys for `SearchField`.
public enum SearchFieldCopy {
    nonisolated public static let defaultPromptString = "Search channels"
    nonisolated public static let sourcesPromptString = "Search sources"
    nonisolated public static let clearSearchString = "Clear search"
    nonisolated public static let cancelString = "Cancel"

    nonisolated public static let allLocalizationKeys: [String] = [
        defaultPromptString,
        sourcesPromptString,
        clearSearchString,
        cancelString
    ]

    @MainActor
    public static var clearSearchKey: LocalizedStringKey {
        LocalizedStringKey(clearSearchString)
    }

    @MainActor
    public static var cancelKey: LocalizedStringKey {
        LocalizedStringKey(cancelString)
    }
}

/// Rounded search field with clear and (when focused) Cancel buttons.
/// Use for searching channels, groups and sources.
public struct SearchField: View {
    @Binding private var text: String
    private let promptKey: LocalizedStringKey
    private let showsCancel: Bool
    private let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 40

    public init(
        text: Binding<String>,
        prompt: String = SearchFieldCopy.defaultPromptString,
        showsCancel: Bool = true,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.promptKey = LocalizedStringKey(prompt)
        self.showsCancel = showsCancel
        self.onSubmit = onSubmit
    }

    public init(
        text: Binding<String>,
        promptKey: LocalizedStringKey,
        showsCancel: Bool = true,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.promptKey = promptKey
        self.showsCancel = showsCancel
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.dcTextTertiary)
                    .accessibilityHidden(true)
                TextField(promptKey, text: $text)
                    .font(DSTypography.body)
                    .foregroundStyle(Color.dcTextPrimary)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { onSubmit?() }
                    .accessibilityLabel(Text(promptKey))
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.dcTextTertiary)
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(SearchFieldCopy.clearSearchKey))
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .frame(minHeight: max(height, DSLayout.minTapTarget - 4))
            .background(Color.dcSurfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .strokeBorder(isFocused ? Color.dcAccent : Color.clear, lineWidth: DSStroke.focus)
            )

            if showsCancel && isFocused {
                Button(SearchFieldCopy.cancelKey) {
                    text = ""
                    isFocused = false
                }
                .font(DSTypography.body)
                .foregroundStyle(Color.dcAccent)
                .buttonStyle(.plain)
                .frame(minHeight: DSLayout.minTapTarget)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion), value: isFocused)
        .padding(.horizontal, DSSpacing.screenGutter)
    }
}

private struct SearchFieldPreview: View {
    @State private var empty = ""
    @State private var filled = "news"

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            SearchField(text: $empty)
            SearchField(text: $filled, prompt: "Search sources")
        }
        .padding(.vertical, DSSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.dcBackground)
    }
}

#Preview("SearchField") {
    SearchFieldPreview()
        .preferredColorScheme(.dark)
}

#Preview("SearchField · Light") {
    SearchFieldPreview()
        .preferredColorScheme(.light)
}
