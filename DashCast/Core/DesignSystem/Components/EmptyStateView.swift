import SwiftUI

/// Centered empty / error / loading placeholder used by every list and grid.
public struct EmptyStateView: View {
    public enum Kind { case empty, error, loading }

    private let kind: Kind
    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?
    private let secondaryActionTitle: String?
    private let secondaryAction: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 56

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.init(kind: .empty, systemImage: systemImage, title: title, message: message,
                  actionTitle: actionTitle, action: action,
                  secondaryActionTitle: secondaryActionTitle, secondaryAction: secondaryAction)
    }

    private init(
        kind: Kind,
        systemImage: String,
        title: String,
        message: String?,
        actionTitle: String?,
        action: (() -> Void)?,
        secondaryActionTitle: String?,
        secondaryAction: (() -> Void)?
    ) {
        self.kind = kind
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    /// Error state with a retry button.
    public static func error(
        title: String = "Something went wrong",
        message: String,
        retryTitle: String = "Try Again",
        retry: (() -> Void)? = nil
    ) -> EmptyStateView {
        EmptyStateView(kind: .error, systemImage: "exclamationmark.triangle", title: title, message: message,
                       actionTitle: retry == nil ? nil : retryTitle, action: retry,
                       secondaryActionTitle: nil, secondaryAction: nil)
    }

    /// Loading state (spinner + optional message).
    public static func loading(_ title: String = "Loading…", message: String? = nil) -> EmptyStateView {
        EmptyStateView(kind: .loading, systemImage: "", title: title, message: message,
                       actionTitle: nil, action: nil, secondaryActionTitle: nil, secondaryAction: nil)
    }

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            icon
            VStack(spacing: DSSpacing.sm) {
                Text(title)
                    .font(DSTypography.title3)
                    .foregroundStyle(Color.dcTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let message {
                    Text(message)
                        .font(DSTypography.callout)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .multilineTextAlignment(.center)

            if actionTitle != nil || secondaryActionTitle != nil {
                VStack(spacing: DSSpacing.sm) {
                    if let actionTitle, let action {
                        PrimaryButton(actionTitle, kind: kind == .error ? .secondary : .primary, action: action)
                    }
                    if let secondaryActionTitle, let secondaryAction {
                        PrimaryButton(secondaryActionTitle, kind: .tertiary, action: secondaryAction)
                    }
                }
                .frame(maxWidth: 320)
                .padding(.top, DSSpacing.sm)
            }
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(Color.dcAccent)
                .frame(height: iconSize)
        case .empty, .error:
            Image(systemName: systemImage)
                .font(.system(size: iconSize * 0.5, weight: .semibold))
                .foregroundStyle(kind == .error ? Color.dcWarning : Color.dcAccent)
                .frame(width: iconSize * 1.4, height: iconSize * 1.4)
                .background(
                    (kind == .error ? Color.dcWarning : Color.dcAccent).opacity(0.14),
                    in: Circle()
                )
                .accessibilityHidden(true)
        }
    }
}

#Preview("EmptyStateView") {
    TabView {
        EmptyStateView(
            systemImage: "tv",
            title: "Add your first source",
            message: "Import an M3U playlist link, connect a media server, or add videos from Files.",
            actionTitle: "Add Source", action: {},
            secondaryActionTitle: "Learn More", secondaryAction: {}
        )
        .tabItem { Text("Empty") }
        EmptyStateView.error(message: "The playlist could not be downloaded. Check the link and your connection.", retry: {})
            .tabItem { Text("Error") }
        EmptyStateView.loading("Loading channels…")
            .tabItem { Text("Loading") }
    }
    .background(Color.dcBackground)
    .preferredColorScheme(.dark)
}
